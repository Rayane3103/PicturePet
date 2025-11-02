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
import '../utils/export_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import '../widgets/mask_brush_painter.dart';
import 'package:image_picker/image_picker.dart';

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

class _StylePreset {
  final String name;
  final String prompt;
  final String asset;
  const _StylePreset({required this.name, required this.prompt, required this.asset});
}

class _StyleSelection {
  final String stylePrompt;
  const _StyleSelection({required this.stylePrompt});
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

  ExportOptions _lastExportOptions = const ExportOptions(
    format: ExportFormat.png,
    quality: 100,
    scale: 1,
    includeMetadata: false,
    transparentBackground: true,
  );

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
        
        // Handle failed or cancelled jobs - remove from active jobs immediately
        if (_activeJobIds.contains(job.id) &&
            (job.status == 'failed' || job.status == 'cancelled')) {
          if (mounted) {
            setState(() {
              _activeJobIds.remove(job.id);
              _saving = _activeJobIds.isNotEmpty;
            });
          }
        }
        
        if (job.status == 'completed' && job.resultUrl != null) {
          try {
            if (job.toolName == 'nano_banana') {
              // Update main editor image automatically like other tools
              _originalOrLastUrl = job.resultUrl;
              await _loadAndDownscaleImage(job.resultUrl!);
              if (!mounted) return;
              setState(() {
                _nanoResultBytes = _imageBytes; // Store for potential panel display
                if (_currentNanoJobId == job.id) {
                  _nanoIsGenerating = false;
                }
                // Now that image is loaded, remove from active jobs
                _activeJobIds.remove(job.id);
                _saving = _activeJobIds.isNotEmpty;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Remix result applied')),
              );
            } else {
              _originalOrLastUrl = job.resultUrl;
              await _loadAndDownscaleImage(job.resultUrl!);
              if (!mounted) return;
              // Now that image is loaded and displayed, remove from active jobs
              setState(() {
                _activeJobIds.remove(job.id);
                _saving = _activeJobIds.isNotEmpty;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(behavior: SnackBarBehavior.floating, content: Text('AI result applied')),
              );
              // Notify library/list views to refresh thumbnails
              ProjectsEvents.instance.notifyChanged();
            }
          } catch (e) {
            Logger.warn('Failed to apply AI job result', context: {'error': e.toString()});
            // Remove from active jobs even on error
            if (mounted) {
              setState(() {
                _activeJobIds.remove(job.id);
                _saving = _activeJobIds.isNotEmpty;
              });
            }
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
        actions: [
          ..._buildAppBarActions(),
          IconButton(
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: _imageBytes == null ? null : _openExportSheet,
          ),
        ],
      ),
      backgroundColor: AppColors.background(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildImage(),
                // Blur overlay only on the image area
                if (_saving || _activeJobIds.isNotEmpty)
                  ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Loading...',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            bottom: 96,
            child: SafeArea(
              child: _ExportFab(
                enabled: _imageBytes != null,
                onTap: _openExportSheet,
              ),
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

  Future<void> _openExportSheet() async {
    if (_imageBytes == null) return;
    final ExportOptions? opts = await _showExportBottomSheetPreview(_imageBytes!);
    if (opts == null) return;
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

  Future<ExportOptions?> _showExportBottomSheetPreview(Uint8List previewBytes) async {
    ExportFormat format = _lastExportOptions.format;
    int quality = _lastExportOptions.quality;
    double scale = _lastExportOptions.scale;
    bool transparentBackground = _lastExportOptions.transparentBackground;
    

    bool exporting = false;

    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final Color onBg = AppColors.onBackground(context);

    double _fitToScreenScale() {
      try {
        final mq = MediaQuery.of(context);
        final double screenW = mq.size.width * mq.devicePixelRatio;
        final double screenH = (mq.size.height * 0.8) * mq.devicePixelRatio;
        final image = img.decodeImage(previewBytes);
        if (image == null) return 1.0;
        final sw = screenW / image.width;
        final sh = screenH / image.height;
        return (math.min(sw, sh)).clamp(0.1, 4.0);
      } catch (_) {
        return 1.0;
      }
    }

    Future<void> doExportAndSave(StateSetter setModal) async {
      if (exporting) return;
      setModal(() { exporting = true; });
      try {
        final options = ExportOptions(
          format: format,
          quality: quality,
          scale: scale,
          includeMetadata: false,
          watermark: null,
          transparentBackground: transparentBackground,
        );
        final rendered = await renderEditorToBytes(directBytes: _imageBytes);
        final encoded = await encodeToFormat(rendered, options);
        final fname = buildFileName(format: options.format);
        final res = await saveToGallery(encoded, fname, options);
        if (!mounted) return;
        if (res.success) {
          _lastExportOptions = options;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(isRTL ? 'تم الحفظ في المعرض' : 'Saved to gallery'),
              action: res.path != null ? SnackBarAction(
                label: isRTL ? 'فتح' : 'Open',
                onPressed: () {
                  Share.shareXFiles([XFile(res.path!)]);
                },
              ) : null,
            ),
          );
          if (Navigator.of(context).canPop()) Navigator.of(context).pop(options);
        } else {
          final denied = (res.error ?? '').toLowerCase().contains('permission');
          if (denied) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.redAccent,
                content: Text(isRTL ? 'الإذن مرفوض. افتح الإعدادات لمنح الوصول.' : 'Permission denied. Open Settings to grant access.', style: const TextStyle(color: Colors.white)),
                action: SnackBarAction(
                  label: isRTL ? 'الإعدادات' : 'Settings',
                  textColor: Colors.white,
                  onPressed: () async { await openAppSettings(); },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.redAccent, content: Text(res.error ?? (isRTL ? 'فشل الحفظ' : 'Save failed'), style: const TextStyle(color: Colors.white))),
            );
          }
        }
      } finally {
        if (mounted) setModal(() { exporting = false; });
      }
    }

    Future<void> doExportAndShare(StateSetter setModal) async {
      if (exporting) return;
      setModal(() { exporting = true; });
      try {
        final options = ExportOptions(
          format: format,
          quality: quality,
          scale: scale,
          includeMetadata: false,
          watermark: null,
          transparentBackground: transparentBackground,
        );
        final rendered = await renderEditorToBytes(directBytes: _imageBytes);
        final encoded = await encodeToFormat(rendered, options);
        final fname = buildFileName(format: options.format);
        final res = await saveToTempAndShare(encoded, fname, options);
        if (!mounted) return;
        if (res.success) {
          _lastExportOptions = options;
          if (Navigator.of(context).canPop()) Navigator.of(context).pop(options);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.redAccent, content: Text(res.error ?? (isRTL ? 'فشل المشاركة' : 'Share failed'), style: const TextStyle(color: Colors.white))),
          );
        }
      } finally {
        if (mounted) setModal(() { exporting = false; });
      }
    }

    return showModalBottomSheet<ExportOptions>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.card(context).withOpacity(0.95),
                  AppColors.background(context).withOpacity(0.98),
                ],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: AppColors.primaryPurple.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.muted(context).withOpacity(0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [AppColors.primaryPurple, AppColors.primaryBlue]),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryPurple.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isRTL ? 'تصدير' : 'Export',
                                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: onBg),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isRTL ? 'اختر التنسيق والجودة والحجم' : 'Choose format, quality, and size',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText(context)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface(context),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [softShadow(context)],
                            ),
                            clipBehavior: Clip.antiAlias,
                            height: 120,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(MaterialPageRoute(builder: (_) => _FullImagePreview(bytes: previewBytes)));
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.memory(previewBytes, fit: BoxFit.cover, filterQuality: FilterQuality.high),
                                  BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                                    child: Container(color: Colors.black.withOpacity(0.08)),
                                  ),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.35),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.visibility_rounded, color: Colors.white, size: 22),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(isRTL ? 'التنسيق' : 'Format', style: TextStyle(color: onBg, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            SegmentedButton<ExportFormat>(
                              segments: const [
                                ButtonSegment(value: ExportFormat.png, label: Text('PNG')),
                                ButtonSegment(value: ExportFormat.jpeg, label: Text('JPEG')),
                              ],
                              selected: {format},
                              onSelectionChanged: (s) => setModal(() { format = s.first; }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (format == ExportFormat.jpeg) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isRTL ? 'الجودة' : 'Quality', style: TextStyle(color: onBg, fontWeight: FontWeight.w700)),
                          Text('$quality'),
                        ],
                      ),
                      Slider(
                        min: 40,
                        max: 100,
                        divisions: 60,
                        value: quality.toDouble().clamp(40, 100),
                        onChanged: (v) => setModal(() { quality = v.round(); }),
                      ),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(isRTL ? 'الحجم' : 'Export size', style: TextStyle(color: onBg, fontWeight: FontWeight.w700)),
                        DropdownButton<double>(
                          value: scale,
                          items: [
                            const DropdownMenuItem(value: 1.0, child: Text('Original')),
                            const DropdownMenuItem(value: 0.25, child: Text('0.25x')),
                            const DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                            const DropdownMenuItem(value: 2.0, child: Text('2x')),
                            DropdownMenuItem(value: _fitToScreenScale(), child: Text(isRTL ? 'ملاءمة للشاشة' : 'Fit to screen')),
                          ],
                          onChanged: (v) => setModal(() { if (v != null) scale = v; }),
                        ),
                      ],
                    ),
                    if (format == ExportFormat.png) ...[
                      SwitchListTile(
                        value: transparentBackground,
                        onChanged: (v) => setModal(() { transparentBackground = v; }),
                        contentPadding: EdgeInsets.zero,
                        title: Text(isRTL ? 'خلفية شفافة' : 'Transparent background'),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (exporting) const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: exporting ? null : () => doExportAndSave(setModal),
                            icon: const Icon(Icons.download_rounded),
                            label: Text(
                              isRTL ? 'تصدير وحفظ' : 'Export & Save',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: exporting ? null : () => doExportAndShare(setModal),
                            icon: const Icon(Icons.ios_share_rounded),
                            label: Text(
                              isRTL ? 'تصدير ومشاركة' : 'Export & Share',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: exporting ? null : () => Navigator.of(ctx).pop(),
                        child: Text(isRTL ? 'إلغاء' : 'Cancel'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
          );
        });
      },
    );
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
                        _aiChip(Icons.bolt_rounded, 'Remix', _onRemix),
                        const SizedBox(width: 8),
                        _aiChip(Icons.autorenew_rounded, 'Reframe', _onIdeogramReframe),
                        const SizedBox(width: 8),
                        _aiChip(Icons.widgets_rounded, 'Elements', _onElementsRemix),
                        const SizedBox(width: 8),
                        _aiChip(Icons.auto_fix_high_rounded, 'Style', _onStyleTransform),
                        const SizedBox(width: 8),
                        _aiChip(Icons.high_quality_rounded, 'Upscale', _onUpscale),
                        const SizedBox(width: 8),
                        _aiChip(Icons.brush_rounded, 'Mask Edit', _onCharacterBrushEdit),
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
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.card(context).withOpacity(0.9),
                AppColors.muted(context).withOpacity(0.5),
              ],
            ),
            border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                spreadRadius: 0,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.primaryPurple.withOpacity(0.08),
                blurRadius: 16,
                spreadRadius: 0,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                  color: AppColors.card(context).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(32),
              ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.secondaryText(context),
                    dividerColor: Colors.transparent,
                    splashBorderRadius: BorderRadius.circular(26),
                indicator: BoxDecoration(
                  gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.2),
                      blurRadius: 8,
                          spreadRadius: 0,
                          offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.5,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.25,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                    indicatorPadding: const EdgeInsets.all(2),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.tune_rounded,
                              size: 18,
                              color: _tabController.index == 0 
                                ? Colors.white 
                                : AppColors.secondaryText(context),
                            ),
                            const SizedBox(width: 6),
                            const Text('Manual'),
                ],
              ),
            ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: _tabController.index == 1 
                                ? Colors.white 
                                : AppColors.secondaryText(context),
                            ),
                            const SizedBox(width: 6),
                            const Text('AI'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
            textEditor: TextEditorConfigs(
              enabled: true,
              showSelectFontStyleBottomBar: true, // Enable style picker
              customTextStyles: [
                // Single styles
                GoogleFonts.inter(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold), // Bold
                GoogleFonts.inter(fontSize: 24, color: Colors.white, fontStyle: FontStyle.italic), // Italic
                GoogleFonts.inter(fontSize: 24, color: Colors.white, decoration: TextDecoration.underline), // Underline
                
                // Combinations of 2
                GoogleFonts.inter(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic), // Bold + Italic
                GoogleFonts.inter(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline), // Bold + Underline
                GoogleFonts.inter(fontSize: 24, color: Colors.white, fontStyle: FontStyle.italic, decoration: TextDecoration.underline), // Italic + Underline
                
                // Combination of 3
                GoogleFonts.inter(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, decoration: TextDecoration.underline), // Bold + Italic + Underline
              ],
              style: TextEditorStyle(
                background: Colors.black.withOpacity(0.7), // Semi-transparent to see image
                appBarBackground: AppColors.background(context),
                appBarColor: AppColors.onBackground(context),
                bottomBarBackground: AppColors.surface(context),
              ),
            ),
          ),
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List bytes) async {
              await _handleSave(
                bytes,
                source: 'manual',
                toolIdName: 'manual_editor',
                editName: 'Manual Editor Session',
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
      
      // Reorder list to put "Initial Import" at the top
      final reorderedEdits = <dynamic>[];
      dynamic initialImport;
      for (final edit in edits) {
        if (edit.editName == 'Initial Import') {
          initialImport = edit;
        } else {
          reorderedEdits.add(edit);
        }
      }
      if (initialImport != null) {
        reorderedEdits.insert(0, initialImport);
      }
      
      if (!mounted) return;
      // ignore: use_build_context_synchronously
      await showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.card(context),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (_) {
          return SafeArea(
            child: ListView.builder(
              itemCount: reorderedEdits.length,
              itemBuilder: (ctx, i) {
                final e = reorderedEdits[i];
                final thumbUrl = e.outputImageUrl ?? e.inputImageUrl;
                final bool isInitialImport = e.editName == 'Initial Import';
                
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
                  title: Text(e.editName, style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: isInitialImport ? FontWeight.w700 : FontWeight.w600)),
                  subtitle: Text(
                    isInitialImport ? 'Pinned' : e.createdAt.toLocal().toString(),
                    style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12),
                  ),
                  trailing: isInitialImport ? const Icon(Icons.push_pin, size: 18) : null,
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
    String editName = 'Manual Editor Session',
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
      width: 85,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
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
      toolIdName: action?.toolIdName ?? 'nano_banana',
      editName: action?.editName ?? 'nano_banana',
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
    final _StyleSelection? sel = await _showStyleTransferBottomSheet();
    if (sel == null) return;

    _pushAiUndo(_imageBytes!);
    _lastAiAction = _AiActionMeta(
      toolIdName: 'style_transfer',
      editName: 'Style Transfer',
      parameters: {
        'tool': 'style_transfer',
        'style_prompt': sel.stylePrompt,
      },
    );

    setState(() { _saving = true; });
    try {
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'style_transfer',
        payload: {
          'style_prompt': sel.stylePrompt,
        },
        inputImageUrl: _originalOrLastUrl,
      );
      if (mounted) setState(() { _activeJobIds.add(job.id); });
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Style transfer started')),
      );
    } catch (e) {
      Logger.error('Queueing style_transfer failed', context: {'error': e.toString()});
      if (!mounted) return;
      setState(() { _error = 'Failed to start style transfer: ${e.toString()}'; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.redAccent, content: Text('Failed to start', style: TextStyle(color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() { _saving = _activeJobIds.isNotEmpty; });
    }
  }

  Future<void> _onUpscale() async {
    if (_imageBytes == null) return;
    final int? factor = await _showUpscaleBottomSheet();
    if (factor == null) return;

    _pushAiUndo(_imageBytes!);
    _lastAiAction = _AiActionMeta(
      toolIdName: 'seedvr_upscale',
      editName: 'SeedVR2 Upscale',
      parameters: {
        'tool': 'seedvr_upscale',
        'upscale_factor': factor,
      },
    );

    setState(() { _saving = true; });
    try {
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'seedvr_upscale',
        payload: {
          'upscale_factor': factor,
        },
        inputImageUrl: _originalOrLastUrl,
      );
      if (mounted) setState(() { _activeJobIds.add(job.id); });
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Upscale started')),
      );
    } catch (e) {
      Logger.error('Queueing seedvr_upscale failed', context: {'error': e.toString()});
      if (!mounted) return;
      setState(() { _error = 'Failed to start upscaler: ${e.toString()}'; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.redAccent, content: Text('Failed to start', style: TextStyle(color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() { _saving = _activeJobIds.isNotEmpty; });
    }
  }

  Future<int?> _showUpscaleBottomSheet() async {
    final Color onBg = AppColors.onBackground(context);
    int selected = 2;

    final int? result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.card(context).withOpacity(0.95),
                AppColors.background(context).withOpacity(0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                          // Handle bar
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.muted(context).withOpacity(0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Header
                    Row(
                      children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryPurple,
                                      AppColors.accentPurple,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryPurple.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.high_quality_rounded, 
                                  color: Colors.white, 
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Upscale',
                                      style: GoogleFonts.inter(
                          color: onBg,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 24,
                                        letterSpacing: 0.25,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Enhance image resolution',
                                      style: GoogleFonts.inter(
                                        color: AppColors.secondaryText(context),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.muted(context).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  tooltip: 'Close',
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: AppColors.secondaryText(context),
                                  ),
                          onPressed: () => Navigator.of(ctx).pop(),
                                ),
                        ),
                      ],
                    ),
                          const SizedBox(height: 24),
                          // Scale Selection
                          Text(
                            'Scale factor',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                      children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setSheetState(() => selected = 2),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: selected == 2 
                                        ? AppGradients.primary
                                        : LinearGradient(
                                            colors: [
                                              AppColors.card(context).withOpacity(0.6),
                                              AppColors.surface(context).withOpacity(0.4),
                                            ],
                                          ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected == 2 
                                          ? Colors.transparent
                                          : AppColors.muted(context).withOpacity(0.3),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        if (selected == 2) ...[
                                          BoxShadow(
                                            color: AppColors.primaryPurple.withOpacity(0.3),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ] else ...[
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '2×',
                                          style: GoogleFonts.inter(
                                            color: selected == 2 
                                              ? Colors.white
                                              : AppColors.onBackground(context),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 32,
                                            letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                                        Text(
                                          'Double size',
                                          style: GoogleFonts.inter(
                                            color: selected == 2 
                                              ? Colors.white.withOpacity(0.9)
                                              : AppColors.secondaryText(context),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setSheetState(() => selected = 4),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: selected == 4 
                                        ? AppGradients.primary
                                        : LinearGradient(
                                            colors: [
                                              AppColors.card(context).withOpacity(0.6),
                                              AppColors.surface(context).withOpacity(0.4),
                                            ],
                                          ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: selected == 4 
                                          ? Colors.transparent
                                          : AppColors.muted(context).withOpacity(0.3),
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        if (selected == 4) ...[
                                          BoxShadow(
                                            color: AppColors.primaryPurple.withOpacity(0.3),
                                            blurRadius: 16,
                                            offset: const Offset(0, 8),
                                          ),
                                        ] else ...[
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          '4×',
                                          style: GoogleFonts.inter(
                                            color: selected == 4 
                                              ? Colors.white
                                              : AppColors.onBackground(context),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 32,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Quadruple size',
                                          style: GoogleFonts.inter(
                                            color: selected == 4 
                                              ? Colors.white.withOpacity(0.9)
                                              : AppColors.secondaryText(context),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Action Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.of(ctx).pop(selected),
                              icon: const Icon(
                                Icons.trending_up_rounded,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Start Upscale',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Footer
                          Center(
                            child: Text(
                              'Powered by SeedVR2',
                              style: GoogleFonts.inter(
                                color: AppColors.mutedText(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ],
                    ),
                  ),
                );
              },
                ),
              ),
            ),
          ),
        );
      },
    );

    return result;
  }

  // Style Transfer UI
  Future<_StyleSelection?> _showStyleTransferBottomSheet() async {
    final Color onBg = AppColors.onBackground(context);

    final List<_StylePreset> presets = const <_StylePreset>[
      _StylePreset(
        name: 'Original',
        prompt: 'apply no changes keep original photo realism',
        asset: 'assets/images/filter.png',
      ),
      _StylePreset(
        name: 'Van Gogh',
        prompt: "in the style of Vincent van Gogh's Starry Night swirling brushstrokes vivid blues and yellows",
        asset: 'assets/images/filter.png',
      ),
      _StylePreset(
        name: 'Ghibli',
        prompt: 'Studio Ghibli painterly whimsical soft colors gentle lighting anime aesthetic',
        asset: 'assets/images/filter.png',
      ),
      _StylePreset(
        name: 'Watercolor',
        prompt: 'watercolor painting soft bleeding edges paper texture pastel tones',
        asset: 'assets/images/filter.png',
      ),
      _StylePreset(
        name: 'Oil Paint',
        prompt: 'thick oil paint impasto dramatic lighting rich contrast canvas texture',
        asset: 'assets/images/filter.png',
      ),
      _StylePreset(
        name: 'Cyberpunk',
        prompt: 'neon cyberpunk city glow magenta cyan rim light futuristic high contrast',
        asset: 'assets/images/filter.png',
      ),
      _StylePreset(
        name: 'Toon',
        prompt: 'bold outlines cel shaded cartoon simplified shapes vibrant palette',
        asset: 'assets/images/filter.png',
      ),
    ];

    int selected = 1; // default to a cool preset

    final _StyleSelection? result = await showModalBottomSheet<_StyleSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.card(context).withOpacity(0.95),
                AppColors.background(context).withOpacity(0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                          // Handle bar
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.muted(context).withOpacity(0.4),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Header
                    Row(
                      children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: AppGradients.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryPurple.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.auto_fix_high_rounded, 
                                  color: Colors.white, 
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Style Transfer',
                                      style: GoogleFonts.inter(
                                        color: onBg,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 24,
                                        letterSpacing: 0.25,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Transform your image with artistic styles',
                                      style: GoogleFonts.inter(
                                        color: AppColors.secondaryText(context),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.muted(context).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                          tooltip: 'Close',
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: AppColors.secondaryText(context),
                                  ),
                          onPressed: () => Navigator.of(ctx).pop(),
                                ),
                        ),
                      ],
                    ),
                          const SizedBox(height: 32),
                          // Style Selection Section
                          Text(
                            'Choose a style',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.card(context).withOpacity(0.6),
                                  AppColors.surface(context).withOpacity(0.4),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryPurple.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: presets.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, index) {
                          final p = presets[index];
                          final bool isSel = selected == index;
                          return GestureDetector(
                            onTap: () {
                              selected = index;
                              setSheetState(() {});
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                            AnimatedContainer(
                                              duration: const Duration(milliseconds: 200),
                                              curve: Curves.easeInOut,
                                  width: 90,
                                              height: 110,
                                  decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                                  color: isSel 
                                                    ? AppColors.primaryPurple 
                                                    : AppColors.muted(context).withOpacity(0.3),
                                                  width: isSel ? 3 : 1,
                                    ),
                                    boxShadow: [
                                                  if (isSel) ...[
                                      BoxShadow(
                                                      color: AppColors.primaryPurple.withOpacity(0.3),
                                                      blurRadius: 16,
                                                      offset: const Offset(0, 8),
                                                    ),
                                                  ] else ...[
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.05),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                    ],
                                  ),
                                  child: ClipRRect(
                                                borderRadius: BorderRadius.circular(19),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                                    Image.asset(
                                                      p.asset, 
                                                      fit: BoxFit.cover,
                                                      color: isSel ? null : AppColors.muted(context).withOpacity(0.2),
                                                      colorBlendMode: isSel ? null : BlendMode.overlay,
                                                    ),
                                                    if (isSel) ...[
                                                      Container(
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            begin: Alignment.topLeft,
                                                            end: Alignment.bottomRight,
                                                            colors: [
                                                              AppColors.primaryPurple.withOpacity(0.2),
                                                              AppColors.primaryBlue.withOpacity(0.1),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                        Positioned(
                                          right: 8,
                                          top: 8,
                                                      child: AnimatedScale(
                                                        scale: isSel ? 1.0 : 0.0,
                                                        duration: const Duration(milliseconds: 200),
                                            child: Container(
                                                          padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                            gradient: AppGradients.primary,
                                                            shape: BoxShape.circle,
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: AppColors.primaryPurple.withOpacity(0.4),
                                                                blurRadius: 8,
                                                                offset: const Offset(0, 2),
                                                              ),
                                                            ],
                                                          ),
                                                          child: const Icon(
                                                            Icons.check_rounded, 
                                                            size: 14, 
                                                            color: Colors.white,
                                                          ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                            const SizedBox(height: 10),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    p.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                                  color: isSel 
                                                    ? AppColors.primaryPurple 
                                                    : AppColors.onBackground(context),
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w600,
                                                  fontSize: 11,
                                                  letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Action Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                      onPressed: () {
                        final chosen = presets[selected];
                        Navigator.of(ctx).pop(_StyleSelection(stylePrompt: chosen.prompt));
                      },
                              icon: const Icon(
                                Icons.palette_rounded,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Apply Style',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Footer
                          Center(
                            child: Text(
                      'Powered by fal.ai Style Transfer',
                              style: GoogleFonts.inter(
                                color: AppColors.mutedText(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ],
                ),
              );
            },
                ),
              ),
            ),
          ),
        );
      },
    );

    return result;
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

  Future<void> _onCharacterBrushEdit() async {
    if (_imageBytes == null) return;
    
    // Collect prompt and mask via brush painter
    final _CharacterEditInput? input = await _showCharacterEditBottomSheet();
    if (input == null) return;

    _pushAiUndo(_imageBytes!);
    _lastAiAction = _AiActionMeta(
      toolIdName: 'ideogram_character_edit',
      editName: 'Character Edit (Mask)',
      parameters: {
        'tool': 'ideogram_character_edit',
        'prompt': input.prompt,
        'reference_count': input.referenceUrls.length,
      },
    );

    setState(() { _saving = true; });
    try {
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'ideogram_character_edit',
        payload: {
          'prompt': input.prompt,
          'mask_url': input.maskUrl,
          'reference_urls': input.referenceUrls,
        },
        inputImageUrl: _originalOrLastUrl,
      );
      if (mounted) setState(() { _activeJobIds.add(job.id); });
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating, 
          content: Text('Character edit started'),
          duration: Duration(seconds: 5),
        ),
      );
    } catch (e) {
      Logger.error('Queueing ideogram_character_edit failed', context: {'error': e.toString()});
      if (!mounted) return;
      setState(() { _error = 'Failed to start character edit: ${e.toString()}'; });
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
    final String? prompt = await _showTextEditBottomSheet();
    if (prompt == null || prompt.isEmpty) return;

    _pushAiUndo(_imageBytes!);
    _lastAiAction = _AiActionMeta(
      toolIdName: 'calligrapher',
      editName: 'Calligrapher Text Edit',
      parameters: {
        'tool': 'calligrapher',
        'prompt': prompt,
      },
    );

    setState(() { _saving = true; });
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.card(context).withOpacity(0.95),
                AppColors.background(context).withOpacity(0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SafeArea(
                child: StatefulBuilder(
                  builder: (ctx, setSheetState) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                            top: 20,
                            bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Handle bar
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.muted(context).withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryBlue,
                                          AppColors.accentBlue,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryBlue.withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.autorenew_rounded, 
                                      color: Colors.white, 
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Reframe',
                                          style: GoogleFonts.inter(
                                            color: onBg,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 24,
                                            letterSpacing: 0.25,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Change image dimensions intelligently',
                                      style: GoogleFonts.inter(
                                        color: AppColors.secondaryText(context),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.muted(context).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                          tooltip: 'Close',
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: AppColors.secondaryText(context),
                                  ),
                          onPressed: () => Navigator.of(ctx).pop(),
                                ),
                        ),
                      ],
                    ),
                          const SizedBox(height: 32),
                          // Suggested sizes section
                          Text(
                            'Popular formats',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.card(context).withOpacity(0.6),
                                  AppColors.surface(context).withOpacity(0.4),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryPurple.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                      children: [
                        for (int i = 0; i < presets.length; i++)
                                      GestureDetector(
                            onTap: () => _applyPreset(i, setSheetState),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: BoxDecoration(
                                            gradient: selectedIndex == i 
                                              ? LinearGradient(
                                                  colors: [
                                                    AppColors.primaryBlue,
                                                    AppColors.accentBlue,
                                                  ],
                                                )
                                              : LinearGradient(
                                                  colors: [
                                                    AppColors.card(context).withOpacity(0.6),
                                                    AppColors.surface(context).withOpacity(0.4),
                                                  ],
                                                ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: selectedIndex == i 
                                                ? Colors.transparent
                                                : AppColors.muted(context).withOpacity(0.3),
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              if (selectedIndex == i) ...[
                                                BoxShadow(
                                                  color: AppColors.primaryBlue.withOpacity(0.3),
                                                  blurRadius: 12,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ] else ...[
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.05),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ],
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                presets[i].label,
                                                style: GoogleFonts.inter(
                                                  color: selectedIndex == i 
                                                    ? Colors.white
                                                    : AppColors.onBackground(context),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  letterSpacing: 0.25,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                presets[i].subtitle,
                                                style: GoogleFonts.inter(
                                                  color: selectedIndex == i 
                                                    ? Colors.white.withOpacity(0.9)
                                                    : AppColors.secondaryText(context),
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Custom size section
                          Text(
                            'Custom dimensions',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.card(context).withOpacity(0.8),
                                  AppColors.surface(context).withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryPurple.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Padding(
                                  padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: widthCtrl,
                                keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                  border: InputBorder.none,
                                            hintText: 'Width',
                                            hintStyle: GoogleFonts.inter(
                                              color: AppColors.mutedText(context),
                                              fontWeight: FontWeight.w400,
                                              fontSize: 16,
                                            ),
                                          ),
                                          style: GoogleFonts.inter(
                                            color: onBg,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                onChanged: (_) {
                                  selectedIndex = null;
                                  setSheetState(() {});
                                },
                              ),
                            ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          '×',
                                          style: GoogleFonts.inter(
                                            color: AppColors.secondaryText(context),
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                            Expanded(
                              child: TextField(
                                controller: heightCtrl,
                                keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                  border: InputBorder.none,
                                            hintText: 'Height',
                                            hintStyle: GoogleFonts.inter(
                                              color: AppColors.mutedText(context),
                                              fontWeight: FontWeight.w400,
                                              fontSize: 16,
                                            ),
                                          ),
                                          style: GoogleFonts.inter(
                                            color: onBg,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
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
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorText!,
                                      style: GoogleFonts.inter(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          // Action Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryBlue,
                                  AppColors.accentBlue,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
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
                              icon: const Icon(
                                Icons.aspect_ratio_rounded,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Start Reframe',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                              // Footer
                              Center(
                                child: Text(
                                  'Powered by Ideogram V3 Reframe',
                                  style: GoogleFonts.inter(
                                    color: AppColors.mutedText(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    return result;
  }

  // Remix bottom sheet: prompt only (Elements remains separate for ref image)
  Future<String?> _showRemixBottomSheet() async {
    final Color onBg = AppColors.onBackground(context);
    final TextEditingController promptCtrl = TextEditingController();
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.card(context).withOpacity(0.95),
                AppColors.background(context).withOpacity(0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 20,
                    bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.muted(context).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Header
                Row(
                  children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.bolt_rounded, 
                              color: Colors.white, 
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Remix',
                                  style: GoogleFonts.inter(
                                    color: onBg,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                    letterSpacing: 0.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Transform your image with AI',
                                  style: GoogleFonts.inter(
                                    color: AppColors.secondaryText(context),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.muted(context).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                      tooltip: 'Close',
                              icon: Icon(
                                Icons.close_rounded,
                                color: AppColors.secondaryText(context),
                              ),
                      onPressed: () => Navigator.of(ctx).pop(),
                            ),
                    ),
                  ],
                ),
                      const SizedBox(height: 32),
                      // Input Section
                      Text(
                        'Describe your vision',
                        style: GoogleFonts.inter(
                          color: AppColors.onBackground(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.card(context).withOpacity(0.8),
                              AppColors.surface(context).withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryPurple.withOpacity(0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Padding(
                              padding: const EdgeInsets.all(20),
                    child: TextField(
                      controller: promptCtrl,
                                minLines: 3,
                                maxLines: 5,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                        border: InputBorder.none,
                                  hintText: 'Turn this into a painting...\nMake it cyberpunk style...\nAdd neon lights and rain...',
                                  hintStyle: GoogleFonts.inter(
                                    color: AppColors.mutedText(context),
                                    fontWeight: FontWeight.w400,
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                                style: GoogleFonts.inter(
                                  color: onBg,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Action Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                  onPressed: () {
                    final p = promptCtrl.text.trim();
                    if (p.isEmpty) {
                      Navigator.of(ctx).pop();
                    } else {
                      Navigator.of(ctx).pop(p);
                    }
                  },
                          icon: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Start Remix',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    return result;
  }

  Future<void> _onRemix() async {
    if (_imageBytes == null) return;
    final String? prompt = await _showRemixBottomSheet();
    if (prompt == null || prompt.isEmpty) return;
    // Use nano_banana for simple remix prompt (no reference)
    _pushAiUndo(_imageBytes!);
    _lastAiAction = _AiActionMeta(
      toolIdName: 'nano_banana',
      editName: 'nano_banana',
      parameters: {
        'tool': 'nano_banana',
        'prompt': prompt,
      },
    );

    setState(() { _saving = true; });
    try {
      final job = await _aiJobsRepo.enqueueJob(
        projectId: widget.projectId,
        toolName: 'nano_banana',
        payload: {'prompt': prompt},
        inputImageUrl: _originalOrLastUrl,
      );
      if (mounted) setState(() { _activeJobIds.add(job.id); });
      await AiJobsService.instance.triggerProcessing(job.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, content: Text('Remix started')),
      );
    } catch (e) {
      Logger.error('Queueing remix failed', context: {'error': e.toString()});
      if (!mounted) return;
      setState(() { _error = 'Failed to start remix: ${e.toString()}'; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: Colors.redAccent, content: Text('Failed to start', style: TextStyle(color: Colors.white))),
      );
    } finally {
      if (mounted) setState(() { _saving = _activeJobIds.isNotEmpty; });
    }
  }

  // Text edit bottom sheet
  Future<String?> _showTextEditBottomSheet() async {
    final Color onBg = AppColors.onBackground(context);
    final TextEditingController controller = TextEditingController();
    final String? result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.card(context).withOpacity(0.95),
                AppColors.background(context).withOpacity(0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 20,
                    bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.muted(context).withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Header
                Row(
                  children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryPurple,
                                  AppColors.primaryBlue,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryPurple.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.text_fields_rounded, 
                              color: Colors.white, 
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Text Edit',
                                  style: GoogleFonts.inter(
                                    color: onBg,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 24,
                                    letterSpacing: 0.25,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Edit text within your image',
                                  style: GoogleFonts.inter(
                                    color: AppColors.secondaryText(context),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.muted(context).withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                      tooltip: 'Close',
                              icon: Icon(
                                Icons.close_rounded,
                                color: AppColors.secondaryText(context),
                              ),
                      onPressed: () => Navigator.of(ctx).pop(),
                            ),
                    ),
                  ],
                ),
                      const SizedBox(height: 32),
                      // Input Section
                      Text(
                        'Text editing instruction',
                        style: GoogleFonts.inter(
                          color: AppColors.onBackground(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          letterSpacing: 0.15,
                        ),
                      ),
                      const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppColors.card(context).withOpacity(0.8),
                              AppColors.surface(context).withOpacity(0.6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryPurple.withOpacity(0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Padding(
                              padding: const EdgeInsets.all(20),
                    child: TextField(
                      controller: controller,
                                minLines: 2,
                                maxLines: 4,
                                textCapitalization: TextCapitalization.sentences,
                                decoration: InputDecoration(
                        border: InputBorder.none,
                                  hintText: 'Change the text "Welcome" to "Hello"\nMake the heading say "2024"\nReplace the sign text with "Open"',
                                  hintStyle: GoogleFonts.inter(
                                    color: AppColors.mutedText(context),
                                    fontWeight: FontWeight.w400,
                                    fontSize: 16,
                                    height: 1.5,
                                  ),
                                ),
                                style: GoogleFonts.inter(
                                  color: onBg,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Action Button
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryPurple,
                              AppColors.primaryBlue,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryPurple.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                  onPressed: () {
                    final p = controller.text.trim();
                    if (p.isEmpty) {
                      Navigator.of(ctx).pop();
                    } else {
                      Navigator.of(ctx).pop(p);
                    }
                  },
                          icon: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            'Start Text Edit',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.5,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
          _activeJobIds.add(job.id);
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
        _nanoIsGenerating = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = _activeJobIds.isNotEmpty;
        });
      }
    }
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
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
      ),
    );
  }

  // Character Remix UI
 
  // Character Edit with Brush Mask
  Future<_CharacterEditInput?> _showCharacterEditBottomSheet() async {
    if (_imageBytes == null) return null;

    final TextEditingController promptCtrl = TextEditingController();
    final Set<String> selectedReferenceUrls = <String>{};
    
    // Step 1: Show prompt + reference selection sheet
    bool isUploading = false;
    
    final bool? continueWithMask = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.card(context).withOpacity(0.95),
                    AppColors.background(context).withOpacity(0.98),
                  ],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: AppColors.primaryPurple.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Fixed header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Handle bar
                            Center(
                              child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.muted(context).withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Header
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [AppColors.primaryPurple, AppColors.primaryBlue],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.brush, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Character Edit',
                                        style: GoogleFonts.inter(
                                          color: AppColors.onBackground(context),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 20,
                                        ),
                                      ),
                                      Text(
                                        'Mask-based character editing',
                                        style: GoogleFonts.inter(
                                          color: AppColors.secondaryText(context),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close_rounded, color: AppColors.secondaryText(context)),
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Scrollable content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                            bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Prompt input
                              Text(
                                'What would you like to edit?',
                                style: GoogleFonts.inter(
                                  color: AppColors.onBackground(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.muted(context).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: promptCtrl,
                                  maxLines: 2,
                                  style: GoogleFonts.inter(
                                    color: AppColors.onBackground(context),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'e.g., "woman holding bag"...',
                                    hintStyle: GoogleFonts.inter(
                                      color: AppColors.secondaryText(context),
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Reference images section  
                              Text(
                                'Reference images (1-4 required)',
                                style: GoogleFonts.inter(
                                  color: AppColors.onBackground(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Images showing the character to preserve',
                                      style: GoogleFonts.inter(
                                        color: AppColors.secondaryText(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: isUploading ? null : () async {
                                      if (selectedReferenceUrls.length >= 4) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Maximum 4 references allowed'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }
                                      
                                      try {
                                        // Pick image from gallery
                                        final ImagePicker picker = ImagePicker();
                                        final XFile? image = await picker.pickImage(
                                          source: ImageSource.gallery,
                                          maxWidth: 2048,
                                          maxHeight: 2048,
                                        );
                                        
                                        if (image == null) return;
                                        
                                        // Set uploading state
                                        setModalState(() => isUploading = true);
                                        
                                        // Upload to storage
                                        final bytes = await image.readAsBytes();
                                        final uploaded = await _mediaRepo.uploadBytes(
                                          bytes: bytes,
                                          filename: 'ref_${DateTime.now().millisecondsSinceEpoch}.jpg',
                                          contentType: 'image/jpeg',
                                          thumbnailBytes: bytes,
                                          metadata: {'type': 'reference', 'tool': 'character_edit'},
                                        );
                                        
                                        // Add to selected references
                                        if (!mounted) return;
                                        setModalState(() {
                                          isUploading = false;
                                          selectedReferenceUrls.add(uploaded.url);
                                        });
                                        
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('✓ Reference added'),
                                            behavior: SnackBarBehavior.floating,
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        setModalState(() => isUploading = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to upload: $e'),
                                            backgroundColor: Colors.redAccent,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    },
                                    icon: isUploading 
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.add_photo_alternate, size: 16),
                                    label: Text(
                                      isUploading ? 'Uploading...' : 'Upload',
                                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      side: BorderSide(color: AppColors.primaryPurple),
                                      foregroundColor: AppColors.primaryPurple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 160,
                                decoration: BoxDecoration(
                                  color: AppColors.surface(context),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.muted(context).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: FutureBuilder<List<MediaItem>>(
                                  future: _mediaRepo.listMedia(limit: 60, filterMime: 'image'),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                      return const Center(child: CircularProgressIndicator());
                                    }
                                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                      return Center(
                                        child: Text(
                                          'No images in library',
                                          style: GoogleFonts.inter(
                                            color: AppColors.secondaryText(context),
                                          ),
                                        ),
                                      );
                                    }
                                    final items = snapshot.data!;
                                    return GridView.builder(
                                      padding: const EdgeInsets.all(8),
                                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 5,
                                        crossAxisSpacing: 6,
                                        mainAxisSpacing: 6,
                                      ),
                                      itemCount: items.length,
                                      itemBuilder: (c, i) {
                                        final item = items[i];
                                        final url = item.thumbnailUrl ?? item.url;
                                        final selected = selectedReferenceUrls.contains(url);
                                        return GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              if (selected) {
                                                selectedReferenceUrls.remove(url);
                                              } else {
                                                if (selectedReferenceUrls.length >= 4) {
                                                  ScaffoldMessenger.of(c).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('Maximum 4 references allowed'),
                                                      behavior: SnackBarBehavior.floating,
                                                    ),
                                                  );
                                                } else {
                                                  selectedReferenceUrls.add(url);
                                                }
                                              }
                                            });
                                          },
                                          child: Stack(
                                            children: [
                                              Positioned.fill(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Image.network(
                                                    url,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, st) => Container(
                                                      color: AppColors.muted(context),
                                                      child: Icon(
                                                        Icons.image_not_supported_outlined,
                                                        color: AppColors.secondaryText(context),
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (selected)
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primaryPurple.withOpacity(0.3),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(
                                                        color: AppColors.primaryPurple,
                                                        width: 2,
                                                      ),
                                                    ),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons.check_circle,
                                                        color: Colors.white,
                                                        size: 20,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              if (selectedReferenceUrls.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Selected (${selectedReferenceUrls.length}/4)',
                                  style: GoogleFonts.inter(
                                    color: AppColors.onBackground(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: selectedReferenceUrls.map((url) {
                                    return Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.primaryPurple,
                                          width: 2,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(6),
                                              child: Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, st) => Container(
                                                  color: AppColors.muted(context),
                                                  child: Icon(
                                                    Icons.image,
                                                    color: AppColors.secondaryText(context),
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                          child: GestureDetector(
                                            onTap: () {
                                              setModalState(() {
                                                selectedReferenceUrls.remove(url);
                                              });
                                            },
                                                child: Container(
                                                padding: const EdgeInsets.all(1),
                                                decoration: const BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 16),
                              // Info box
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryPurple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primaryPurple.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: AppColors.primaryPurple, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Next: Paint over the area to edit',
                                        style: GoogleFonts.inter(
                                          color: AppColors.onBackground(context),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              // Continue button
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [AppColors.primaryPurple, AppColors.primaryBlue],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryPurple.withOpacity(0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      if (promptCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please enter a description'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }
                                      if (selectedReferenceUrls.isEmpty) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          const SnackBar(
                                            content: Text('Please select at least 1 reference'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }
                                      Navigator.of(ctx).pop(true);
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.brush, color: Colors.white, size: 20),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Next: Paint Mask',
                                            style: GoogleFonts.inter(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (continueWithMask != true || !mounted) return null;

    // Step 2: Show brush painter
    final Uint8List? paintedMask = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (ctx) => MaskBrushPainter(
          imageBytes: _imageBytes!,
          onMaskComplete: (mask) => Navigator.of(ctx).pop(mask),
          onCancel: () => Navigator.of(ctx).pop(),
        ),
      ),
    );

    if (paintedMask == null || !mounted) return null;

    // Upload mask to get URL
    try {
      setState(() { _saving = true; });
      final uploaded = await _mediaRepo.uploadBytes(
        bytes: paintedMask,
        filename: 'mask_${DateTime.now().millisecondsSinceEpoch}.png',
        contentType: 'image/png',
        thumbnailBytes: paintedMask,
        metadata: {'type': 'mask', 'tool': 'character_edit'},
      );
      
      setState(() { _saving = false; });
      
      return _CharacterEditInput(
        prompt: promptCtrl.text.trim(),
        maskUrl: uploaded.url,
        referenceUrls: selectedReferenceUrls.toList(),
      );
    } catch (e) {
      setState(() { _saving = false; });
      Logger.error('Failed to upload mask', context: {'error': e.toString()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to upload mask: $e'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.card(context).withOpacity(0.95),
                AppColors.background(context).withOpacity(0.98),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: AppColors.primaryPurple.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: SafeArea(
                child: StatefulBuilder(
                  builder: (ctx, setSheetState) {
                    return ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.9,
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: 24,
                            right: 24,
                            top: 20,
                            bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Handle bar
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: AppColors.muted(context).withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Header
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primaryPurple,
                                          AppColors.primaryBlue,
                                        ],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primaryPurple.withOpacity(0.3),
                                          blurRadius: 12,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.widgets_rounded, 
                                      color: Colors.white, 
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Elements',
                                          style: GoogleFonts.inter(
                                            color: onBg,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 24,
                                            letterSpacing: 0.25,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Add or remix elements into your photo',
                                      style: GoogleFonts.inter(
                                        color: AppColors.secondaryText(context),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.muted(context).withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                          tooltip: 'Close',
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: AppColors.secondaryText(context),
                                  ),
                          onPressed: () => Navigator.of(ctx).pop(),
                                ),
                        ),
                      ],
                    ),
                          const SizedBox(height: 32),
                          // Prompt Section
                          Text(
                            'Describe what to add',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.15,
                            ),
                          ),
                          const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.card(context).withOpacity(0.8),
                                  AppColors.surface(context).withOpacity(0.6),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryPurple.withOpacity(0.15),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Padding(
                                  padding: const EdgeInsets.all(20),
                        child: TextField(
                          controller: promptCtrl,
                                    minLines: 2,
                                    maxLines: 4,
                                    textCapitalization: TextCapitalization.sentences,
                                    decoration: InputDecoration(
                            border: InputBorder.none,
                                      hintText: 'Add a dragon flying overhead...\nPlace flowers around the person...\nAdd a rainbow in the sky...',
                                      hintStyle: GoogleFonts.inter(
                                        color: AppColors.mutedText(context),
                                        fontWeight: FontWeight.w400,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                    style: GoogleFonts.inter(
                                      color: onBg,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                      height: 1.5,
                                    ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Reference Image Section
                    Row(
                      children: [
                              Text(
                                'Reference image',
                                style: GoogleFonts.inter(
                                  color: AppColors.onBackground(context),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: 0.15,
                                ),
                              ),
                        const Spacer(),
                        if (selectedUrl != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.primary,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primaryPurple.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '1 selected',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      letterSpacing: 0.25,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.card(context).withOpacity(0.6),
                                  AppColors.surface(context).withOpacity(0.4),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primaryPurple.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: FutureBuilder<List<MediaItem>>(
                      future: mediaFuture,
                      builder: (c, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Padding(
                                          padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final items = (snap.data ?? <MediaItem>[]) 
                            .where((m) => m.mimeType.startsWith('image'))
                            .toList();
                                      final double gridSpacing = 12;
                                      final int crossAxisCount = 3;
                                      // Calculate rows needed and set appropriate height
                                      final int rows = (items.length / crossAxisCount).ceil();
                                      final double itemHeight = 110;
                                      final double gridH = (rows * itemHeight + (rows - 1) * gridSpacing).clamp(110.0, 250.0);
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                                          if (items.isEmpty) ...[
                              Padding(
                                              padding: const EdgeInsets.all(24),
                                              child: Column(
                                                children: [
                                                  Icon(
                                                    Icons.image_outlined,
                                                    size: 40,
                                                    color: AppColors.mutedText(context),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'No images in your library yet',
                                                    style: GoogleFonts.inter(
                                                      color: AppColors.secondaryText(context),
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 14,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Upload one from your gallery below',
                                                    style: GoogleFonts.inter(
                                                      color: AppColors.mutedText(context),
                                                      fontSize: 12,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ] else ...[
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
                                                    child: AnimatedContainer(
                                                      duration: const Duration(milliseconds: 200),
                                                      decoration: BoxDecoration(
                                                        borderRadius: BorderRadius.circular(16),
                                                        border: Border.all(
                                                          color: selected 
                                                            ? AppColors.primaryPurple 
                                                            : AppColors.muted(context).withOpacity(0.3),
                                                          width: selected ? 3 : 1,
                                                        ),
                                                        boxShadow: [
                                                          if (selected) ...[
                                                            BoxShadow(
                                                              color: AppColors.primaryPurple.withOpacity(0.3),
                                                              blurRadius: 12,
                                                              offset: const Offset(0, 6),
                                                            ),
                                                          ] else ...[
                                                            BoxShadow(
                                                              color: Colors.black.withOpacity(0.05),
                                                              blurRadius: 6,
                                                              offset: const Offset(0, 3),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(15),
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                              child: Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (c, e, st) => Container(
                                                  color: AppColors.muted(context),
                                                                  child: Icon(
                                                                    Icons.image_not_supported_outlined, 
                                                                    color: AppColors.secondaryText(context),
                                                ),
                                              ),
                                            ),
                                          ),
                                                            if (selected) ...[
                                          Positioned.fill(
                                                                child: Container(
                                              decoration: BoxDecoration(
                                                                    gradient: LinearGradient(
                                                                      begin: Alignment.topLeft,
                                                                      end: Alignment.bottomRight,
                                                                      colors: [
                                                                        AppColors.primaryPurple.withOpacity(0.2),
                                                                        AppColors.primaryBlue.withOpacity(0.1),
                                                                      ],
                                              ),
                                            ),
                                          ),
                                                              ),
                                            Positioned(
                                                                right: 8,
                                                                top: 8,
                                              child: Container(
                                                                  padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                                    gradient: AppGradients.primary,
                                                                    shape: BoxShape.circle,
                                                  boxShadow: [
                                                                      BoxShadow(
                                                                        color: AppColors.primaryPurple.withOpacity(0.4),
                                                                        blurRadius: 8,
                                                                        offset: const Offset(0, 2),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                  child: const Icon(
                                                                    Icons.check_rounded, 
                                                                    color: Colors.white, 
                                                                    size: 14,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                                            const SizedBox(height: 16),
                                          ],
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  AppColors.muted(context).withOpacity(0.6),
                                                  AppColors.surface(context).withOpacity(0.4),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(
                                                color: AppColors.primaryPurple.withOpacity(0.1),
                                                width: 1,
                                              ),
                                            ),
                                            child: OutlinedButton.icon(
                              onPressed: () async {
                                // Let user upload a new reference from gallery; on success, refresh list and select it
                                try {
                                  final mediaCap = MediaPipelineService();
                                  await mediaCap.pickFromGalleryAndQueue();
                                  mediaFuture = _mediaRepo.listMedia(limit: 60, filterMime: 'image');
                                  setSheetState(() {});
                                } catch (_) {}
                              },
                                              icon: Icon(
                                                Icons.photo_library_rounded,
                                                color: AppColors.primaryPurple,
                                              ),
                                              label: Text(
                                                'Upload from gallery',
                                                style: GoogleFonts.inter(
                                                  color: AppColors.primaryPurple,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                backgroundColor: Colors.transparent,
                                                side: BorderSide.none,
                                                padding: const EdgeInsets.symmetric(vertical: 16),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(16),
                                                ),
                                              ),
                                            ),
                            ),
                          ],
                        );
                      },
                    ),
                                ),
                              ),
                            ),
                          ),
                          if (errorText != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    color: Colors.redAccent,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      errorText!,
                                      style: GoogleFonts.inter(
                                        color: Colors.redAccent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          // Action Button
                          Container(
                            decoration: BoxDecoration(
                              gradient: canStart() 
                                ? LinearGradient(
                                    colors: [
                                      AppColors.primaryPurple,
                                      AppColors.primaryBlue,
                                    ],
                                  )
                                : LinearGradient(
                                    colors: [
                                      AppColors.muted(context).withOpacity(0.3),
                                      AppColors.muted(context).withOpacity(0.2),
                                    ],
                                  ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                if (canStart()) ...[
                                  BoxShadow(
                                    color: AppColors.primaryPurple.withOpacity(0.4),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ],
                            ),
                            child: ElevatedButton.icon(
                      onPressed: canStart()
                          ? () {
                              Navigator.of(ctx).pop(_ElementsInput(
                                prompt: promptCtrl.text.trim(),
                                referenceUrl: selectedUrl!,
                              ));
                            }
                          : null,
                              icon: Icon(
                                Icons.auto_awesome_mosaic_rounded,
                                color: canStart() ? Colors.white : AppColors.mutedText(context),
                              ),
                              label: Text(
                                'Start Elements',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: canStart() ? Colors.white : AppColors.mutedText(context),
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                              // Footer
                              Center(
                                child: Text(
                                  'Powered by Nano Banana Edit',
                                  style: GoogleFonts.inter(
                                    color: AppColors.mutedText(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    return result;
  }

}


class _CharacterEditInput {
  final String prompt;
  final String maskUrl;
  final List<String> referenceUrls;
  const _CharacterEditInput({required this.prompt, required this.maskUrl, required this.referenceUrls});
}

class _ElementsInput {
  final String prompt;
  final String referenceUrl;
  const _ElementsInput({required this.prompt, required this.referenceUrl});
}

class _FullImagePreview extends StatelessWidget {
  final Uint8List bytes;
  const _FullImagePreview({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      backgroundColor: Colors.black,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.memory(bytes, fit: BoxFit.contain, filterQuality: FilterQuality.high),
        ),
      ),
    );
  }
}

class _ExportFab extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _ExportFab({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: enabled ? AppGradients.primary : AppGradients.blueToPurple,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [mediaPetShadow(context)],
          ),
          child: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}






