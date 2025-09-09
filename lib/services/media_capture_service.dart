import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class MediaCaptureService {
  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> pickFromGallery({bool imagesOnly = true}) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: true,
    );
    if (file == null) return null;
    return await file.readAsBytes();
  }

  Future<Uint8List?> captureFromCamera() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      requestFullMetadata: true,
    );
    if (file == null) return null;
    return await file.readAsBytes();
  }

  Future<XFile?> pickFromGalleryFile() async {
    return _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: true,
    );
  }

  Future<XFile?> captureFromCameraFile() async {
    return _picker.pickImage(
      source: ImageSource.camera,
      requestFullMetadata: true,
    );
  }
}


