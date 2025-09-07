import 'dart:typed_data';
import '../services/media_capture_service.dart';
import '../utils/exif_fix.dart';
import '../utils/image_compress.dart';
import '../services/upload_queue_service.dart';

class MediaPipelineService {
  final MediaCaptureService _capture = MediaCaptureService();
  final UploadQueueService _queue = UploadQueueService.instance;

  Future<void> pickFromGalleryAndQueue() async {
    final raw = await _capture.pickFromGallery();
    if (raw == null) return;
    await _processAndQueue(raw, filename: 'gallery.jpg', contentType: 'image/jpeg');
  }

  Future<void> captureFromCameraAndQueue() async {
    final raw = await _capture.captureFromCamera();
    if (raw == null) return;
    await _processAndQueue(raw, filename: 'camera.jpg', contentType: 'image/jpeg');
  }

  Future<void> _processAndQueue(Uint8List bytes, {required String filename, required String contentType}) async {
    final oriented = await fixExifOrientation(bytes);
    final compressed = await compressImage(oriented, quality: 85);
    final thumb = await generateThumbnail(oriented, size: 256, quality: 70);

    _queue.enqueue(UploadTask(
      bytes: compressed,
      filename: filename,
      contentType: contentType,
      thumbnailBytes: thumb,
      metadata: const {},
    ));
  }
}
