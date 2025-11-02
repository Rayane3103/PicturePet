import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/media_repository.dart';
import '../utils/logger.dart';

class UploadTask {
  final Uint8List bytes;
  final String filename;
  final String contentType;
  final Uint8List? thumbnailBytes;
  final String thumbnailContentType;
  final Map<String, dynamic> metadata;
  final String? sourcePath;
  final String? projectName;

  int uploadedBytes = 0;
  bool cancelled = false;
  Completer<void>? _completer;

  UploadTask({
    required this.bytes,
    required this.filename,
    required this.contentType,
    this.thumbnailBytes,
    this.thumbnailContentType = 'image/jpeg',
    this.metadata = const {},
    this.sourcePath,
    this.projectName,
  });

  Future<void> cancel() async {
    cancelled = true;
    _completer?.completeError(StateError('cancelled'));
  }

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'contentType': contentType,
        'thumbnailContentType': thumbnailContentType,
        'metadata': metadata,
        'sourcePath': sourcePath,
        'projectName': projectName,
      };

  static UploadTask fromJson(Map<String, dynamic> json) {
    return UploadTask(
      bytes: Uint8List(0),
      filename: json['filename'] as String,
      contentType: json['contentType'] as String,
      thumbnailBytes: null,
      thumbnailContentType: (json['thumbnailContentType'] as String?) ?? 'image/jpeg',
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      sourcePath: json['sourcePath'] as String?,
      projectName: json['projectName'] as String?,
    );
  }
}

class UploadQueueService {
  UploadQueueService._internal({MediaRepository? repo}) : _repo = repo ?? MediaRepository();
  static final UploadQueueService instance = UploadQueueService._internal();
  factory UploadQueueService({MediaRepository? repo}) {
    if (repo != null) return UploadQueueService._internal(repo: repo);
    return instance;
  }
  final MediaRepository _repo;

  final List<UploadTask> _queue = [];
  bool _isProcessing = false;
  final Map<String, UploadTask> _failedTasks = {};

  final StreamController<Map<String, dynamic>> _events = StreamController.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Emit a custom event to the events stream
  void emitEvent(Map<String, dynamic> event) {
    _events.add(event);
  }

  void enqueue(UploadTask task, {bool emitPreparing = false}) {
    _queue.add(task);
    if (emitPreparing) {
      _events.add({'type': 'preparing', 'filename': task.filename});
    }
    _persistQueue();
    _process();
  }

  /// Re-enqueue a failed upload by filename, if there was a matching task persisted.
  /// Returns true if a task was scheduled.
  bool retry(String filename) {
    // Prefer the last failed task snapshot
    final failed = _failedTasks.remove(filename);
    if (failed != null) {
      failed.cancelled = false;
      enqueue(failed);
      return true;
    }
    // Fallback: if still in queue
    try {
      final existing = _queue.firstWhere((t) => t.filename == filename);
      existing.cancelled = false;
      enqueue(existing);
      return true;
    } catch (_) {
      _events.add({'type': 'failed', 'filename': filename, 'error': 'original task not found'});
      return false;
    }
  }

  Future<void> restoreQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('upload_queue') ?? [];
    _queue.clear();
    for (final item in list) {
      try {
        final map = await _decode(item);
        _queue.add(UploadTask.fromJson(map));
      } catch (_) {}
    }
    if (_queue.isNotEmpty) {
      _process();
    }
  }

  Future<void> _persistQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final list = <String>[];
    for (final t in _queue) {
      list.add(await _encode(t.toJson()));
    }
    await prefs.setStringList('upload_queue', list);
  }

  Future<String> _encode(Map<String, dynamic> json) async => jsonEncode(json);
  Future<Map<String, dynamic>> _decode(String s) async => Map<String, dynamic>.from(jsonDecode(s) as Map);

  Future<void> _process() async {
    if (_isProcessing) return;
    _isProcessing = true;
    while (_queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      try {
        _events.add({'type': 'started', 'filename': task.filename});
        if (task.cancelled) throw StateError('cancelled');
        Uint8List bytes = task.bytes;
        if (bytes.isEmpty && task.sourcePath != null) {
          bytes = await File(task.sourcePath!).readAsBytes();
        }
        // Before uploading, ensure we have connectivity
        await _ensureOnline();

        // Emit initial progress
        _events.add({'type': 'progress', 'filename': task.filename, 'stage': 'uploading', 'progress': 0.01});

        // Simulated smooth progress while awaiting network I/O
        double simulatedProgress = 0.01;
        bool uploadCompleted = false;
        Timer? ticker;
        try {
          ticker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
            if (uploadCompleted) {
              timer.cancel();
              return;
            }
            final remaining = 0.85 - simulatedProgress;
            final step = (remaining * 0.15).clamp(0.005, 0.05);
            simulatedProgress = (simulatedProgress + step).clamp(0.01, 0.85);
            _events.add({'type': 'progress', 'filename': task.filename, 'stage': 'uploading', 'progress': simulatedProgress});
          });
        } catch (_) {}

        final uploadedMedia = await _repo.uploadBytes(
          bytes: bytes,
          filename: task.filename,
          contentType: task.contentType,
          thumbnailBytes: task.thumbnailBytes,
          thumbnailContentType: task.thumbnailContentType,
          metadata: task.metadata,
          projectName: task.projectName,
        );
        uploadCompleted = true;
        try { ticker?.cancel(); } catch (_) {}
        _events.add({'type': 'progress', 'filename': task.filename, 'stage': 'finalizing', 'progress': 0.95});
        final mediaJson = _serializeMedia(uploadedMedia);
        final createdProjectId = (mediaJson['metadata'] is Map && mediaJson['metadata']['created_project_id'] is String)
            ? mediaJson['metadata']['created_project_id'] as String
            : null;
        _events.add({
          'type': 'completed',
          'filename': task.filename,
          'media': mediaJson,
          if (createdProjectId != null) 'project_id': createdProjectId,
        });
      } catch (e) {
        Logger.error('Upload failed', context: {'error': e.toString(), 'filename': task.filename});
        // Keep a reference for retry
        _failedTasks[task.filename] = task;
        final isOffline = _isOfflineError(e);
        _events.add({
          'type': 'failed',
          'filename': task.filename,
          'error': e.toString(),
          if (isOffline) 'code': 'offline',
          if (isOffline) 'message': 'No internet connection',
        });
      }
      await _persistQueue();
    }
    _isProcessing = false;
  }

  Map<String, dynamic> _serializeMedia(dynamic media) {
    try {
      // MediaItem has toMap
      // ignore: avoid_dynamic_calls
      return Map<String, dynamic>.from(media.toMap() as Map);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _ensureOnline() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isEmpty || result.first.rawAddress.isEmpty) {
        throw const SocketException('No internet');
      }
    } catch (_) {
      throw const SocketException('No internet');
    }
  }

  bool _isOfflineError(Object e) {
    if (e is SocketException) return true;
    final text = e.toString().toLowerCase();
    return text.contains('failed host lookup') || text.contains('network is unreachable') || text.contains('no internet');
  }
}


