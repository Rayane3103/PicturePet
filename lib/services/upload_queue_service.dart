import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/media_repository.dart';
import '../utils/image_compress.dart';
import '../utils/logger.dart';
import 'fal_ai_service.dart';

enum UploadTaskType { upload, aiGenerate }

UploadTaskType _taskTypeFromString(String? raw) {
  switch (raw) {
    case 'aiGenerate':
      return UploadTaskType.aiGenerate;
    case 'upload':
    default:
      return UploadTaskType.upload;
  }
}

class UploadTask {
  UploadTask({
    required Uint8List bytes,
    required this.filename,
    required this.contentType,
    Uint8List? thumbnailBytes,
    this.thumbnailContentType = 'image/jpeg',
    Map<String, dynamic>? metadata,
    String? sourcePath,
    this.projectName,
    this.type = UploadTaskType.upload,
    this.aiPrompt,
    Map<String, dynamic>? aiOptions,
  })  : bytes = bytes,
        thumbnailBytes = thumbnailBytes,
        sourcePath = sourcePath,
        metadata = metadata != null ? Map<String, dynamic>.from(metadata) : <String, dynamic>{},
        aiOptions = aiOptions != null ? Map<String, dynamic>.from(aiOptions) : <String, dynamic>{};

  Uint8List bytes;
  final String filename;
  final String contentType;
  Uint8List? thumbnailBytes;
  final String thumbnailContentType;
  final Map<String, dynamic> metadata;
  String? sourcePath;
  final String? projectName;
  final UploadTaskType type;
  final String? aiPrompt;
  final Map<String, dynamic> aiOptions;

  int uploadedBytes = 0;
  bool cancelled = false;
  Completer<void>? _completer;

  Future<void> cancel() async {
    cancelled = true;
    _completer?.completeError(StateError('cancelled'));
  }

  UploadTask copyWith({
    Uint8List? bytes,
    Uint8List? thumbnailBytes,
    String? sourcePath,
    Map<String, dynamic>? metadata,
    UploadTaskType? type,
    String? aiPrompt,
    Map<String, dynamic>? aiOptions,
  }) {
    final updated = UploadTask(
      bytes: bytes ?? this.bytes,
      filename: filename,
      contentType: contentType,
      thumbnailBytes: thumbnailBytes ?? this.thumbnailBytes,
      thumbnailContentType: thumbnailContentType,
      metadata: metadata ?? this.metadata,
      sourcePath: sourcePath ?? this.sourcePath,
      projectName: projectName,
      type: type ?? this.type,
      aiPrompt: aiPrompt ?? this.aiPrompt,
      aiOptions: aiOptions ?? this.aiOptions,
    )
      ..uploadedBytes = uploadedBytes
      ..cancelled = cancelled;
    if (_completer != null) {
      updated._completer = _completer;
    }
    return updated;
  }

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'contentType': contentType,
        'thumbnailContentType': thumbnailContentType,
        'metadata': metadata,
        'sourcePath': sourcePath,
        'projectName': projectName,
        'type': type.name,
        'aiPrompt': aiPrompt,
        if (aiOptions.isNotEmpty) 'aiOptions': aiOptions,
      };

  static UploadTask fromJson(Map<String, dynamic> json) {
    return UploadTask(
      bytes: Uint8List(0),
      filename: json['filename'] as String,
      contentType: (json['contentType'] as String?) ?? 'image/jpeg',
      thumbnailBytes: null,
      thumbnailContentType: (json['thumbnailContentType'] as String?) ?? 'image/jpeg',
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      sourcePath: json['sourcePath'] as String?,
      projectName: json['projectName'] as String?,
      type: _taskTypeFromString(json['type'] as String?),
      aiPrompt: json['aiPrompt'] as String?,
      aiOptions: Map<String, dynamic>.from(json['aiOptions'] as Map? ?? {}),
    );
  }
}

class UploadQueueService {
  UploadQueueService._internal({MediaRepository? repo, FalAiService? fal})
      : _repo = repo ?? MediaRepository(),
        _fal = fal ?? FalAiService();

  static final UploadQueueService instance = UploadQueueService._internal();

  factory UploadQueueService({MediaRepository? repo, FalAiService? fal}) {
    if (repo != null || fal != null) {
      return UploadQueueService._internal(repo: repo, fal: fal);
    }
    return instance;
  }

  final MediaRepository _repo;
  final FalAiService _fal;

  final List<UploadTask> _queue = [];
  bool _isProcessing = false;
  final Map<String, UploadTask> _failedTasks = {};

  final StreamController<Map<String, dynamic>> _events = StreamController.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  /// Emit a custom event to the events stream
  void emitEvent(Map<String, dynamic> event) {
    _events.add(event);
  }

  void enqueue(UploadTask task, {bool emitPreparing = false, String? stage}) {
    _queue.add(task);
    if (emitPreparing) {
      _events.add({
        'type': 'preparing',
        'filename': task.filename,
        'stage': stage ?? (task.type == UploadTaskType.aiGenerate ? 'generating' : 'uploading'),
        if (task.aiPrompt != null) 'prompt': task.aiPrompt,
      });
    }
    unawaited(_persistQueue());
    _process();
  }

