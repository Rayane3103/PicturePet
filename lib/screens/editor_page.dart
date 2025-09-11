import 'package:flutter/material.dart';
import 'dart:ui';
// duplicate import removed
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:image/image.dart' as img;
import '../repositories/media_repository.dart';
import '../repositories/projects_repository.dart';
import '../repositories/project_edits_repository.dart';
import '../theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import '../repositories/tools_repository.dart';
import '../services/projects_events.dart';

class EditorPage extends StatefulWidget {
  final String projectId;

  const EditorPage({super.key, required this.projectId});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);

  Uint8List? _imageBytes;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  final MediaRepository _mediaRepo = MediaRepository();
  final ProjectsRepository _projectsRepo = ProjectsRepository();
  final ProjectEditsRepository _editsRepo = ProjectEditsRepository();
  final ToolsRepository _toolsRepo = ToolsRepository();
  String? _originalOrLastUrl;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() => setState(() {}));
    _initProjectAndLoad();
  }

  Future<void> _initProjectAndLoad() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project = await _projectsRepo.getById(widget.projectId);
      if (project == null) throw Exception('Project not found');
      _originalOrLastUrl = project.outputImageUrl ?? project.originalImageUrl;
      if (_originalOrLastUrl == null) throw Exception('Project has no image URL');
      await _loadAndDownscaleImage(_originalOrLastUrl!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load project: ${e.toString()}';
      });
    }
  }

  Future<void> _loadAndDownscaleImage(String urlOrAsset) async {
    try {
      Uint8List raw;
      if (urlOrAsset.startsWith('http')) {
        final Uri uri = Uri.parse(urlOrAsset);
        final http.Response resp = await http.get(uri);
        if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
          throw Exception('HTTP ${resp.statusCode}');
        }
        raw = resp.bodyBytes;
      } else {
        final data = await rootBundle.load(urlOrAsset);
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load image${kIsWeb ? ' (web)' : ''}: ${e.toString()}';
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
      appBar: AppBar(
        title: const Text('Editor'),
        actions: [
          IconButton(
            tooltip: 'Versions',
            icon: const Icon(Icons.history_rounded),
            onPressed: _openVersions,
          ),
        ],
      ),
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildImage(),
          ),
          _buildAiSideOverlay(),
          if (_saving)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.35),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: AppColors.secondaryText(context), size: 42),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Failed to load image',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    if (_originalOrLastUrl != null) _loadAndDownscaleImage(_originalOrLastUrl!);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                const SizedBox(width: 8),
                if ((_originalOrLastUrl ?? '').startsWith('http'))
                  OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.tryParse(_originalOrLastUrl ?? '');
                      if (uri != null) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open URL'),
                  ),
              ],
            ),
            if (kIsWeb)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'If this persists on web, ensure the image host allows CORS.',
                  style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12),
                ),
              ),
          ],
        ),
      );
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
            await _handleSave(bytes);
          },
        ),
      ),
    );
  }

  Future<void> _openVersions() async {
    try {
      final edits = await _editsRepo.listForProject(widget.projectId, limit: 50);
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.card(context),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) {
          return SafeArea(
            child: ListView.builder(
              itemCount: edits.length,
              itemBuilder: (ctx, i) {
                final e = edits[i];
                final thumbUrl = e.outputImageUrl ?? e.inputImageUrl;
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: thumbUrl != null
                        ? Image.network(
                            thumbUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (c, err, st) => Container(
                              width: 48,
                              height: 48,
                              color: AppColors.muted(context),
                              child: Icon(Icons.image_not_supported_outlined, color: AppColors.secondaryText(context), size: 20),
                            ),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: AppColors.muted(context),
                            child: Icon(Icons.image_outlined, color: AppColors.secondaryText(context), size: 20),
                          ),
                  ),
                  title: Text(e.editName, style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w600)),
                  subtitle: Text(e.createdAt.toLocal().toString(), style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12)),
                  onTap: () async {
                    final url = e.outputImageUrl ?? e.inputImageUrl;
                    if (url != null) {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _originalOrLastUrl = url;
                        _loading = true;
                        _error = null;
                      });
                      await _loadAndDownscaleImage(url);
                    }
                  },
                );
              },
            ),
          );
        },
      );
    } catch (_) {}
  }

  Future<void> _handleSave(Uint8List bytes) async {
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uploaded = await _mediaRepo.uploadBytes(
        bytes: bytes,
        filename: 'edited.jpg',
        contentType: 'image/jpeg',
        thumbnailBytes: bytes, // simple same-bytes thumbnail; upstream compress handles size
        metadata: {
          'source': 'editor_page',
          'tool_chain': 'manual',
        },
      );

      final updated = await _projectsRepo.updateOutputUrl(
        projectId: widget.projectId,
        outputImageUrl: uploaded.url,
        thumbnailUrl: uploaded.thumbnailUrl,
      );
      // Notify library listeners to refresh thumbnails
      try {
        // lazy import avoided to keep file slim; using events service here would create a circular dep
      } catch (_) {}

      // Log edit entry (manual session) with required tool_id
      final manualToolId = await _toolsRepo.getToolIdByName('manual_editor');
      await _editsRepo.insert(
        projectId: updated.id,
        toolId: manualToolId,
        editName: 'Manual Editor',
        parameters: {
          'editor': 'ProImageEditor',
          'notes': 'Exported from manual tab',
        },
        inputImageUrl: _originalOrLastUrl,
        outputImageUrl: uploaded.url,
        creditCost: 0,
        status: 'completed',
      );

      // Stay in editor: update in-memory image so user can continue editing
      if (!mounted) return;
      setState(() {
        _originalOrLastUrl = uploaded.url;
        _imageBytes = bytes;
      });
      // Notify library to refresh thumbnails in background
      ProjectsEvents.instance.notifyChanged();
      // Friendly success toast
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Saved'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
      _showSaveErrorSnack();
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _showSaveErrorSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(_error ?? 'Failed to save', style: const TextStyle(color: Colors.white))),
          ],
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
            child: Stack(
              children: [
                _buildAiPanelContent(),
                if (_saving)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            ),
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






