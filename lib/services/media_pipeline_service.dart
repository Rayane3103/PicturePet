import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../services/media_capture_service.dart';
import '../utils/exif_fix.dart';
import '../utils/image_compress.dart';
import '../services/upload_queue_service.dart';

class MediaPipelineService {
  final MediaCaptureService _capture = MediaCaptureService();
  final UploadQueueService _queue = UploadQueueService.instance;

  Future<void> pickFromGalleryAndQueue({String? projectName}) async {
    final XFile? file = await _capture.pickFromGalleryFile();
    if (file == null) return;
    try {
      final raw = await file.readAsBytes();
      await _processAndQueue(raw, filename: 'gallery.jpg', contentType: 'image/jpeg', sourcePath: file.path, projectName: projectName);
    } catch (_) {
      // As a last resort, enqueue reading from path in processor (it re-reads bytes)
      _queue.enqueue(UploadTask(
        bytes: Uint8List(0),
        filename: 'gallery.jpg',
        contentType: 'image/jpeg',
        thumbnailBytes: null,
        metadata: const {},
        sourcePath: file.path,
        projectName: projectName,
      ));
    }
  }

  Future<void> captureFromCameraAndQueue({String? projectName}) async {
    final XFile? file = await _capture.captureFromCameraFile();
    if (file == null) return;
    try {
      final raw = await file.readAsBytes();
      await _processAndQueue(raw, filename: 'camera.jpg', contentType: 'image/jpeg', sourcePath: file.path, projectName: projectName);
    } catch (_) {
      _queue.enqueue(UploadTask(
        bytes: Uint8List(0),
        filename: 'camera.jpg',
        contentType: 'image/jpeg',
        thumbnailBytes: null,
        metadata: const {},
        sourcePath: file.path,
        projectName: projectName,
      ));
    }
  }

  Future<void> _processAndQueue(Uint8List bytes, {required String filename, required String contentType, String? sourcePath, String? projectName}) async {
    Uint8List oriented = bytes;
    Uint8List compressed = bytes;
    Uint8List thumb = bytes;
    try {
      oriented = await fixExifOrientation(bytes);
    } catch (_) {}
    try {
      compressed = await compressImage(oriented, quality: 85);
    } catch (_) {}
    try {
      thumb = await generateThumbnail(oriented, size: 256, quality: 70);
    } catch (_) {
      thumb = compressed;
    }

    _queue.enqueue(UploadTask(
      bytes: compressed,
      filename: filename,
      contentType: contentType,
      thumbnailBytes: thumb,
      metadata: const {},
      sourcePath: sourcePath,
      projectName: projectName,
    ));
  }
}
