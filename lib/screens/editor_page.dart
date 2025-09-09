import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tools/tools.dart';

class EditorPage extends StatefulWidget {
  final String imageAsset;
  final String projectName;

  const EditorPage({super.key, required this.imageAsset, required this.projectName});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  
  // Tools
  final CropRotateTool _cropRotateTool = CropRotateTool();
  final FiltersTool _filtersTool = FiltersTool();
  final AIStylesTool _aiStylesTool = AIStylesTool();

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background(context),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Top gradient overlay for better text readability
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.background(context).withOpacity(0.9),
                      AppColors.background(context).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Main image canvas
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 120),
              child: Center(
                child: Hero(
                  tag: widget.imageAsset,
                  child: _buildImage(),
                ),
              ),
            ),
          ),
          
          // Bottom control panel
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: _buildControlPanel(),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: AppColors.card(context).withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.onBackground(context),
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.card(context).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          widget.projectName,
          style: GoogleFonts.inter(
            color: AppColors.onBackground(context),
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      centerTitle: true,
      actions: [
        _buildActionButton(Icons.undo_rounded, 'Undo'),
        _buildActionButton(Icons.redo_rounded, 'Redo'),
        const SizedBox(width: 8),
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: AppColors.card(context).withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.onBackground(context), size: 20),
        onPressed: () {
          if (_cropRotateTool.showCropRotateView) {
            setState(() {
              if (tooltip == 'Undo') {
                _cropRotateTool.undo();
              } else if (tooltip == 'Redo') {
                _cropRotateTool.redo();
              }
            });
          }
        },
        tooltip: tooltip,
      ),
    );
  }

 Widget _buildControlPanel() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.card(context).withOpacity(0.85),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ],
      border: Border.all(
        color: AppColors.muted(context).withOpacity(0.25),
        width: 1,
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with back button when in filters, crop, or AI styles view
              if (_filtersTool.showFiltersView || _cropRotateTool.showCropRotateView || _aiStylesTool.showStylesView) ...[
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.muted(context).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: AppColors.onBackground(context),
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_filtersTool.showFiltersView) {
                              _filtersTool.backFromFiltersView();
                            } else if (_aiStylesTool.showStylesView) {
                              _aiStylesTool.backFromStylesView();
                            } else if (_cropRotateTool.showCropRotateView) {
                              _cropRotateTool.backFromCropView();
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _filtersTool.showFiltersView
                          ? 'Filters'
                          : _aiStylesTool.showStylesView
                              ? 'AI Styles'
                              : 'Crop & Rotate',
                      style: GoogleFonts.inter(
                        color: AppColors.onBackground(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    if (_cropRotateTool.showCropRotateView) ...[
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _cropRotateTool.applyCropAndRotate();
                            });
                            _showCropAppliedMessage();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                // Tab bar
                Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.muted(context).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.secondaryText(context),
                  indicator: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  unselectedLabelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Manual'),
                    Tab(text: 'AI'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ],

              // Fixed height for both tabs to avoid unbounded height error
              SizedBox(
                height: 130, // same height for both tabs
                child: _filtersTool.showFiltersView 
                  ? FiltersView(
                      tool: _filtersTool,
                      onBack: () {
                        setState(() {
                          _filtersTool.backFromFiltersView();
                        });
                      },
                      onStateChanged: () {
                        setState(() {
                          // Trigger rebuild when tool state changes
                        });
                      },
                    )
                  : _aiStylesTool.showStylesView
                    ? AIStylesView(
                        tool: _aiStylesTool,
                        onBack: () {
                          setState(() {
                            _aiStylesTool.backFromStylesView();
                          });
                        },
                        onStateChanged: () {
                          setState(() {
                            // Trigger rebuild when tool state changes
                          });
                        },
                      )
                  : _cropRotateTool.showCropRotateView
                    ? CropRotateView(
                        tool: _cropRotateTool,
                        onBack: () {
                          setState(() {
                            _cropRotateTool.backFromCropView();
                          });
                        },
                        onApply: () {
                          setState(() {
                            _cropRotateTool.applyCropAndRotate();
                          });
                          _showCropAppliedMessage();
                        },
                        onStateChanged: () {
                          setState(() {
                            // Trigger rebuild when tool state changes
                          });
                        },
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _manualTools(context),
                          _aiTools(context),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}


  Widget _buildImage() {
    Widget imageWidget = widget.imageAsset.startsWith('http')
        ? Image.network(
            widget.imageAsset,
            //fit: BoxFit.cover,
            width: 400,
            height: 400,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }
              return Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.muted(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: AppColors.primaryPurple,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppColors.muted(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    Icons.wifi_off_rounded,
                    color: AppColors.secondaryText(context),
                    size: 36,
                  ),
                ),
              );
            },
          )
        : Image.asset(
            widget.imageAsset,
            fit: BoxFit.cover,
            width: 400,
            height: 400,
          );

    // Apply filter if one is selected
    final colorFilter = _filtersTool.getSelectedColorFilter();
    if (colorFilter != null) {
      imageWidget = ColorFiltered(
        colorFilter: colorFilter,
        child: imageWidget,
      );
    }

    // Apply rotation only when NOT in crop mode to keep overlay math aligned
    if (!_cropRotateTool.showCropRotateView) {
      double currentRotation = _cropRotateTool.getCurrentRotation();
      if (currentRotation != 0) {
        imageWidget = Transform.rotate(
          angle: currentRotation * (3.14159 / 180), // Convert degrees to radians
          child: imageWidget,
        );
      }
    }

    Widget imageContainer = Container(
      constraints: const BoxConstraints(
        maxWidth: 400,
        maxHeight: 400,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // BoxShadow(
          //   color: Colors.black.withOpacity(0.1),
          //   blurRadius: 6,
          //   spreadRadius: 0,
          //   offset: const Offset(0, 2),
          // ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: _buildImageWithCrop(imageWidget),
      ),
    );

    // Add crop overlay if in crop mode
    if (_cropRotateTool.showCropRotateView) {
      imageContainer = Stack(
        children: [
          imageContainer,
          // Interactive crop overlay
          Positioned.fill(
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _cropRotateTool.handleCropPanUpdate(details);
                });
              },
              onPanStart: (details) {
                _cropRotateTool.handleCropPanStart(details);
              },
              child: CustomPaint(
                painter: CropOverlayPainter(
                  _cropRotateTool.cropArea,
                  showGrid: _cropRotateTool.isGridVisible,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return imageContainer;
  }

  Widget _manualTools(BuildContext context) {
  final tools = [
    (Icons.crop_rotate_rounded, 'Crop & Rotate', AppColors.primaryPurple),
    (Icons.filter_vintage_rounded, 'Filters', AppColors.accentPurple),
    (Icons.brightness_6_rounded, 'Adjust', AppColors.primaryBlue),
    (Icons.text_fields_rounded, 'Add Text', AppColors.accentBlue),
  ];

  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: tools.map((tool) {
      return _buildToolButton(
        icon: tool.$1,
        label: tool.$2,
        color: tool.$3,
      );
    }).toList(),
  );
}

Widget _aiTools(BuildContext context) {
  final items = [
    ('ai-styles', Icons.palette_rounded, 'AI Styles'),
    ('fal-ai/ideogram/v3/edit', Icons.auto_fix_high_rounded, 'Ideogram Edit'),
    ('fal-ai/ideogram/character/edit', Icons.portrait_rounded, 'Character Edit'),
    ('fal-ai/ideogram/v3/reframe', Icons.crop_16_9_rounded, 'Reframe'),
    ('fal-ai/qwen-image-edit', Icons.image_rounded, 'Qwen Edit'),
  ];

  return SizedBox(
    height: 120, // fixes unbounded height
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemBuilder: (context, i) {
        final item = items[i];
        final isAIStyles = item.$1 == 'ai-styles';
        return Container(
          width: 140,
          decoration: BoxDecoration(
            color: AppColors.muted(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.muted(context).withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (isAIStyles) {
                  setState(() {
                    _aiStylesTool.showStyles();
                  });
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.$2,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.$3,
                      style: GoogleFonts.inter(
                        color: AppColors.onBackground(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemCount: items.length,
    ),
  );
}

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        if (label == 'Filters') {
          setState(() {
            _filtersTool.showFilters();
          });
        } else if (label == 'Crop & Rotate') {
          setState(() {
            _cropRotateTool.showCropRotateView = true;
            _cropRotateTool.initializeCropView();
          });
        }
        // Handle other tools here
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppColors.onBackground(context),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  Widget _buildImageWithCrop(Widget imageWidget) {
    // If in crop mode, show original image (cropping is handled by overlay)
    if (_cropRotateTool.showCropRotateView) {
      return Center(child: imageWidget);
    }
    
    // If not in crop mode, apply the actual crop
    Rect appliedCropArea = _cropRotateTool.appliedCropArea;
    
    // If crop area is the default (no cropping), return original image centered
    if (appliedCropArea == const Rect.fromLTWH(0.1, 0.1, 0.8, 0.8)) {
      return Center(child: imageWidget);
    }
    
    // Crop using Align widthFactor/heightFactor and then scale to canvas
    const double canvasSize = 400;
    final double centerX = appliedCropArea.left + appliedCropArea.width / 2;
    final double centerY = appliedCropArea.top + appliedCropArea.height / 2;
    final Alignment alignment = Alignment(
      (centerX - 0.5) * 2.0,
      (centerY - 0.5) * 2.0,
    );

    final Widget cropped = SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: ClipRect(
        child: Align(
          alignment: alignment,
          widthFactor: appliedCropArea.width,
          heightFactor: appliedCropArea.height,
          child: SizedBox(
            width: canvasSize,
            height: canvasSize,
            child: imageWidget,
          ),
        ),
      ),
    );

    return SizedBox(
      width: canvasSize,
      height: canvasSize,
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: cropped,
        ),
      ),
    );
  }

  void _showCropAppliedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Crop & Rotate applied successfully!',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.primaryPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

 
}






