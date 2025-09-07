import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Fixes common EXIF orientation issues by decoding and re-encoding the image.
Future<Uint8List> fixExifOrientation(Uint8List bytes) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final oriented = img.bakeOrientation(decoded);
  final out = img.encodeJpg(oriented, quality: 95);
  return Uint8List.fromList(out);
}


