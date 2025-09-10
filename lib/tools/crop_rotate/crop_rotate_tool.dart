import 'package:flutter/material.dart';
import 'transform_state.dart';

class CropRotateTool {
  // View visibility
  bool showCropRotateView = false;

  // History (max depth 5)
  final List<TransformState> _undoStack = <TransformState>[];
  final List<TransformState> _redoStack = <TransformState>[];
  static const int _historyLimit = 5;

  // State
  TransformState _current = TransformState.initial();
  TransformState _applied = TransformState.initial();

  // UI selection
  String selectedAspectRatio = 'Free';

  // Gesture handling
  Offset? lastPanPosition;
  String? draggedHandle;

  // Aspect ratio presets
  final List<Map<String, dynamic>> aspectRatios = [
    {'name': 'Free', 'ratio': null},
    {'name': '1:1', 'ratio': 1.0},
    {'name': '3:2', 'ratio': 3 / 2},
    {'name': '4:3', 'ratio': 4 / 3},
    {'name': '16:9', 'ratio': 16 / 9},
    {'name': '2:3', 'ratio': 2 / 3},
  ];

  // Public getters
  Rect get cropArea => _current.cropRect;
  Rect get appliedCropArea => _applied.cropRect;
  bool get isGridVisible => _current.isGridVisible;

  double get currentRotationRadians => _current.rotationRadians;
  double get appliedRotationRadians => _applied.rotationRadians;

  // View lifecycle
  void initializeCropView() {
    _current = _applied; // start editing from applied state
    _redoStack.clear();
    _pushHistory(_current);
  }

