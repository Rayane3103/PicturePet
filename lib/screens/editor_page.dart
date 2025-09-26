import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'dart:ui';
// duplicate import removed
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'dart:async';
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
import '../services/ai_jobs_service.dart';
import '../repositories/ai_jobs_repository.dart';
import '../services/media_pipeline_service.dart';
import '../models/ai_job.dart';
import '../models/media_item.dart';
import 'reframe_presets.dart';
import '../utils/logger.dart';

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

class _AiActionMeta {
  final String toolIdName;
  final String editName;
  final Map<String, dynamic> parameters;
  const _AiActionMeta({
    required this.toolIdName,
    required this.editName,
    this.parameters = const {},
  });
}

class _AiSnapshot {
  final Uint8List bytes;
  final _AiActionMeta? actionMeta;
  const _AiSnapshot({required this.bytes, this.actionMeta});
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
  // Legacy direct AI client retained for potential future use
  // ignore: unused_field
  final FalAiService _fal = FalAiService();
  final AiJobsRepository _aiJobsRepo = AiJobsRepository();
  StreamSubscription<AiJob>? _jobUpdatesSub;
  // Track active AI jobs and dialog state for live updates
  final Set<String> _activeJobIds = <String>{};
  String? _currentNanoJobId;
  bool _showNanoPanel = false;

  // AI tools row scroll hint state
  final ScrollController _aiToolsScrollController = ScrollController();
  bool _aiCanScrollLeft = false;
  bool _aiCanScrollRight = false;

  // AI session state
  Uint8List? _aiSessionStartBytes;
  final List<_AiSnapshot> _aiUndoStack = <_AiSnapshot>[];
  final List<_AiSnapshot> _aiRedoStack = <_AiSnapshot>[];
  _AiActionMeta? _lastAiAction;

  // Bottom tabs sizing (to align AI toolbar exactly above it)
  final GlobalKey _bottomTabsKey = GlobalKey();

  // nano_banana UI state
  final TextEditingController _nanoPromptController = TextEditingController();
  Uint8List? _nanoResultBytes;
  bool _nanoIsGenerating = false;
  String? _nanoError;

