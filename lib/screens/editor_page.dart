import 'package:flutter/material.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:image/image.dart' as img;

class EditorPage extends StatefulWidget {
  final String imageAsset;
  final String projectName;

  const EditorPage({super.key, required this.imageAsset, required this.projectName});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  Uint8List? _imageBytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() => setState(() {}));
    _loadAndDownscaleImage();
  }

  Future<void> _loadAndDownscaleImage() async {
    try {
      Uint8List raw;
      if (widget.imageAsset.startsWith('http')) {
        final data = await NetworkAssetBundle(Uri.parse(widget.imageAsset)).load(widget.imageAsset);
        raw = data.buffer.asUint8List();
      } else {
        final data = await rootBundle.load(widget.imageAsset);
        raw = data.buffer.asUint8List();
      }
      // Downscale if too large
      final img.Image? decoded = img.decodeImage(raw);
      if (decoded != null) {
        const int maxSide = 2048;
        final int w = decoded.width;
        final int h = decoded.height;
        if (w > maxSide || h > maxSide) {
          final resized = img.copyResize(decoded, width: w > h ? maxSide : null, height: h >= w ? maxSide : null);
          raw = img.encodeJpg(resized, quality: 90);
        }
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = raw;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildImage(),
          ),
          _buildAiSideOverlay(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        child: _buildBottomTabs(),
      ),
    );
  }

  Widget _buildBottomTabs() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context).withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
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
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.muted(context).withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.secondaryText(context),
            indicator: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }

  Widget _buildImage() {
    if (_loading) {
      return const SizedBox(
        width: 200,
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_imageBytes == null) {
      return const Text('Failed to load image');
    }
    return Theme(
      data: _editorTheme(context),
      child: ProImageEditor.memory(
        _imageBytes!,
        configs: ProImageEditorConfigs(
          theme: _editorTheme(context),
          mainEditor: MainEditorConfigs(
            style: MainEditorStyle(
              bottomBarBackground: AppColors.background(context),
              bottomBarColor: AppColors.onBackground(context),
              background: AppColors.background(context),
              appBarBackground: AppColors.card(context),
              appBarColor: AppColors.onCard(context),
            ),
          ),
        ),
        callbacks: ProImageEditorCallbacks(
          onImageEditingComplete: (Uint8List bytes) async {
            Navigator.pop(context, bytes);
          },
        ),
      ),
    );
  }

  Widget _buildAiSideOverlay() {
    final bool show = _tabController.index == 1;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      top: 0,
      bottom: 0,
      right: show ? 0 : -320,
      width: 320,
      child: SafeArea(
        minimum: const EdgeInsets.only(top: 16, right: 16, bottom: 90),
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.card(context).withOpacity(0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
              border: Border.all(
                color: AppColors.muted(context).withOpacity(0.25),
                width: 1,
              ),
            ),
            child: _buildAiPanelContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildAiPanelContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI Tools',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ListView(
              children: [
                _aiActionButton(Icons.remove_circle_outline, 'Remove background'),
                const SizedBox(height: 10),
                _aiActionButton(Icons.brush_outlined, 'Magic eraser'),
                const SizedBox(height: 10),
                _aiActionButton(Icons.auto_fix_high_rounded, 'AI Style transformation'),
                const SizedBox(height: 10),
                _aiActionButton(Icons.auto_fix_high_rounded, 'ideogram/v3/edit'),
                const SizedBox(height: 10),
                _aiActionButton(Icons.person_rounded, 'ideogram/character_edit'),
                const SizedBox(height: 10),
                _aiActionButton(Icons.autorenew_rounded, 'ideogram/v3/reframe'),
                const SizedBox(height: 10),
                _aiActionButton(Icons.bolt_rounded, 'nano-banana'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _aiActionButton(IconData icon, String label) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.card(context),
          foregroundColor: AppColors.onBackground(context),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () {
          // TODO: hook into your AI actions
        },
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  ThemeData _editorTheme(BuildContext context) {
    final ThemeData base = Theme.of(context);
    final bool isDark = base.brightness == Brightness.dark;

    final ColorScheme scheme = base.colorScheme.copyWith(
      primary: AppColors.primaryPurple,
      secondary: AppColors.primaryBlue,
      surface: AppColors.surface(context),
      onSurface: AppColors.onSurface(context),
      background: AppColors.background(context),
      onBackground: AppColors.onBackground(context),
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background(context),
      cardColor: AppColors.card(context),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.card(context).withOpacity(isDark ? 0.9 : 0.95),
        foregroundColor: AppColors.onCard(context),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.onCard(context),
        ),
      ),
      iconTheme: IconThemeData(color: AppColors.onBackground(context)),
      tabBarTheme: base.tabBarTheme.copyWith(
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.secondaryText(context),
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
        indicator: BoxDecoration(
          color: AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onBackground(context),
          side: BorderSide(color: AppColors.muted(context).withOpacity(0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.primaryPurple,
        thumbColor: AppColors.primaryPurple,
        inactiveTrackColor: AppColors.muted(context).withOpacity(0.4),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card(context),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.card(context),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.selectedBackground(context),
        selectedColor: AppColors.primaryPurple,
        labelStyle: GoogleFonts.inter(color: AppColors.onBackground(context), fontSize: 12),
        selectedShadowColor: Colors.transparent,
      ),
    );
  }
}






