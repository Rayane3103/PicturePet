import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

Future<Uint8List> compressImage(Uint8List bytes, {int quality = 80}) async {
  try {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    if (out.isNotEmpty) {
      return Uint8List.fromList(out);
    }
  } catch (_) {}
  // Fallback: try dart image encodeJpg; if decode fails, return original
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final out = img.encodeJpg(decoded, quality: quality.clamp(1, 100));
      return Uint8List.fromList(out);
    }
  } catch (_) {}
  return bytes;
}

Future<Uint8List> generateThumbnail(Uint8List bytes, {int size = 256, int quality = 70}) async {
  try {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: size,
      minHeight: size,
      quality: quality,
      format: CompressFormat.jpeg,
    );
    if (out.isNotEmpty) {
      return Uint8List.fromList(out);
    }
  } catch (_) {}
  // Fallback: use dart image to resize; if decode fails, return original
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded != null) {
      final resized = img.copyResize(decoded, width: size, height: size);
      final out = img.encodeJpg(resized, quality: quality.clamp(1, 100));
      return Uint8List.fromList(out);
    }
  } catch (_) {}
  return bytes;
}