  void applyCropAndRotate() {
    // After committing edits to bytes, reset baseline to full image to avoid double-cropping/rotation in preview
    _applied = TransformState.initial().copyWith(
      cropRect: const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0),
      rotationRadians: 0.0,
      exifOrientation: _current.exifOrientation,
      isGridVisible: _current.isGridVisible,
    );
    _current = _applied;
    _undoStack.clear();
    _redoStack.clear();
    _pushHistory(_current);
    showCropRotateView = false;
  }

  void backFromCropView() {
    // Cancel edits and restore applied
    showCropRotateView = false;
    _current = _applied;
    _undoStack.clear();
    _redoStack.clear();
  }

  // History
  void _pushHistory(TransformState state) {
    _undoStack.add(state);
    if (_undoStack.length > _historyLimit) {
      _undoStack.removeAt(0);
    }
  }

  bool canUndo() => _undoStack.length > 1; // keep at least one (initial)
  bool canRedo() => _redoStack.isNotEmpty;

  void undo() {
    if (!canUndo()) return;
    final TransformState last = _undoStack.removeLast();
    _redoStack.add(last);
    _current = _undoStack.last;
  }

  void redo() {
    if (!canRedo()) return;
    final TransformState next = _redoStack.removeLast();
    _undoStack.add(next);
    _current = next;
  }

  // Aspect ratio handling
  void updateCropAreaForAspectRatio(double? ratio) {
    if (ratio == null) {
      _current = _current.copyWith(isAspectLocked: false, lockedAspectRatio: null);
      _current = _current.copyWith(cropRect: const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8));
    } else {
      final double maxDim = 0.8;
      double width = maxDim;
      double height = maxDim;
      if (ratio > 1.0) {
        height = maxDim;
        width = height * ratio;
        if (width > maxDim) {
          width = maxDim;
          height = width / ratio;
        }
      } else {
        width = maxDim;
        height = width / ratio;
        if (height > maxDim) {
          height = maxDim;
          width = height * ratio;
        }
      }
      final double left = (1.0 - width) / 2;
      final double top = (1.0 - height) / 2;
      _current = _current.copyWith(
        cropRect: Rect.fromLTWH(left, top, width, height),
        isAspectLocked: true,
        lockedAspectRatio: ratio,
      );
    }
    _pushHistory(_current);
  }

  // Rotation controls
  void rotateLeft90() {
    final double deg = getCurrentRotation() - 90.0;
    setRotationDegrees(deg);
  }

  void rotateRight90() {
    final double deg = getCurrentRotation() + 90.0;
    setRotationDegrees(deg);
  }

  void setRotationDegrees(double degrees) {
    double norm = degrees % 360.0;
    if (norm < 0) norm += 360.0;
    final double radians = norm * (3.1415926535897932 / 180.0);
    _current = _current.copyWith(rotationRadians: radians);
    _pushHistory(_current);
  }

  void toggleGrid() {
    _current = _current.copyWith(isGridVisible: !_current.isGridVisible);
    _pushHistory(_current);
  }

  void reset() {
    _current = TransformState.initial().copyWith(exifOrientation: _current.exifOrientation);
    selectedAspectRatio = 'Free';
    _pushHistory(_current);
  }

  // Gesture handling: drag crop or resize via handles
  void handleCropPanStart(DragStartDetails details) {
    lastPanPosition = details.localPosition;

    final Size imageSize = const Size(400, 400);
    final Rect cropRect = Rect.fromLTWH(
      _current.cropRect.left * imageSize.width,
      _current.cropRect.top * imageSize.height,
      _current.cropRect.width * imageSize.width,
      _current.cropRect.height * imageSize.height,
    );

    const double handleSize = 24.0;
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
    } else {
      draggedHandle = null;
    }
  }

  void handleCropPanUpdate(DragUpdateDetails details) {
    if (lastPanPosition == null || draggedHandle == null) return;

    final Size imageSize = const Size(400, 400);
    final Offset delta = details.localPosition - lastPanPosition!;
    final double deltaX = delta.dx / imageSize.width;
    final double deltaY = delta.dy / imageSize.height;

    Rect r = _current.cropRect;
    if (draggedHandle == 'move') {
      final double newLeft = (r.left + deltaX).clamp(0.0, 1.0 - r.width);
      final double newTop = (r.top + deltaY).clamp(0.0, 1.0 - r.height);
      r = Rect.fromLTWH(newLeft, newTop, r.width, r.height);
    } else if (draggedHandle == 'topLeft') {
      final double newLeft = (r.left + deltaX).clamp(0.0, r.right - 0.05);
      final double newTop = (r.top + deltaY).clamp(0.0, r.bottom - 0.05);
      r = Rect.fromLTRB(newLeft, newTop, r.right, r.bottom);
    } else if (draggedHandle == 'topRight') {
      final double newRight = (r.right + deltaX).clamp(r.left + 0.05, 1.0);
      final double newTop = (r.top + deltaY).clamp(0.0, r.bottom - 0.05);
      r = Rect.fromLTRB(r.left, newTop, newRight, r.bottom);
    } else if (draggedHandle == 'bottomLeft') {
      final double newLeft = (r.left + deltaX).clamp(0.0, r.right - 0.05);
      final double newBottom = (r.bottom + deltaY).clamp(r.top + 0.05, 1.0);
      r = Rect.fromLTRB(newLeft, r.top, r.right, newBottom);
    } else if (draggedHandle == 'bottomRight') {
      final double newRight = (r.right + deltaX).clamp(r.left + 0.05, 1.0);
      final double newBottom = (r.bottom + deltaY).clamp(r.top + 0.05, 1.0);
      r = Rect.fromLTRB(r.left, r.top, newRight, newBottom);
    }

    // Enforce aspect lock if active
    if (_current.isAspectLocked && _current.lockedAspectRatio != null && draggedHandle != 'move') {
      final double ratio = _current.lockedAspectRatio!; // w/h
      final double newWidth = r.width;
      final double newHeight = r.height;
      double targetWidth = newWidth;
      double targetHeight = newHeight;
      if ((newWidth / newHeight) > ratio) {
        targetWidth = newHeight * ratio;
      } else {
        targetHeight = newWidth / ratio;
      }
      // Anchor based on handle
      if (draggedHandle == 'topLeft') {
        r = Rect.fromLTWH(r.right - targetWidth, r.bottom - targetHeight, targetWidth, targetHeight);
      } else if (draggedHandle == 'topRight') {
        r = Rect.fromLTWH(r.left, r.bottom - targetHeight, targetWidth, targetHeight);
      } else if (draggedHandle == 'bottomLeft') {
        r = Rect.fromLTWH(r.right - targetWidth, r.top, targetWidth, targetHeight);
      } else if (draggedHandle == 'bottomRight') {
        r = Rect.fromLTWH(r.left, r.top, targetWidth, targetHeight);
      }
      // Clamp
      r = Rect.fromLTWH(
        r.left.clamp(0.0, 1.0 - r.width),
        r.top.clamp(0.0, 1.0 - r.height),
        r.width,
        r.height,
      );
    }

    _current = _current.copyWith(cropRect: r).clampToBounds();
    _pushHistory(_current);
    lastPanPosition = details.localPosition;
  }

  // Get current rotation angle in degrees for UI compatibility
  double getCurrentRotation() {
    return showCropRotateView
        ? _current.rotationRadians * (180.0 / 3.1415926535897932)
        : _applied.rotationRadians * (180.0 / 3.1415926535897932);
  }

  // Current crop area (normalized)
  Rect getCurrentCropArea() {
    return showCropRotateView ? _current.cropRect : _applied.cropRect;
  }

  // Export helpers
  Rect getAppliedPixelCropRect({required int imageWidth, required int imageHeight}) {
    final Rect r = _applied.cropRect;
    return Rect.fromLTWH(r.left * imageWidth, r.top * imageHeight, r.width * imageWidth, r.height * imageHeight);
  }

  Rect getCurrentPixelCropRect({required int imageWidth, required int imageHeight}) {
    final Rect r = getCurrentCropArea();
    return Rect.fromLTWH(r.left * imageWidth, r.top * imageHeight, r.width * imageWidth, r.height * imageHeight);
  }
}
