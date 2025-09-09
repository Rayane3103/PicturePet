import 'package:flutter/material.dart';

/// Immutable state for crop/rotate tool.
/// Stores normalized crop rect (0..1), rotation in radians, pan/zoom for interactions,
/// and UI flags such as aspect lock and grid visibility.
class TransformState {
  final Rect cropRect; // normalized in [0,1]
  final double rotationRadians; // rotation around image center
  final double scale; // for interactive preview only (not used for final export)
  final Offset translation; // for interactive preview only (not used for final export)
  final bool isAspectLocked;
  final double? lockedAspectRatio; // width/height when locked
  final int exifOrientation; // original image orientation (1 = normal)
  final bool isGridVisible;

  const TransformState({
    required this.cropRect,
    required this.rotationRadians,
    required this.scale,
    required this.translation,
    required this.isAspectLocked,
    required this.lockedAspectRatio,
    required this.exifOrientation,
    required this.isGridVisible,
  });

  factory TransformState.initial() {
    return const TransformState(
      cropRect: Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
      rotationRadians: 0.0,
      scale: 1.0,
      translation: Offset.zero,
      isAspectLocked: false,
      lockedAspectRatio: null,
      exifOrientation: 1,
      isGridVisible: true,
    );
  }

  TransformState copyWith({
    Rect? cropRect,
    double? rotationRadians,
    double? scale,
    Offset? translation,
    bool? isAspectLocked,
    double? lockedAspectRatio,
    int? exifOrientation,
    bool? isGridVisible,
  }) {
    return TransformState(
      cropRect: cropRect ?? this.cropRect,
      rotationRadians: rotationRadians ?? this.rotationRadians,
      scale: scale ?? this.scale,
      translation: translation ?? this.translation,
      isAspectLocked: isAspectLocked ?? this.isAspectLocked,
      lockedAspectRatio: isAspectLocked == true
          ? (lockedAspectRatio ?? this.lockedAspectRatio)
          : (isAspectLocked == false ? null : this.lockedAspectRatio),
      exifOrientation: exifOrientation ?? this.exifOrientation,
      isGridVisible: isGridVisible ?? this.isGridVisible,
    );
  }

  /// Clamp crop rect to [0,1] bounds.
  TransformState clampToBounds() {
    final Rect r = cropRect;
    final double left = r.left.clamp(0.0, 1.0);
    final double top = r.top.clamp(0.0, 1.0);
    final double right = r.right.clamp(0.0, 1.0);
    final double bottom = r.bottom.clamp(0.0, 1.0);
    final Rect clamped = Rect.fromLTRB(left, top, right, bottom);
    return copyWith(cropRect: clamped);
  }
}
