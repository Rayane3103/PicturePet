import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class CropOverlayPainter extends CustomPainter {
  final Rect cropArea;
  final bool showGrid;

  CropOverlayPainter(this.cropArea, {this.showGrid = true});

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

    // Optional rule-of-thirds grid
    if (showGrid) {
      final gridPaint = Paint()
        ..color = AppColors.primaryPurple.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final double dx = cropRect.width / 3.0;
      final double dy = cropRect.height / 3.0;
      // Vertical
      canvas.drawLine(Offset(cropRect.left + dx, cropRect.top), Offset(cropRect.left + dx, cropRect.bottom), gridPaint);
      canvas.drawLine(Offset(cropRect.left + 2 * dx, cropRect.top), Offset(cropRect.left + 2 * dx, cropRect.bottom), gridPaint);
      // Horizontal
      canvas.drawLine(Offset(cropRect.left, cropRect.top + dy), Offset(cropRect.right, cropRect.top + dy), gridPaint);
      canvas.drawLine(Offset(cropRect.left, cropRect.top + 2 * dy), Offset(cropRect.right, cropRect.top + 2 * dy), gridPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
