import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CropOverlayPainter extends CustomPainter {
  final Rect cropArea;

  CropOverlayPainter(this.cropArea);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final cropRect = Rect.fromLTWH(
      cropArea.left * size.width,
      cropArea.top * size.height,
      cropArea.width * size.width,
      cropArea.height * size.height,
    );

    // Draw dark overlay outside crop area
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(overlayPath, paint);

    // Draw crop border
    final borderPaint = Paint()
      ..color = AppColors.primaryPurple
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(cropRect, borderPaint);

    // Draw corner handles
    final handlePaint = Paint()
      ..color = AppColors.primaryPurple
      ..style = PaintingStyle.fill;

    const handleSize = 8.0;
    final handles = [
      Offset(cropRect.left, cropRect.top),
      Offset(cropRect.right, cropRect.top),
      Offset(cropRect.left, cropRect.bottom),
      Offset(cropRect.right, cropRect.bottom),
    ];

    for (final handle in handles) {
      canvas.drawCircle(handle, handleSize, handlePaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