  @override
  void initState() {
    super.initState();
    _tabController.addListener(() {
      // Handle AI session lifecycle when switching tabs
      if (_tabController.index == 1) {
        _ensureAiSessionStarted();
        // Update scroll hints when switching into AI tab
        WidgetsBinding.instance.addPostFrameCallback((_) => _updateAiScrollHints());
      } else {
        _endAiSessionIfInactive();
      }
      setState(() {});
    });
    _aiToolsScrollController.addListener(_updateAiScrollHints);
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
      // Subscribe to AI job updates for this project
      AiJobsService.instance.subscribeToProjectJobs(project.id);
      _jobUpdatesSub?.cancel();
      _jobUpdatesSub = AiJobsService.instance.jobUpdates.listen((AiJob job) async {
        if (job.projectId != widget.projectId) return;
        // Clear global overlay for tracked jobs on completion/failure
        if (_activeJobIds.contains(job.id) &&
            (job.status == 'completed' || job.status == 'failed' || job.status == 'cancelled')) {
          if (mounted) {
            setState(() {
              _activeJobIds.remove(job.id);
              // Ensure global overlay hides when no active jobs remain
              _saving = _activeJobIds.isNotEmpty;
            });
          }
        }
        if (job.status == 'completed' && job.resultUrl != null) {
          try {
            if (job.toolName == 'nano_banana') {
              final Uri uri = Uri.parse(job.resultUrl!);
              final http.Response resp = await http.get(uri);
              if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                if (!mounted) return;
                setState(() {
                  _nanoResultBytes = resp.bodyBytes;
                  if (_currentNanoJobId == job.id) {
                    _nanoIsGenerating = false;
                  }
                });
                // Inline panel is bound to state; no dialog refresh needed
              }
            } else {
              _originalOrLastUrl = job.resultUrl;
              await _loadAndDownscaleImage(job.resultUrl!);
              if (!mounted) return;
              // Best-effort: hide overlay once applied
              setState(() { _saving = _activeJobIds.isNotEmpty; });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(behavior: SnackBarBehavior.floating, content: Text('AI result applied')),
              );
              // Notify library/list views to refresh thumbnails
              ProjectsEvents.instance.notifyChanged();
            }
          } catch (e) {
            Logger.warn('Failed to apply AI job result', context: {'error': e.toString()});
          }
        } else if (job.status == 'failed') {
          // Print detailed error to console for easy copy/paste
          Logger.error('AI job failed', context: {
            'job_id': job.id,
            'tool': job.toolName,
            'error': job.error ?? 'unknown',
            'payload': job.payload,
            'input_image_url': job.inputImageUrl,
            'project_id': job.projectId,
          });
          if (_currentNanoJobId == job.id && mounted) setState(() { _nanoIsGenerating = false; });
          if (mounted) setState(() { _saving = _activeJobIds.isNotEmpty; });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.redAccent,
              content: Text('AI job failed${job.error != null ? ': ${job.error}' : ''}', style: const TextStyle(color: Colors.white)),
            ),
          );
        }
      });
      // Ensure an initial history entry exists for the original image
      try {
        final bool hasInitial = await _editsRepo.hasInitialImport(project.id);
        final String? originalUrl = project.originalImageUrl;
        if (!hasInitial && originalUrl != null && originalUrl.isNotEmpty) {
          await _editsRepo.insert(
            projectId: project.id,
            editName: 'Initial Import',
            parameters: const {'stage': 'original'},
            inputImageUrl: originalUrl,
            outputImageUrl: originalUrl,
            creditCost: 0,
            status: 'completed',
          );
        }
      } catch (_) {}
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
    _aiToolsScrollController.dispose();
    _currentNanoJobId = null;
    _jobUpdatesSub?.cancel();
    AiJobsService.instance.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor'),
        actions: _buildAppBarActions(),
      ),
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: _buildImage(),
          ),
          // Keep overlay visible while saving OR while any tracked background job is active
          if (_saving || _activeJobIds.isNotEmpty)
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

  List<Widget> _buildAppBarActions() {
    // Always show Versions; show AI controls only on AI tab
    if (_tabController.index == 1) {
      return [
        IconButton(
          tooltip: 'Undo',
          icon: const Icon(Icons.undo),
          onPressed: _canAiUndo ? _aiUndo : null,
        ),
        IconButton(
          tooltip: 'Redo',
          icon: const Icon(Icons.redo),
          onPressed: _canAiRedo ? _aiRedo : null,
        ),
        TextButton(
          onPressed: _aiSessionStartBytes == null ? null : _aiCancel,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _imageBytes == null ? null : _aiSave,
          child: const Text('Save'),
        ),
        IconButton(
          tooltip: 'Versions',
          icon: const Icon(Icons.history_rounded),
          onPressed: _openVersions,
        ),
      ];
    } else {
      return [
        IconButton(
          tooltip: 'Versions',
          icon: const Icon(Icons.history_rounded),
          onPressed: _openVersions,
        ),
      ];
    }
  }

  Widget _buildBottomTabs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Transparent chips row above the TabBar
        if (_tabController.index == 1)
          SizedBox(
            height: 75,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Stack(
                children: [
                  ScrollConfiguration(
                    behavior: const _AllowAllScrollBehavior(),
                    child: ListView(
                      controller: _aiToolsScrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _aiChip(Icons.remove_circle_outline, 'BG Remove', _onRemoveBackground),
                        const SizedBox(width: 8),
                        _aiChip(Icons.bolt_rounded, _showNanoPanel ? 'Hide Remix' : 'Remix', () {
                          setState(() {
                            _showNanoPanel = !_showNanoPanel;
                          });
                        }),
                        const SizedBox(width: 8),
                        _aiChip(Icons.autorenew_rounded, 'Reframe', _onIdeogramReframe),
                        const SizedBox(width: 8),
                        _aiChip(Icons.widgets_rounded, 'Elements', _onElementsRemix),
                        const SizedBox(width: 8),
                        _aiChip(Icons.auto_fix_high_rounded, 'Style', _onStyleTransform),
                        const SizedBox(width: 8),
                        // _aiChip(Icons.auto_fix_high_rounded, 'Smart Edit', _onIdeogramEdit),
                        // const SizedBox(width: 8),
                        _aiChip(Icons.person_rounded, 'Character', _onIdeogramCharacterEdit),
                        const SizedBox(width: 8),
                        
                        
                        _aiChip(Icons.text_fields_rounded, 'Text Edit', _onCalligrapher),
                        
                      ],
                    ),
                  ),
                  // Left fade hint
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: AnimatedOpacity(
                        opacity: _aiCanScrollLeft ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          width: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                AppColors.background(context),
                                AppColors.background(context).withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right fade hint
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: AnimatedOpacity(
                        opacity: _aiCanScrollRight ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: Container(
                          width: 16,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                AppColors.background(context),
                                AppColors.background(context).withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Right chevron hint
                  Positioned(
                    right: 4,
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: true,
                      child: AnimatedOpacity(
                        opacity: _aiCanScrollRight ? 0.7 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: AppColors.onBackground(context).withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Container(
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
        ),
      ],
    );
  }

  void _updateAiScrollHints() {
    if (!_aiToolsScrollController.hasClients) {
      if (_aiCanScrollLeft || _aiCanScrollRight) {
        setState(() {
          _aiCanScrollLeft = false;
          _aiCanScrollRight = false;
        });
      }
      return;
    }
    final position = _aiToolsScrollController.position;
    final double offset = position.pixels;
    final double max = position.maxScrollExtent;
    final bool canLeft = offset > 2.0;
    final bool canRight = (max - offset) > 2.0;
    if (canLeft != _aiCanScrollLeft || canRight != _aiCanScrollRight) {
      setState(() {
        _aiCanScrollLeft = canLeft;
        _aiCanScrollRight = canRight;
      });
    }
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
    return Stack(
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Image.memory(_imageBytes!, filterQuality: FilterQuality.high),
          ),
        ),
        if (_showNanoPanel)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _buildNanoInlinePanel(),
          ),
      ],
    );
  }

  Widget _buildNanoInlinePanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context).withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.muted(context).withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: AppColors.onBackground(context)),
              const SizedBox(width: 8),
              Text('Remix', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.onBackground(context))),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _showNanoPanel = false;
                    _nanoError = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
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
                onSubmitted: (_) async {
                  if (_nanoIsGenerating) return;
                  setState(() { _currentNanoJobId = null; _nanoIsGenerating = true; _nanoError = null; });
                  try {
                    await _handleNanoGenerate();
                  } finally {
                    if (mounted && (_currentNanoJobId == null || _currentNanoJobId!.isEmpty)) {
                      setState(() { _nanoIsGenerating = false; });
                    }
                  }
                },
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Describe the style or transformation…',
                  hintStyle: GoogleFonts.inter(color: AppColors.secondaryText(context)),
                ),
                style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_nanoError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_nanoError!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
            ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _nanoIsGenerating ? null : () async {
                    setState(() { _currentNanoJobId = null; _nanoIsGenerating = true; _nanoError = null; });
                    try {
                      await _handleNanoGenerate();
                    } finally {
                      if (mounted && (_currentNanoJobId == null || _currentNanoJobId!.isEmpty)) {
                        setState(() { _nanoIsGenerating = false; });
                      }
                    }
                  },
                  icon: _nanoIsGenerating
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_nanoIsGenerating ? 'Generating…' : (_nanoResultBytes != null ? 'Regenerate' : 'Generate')),
                ),
                const SizedBox(width: 8),
                if (_nanoResultBytes != null) ...[
                  OutlinedButton.icon(
                    onPressed: _saving ? null : () async {
                      await _handleNanoSaveResultOnly();
                    },
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save Result'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 180,
            child: _buildNanoResultCard(),
          ),
        ],
      ),
    );
  }

  Future<void> _openVersions() async {
    try {
      final edits = await _editsRepo.listForProject(widget.projectId, limit: 50);
      final project = await _projectsRepo.getById(widget.projectId);
      final String? originalUrl = project?.originalImageUrl;
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.card(context),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) {
          return SafeArea(
            child: ListView.builder(
              itemCount: edits.length + ((originalUrl != null && originalUrl.isNotEmpty) ? 1 : 0),
              itemBuilder: (ctx, i) {
                final bool hasOriginal = originalUrl != null && originalUrl.isNotEmpty;
                if (hasOriginal && i == 0) {
                  // Pinned original image entry
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        originalUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (c, err, st) => Container(
                          width: 48,
                          height: 48,
                          color: AppColors.muted(context),
                          child: Icon(Icons.image_outlined, color: AppColors.secondaryText(context), size: 20),
                        ),
                      ),
                    ),
                    title: Text('Original image', style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w700)),
                    subtitle: Text('Pinned', style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12)),
                    trailing: const Icon(Icons.push_pin, size: 18),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _originalOrLastUrl = originalUrl;
                        _loading = true;
                        _error = null;
                      });
                      await _loadAndDownscaleImage(originalUrl);
                    },
                  );
                }

                final int idx = hasOriginal ? i - 1 : i;
                final e = edits[idx];
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
      final int? manualToolId = await _toolsRepo.getToolIdByName(toolIdName);
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

  Widget _aiChip(IconData icon, String label, VoidCallback onPressed) {
    return SizedBox(
      width: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: Colors.white),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
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
    _nanoResultBytes = null;
    _nanoIsGenerating = false;
    _nanoError = null;
    _nanoPromptController.clear();
    _lastAiAction = null;
  }

  void _pushAiUndo(Uint8List current) {
    // Establish session start on first change if needed
    _aiSessionStartBytes ??= Uint8List.fromList(current);
    _aiUndoStack.add(
      _AiSnapshot(bytes: Uint8List.fromList(current), actionMeta: _lastAiAction),
    );
    _aiRedoStack.clear();
  }

  void _aiUndo() {
    if (!_canAiUndo || _imageBytes == null) return;
    final _AiSnapshot previous = _aiUndoStack.removeLast();
    _aiRedoStack.add(
      _AiSnapshot(bytes: Uint8List.fromList(_imageBytes!), actionMeta: _lastAiAction),
    );
    setState(() {
      _imageBytes = previous.bytes;
      _lastAiAction = previous.actionMeta;
    });
  }

  void _aiRedo() {
    if (!_canAiRedo || _imageBytes == null) return;
    final _AiSnapshot next = _aiRedoStack.removeLast();
    _aiUndoStack.add(
      _AiSnapshot(bytes: Uint8List.fromList(_imageBytes!), actionMeta: _lastAiAction),
    );
    setState(() {
      _imageBytes = next.bytes;
      _lastAiAction = next.actionMeta;
    });
  }

  Future<void> _aiSave() async {
    if (_imageBytes == null) return;
    final _AiActionMeta? action = _lastAiAction;
    await _handleSave(
      _imageBytes!,
      source: 'ai',
      toolIdName: action?.toolIdName ?? 'ai_editor',
      editName: action?.editName ?? 'AI Editor',
      parameters: {
        'editor': 'AI',
        if (action != null) ...action.parameters,
        'undo_stack_size': _aiUndoStack.length,
        'redo_stack_size': _aiRedoStack.length,
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
    const String defaultPrompt = 'remove background make it transparent background not white, isolated subject';
    _lastAiAction = const _AiActionMeta(
      toolIdName: 'remove_background',
      editName: 'Remove Background',
      parameters: {
        'tool': 'remove_background',
        'model': 'nano_banana',
        'notes': 'AI background removal',
        'prompt': defaultPrompt,
      },
    );
    setState(() {
      _saving = true; // Show overlay until we confirm realtime subscription is active
    });
    try {
      // Enqueue background job; result handled via Realtime when Edge Function completes
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'remove_background',
        payload: const {
          'prompt': defaultPrompt,
        },
        inputImageUrl: _originalOrLastUrl,
      );
      // Track this job to keep loader visible until it completes
      if (mounted) setState(() { _activeJobIds.add(job.id); });
      // Trigger processing on Edge Function (runs in background)
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Background job queued'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      Logger.error('Queueing AI background removal failed', context: {
        'error': e.toString(),
      });
      if (!mounted) return;
      setState(() {
        _error = 'Failed to start job: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          content: Text('Failed to start AI job', style: TextStyle(color: Colors.white)),
        ),
      );
    } finally {
      if (mounted) {
        // Keep overlay if there are active jobs; otherwise hide
        setState(() {
          _saving = _activeJobIds.isNotEmpty;
        });
      }
    }
  }

  

  Future<void> _onStyleTransform() async {
    if (_imageBytes == null) return;
    _pushAiUndo(_imageBytes!);
    _lastAiAction = const _AiActionMeta(
      toolIdName: 'ai_style',
      editName: 'AI Style Transform',
      parameters: {
        'tool': 'ai_style',
      },
    );
    // TODO: Implement style transform
    setState(() {});
  }

  // ignore: unused_element
  Future<void> _onIdeogramEdit() async {
    if (_imageBytes == null) return;
    _pushAiUndo(_imageBytes!);
    _lastAiAction = const _AiActionMeta(
      toolIdName: 'ideogram_v3_edit',
      editName: 'ideogram/v3/edit',
      parameters: {
        'tool': 'ideogram_v3_edit',
      },
    );
    // TODO: Call ideogram/v3/edit
    setState(() {});
  }

  Future<void> _onIdeogramCharacterEdit() async {
    if (_imageBytes == null) return;
    // Collect prompt + references via a polished bottom sheet
    final _CharacterRemixInput? remix = await _showCharacterRemixBottomSheet();
    if (remix == null) return;

    _pushAiUndo(_imageBytes!);
    _lastAiAction = _AiActionMeta(
      toolIdName: 'ideogram_character_remix',
      editName: 'ideogram/character/remix',
      parameters: {
        'tool': 'ideogram_character_remix',
        'prompt': remix.prompt,
        'reference_count': remix.referenceUrls.length,
      },
    );

    setState(() { _saving = true; });
    try {
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'ideogram_character_remix',
        payload: {
          'prompt': remix.prompt,
          'reference_urls': remix.referenceUrls,
        },
        inputImageUrl: _originalOrLastUrl,
      );
      if (mounted) setState(() { _activeJobIds.add(job.id); });
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Character remix started')),
      );
    } catch (e) {
      Logger.error('Queueing ideogram_character_remix failed', context: {'error': e.toString()});
      if (!mounted) return;
      setState(() { _error = 'Failed to start character remix: ${e.toString()}'; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.redAccent, content: Text('Failed to start', style: TextStyle(color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() { _saving = _activeJobIds.isNotEmpty; });
    }
  }

  Future<void> _onElementsRemix() async {
    if (_imageBytes == null) return;
    // Collect prompt + single reference image (from library or upload)
    final _ElementsInput? data = await _showElementsBottomSheet();
    if (data == null) return;

    _pushAiUndo(_imageBytes!);
    _lastAiAction = _AiActionMeta(
      toolIdName: 'elements',
      editName: 'Elements Remix',
      parameters: {
        'tool': 'elements',
        'prompt': data.prompt,
        'reference_url': data.referenceUrl,
      },
    );

    setState(() { _saving = true; });
    try {
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'elements',
        payload: {
          'prompt': data.prompt,
          'reference_url': data.referenceUrl,
        },
        inputImageUrl: _originalOrLastUrl,
      );
      if (mounted) setState(() { _activeJobIds.add(job.id); });
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Elements remix started')),
      );
    } catch (e) {
      Logger.error('Queueing elements failed', context: {'error': e.toString()});
      if (!mounted) return;
      setState(() { _error = 'Failed to start elements remix: ${e.toString()}'; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.redAccent, content: Text('Failed to start', style: TextStyle(color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() { _saving = _activeJobIds.isNotEmpty; });
    }
  }

  Future<void> _onIdeogramReframe() async {
    if (_imageBytes == null) return;
    // Ask for target resolution with beautiful bottom sheet
    final ReframeSelection? sel = await _showReframeBottomSheet();
    if (sel == null) return;

    _pushAiUndo(_imageBytes!);
    _lastAiAction = _AiActionMeta(
      toolIdName: 'ideogram_v3_reframe',
      editName: 'ideogram/v3/reframe',
      parameters: {
        'tool': 'ideogram_v3_reframe',
        'width': sel.width,
        'height': sel.height,
        if (sel.label != null) 'preset': sel.label,
      },
    );

    setState(() { _saving = true; });
    try {
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'ideogram_v3_reframe',
        payload: {
          'width': sel.width,
          'height': sel.height,
        },
        inputImageUrl: _originalOrLastUrl,
      );
      if (mounted) setState(() { _activeJobIds.add(job.id); });
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Reframe started')),
      );
    } catch (e) {
      Logger.error('Queueing ideogram_v3_reframe failed', context: {'error': e.toString()});
      if (!mounted) return;
      setState(() { _error = 'Failed to start reframe: ${e.toString()}'; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.redAccent, content: Text('Failed to start', style: TextStyle(color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() { _saving = _activeJobIds.isNotEmpty; });
    }
  }

  // _onNanoBanana is no longer used; Remix is toggled inline from the toolbar

  // Removed modal dialog version of nano_banana UI

  Future<void> _onCalligrapher() async {
    if (_imageBytes == null) return;
    _ensureAiSessionStarted();
    final TextEditingController controller = TextEditingController();
    String? prompt;
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Text in Image'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: "e.g. The text is 'Rise'"),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                prompt = controller.text.trim();
                Navigator.of(ctx).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (prompt == null || prompt!.isEmpty) return;

    _pushAiUndo(_imageBytes!);
    _lastAiAction = _AiActionMeta(
      toolIdName: 'calligrapher',
      editName: 'Calligrapher Text Edit',
      parameters: {
        'tool': 'calligrapher',
        'prompt': prompt,
      },
    );

    setState(() {
      _saving = true;
    });
    try {
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'calligrapher',
        payload: {'prompt': prompt},
        inputImageUrl: _originalOrLastUrl,
      );
      if (mounted) setState(() { _activeJobIds.add(job.id); });
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Calligrapher started')),
      );
    } catch (e) {
      Logger.error('Queueing calligrapher failed', context: {'error': e.toString()});
      if (!mounted) return;
      setState(() { _error = 'Failed to start calligrapher: ${e.toString()}'; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.redAccent, content: Text('Failed to start', style: TextStyle(color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() { _saving = _activeJobIds.isNotEmpty; });
    }
  }

  // Reframe UI
  Future<ReframeSelection?> _showReframeBottomSheet() async {
    final Color onBg = AppColors.onBackground(context);
    final TextEditingController widthCtrl = TextEditingController();
    final TextEditingController heightCtrl = TextEditingController();

    // Helpful presets
    final List<ReframePreset> presets = <ReframePreset>[
      const ReframePreset(label: 'Square', subtitle: '1:1', width: 1024, height: 1024),
      const ReframePreset(label: 'Portrait', subtitle: '4:5', width: 2048, height: 2560),
      const ReframePreset(label: 'Story', subtitle: '9:16', width: 1080, height: 1920),
      const ReframePreset(label: 'Landscape', subtitle: '16:9', width: 1920, height: 1080),
      const ReframePreset(label: 'Widescreen', subtitle: '1440p', width: 2560, height: 1440),
    ];

    int? selectedIndex;
    String? errorText;

    void _applyPreset(int index, void Function(void Function()) setState) {
      selectedIndex = index;
      widthCtrl.text = presets[index].width.toString();
      heightCtrl.text = presets[index].height.toString();
      setState(() {});
    }

    bool _validWH() {
      final int? w = int.tryParse(widthCtrl.text.trim());
      final int? h = int.tryParse(heightCtrl.text.trim());
      if (w == null || h == null) return false;
      if (w < 64 || h < 64) return false;
      if (w > 4096 || h > 4096) return false;
      return true;
    }

    final ReframeSelection? result = await showModalBottomSheet<ReframeSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.autorenew_rounded, color: onBg),
                        const SizedBox(width: 8),
                        Text('Reframe', style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w800, fontSize: 16)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Suggested sizes', style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (int i = 0; i < presets.length; i++)
                          ReframePresetCard(
                            preset: presets[i],
                            selected: selectedIndex == i,
                            onTap: () => _applyPreset(i, setSheetState),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text('Custom size', style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.muted(context).withOpacity(0.25), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: widthCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Width (px)',
                                ),
                                style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w600),
                                onChanged: (_) {
                                  selectedIndex = null;
                                  setSheetState(() {});
                                },
                              ),
                            ),
                            Text('×', style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontWeight: FontWeight.w900)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: heightCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Height (px)',
                                ),
                                style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w600),
                                onChanged: (_) {
                                  selectedIndex = null;
                                  setSheetState(() {});
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(errorText!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                      ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (!_validWH()) {
                          errorText = 'Please enter a valid size between 64 and 4096 px.';
                          setSheetState(() {});
                          return;
                        }
                        final int w = int.parse(widthCtrl.text.trim());
                        final int h = int.parse(heightCtrl.text.trim());
                        Navigator.of(ctx).pop(ReframeSelection(width: w, height: h, label: selectedIndex != null ? presets[selectedIndex!].label : null));
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Reframe'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Powered by Ideogram V3 Reframe',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    return result;
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
                  // Padding(
                  //   padding: const EdgeInsets.all(12),
                  //   child: Row(
                  //     children: [
                  //       OutlinedButton.icon(
                  //         onPressed: _nanoIsGenerating ? null : _handleNanoGenerate,
                  //         icon: const Icon(Icons.refresh_rounded),
                  //         label: const Text('Regenerate'),
                  //       ),
                  //       const SizedBox(width: 8),
                  //       OutlinedButton.icon(
                  //         onPressed: _nanoResultBytes == null || _imageBytes == null || _saving
                  //             ? null
                  //             : () => _handleNanoReplaceWithResult(),
                  //         icon: const Icon(Icons.swap_horizontal_circle_outlined),
                  //         label: const Text('Replace Original'),
                  //       ),
                  //       const Spacer(),
                  //       ElevatedButton.icon(
                  //         onPressed: _nanoResultBytes == null || _saving ? null : () => _handleNanoSaveResultOnly(),
                  //         icon: const Icon(Icons.save_alt_rounded),
                  //         label: const Text('Save Result'),
                  //       ),
                  //     ],
                  //   ),
                  // ),
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
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'nano_banana',
        payload: {'prompt': prompt},
        inputImageUrl: _originalOrLastUrl,
      );
      if (mounted) {
        setState(() {
          _currentNanoJobId = job.id;
        });
        // Inline panel auto-rebuilds via setState
      }
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('AI started working')),
      );
    } catch (e) {
      Logger.error('Queueing nano_banana failed', context: {
        'prompt': prompt,
        'error': e.toString(),
      });
      if (!mounted) return;
      setState(() {
        _nanoError = e.toString();
      });
    } finally {}
  }

  // Removed Replace Original action per request

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

  // Character Remix UI
  Future<_CharacterRemixInput?> _showCharacterRemixBottomSheet() async {
    final TextEditingController promptCtrl = TextEditingController();
    final Color onBg = AppColors.onBackground(context);

    // Load user's recent images to use as references
    late Future<List<MediaItem>> mediaFuture;
    mediaFuture = _mediaRepo.listMedia(limit: 60, filterMime: 'image');

    // Local selection state inside the sheet
    final Set<String> selectedUrls = <String>{};
    String? errorText;

    bool canStart() => promptCtrl.text.trim().isNotEmpty && selectedUrls.isNotEmpty;

    final _CharacterRemixInput? result = await showModalBottomSheet<_CharacterRemixInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_rounded, color: onBg),
                        const SizedBox(width: 8),
                        Text('Character Remix', style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w800, fontSize: 16)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Prompt', style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.muted(context).withOpacity(0.25), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: TextField(
                          controller: promptCtrl,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Describe the style, setting, or scenario for your character…',
                          ),
                          style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w600),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('Reference images', style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (selectedUrls.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.selectedBackground(context),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('${selectedUrls.length} selected', style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<MediaItem>>(
                      future: mediaFuture,
                      builder: (c, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final items = (snap.data ?? <MediaItem>[])
                            .where((m) => m.mimeType.startsWith('image'))
                            .toList();
                        if (items.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text('No images in your library yet. Upload some to use as references.',
                                style: GoogleFonts.inter(color: AppColors.secondaryText(context))),
                          );
                        }
                        final double gridSpacing = 8;
                        final int crossAxisCount = 3;
                        final double availH = MediaQuery.of(ctx).size.height;
                        final double gridH = (availH * 0.45).clamp(220.0, 420.0);
                        return SizedBox(
                          height: gridH,
                          child: GridView.builder(
                            padding: const EdgeInsets.only(bottom: 4),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: gridSpacing,
                              mainAxisSpacing: gridSpacing,
                              childAspectRatio: 1,
                            ),
                            itemCount: items.length,
                            itemBuilder: (c, i) {
                              final item = items[i];
                              final String url = item.thumbnailUrl ?? item.url;
                              final bool selected = selectedUrls.contains(url);
                              return GestureDetector(
                                onTap: () {
                                  if (selected) {
                                    selectedUrls.remove(url);
                                  } else {
                                    // Limit to 4 refs to keep API efficient
                                    if (selectedUrls.length >= 4) {
                                      errorText = 'Maximum 4 reference images';
                                    } else {
                                      errorText = null;
                                      selectedUrls.add(url);
                                    }
                                  }
                                  setSheetState(() {});
                                },
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          url,
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, st) => Container(
                                            color: AppColors.muted(context),
                                            child: Icon(Icons.image_not_supported_outlined, color: AppColors.secondaryText(context)),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: selected ? AppColors.primaryPurple : Colors.transparent, width: 2),
                                          color: selected ? AppColors.primaryPurple.withOpacity(0.15) : Colors.transparent,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryPurple,
                                            borderRadius: BorderRadius.circular(999),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
                                            ],
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(errorText!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                      ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: canStart()
                          ? () {
                              Navigator.of(ctx).pop(_CharacterRemixInput(
                                prompt: promptCtrl.text.trim(),
                                referenceUrls: selectedUrls.toList(growable: false),
                              ));
                            }
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Remix'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Powered by Ideogram V3 Character Remix',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    return result;
  }

  // Elements bottom sheet: prompt + pick single reference or upload from gallery
  Future<_ElementsInput?> _showElementsBottomSheet() async {
    final TextEditingController promptCtrl = TextEditingController();
    final Color onBg = AppColors.onBackground(context);

    late Future<List<MediaItem>> mediaFuture;
    mediaFuture = _mediaRepo.listMedia(limit: 60, filterMime: 'image');

    String? selectedUrl;
    String? errorText;

    bool canStart() => promptCtrl.text.trim().isNotEmpty && (selectedUrl != null && selectedUrl!.isNotEmpty);

    final _ElementsInput? result = await showModalBottomSheet<_ElementsInput>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.widgets_rounded, color: onBg),
                        const SizedBox(width: 8),
                        Text('Elements', style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w800, fontSize: 16)),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Prompt', style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.muted(context).withOpacity(0.25), width: 1),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: TextField(
                          controller: promptCtrl,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Describe what to add or remix into your photo…',
                          ),
                          style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w600),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('Reference image', style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontWeight: FontWeight.w700)),
                        const Spacer(),
                        if (selectedUrl != null)
                          Text('1 selected', style: GoogleFonts.inter(color: onBg, fontWeight: FontWeight.w700, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<List<MediaItem>>(
                      future: mediaFuture,
                      builder: (c, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final items = (snap.data ?? <MediaItem>[]) 
                            .where((m) => m.mimeType.startsWith('image'))
                            .toList();
                        final double gridSpacing = 8;
                        final int crossAxisCount = 3;
                        final double availH = MediaQuery.of(ctx).size.height;
                        final double gridH = (availH * 0.38).clamp(200.0, 380.0);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (items.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text('No images yet. Upload one from your gallery below.',
                                    style: GoogleFonts.inter(color: AppColors.secondaryText(context))),
                              ),
                            if (items.isNotEmpty)
                              SizedBox(
                                height: gridH,
                                child: GridView.builder(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  physics: const BouncingScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: gridSpacing,
                                    mainAxisSpacing: gridSpacing,
                                    childAspectRatio: 1,
                                  ),
                                  itemCount: items.length,
                                  itemBuilder: (c, i) {
                                    final item = items[i];
                                    final String url = item.thumbnailUrl ?? item.url;
                                    final bool selected = selectedUrl == url;
                                    return GestureDetector(
                                      onTap: () {
                                        selectedUrl = selected ? null : url;
                                        errorText = null;
                                        setSheetState(() {});
                                      },
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, st) => Container(
                                                  color: AppColors.muted(context),
                                                  child: Icon(Icons.image_not_supported_outlined, color: AppColors.secondaryText(context)),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned.fill(
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: selected ? AppColors.primaryPurple : Colors.transparent, width: 2),
                                                color: selected ? AppColors.primaryPurple.withOpacity(0.15) : Colors.transparent,
                                              ),
                                            ),
                                          ),
                                          if (selected)
                                            Positioned(
                                              right: 6,
                                              top: 6,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryPurple,
                                                  borderRadius: BorderRadius.circular(999),
                                                  boxShadow: [
                                                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 3)),
                                                  ],
                                                ),
                                                padding: const EdgeInsets.all(4),
                                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                // Let user upload a new reference from gallery; on success, refresh list and select it
                                try {
                                  final mediaCap = MediaPipelineService();
                                  await mediaCap.pickFromGalleryAndQueue();
                                  mediaFuture = _mediaRepo.listMedia(limit: 60, filterMime: 'image');
                                  setSheetState(() {});
                                } catch (_) {}
                              },
                              icon: const Icon(Icons.photo_library_rounded),
                              label: const Text('Upload from gallery'),
                            ),
                          ],
                        );
                      },
                    ),
                    if (errorText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(errorText!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12)),
                      ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: canStart()
                          ? () {
                              Navigator.of(ctx).pop(_ElementsInput(
                                prompt: promptCtrl.text.trim(),
                                referenceUrl: selectedUrl!,
                              ));
                            }
                          : null,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Elements'),
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Powered by Nano Banana Edit',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    return result;
  }

}

class _CharacterRemixInput {
  final String prompt;
  final List<String> referenceUrls;
  const _CharacterRemixInput({required this.prompt, required this.referenceUrls});
}

class _ElementsInput {
  final String prompt;
  final String referenceUrl;
  const _ElementsInput({required this.prompt, required this.referenceUrl});
}






