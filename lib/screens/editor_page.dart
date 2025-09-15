import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
import '../services/fal_ai_service.dart';

enum _AiTool { none, nanoBanana }

class _AllowAllScrollBehavior extends ScrollBehavior {
  const _AllowAllScrollBehavior();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

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
  final FalAiService _fal = FalAiService();

  // AI session state
  Uint8List? _aiSessionStartBytes;
  final List<Uint8List> _aiUndoStack = <Uint8List>[];
  final List<Uint8List> _aiRedoStack = <Uint8List>[];

  // Bottom tabs sizing (to align AI toolbar exactly above it)
  final GlobalKey _bottomTabsKey = GlobalKey();
  double? _bottomTabsHeight;

  // nano_banana UI state
  final TextEditingController _nanoPromptController = TextEditingController();
  Uint8List? _nanoResultBytes;
  bool _nanoIsGenerating = false;
  String? _nanoError;
  _AiTool _activeAiTool = _AiTool.none;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      // Handle AI session lifecycle when switching tabs
      if (_tabController.index == 1) {
        _ensureAiSessionStarted();
      } else {
        _endAiSessionIfInactive();
      }
      setState(() {});
    });
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
    _nanoPromptController.dispose();
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
          _buildAiBottomOverlay(),
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
      key: _bottomTabsKey,
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
    // Show package editor for Manual tab only; render custom canvas for AI tab
    if (_tabController.index == 0) {
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
                appBarBackground: AppColors.background(context),
                appBarColor: AppColors.onBackground(context),
              ),
            ),
          ),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              await _handleSave(
                bytes,
                source: 'manual',
                toolIdName: 'manual_editor',
                editName: 'Manual Editor',
                parameters: {
                  'editor': 'ProImageEditor',
                  'notes': 'Exported from manual tab',
                },
              );
            },
          ),
        ),
      );
    } else {
      return _buildAiImageCanvas();
    }
  }

  Widget _buildAiImageCanvas() {
    // Centered, contain-fit image canvas for AI tab
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Image.memory(_imageBytes!, filterQuality: FilterQuality.high),
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

  Future<void> _handleSave(
    Uint8List bytes, {
    String source = 'manual',
    String toolIdName = 'manual_editor',
    String editName = 'Manual Editor',
    Map<String, dynamic>? parameters,
  }) async {
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
          'tool_chain': source,
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

      // Log edit entry with required tool_id
      final manualToolId = await _toolsRepo.getToolIdByName(toolIdName);
      await _editsRepo.insert(
        projectId: updated.id,
        toolId: manualToolId,
        editName: editName,
        parameters: parameters ?? const {},
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
      // If saving from AI tab, end session after successful save
      if (_tabController.index == 1) {
        _resetAiSession();
      }
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

  Widget _buildAiBottomOverlay() {
    final bool show = _tabController.index == 1;
    final bool isNanoPanel = _activeAiTool == _AiTool.nanoBanana;
    final double barHeight = isNanoPanel ? 360 : 136;
    // Measure bottom tabs height after layout to align precisely above it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _bottomTabsKey.currentContext;
      if (ctx != null) {
        final size = (ctx.findRenderObject() as RenderBox?)?.size;
        if (size != null && size.height != _bottomTabsHeight) {
          setState(() {
            _bottomTabsHeight = size.height;
          });
        }
      }
    });
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      left: 0,
      right: 0,
      bottom: show ? ((_bottomTabsHeight ?? 96) + 4) : -barHeight,
      height: barHeight,
      child: IgnorePointer(
        ignoring: !show,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
                      color: AppColors.card(context).withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: AppColors.muted(context).withOpacity(0.2), width: 1),
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                            const SizedBox(height: 6),
                            // Handle
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.muted(context).withOpacity(0.6),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                switchInCurve: Curves.easeOut,
                                switchOutCurve: Curves.easeIn,
                                child: !isNanoPanel
                                    ? _buildAiChipsContent()
                                    : _buildNanoBananaPanel(),
                              ),
                            ),
                          ],
                        ),
                        if (_saving)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(child: CircularProgressIndicator()),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiChipsContent() {
    return Column(
      children: [
        // Controls row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Undo',
                            icon: Icon(Icons.undo, color: AppColors.onBackground(context)),
                            onPressed: _canAiUndo ? _aiUndo : null,
                          ),
                          IconButton(
                            tooltip: 'Redo',
                            icon: Icon(Icons.redo, color: AppColors.onBackground(context)),
                            onPressed: _canAiRedo ? _aiRedo : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.onBackground(context)),
                    const SizedBox(width: 6),
                    Text(
                              'AI Tools',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                color: AppColors.onBackground(context),
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                    ),
                  ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: _aiCancel,
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _imageBytes == null ? null : _aiSave,
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                    ),
        SizedBox(
          height: 56,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: ScrollConfiguration(
              behavior: const _AllowAllScrollBehavior(),
              child: ListView(
                          scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                            children: [
                              _aiChip(Icons.remove_circle_outline, 'Remove background', _onRemoveBackground),
                              const SizedBox(width: 8),
                              _aiChip(Icons.brush_outlined, 'Magic eraser', _onMagicEraser),
                              const SizedBox(width: 8),
                              _aiChip(Icons.auto_fix_high_rounded, 'AI Style', _onStyleTransform),
                              const SizedBox(width: 8),
                              _aiChip(Icons.auto_fix_high_rounded, 'ideogram/v3/edit', _onIdeogramEdit),
                              const SizedBox(width: 8),
                              _aiChip(Icons.person_rounded, 'ideogram/character_edit', _onIdeogramCharacterEdit),
                              const SizedBox(width: 8),
                              _aiChip(Icons.autorenew_rounded, 'ideogram/v3/reframe', _onIdeogramReframe),
                              const SizedBox(width: 8),
                              _aiChip(Icons.bolt_rounded, 'nano-banana', _onNanoBanana),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
    );
  }

  Widget _aiChip(IconData icon, String label, VoidCallback onPressed) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.card(context),
          foregroundColor: AppColors.onBackground(context),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  // AI session helpers
  bool get _canAiUndo => _aiUndoStack.isNotEmpty;
  bool get _canAiRedo => _aiRedoStack.isNotEmpty;

  void _ensureAiSessionStarted() {
    if (_aiSessionStartBytes == null && _imageBytes != null) {
      _aiSessionStartBytes = Uint8List.fromList(_imageBytes!);
      _aiUndoStack.clear();
      _aiRedoStack.clear();
    }
  }

  void _endAiSessionIfInactive() {
    // Keep any saved changes; clear temp stacks when leaving AI tab
    _resetAiSession();
  }

  void _resetAiSession() {
    _aiSessionStartBytes = null;
    _aiUndoStack.clear();
    _aiRedoStack.clear();
    // Reset nano_banana panel state when session resets
    _activeAiTool = _AiTool.none;
    _nanoResultBytes = null;
    _nanoIsGenerating = false;
    _nanoError = null;
    _nanoPromptController.clear();
  }

  void _pushAiUndo(Uint8List current) {
    _aiUndoStack.add(Uint8List.fromList(current));
    _aiRedoStack.clear();
  }

  void _aiUndo() {
    if (!_canAiUndo || _imageBytes == null) return;
    final Uint8List last = _aiUndoStack.removeLast();
    _aiRedoStack.add(Uint8List.fromList(_imageBytes!));
    setState(() {
      _imageBytes = last;
    });
  }

  void _aiRedo() {
    if (!_canAiRedo || _imageBytes == null) return;
    final Uint8List next = _aiRedoStack.removeLast();
    _aiUndoStack.add(Uint8List.fromList(_imageBytes!));
    setState(() {
      _imageBytes = next;
    });
  }

  Future<void> _aiSave() async {
    if (_imageBytes == null) return;
    await _handleSave(
      _imageBytes!,
      source: 'ai',
      toolIdName: 'ai_editor',
      editName: 'AI Editor',
      parameters: {
        'editor': 'AI',
        'notes': 'Exported from AI tab',
      },
    );
  }

  void _aiCancel() {
    if (_aiSessionStartBytes == null) return;
    setState(() {
      _imageBytes = Uint8List.fromList(_aiSessionStartBytes!);
      _resetAiSession();
    });
  }

  // Placeholder AI action handlers (hook your real AI here)
  Future<void> _onRemoveBackground() async {
    if (_imageBytes == null) return;
    _pushAiUndo(_imageBytes!);
    // TODO: Replace with real background removal; keep image centered afterward
    setState(() {});
  }

  Future<void> _onMagicEraser() async {
    if (_imageBytes == null) return;
    _pushAiUndo(_imageBytes!);
    // TODO: Implement magic eraser
    setState(() {});
  }

  Future<void> _onStyleTransform() async {
    if (_imageBytes == null) return;
    _pushAiUndo(_imageBytes!);
    // TODO: Implement style transform
    setState(() {});
  }

  Future<void> _onIdeogramEdit() async {
    if (_imageBytes == null) return;
    _pushAiUndo(_imageBytes!);
    // TODO: Call ideogram/v3/edit
    setState(() {});
  }

  Future<void> _onIdeogramCharacterEdit() async {
    if (_imageBytes == null) return;
    _pushAiUndo(_imageBytes!);
    // TODO: Call ideogram/character_edit
    setState(() {});
  }

  Future<void> _onIdeogramReframe() async {
    if (_imageBytes == null) return;
    _pushAiUndo(_imageBytes!);
    // TODO: Call ideogram/v3/reframe
    setState(() {});
  }

  Future<void> _onNanoBanana() async {
    if (_imageBytes == null) return;
    setState(() {
      _activeAiTool = _AiTool.nanoBanana;
      _nanoError = null;
    });
  }

  Widget _buildNanoBananaPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.onBackground(context)),
                onPressed: () {
                  setState(() {
                    _activeAiTool = _AiTool.none;
                  });
                },
              ),
              Expanded(
                child: Text(
                  'AI Edit · nano_banana',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppColors.onBackground(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: _aiCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _imageBytes == null ? null : _aiSave,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.muted(context).withOpacity(0.3), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _nanoPromptController,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _handleNanoGenerate(),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Describe the style or transformation…',
                        hintStyle: GoogleFonts.inter(color: AppColors.secondaryText(context)),
                      ),
                      style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _nanoIsGenerating ? null : _handleNanoGenerate,
                  icon: _nanoIsGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_nanoIsGenerating ? 'Generating…' : 'Generate'),
                ),
              ),
            ],
          ),
        ),
        if (_nanoError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_nanoError!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: _buildNanoResultCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildNanoResultCard() {
    final bool hasResult = _nanoResultBytes != null;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.muted(context).withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: hasResult
            ? Column(
                children: [
                  Expanded(
                    child: Container(
                      color: AppColors.background(context),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Image.memory(
                            _nanoResultBytes!,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _nanoIsGenerating ? null : _handleNanoGenerate,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Regenerate'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _nanoResultBytes == null || _imageBytes == null || _saving
                              ? null
                              : () => _handleNanoReplaceWithResult(),
                          icon: const Icon(Icons.swap_horizontal_circle_outlined),
                          label: const Text('Replace Original'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _nanoResultBytes == null || _saving ? null : () => _handleNanoSaveResultOnly(),
                          icon: const Icon(Icons.save_alt_rounded),
                          label: const Text('Save Result'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : _buildEmptyResultPlaceholder(),
      ),
    );
  }

  Widget _buildEmptyResultPlaceholder() {
    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_search_rounded, size: 36, color: AppColors.secondaryText(context)),
          const SizedBox(height: 8),
          Text(
            'Your AI result will appear here',
            style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter a prompt and tap Generate',
            style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _handleNanoGenerate() async {
    if (_imageBytes == null) return;
    final String prompt = _nanoPromptController.text.trim();
    if (prompt.isEmpty) {
      setState(() {
        _nanoError = 'Please enter a prompt.';
      });
      return;
    }
    setState(() {
      _nanoIsGenerating = true;
      _nanoError = null;
    });
    try {
      final Uint8List result = await _fal.nanoBananaEdit(
        inputImageBytes: _imageBytes!,
        prompt: prompt,
      );
      if (!mounted) return;
      setState(() {
        _nanoResultBytes = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _nanoError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _nanoIsGenerating = false;
        });
      }
    }
  }

  Future<void> _handleNanoReplaceWithResult() async {
    if (_nanoResultBytes == null) return;
    // Push undo before replacing current canvas image
    if (_imageBytes != null) _pushAiUndo(_imageBytes!);
    setState(() {
      _imageBytes = Uint8List.fromList(_nanoResultBytes!);
    });
  }

  Future<void> _handleNanoSaveResultOnly() async {
    if (_nanoResultBytes == null) return;
    await _handleSave(
      _nanoResultBytes!,
      source: 'ai',
      toolIdName: 'nano_banana',
      editName: 'nano_banana',
      parameters: {
        'editor': 'AI',
        'tool': 'nano_banana',
        'prompt': _nanoPromptController.text.trim(),
      },
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






