import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

/// A widget that allows users to paint a mask on an image using a brush
class MaskBrushPainter extends StatefulWidget {
  final Uint8List imageBytes;
  final Function(Uint8List maskBytes) onMaskComplete;
  final VoidCallback onCancel;

  const MaskBrushPainter({
    super.key,
    required this.imageBytes,
    required this.onMaskComplete,
    required this.onCancel,
  });

  @override
  State<MaskBrushPainter> createState() => _MaskBrushPainterState();
}

class _MaskBrushPainterState extends State<MaskBrushPainter> {
  final List<_DrawingPoint> _points = [];
  double _brushSize = 20.0;
  bool _isErasing = false;
  ui.Image? _uiImage;
  Size? _imageSize;
  Size? _canvasSize;
  double _scale = 1.0;
  Offset _offset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }
  
  void _updateTransform() {
    if (_imageSize == null || _canvasSize == null) return;
    
    final double imageAspect = _imageSize!.width / _imageSize!.height;
    final double canvasAspect = _canvasSize!.width / _canvasSize!.height;

    if (canvasAspect > imageAspect) {
      _scale = _canvasSize!.height / _imageSize!.height;
      _offset = Offset((_canvasSize!.width - _imageSize!.width * _scale) / 2, 0);
    } else {
      _scale = _canvasSize!.width / _imageSize!.width;
      _offset = Offset(0, (_canvasSize!.height - _imageSize!.height * _scale) / 2);
    }
  }

  Future<void> _loadImage() async {
    final codec = await ui.instantiateImageCodec(widget.imageBytes);
    final frame = await codec.getNextFrame();
    setState(() {
      _uiImage = frame.image;
      _imageSize = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
    });
  }

  void _clear() {
    setState(() {
      _points.clear();
    });
  }

  void _undo() {
    if (_points.isEmpty) return;
    setState(() {
      // Remove last continuous stroke
      while (_points.isNotEmpty && _points.last.paint != null) {
        _points.removeLast();
      }
      if (_points.isNotEmpty) _points.removeLast();
    });
  }

  Future<Uint8List> _generateMask() async {
    if (_imageSize == null) {
      throw Exception('Image not loaded');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Fill with black background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _imageSize!.width, _imageSize!.height),
      Paint()..color = Colors.black,
    );

    // Draw white strokes where user painted - transform screen coords to image coords
    for (int i = 0; i < _points.length - 1; i++) {
      if (_points[i].paint != null && _points[i + 1].paint != null) {
        // Transform screen coordinates to image coordinates
        final p1 = Offset(
          (_points[i].offset.dx - _offset.dx) / _scale,
          (_points[i].offset.dy - _offset.dy) / _scale,
        );
        final p2 = Offset(
          (_points[i + 1].offset.dx - _offset.dx) / _scale,
          (_points[i + 1].offset.dy - _offset.dy) / _scale,
        );
        
        // Scale brush size to image coordinates too
        final scaledPaint = Paint()
          ..color = _points[i].paint!.color
          ..strokeWidth = _points[i].paint!.strokeWidth / _scale
          ..strokeCap = _points[i].paint!.strokeCap;
        
        canvas.drawLine(p1, p2, scaledPaint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      _imageSize!.width.toInt(),
      _imageSize!.height.toInt(),
    );

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _complete() async {
    if (_points.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paint on the image to create a mask'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final maskBytes = await _generateMask();
      widget.onMaskComplete(maskBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating mask: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uiImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: widget.onCancel,
        ),
        title: const Text(
          'Paint Mask',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: _points.isEmpty ? null : _undo,
          ),
          IconButton(
            icon: const Icon(Icons.clear, color: Colors.white),
            onPressed: _points.isEmpty ? null : _clear,
          ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: _complete,
          ),
        ],
      ),
      body: Column(
        children: [
          // Canvas area
          Expanded(
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Update canvas size for coordinate transformation
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_canvasSize != constraints.biggest) {
                      setState(() {
                        _canvasSize = constraints.biggest;
                        _updateTransform();
                      });
                    }
                  });
                  
                  return GestureDetector(
                    onPanStart: (details) {
                      setState(() {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final offset = box.globalToLocal(details.globalPosition);
                        _points.add(_DrawingPoint(
                          offset: offset,
                          paint: Paint()
                            ..color = _isErasing ? Colors.black : Colors.white
                            ..strokeWidth = _brushSize
                            ..strokeCap = StrokeCap.round,
                        ));
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final offset = box.globalToLocal(details.globalPosition);
                        _points.add(_DrawingPoint(
                          offset: offset,
                          paint: Paint()
                            ..color = _isErasing ? Colors.black : Colors.white
                            ..strokeWidth = _brushSize
                            ..strokeCap = StrokeCap.round,
                        ));
                      });
                    },
                    onPanEnd: (details) {
                      setState(() {
                        _points.add(_DrawingPoint(offset: Offset.zero, paint: null));
                      });
                    },
                    child: CustomPaint(
                      painter: _MaskPainter(
                        image: _uiImage!,
                        points: _points,
                        onTransformCalculated: (scale, offset) {
                          if (_scale != scale || _offset != offset) {
                            _scale = scale;
                            _offset = offset;
                          }
                        },
                      ),
                      size: Size.infinite,
                    ),
                  );
                },
              ),
            ),
          ),

          // Controls
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brush/Eraser toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildToolButton(
                        icon: Icons.brush,
                        label: 'Paint',
                        isActive: !_isErasing,
                        onTap: () => setState(() => _isErasing = false),
                      ),
                      const SizedBox(width: 16),
                      _buildToolButton(
                        icon: Icons.cleaning_services,
                        label: 'Erase',
                        isActive: _isErasing,
                        onTap: () => setState(() => _isErasing = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Brush size slider
                  Row(
                    children: [
                      const Icon(Icons.brush, color: Colors.white70, size: 16),
                      Expanded(
                        child: Slider(
                          value: _brushSize,
                          min: 5.0,
                          max: 100.0,
                          divisions: 19,
                          label: _brushSize.round().toString(),
                          activeColor: Colors.white,
                          inactiveColor: Colors.white30,
                          onChanged: (value) {
                            setState(() => _brushSize = value);
                          },
                        ),
                      ),
                      const Icon(Icons.brush, color: Colors.white70, size: 32),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Info text
                  Text(
                    'Paint over the area you want to edit',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.white : Colors.grey[700]!,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.black : Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawingPoint {
  final Offset offset;
  final Paint? paint;

  _DrawingPoint({required this.offset, this.paint});
}

class _MaskPainter extends CustomPainter {
  final ui.Image image;
  final List<_DrawingPoint> points;
  final Function(double scale, Offset offset)? onTransformCalculated;

  _MaskPainter({
    required this.image, 
    required this.points,
    this.onTransformCalculated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale to fit image in canvas
    final double imageAspect = image.width / image.height;
    final double canvasAspect = size.width / size.height;

    double scale;
    double offsetX = 0;
    double offsetY = 0;

    if (canvasAspect > imageAspect) {
      scale = size.height / image.height;
      offsetX = (size.width - image.width * scale) / 2;
    } else {
      scale = size.width / image.width;
      offsetY = (size.height - image.height * scale) / 2;
    }
    
    // Notify parent of transform for coordinate conversion
    if (onTransformCalculated != null) {
      onTransformCalculated!(scale, Offset(offsetX, offsetY));
    }

    canvas.save();
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);

    // Draw image
    canvas.drawImage(image, Offset.zero, Paint());

    // Draw semi-transparent overlay
    canvas.drawRect(
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Paint()..color = Colors.black.withOpacity(0.3),
    );

    // Draw strokes
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i].paint != null && points[i + 1].paint != null) {
        // Scale points back to image coordinates
        final p1 = Offset(
          (points[i].offset.dx - offsetX) / scale,
          (points[i].offset.dy - offsetY) / scale,
        );
        final p2 = Offset(
          (points[i + 1].offset.dx - offsetX) / scale,
          (points[i + 1].offset.dy - offsetY) / scale,
        );

        // Draw highlight overlay for user feedback
        canvas.drawLine(
          p1,
          p2,
          Paint()
            ..color = Colors.white.withOpacity(0.1)
            ..strokeWidth = points[i].paint!.strokeWidth
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MaskPainter oldDelegate) => true;
}

