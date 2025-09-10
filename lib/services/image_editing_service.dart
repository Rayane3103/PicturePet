import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_editor/image_editor.dart' as ie;
import 'package:image/image.dart' as img;

/// Provides image-editing operations backed by the `image_editor` plugin.
///
/// All coordinates for cropping are provided in normalized space [0,1] and
/// converted to pixel values using the decoded image dimensions.
class ImageEditingService {
  const ImageEditingService();

  /// Applies crop (normalized rect) and rotation (in degrees) to [bytes].
  Future<Uint8List> applyCropRotate({
    required Uint8List bytes,
    required double rotationDegrees,
    required double cropLeft,
    required double cropTop,
    required double cropWidth,
    required double cropHeight,
  }) async {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final int imageWidth = decoded.width;
    final int imageHeight = decoded.height;

    final int x = (cropLeft * imageWidth).clamp(0, imageWidth).round();
    final int y = (cropTop * imageHeight).clamp(0, imageHeight).round();
    final int w = (cropWidth * imageWidth).clamp(1, imageWidth - x).round();
    final int h = (cropHeight * imageHeight).clamp(1, imageHeight - y).round();

    final ie.ImageEditorOption option = ie.ImageEditorOption();
    option.addOption(ie.ClipOption(x: x, y: y, width: w, height: h));

    final int deg = rotationDegrees.round();
    if (deg % 360 != 0) {
      option.addOption(ie.RotateOption(deg));
    }

    final Uint8List? result = await ie.ImageEditor.editImage(
      image: bytes,
      imageEditorOption: option,
    );
    return result ?? bytes;
  }

  /// Applies a 4x5 color matrix to the image.
  Future<Uint8List> applyColorMatrix({
    required Uint8List bytes,
    required List<double> matrix,
  }) async {
    final ie.ImageEditorOption option = ie.ImageEditorOption();
    option.addOption(ie.ColorOption(matrix: matrix));
    final Uint8List? result = await ie.ImageEditor.editImage(
      image: bytes,
      imageEditorOption: option,
    );
    return result ?? bytes;
  }

  /// Adjusts image using brightness/contrast/saturation by converting to a color matrix.
  /// brightness in [-1,1], contrast >= 0, saturation >= 0
  Future<Uint8List> adjust({
    required Uint8List bytes,
    double brightness = 0.0,
    double contrast = 1.0,
    double saturation = 1.0,
  }) async {
    final List<double> m = _composeAdjustMatrix(
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );
    return applyColorMatrix(bytes: bytes, matrix: m);
  }

  /// Draws simple text onto the image at pixel position (x, y).
  /// Note: Uses AddTextOption via platform interface.
  Future<Uint8List> drawText({
    required Uint8List bytes,
    required String text,
    required int x,
    required int y,
    int fontSize = 32,
    int a = 255,
    int r = 255,
    int g = 255,
    int b = 255,
    TextAlign textAlign = TextAlign.left,
    String fontName = '',
  }) async {
    final ie.AddTextOption addText = ie.AddTextOption();
    addText.addText(
      ie.EditorText(
        text: text,
        offset: Offset(x.toDouble(), y.toDouble()),
        fontSizePx: fontSize,
        textColor: Color.fromARGB(a, r, g, b),
        textAlign: textAlign,
        fontName: fontName,
      ),
    );
    final ie.ImageEditorOption option = ie.ImageEditorOption();
    option.addOption(addText);
    final Uint8List? result = await ie.ImageEditor.editImage(
      image: bytes,
      imageEditorOption: option,
    );
    return result ?? bytes;
  }

  // Builds a color matrix from brightness/contrast/saturation adjustments.
  List<double> _composeAdjustMatrix({
    required double brightness,
    required double contrast,
    required double saturation,
  }) {
    // Based on standard color matrix composition.
    final double b = (brightness * 255.0);
    final double c = contrast;
    final double s = saturation;

    // Luminance constants
    const double lr = 0.2126;
    const double lg = 0.7152;
    const double lb = 0.0722;

    // Saturation matrix
    final double sr = (1 - s) * lr;
    final double sg = (1 - s) * lg;
    final double sb = (1 - s) * lb;

    final List<double> satM = <double>[
      sr + s, sg,     sb,     0, 0,
      sr,     sg + s, sb,     0, 0,
      sr,     sg,     sb + s, 0, 0,
      0,      0,      0,      1, 0,
    ];

    // Contrast matrix
    final double t = (1.0 - c) * 128.0;
    final List<double> conM = <double>[
      c, 0, 0, 0, -t,
      0, c, 0, 0, -t,
      0, 0, c, 0, -t,
      0, 0, 0, 1, 0,
    ];

    // Brightness matrix
    final List<double> brightM = <double>[
      1, 0, 0, 0, b,
      0, 1, 0, 0, b,
      0, 0, 1, 0, b,
      0, 0, 0, 1, 0,
    ];

    return _multiplyColorMatrices(_multiplyColorMatrices(satM, conM), brightM);
  }

  List<double> _multiplyColorMatrices(List<double> a, List<double> b) {
    // Both are 4x5 matrices.
    final List<double> out = List<double>.filled(20, 0);
    for (int row = 0; row < 4; row++) {
      for (int col = 0; col < 5; col++) {
        out[row * 5 + col] =
            a[row * 5 + 0] * b[0 * 5 + col] +
            a[row * 5 + 1] * b[1 * 5 + col] +
            a[row * 5 + 2] * b[2 * 5 + col] +
            a[row * 5 + 3] * b[3 * 5 + col] +
            (col == 4 ? a[row * 5 + 4] : 0);
      }
    }
    return out;
  }
}


