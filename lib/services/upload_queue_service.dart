import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/media_repository.dart';
import '../utils/retry.dart';
import '../utils/logger.dart';

class UploadTask {
  final Uint8List bytes;
  final String filename;
  final String contentType;
  final Uint8List? thumbnailBytes;
  final String thumbnailContentType;
  final Map<String, dynamic> metadata;
  final String? sourcePath;

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

  final StreamController<Map<String, dynamic>> _events = StreamController.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  void enqueue(UploadTask task) {
    _queue.add(task);
    _persistQueue();
    _process();
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
        await retry(() async {
          if (task.cancelled) throw StateError('cancelled');
          Uint8List bytes = task.bytes;
          if (bytes.isEmpty && task.sourcePath != null) {
            bytes = await File(task.sourcePath!).readAsBytes();
          }
          await _repo.uploadBytes(
            bytes: bytes,
            filename: task.filename,
            contentType: task.contentType,
            thumbnailBytes: task.thumbnailBytes,
            thumbnailContentType: task.thumbnailContentType,
            metadata: task.metadata,
          );
        });
        _events.add({'type': 'completed', 'filename': task.filename});
      } catch (e) {
        Logger.error('Upload failed', context: {'error': e.toString(), 'filename': task.filename});
        _events.add({'type': 'failed', 'filename': task.filename, 'error': e.toString()});
      }
      await _persistQueue();
    }
    _isProcessing = false;
  }
}


