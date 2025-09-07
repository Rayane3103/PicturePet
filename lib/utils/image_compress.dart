import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

Future<Uint8List> compressImage(Uint8List bytes, {int quality = 80}) async {
  final out = await FlutterImageCompress.compressWithList(
    bytes,
    quality: quality,
    format: CompressFormat.jpeg,
  );
  return Uint8List.fromList(out);
}

Future<Uint8List> generateThumbnail(Uint8List bytes, {int size = 256, int quality = 70}) async {
  final out = await FlutterImageCompress.compressWithList(
    bytes,
    minWidth: size,
    minHeight: size,
    quality: quality,
    format: CompressFormat.jpeg,
  );
  return Uint8List.fromList(out);
}


