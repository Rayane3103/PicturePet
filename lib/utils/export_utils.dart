// Export utilities for saving and sharing rendered editor images.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

enum ExportFormat { png, jpeg }

class ExportOptions {
  final ExportFormat format;
  final int quality;
  final double scale;
  final bool includeMetadata;
  final String? watermark;
  final bool transparentBackground;
  const ExportOptions({
    required this.format,
    required this.quality,
    required this.scale,
    required this.includeMetadata,
    this.watermark,
    this.transparentBackground = true,
  });
}

class ExportResult {
  final bool success;
  final String? path;
  final String? error;
  const ExportResult({required this.success, this.path, this.error});
}

Future<Uint8List> renderEditorToBytes({Uint8List? directBytes, ui.Image? image}) async {
  if (directBytes != null) return directBytes;
  if (image != null) {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) return byteData.buffer.asUint8List();
  }
  throw Exception('No source provided for rendering');
}

Future<Uint8List> _applyScaleWatermarkAndFlatten(
  Uint8List inputBytes,
  ExportOptions options,
) async {
  img.Image? decoded = img.decodeImage(inputBytes);
  if (decoded == null) return inputBytes;

  if (options.scale != 1.0 && options.scale > 0) {
    final int newW = (decoded.width * options.scale).round().clamp(1, 100000);
    final int newH = (decoded.height * options.scale).round().clamp(1, 100000);
    decoded = img.copyResize(decoded, width: newW, height: newH, interpolation: img.Interpolation.average);
  }

  // watermark removed by request

  if (options.format == ExportFormat.jpeg || (options.format == ExportFormat.png && !options.transparentBackground)) {
    final img.Image flattened = img.Image(width: decoded.width, height: decoded.height);
    img.fill(flattened, color: img.ColorUint8.rgba(255, 255, 255, 255));
    img.compositeImage(flattened, decoded);
    decoded = flattened;
  }

  if (options.format == ExportFormat.png) {
    final out = img.encodePng(decoded, level: 6);
    return Uint8List.fromList(out);
  } else {
    final q = options.quality.clamp(1, 100);
    final out = img.encodeJpg(decoded, quality: q);
    return Uint8List.fromList(out);
  }
}

Future<Uint8List> encodeToFormat(Uint8List inputBytes, ExportOptions options) async {
  try {
    return await _applyScaleWatermarkAndFlatten(inputBytes, options);
  } catch (_) {
    try {
      if (options.format == ExportFormat.png) {
        final out = await FlutterImageCompress.compressWithList(
          inputBytes,
          quality: 100,
          format: CompressFormat.png,
        );
        return Uint8List.fromList(out);
      } else {
        final out = await FlutterImageCompress.compressWithList(
          inputBytes,
          quality: options.quality.clamp(1, 100),
          format: CompressFormat.jpeg,
        );
        return Uint8List.fromList(out);
      }
    } catch (_) {
      return inputBytes;
    }
  }
}

Future<Uint8List> compressImageBytes(Uint8List bytes, int quality) async {
  try {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      quality: quality.clamp(1, 100),
      format: CompressFormat.jpeg,
    );
    return Uint8List.fromList(out);
  } catch (_) {
    return bytes;
  }
}

Future<ExportResult> saveToGallery(Uint8List bytes, String filename, ExportOptions options) async {
  try {
    final permitted = await ensurePermissionsForSave();
    if (!permitted) {
      return const ExportResult(success: false, error: 'Permission denied');
    }
    final String ext = options.format == ExportFormat.png ? '.png' : '.jpg';
    final String safeName = filename.endsWith(ext) ? filename : filename + ext;
    await Gal.putImageBytes(bytes, name: safeName, album: 'PicturePet');
    return const ExportResult(success: true, path: null);
  } catch (e) {
    return ExportResult(success: false, error: e.toString());
  }
}

Future<ExportResult> saveToTempAndShare(Uint8List bytes, String filename, ExportOptions options) async {
  try {
    final Directory dir = await getTemporaryDirectory();
    final String ext = options.format == ExportFormat.png ? '.png' : '.jpg';
    final String safeName = filename.endsWith(ext) ? filename : filename + ext;
    final String fullPath = p.join(dir.path, safeName);
    final file = File(fullPath);
    await file.writeAsBytes(bytes, flush: true);
    final mime = options.format == ExportFormat.png ? 'image/png' : 'image/jpeg';
    await Share.shareXFiles([XFile(fullPath, mimeType: mime)]);
    return ExportResult(success: true, path: fullPath);
  } catch (e) {
    return ExportResult(success: false, error: e.toString());
  }
}

Future<bool> ensurePermissionsForSave() async {
  try {
    final has = await Gal.hasAccess();
    if (has == true) return true;
    final req = await Gal.requestAccess();
    if (req == true) return true;
  } catch (_) {}
  try {
    if (Platform.isIOS) {
      final status = await Permission.photos.status;
      if (status.isGranted) return true;
      final req = await Permission.photos.request();
      return req.isGranted;
    }
    if (Platform.isAndroid) {
      final sdkInt = (await _androidSdkInt());
      if (sdkInt >= 33) {
        var st = await Permission.storage.status;
        if (st.isGranted) return true;
        st = await Permission.storage.request();
        if (st.isGranted) return true;
        return await Permission.manageExternalStorage.isGranted || (await Permission.manageExternalStorage.request()).isGranted;
      } else {
        var status = await Permission.storage.status;
        if (status.isGranted) return true;
        status = await Permission.storage.request();
        return status.isGranted;
      }
    }
  } catch (_) {}
  return false;
}

Future<int> _androidSdkInt() async {
  try {
    final file = File('/system/build.prop');
    if (await file.exists()) {
      final s = await file.readAsString();
      final line = s.split('\n').firstWhere(
        (l) => l.startsWith('ro.build.version.sdk='),
        orElse: () => '',
      );
      if (line.isNotEmpty) {
        return int.tryParse(line.split('=').last.trim()) ?? 30;
      }
    }
  } catch (_) {}
  return 30;
}

String buildFileName({required ExportFormat format}) {
  final now = DateTime.now();
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  final hh = now.hour.toString().padLeft(2, '0');
  final mm = now.minute.toString().padLeft(2, '0');
  final ss = now.second.toString().padLeft(2, '0');
  final ext = format == ExportFormat.png ? 'png' : 'jpg';
  return 'PicturePet_${y}${m}${d}_${hh}${mm}${ss}.$ext';
}


