import 'package:flutter/material.dart';

class CropRotateTool {
  // State variables
  bool showCropRotateView = false;
  double rotationAngle = 0.0;
  String selectedAspectRatio = 'Free';
  Rect cropArea = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
  double appliedRotationAngle = 0.0;
  Rect appliedCropArea = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
  
  // Gesture handling
  Offset? lastPanPosition;
  String? draggedHandle;

  // Aspect ratio presets
  final List<Map<String, dynamic>> aspectRatios = [
    {'name': 'Free', 'ratio': null},
    {'name': '1:1', 'ratio': 1.0},
    {'name': '4:5', 'ratio': 4/5},
    {'name': '16:9', 'ratio': 16/9},
    {'name': '3:2', 'ratio': 3/2},
    {'name': '2:3', 'ratio': 2/3},
  ];

  // Initialize crop view
  void initializeCropView() {
    rotationAngle = appliedRotationAngle;
    cropArea = appliedCropArea;
  }

  // Update crop area for aspect ratio
  void updateCropAreaForAspectRatio(double? ratio) {
    if (ratio == null) {
      // Free aspect ratio - reset to default
      cropArea = const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8);
    } else {
      // Calculate crop area based on aspect ratio
      double width = 0.8;
      double height = 0.8;
      
      if (ratio > 1.0) {
        // Landscape - height is limiting factor
        height = 0.8;
        width = height * ratio;
        if (width > 0.8) {
          width = 0.8;
          height = width / ratio;
        }
      } else {
        // Portrait or square - width is limiting factor
        width = 0.8;
        height = width / ratio;
        if (height > 0.8) {
          height = 0.8;
          width = height * ratio;
        }
      }
      
      // Center the crop area
      double left = (1.0 - width) / 2;
      double top = (1.0 - height) / 2;
      
      cropArea = Rect.fromLTWH(left, top, width, height);
    }
  }

  // Apply crop and rotate
  void applyCropAndRotate() {
    appliedRotationAngle = rotationAngle;
    appliedCropArea = cropArea;
    showCropRotateView = false;
  }

  // Back from crop view
  void backFromCropView() {
    showCropRotateView = false;
    // Keep the current values as applied values
    appliedRotationAngle = rotationAngle;
    appliedCropArea = cropArea;
  }

  // Handle crop pan start
  void handleCropPanStart(DragStartDetails details) {
    lastPanPosition = details.localPosition;
    
    // Check if user is dragging a corner handle
    final imageSize = const Size(400, 400); // Match the image container size
    final cropRect = Rect.fromLTWH(
      cropArea.left * imageSize.width,
      cropArea.top * imageSize.height,
      cropArea.width * imageSize.width,
      cropArea.height * imageSize.height,
    );
    
    const handleSize = 20.0; // Larger touch area for handles
    
    // Check which handle is being dragged
    if ((details.localPosition - Offset(cropRect.left, cropRect.top)).distance < handleSize) {
      draggedHandle = 'topLeft';
    } else if ((details.localPosition - Offset(cropRect.right, cropRect.top)).distance < handleSize) {
      draggedHandle = 'topRight';
    } else if ((details.localPosition - Offset(cropRect.left, cropRect.bottom)).distance < handleSize) {
      draggedHandle = 'bottomLeft';
    } else if ((details.localPosition - Offset(cropRect.right, cropRect.bottom)).distance < handleSize) {
      draggedHandle = 'bottomRight';
    } else if (cropRect.contains(details.localPosition)) {
      draggedHandle = 'move';
    }
  }

  // Handle crop pan update
  void handleCropPanUpdate(DragUpdateDetails details) {
    if (lastPanPosition == null || draggedHandle == null) return;
    
    final imageSize = const Size(400, 400);
    final delta = details.localPosition - lastPanPosition!;
    final deltaX = delta.dx / imageSize.width;
    final deltaY = delta.dy / imageSize.height;
    
    if (draggedHandle == 'move') {
      // Move the entire crop area
      double newLeft = (cropArea.left + deltaX).clamp(0.0, 1.0 - cropArea.width);
      double newTop = (cropArea.top + deltaY).clamp(0.0, 1.0 - cropArea.height);
      cropArea = Rect.fromLTWH(newLeft, newTop, cropArea.width, cropArea.height);
    } else if (draggedHandle == 'topLeft') {
      // Resize from top-left corner
      double newLeft = (cropArea.left + deltaX).clamp(0.0, cropArea.right - 0.1);
      double newTop = (cropArea.top + deltaY).clamp(0.0, cropArea.bottom - 0.1);
      double newWidth = cropArea.right - newLeft;
      double newHeight = cropArea.bottom - newTop;
      cropArea = Rect.fromLTWH(newLeft, newTop, newWidth, newHeight);
    } else if (draggedHandle == 'topRight') {
      // Resize from top-right corner
      double newRight = (cropArea.right + deltaX).clamp(cropArea.left + 0.1, 1.0);
      double newTop = (cropArea.top + deltaY).clamp(0.0, cropArea.bottom - 0.1);
      double newWidth = newRight - cropArea.left;
      double newHeight = cropArea.bottom - newTop;
      cropArea = Rect.fromLTWH(cropArea.left, newTop, newWidth, newHeight);
    } else if (draggedHandle == 'bottomLeft') {
      // Resize from bottom-left corner
      double newLeft = (cropArea.left + deltaX).clamp(0.0, cropArea.right - 0.1);
      double newBottom = (cropArea.bottom + deltaY).clamp(cropArea.top + 0.1, 1.0);
      double newWidth = cropArea.right - newLeft;
      double newHeight = newBottom - cropArea.top;
      cropArea = Rect.fromLTWH(newLeft, cropArea.top, newWidth, newHeight);
    } else if (draggedHandle == 'bottomRight') {
      // Resize from bottom-right corner
      double newRight = (cropArea.right + deltaX).clamp(cropArea.left + 0.1, 1.0);
      double newBottom = (cropArea.bottom + deltaY).clamp(cropArea.top + 0.1, 1.0);
      double newWidth = newRight - cropArea.left;
      double newHeight = newBottom - cropArea.top;
      cropArea = Rect.fromLTWH(cropArea.left, cropArea.top, newWidth, newHeight);
    }
    
    lastPanPosition = details.localPosition;
  }

  // Build cropped image
  Widget buildCroppedImage(Widget imageWidget, Rect cropArea) {
    // Always return the original image centered - cropping is handled by the overlay
    return Center(child: imageWidget);
  }

  // Get current rotation angle
  double getCurrentRotation() {
    return showCropRotateView ? rotationAngle : appliedRotationAngle;
  }

  // Get current crop area
  Rect getCurrentCropArea() {
    return showCropRotateView ? cropArea : appliedCropArea;
  }
}