  void enqueueAiGeneration({
    required String prompt,
    required String filename,
    String contentType = 'image/jpeg',
    String? projectName,
    Map<String, dynamic> metadata = const {},
  }) {
    final mergedMetadata = <String, dynamic>{...metadata, 'prompt': prompt};
    enqueue(
      UploadTask(
        bytes: Uint8List(0),
        filename: filename,
        contentType: contentType,
        thumbnailBytes: null,
        metadata: mergedMetadata,
        projectName: projectName,
        type: UploadTaskType.aiGenerate,
        aiPrompt: prompt,
      ),
      emitPreparing: true,
      stage: 'generating',
    );
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
      for (final task in _queue) {
        final restoredStage = task.type == UploadTaskType.aiGenerate
            ? (task.sourcePath != null ? 'uploading' : 'generating')
            : 'uploading';
        _events.add({
          'type': 'preparing',
          'filename': task.filename,
          'stage': restoredStage,
          if (task.aiPrompt != null) 'prompt': task.aiPrompt,
        });
      }
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
      var task = _queue.first;
      if (task.cancelled) {
        _queue.removeAt(0);
        await _persistQueue();
        continue;
      }
      Uint8List bytes = task.bytes;
      Uint8List? thumbnailBytes = task.thumbnailBytes;
      String? sourcePath = task.sourcePath;
      bool createdTempFile = false;
      try {
        final initialStage = task.type == UploadTaskType.aiGenerate ? 'generating' : 'uploading';
        _events.add({'type': 'started', 'filename': task.filename, 'stage': initialStage});

        if (task.type == UploadTaskType.aiGenerate) {
          final prompt = task.aiPrompt ?? (task.metadata['prompt'] as String?);
          if (prompt == null || prompt.trim().isEmpty) {
            throw Exception('AI prompt missing for ${task.filename}');
          }
          double genProgress = 0.05;
          _events.add({'type': 'progress', 'filename': task.filename, 'stage': 'generating', 'progress': genProgress});
          Timer? genTicker;
          bool generationCompleted = false;
          try {
            genTicker = Timer.periodic(const Duration(milliseconds: 400), (timer) {
              if (generationCompleted) {
                timer.cancel();
                return;
              }
              final remaining = 0.65 - genProgress;
              final step = (remaining * 0.2).clamp(0.01, 0.06);
              genProgress = (genProgress + step).clamp(0.05, 0.65);
              _events.add({'type': 'progress', 'filename': task.filename, 'stage': 'generating', 'progress': genProgress});
            });
          } catch (_) {}

          final rawBytes = await _fal.imagen4Generate(prompt: prompt);
          Uint8List processed = rawBytes;
          try {
            processed = await compressImage(rawBytes, quality: 90);
          } catch (_) {}
          Uint8List? thumb;
          try {
            thumb = await generateThumbnail(processed, size: 384, quality: 75);
          } catch (_) {}

          final tempPath = await _writeTempFile(processed, task.filename);
          createdTempFile = true;
          bytes = processed;
          thumbnailBytes = thumb ?? processed;
          sourcePath = tempPath;

          task = task.copyWith(
            bytes: bytes,
            thumbnailBytes: thumbnailBytes,
            sourcePath: sourcePath,
          );
          _queue[0] = task;
          await _persistQueue();

          generationCompleted = true;
          try {
            genTicker?.cancel();
          } catch (_) {}
          _events.add({'type': 'progress', 'filename': task.filename, 'stage': 'processing', 'progress': 0.7});
        }

        await _ensureOnline();

        if (bytes.isEmpty && sourcePath != null) {
          bytes = await File(sourcePath).readAsBytes();
        }

        double simulatedProgress = task.type == UploadTaskType.aiGenerate ? 0.72 : 0.05;
        _events.add({
          'type': 'progress',
          'filename': task.filename,
          'stage': 'uploading',
          'progress': simulatedProgress,
        });

        Timer? uploadTicker;
        bool uploadCompleted = false;
        try {
          uploadTicker = Timer.periodic(const Duration(milliseconds: 200), (timer) {
            if (uploadCompleted) {
              timer.cancel();
              return;
            }
            final maxProgress = 0.93;
            final remaining = maxProgress - simulatedProgress;
            final step = (remaining * 0.25).clamp(0.01, 0.05);
            simulatedProgress = (simulatedProgress + step).clamp(0.05, maxProgress);
            _events.add({
              'type': 'progress',
              'filename': task.filename,
              'stage': 'uploading',
              'progress': simulatedProgress,
            });
          });
        } catch (_) {}

        final uploadedMedia = await _repo.uploadBytes(
          bytes: bytes,
          filename: task.filename,
          contentType: task.contentType,
          thumbnailBytes: thumbnailBytes,
          thumbnailContentType: task.thumbnailContentType,
          metadata: task.metadata,
          projectName: task.projectName,
        );
        uploadCompleted = true;
        try {
          uploadTicker?.cancel();
        } catch (_) {}

        _events.add({'type': 'progress', 'filename': task.filename, 'stage': 'finalizing', 'progress': 0.97});
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

        _queue.removeAt(0);
        await _persistQueue();
        if (createdTempFile && sourcePath != null) {
          await _deleteTempFile(sourcePath);
        }
      } catch (e) {
        Logger.error('Upload failed', context: {'error': e.toString(), 'filename': task.filename});
        _failedTasks[task.filename] = task;
        _queue.removeAt(0);
        await _persistQueue();
        if (createdTempFile && sourcePath != null) {
          await _deleteTempFile(sourcePath);
        }
        final isOffline = _isOfflineError(e);
        _events.add({
          'type': 'failed',
          'filename': task.filename,
          'error': e.toString(),
          if (isOffline) 'code': 'offline',
          if (isOffline) 'message': 'No internet connection',
        });
      }
    }
    _isProcessing = false;
  }

  Future<String> _writeTempFile(Uint8List bytes, String filename) async {
    final dir = await getTemporaryDirectory();
    final sanitized = filename.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File('${dir.path}/upload_$sanitized');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _deleteTempFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
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


