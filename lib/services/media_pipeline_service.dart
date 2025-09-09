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
    final raw = await file.readAsBytes();
    await _processAndQueue(raw, filename: 'gallery.jpg', contentType: 'image/jpeg', sourcePath: file.path, projectName: projectName);
  }

  Future<void> captureFromCameraAndQueue({String? projectName}) async {
    final XFile? file = await _capture.captureFromCameraFile();
    if (file == null) return;
    final raw = await file.readAsBytes();
    await _processAndQueue(raw, filename: 'camera.jpg', contentType: 'image/jpeg', sourcePath: file.path, projectName: projectName);
  }

  Future<void> _processAndQueue(Uint8List bytes, {required String filename, required String contentType, String? sourcePath, String? projectName}) async {
    final oriented = await fixExifOrientation(bytes);
    final compressed = await compressImage(oriented, quality: 85);
    final thumb = await generateThumbnail(oriented, size: 256, quality: 70);

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
