import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../theme/app_theme.dart';
import 'dart:async';
import '../repositories/projects_repository.dart';
import '../models/project.dart';
import '../services/upload_queue_service.dart';

class LibraryPage extends StatefulWidget {
  final void Function()? onNewProject;
  final void Function(String imageAsset)? onOpenProject;

  const LibraryPage({
    super.key,
    this.onNewProject,
    this.onOpenProject,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final ProjectsRepository _projects = ProjectsRepository();
  final List<Project> _items = [];
  final ScrollController _scroll = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _uploadSub;
  final List<Map<String, dynamic>> _uploadStatuses = [];
  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300 && !_loading && _hasMore) {
        _loadMore();
      }
    });
    _uploadSub = UploadQueueService.instance.events.listen((event) {
      if (!mounted) return;
      if (event['type'] == 'completed') {
        _refresh();
      }
      // Maintain a rolling status list for display
      setState(() {
        final filename = (event['filename'] as String?) ?? '';
        final idx = _uploadStatuses.indexWhere((e) => e['filename'] == filename);
        if (idx >= 0) {
          _uploadStatuses[idx] = {..._uploadStatuses[idx], ...event};
        } else {
          _uploadStatuses.insert(0, event);
        }
        // Keep recent few
        if (_uploadStatuses.length > 5) {
          _uploadStatuses.removeRange(5, _uploadStatuses.length);
        }
      });
      // Auto-hide completed status after 5 seconds
      if (event['type'] == 'completed') {
        final filename = (event['filename'] as String?) ?? '';
        Future.delayed(const Duration(seconds: 5), () {
          if (!mounted) return;
          setState(() {
            _uploadStatuses.removeWhere((e) => e['type'] == 'completed' && e['filename'] == filename);
          });
        });
      }
    });
  }

  Future<void> _loadMore() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final page = await _projects.list(limit: _limit, offset: _offset);
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _offset += page.length;
        _hasMore = page.length == _limit;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _items.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _loadMore();
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _open(Project p) {
    final url = p.outputImageUrl ?? p.originalImageUrl;
    if (url != null) {
      widget.onOpenProject?.call(url);
    }
  }

  Widget _card(Project p) {
    final imageUrl = p.thumbnailUrl ?? p.outputImageUrl ?? p.originalImageUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(p),
        borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
        child: Container(
          height: 300,
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.muted(context),
                              child: Center(
                                child: Icon(
                                  Icons.wifi_off_rounded,
                                  color: AppColors.secondaryText(context),
                                  size: 32,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(color: AppColors.muted(context)),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            color: Colors.white70,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDate(p.createdAt.toLocal()),
                              style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              //overflow: TextOverflow.clip,
                            ),
                          ),
                        ],
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
  }

  Widget _uploadPlaceholderCard(Map<String, dynamic> e) {
    final type = e['type'] as String?;
    final filename = (e['filename'] as String?) ?? '';
    final progress = (e['progress'] as num?)?.toDouble();
    final isFailed = type == 'failed';
    final isOffline = (e['code'] as String?) == 'offline';

    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Placeholder backdrop
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
            child: Container(color: AppColors.muted(context)),
          ),
          // Centered circular progress or error
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isFailed) ...[
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 6,
                            color: AppColors.primaryPurple,
                            backgroundColor: AppColors.surface(context),
                          ),
                        ),
                        Text(
                          progress != null ? '${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%' : '...%',
                          style: GoogleFonts.inter(
                            color: AppColors.onBackground(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Uploading',
                    style: GoogleFonts.inter(
                      color: AppColors.onBackground(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    isOffline ? 'No connection' : 'Upload failed',
                    style: GoogleFonts.inter(
                      color: AppColors.onBackground(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      UploadQueueService.instance.retry(filename);
                    },
                    icon: const Icon(Icons.refresh),
                    label: Text(isOffline ? 'Retry when online' : 'Retry'),
                  ),
                ],
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    filename,
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final yy = (dt.year % 100).toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$yy-$mm-$dd  $hh:$min';
  }

  Widget _grid() {
    if (_items.isEmpty && !_loading) {
      return SliverToBoxAdapter(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No projects yet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onBackground(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap "Create New Project" to start.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build a combined list: uploading placeholders first, then projects
    final placeholders = _uploadStatuses
        .where((e) => e['type'] == 'progress' || e['type'] == 'started' || e['type'] == 'failed')
        .toList();
    final totalCount = placeholders.length + _items.length;

    return SliverMasonryGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childCount: totalCount,
      itemBuilder: (context, index) {
        if (index < placeholders.length) {
          return _uploadPlaceholderCard(placeholders[index]);
        }
        return _card(_items[index - placeholders.length]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: _scroll,
      slivers: [
        // MediaPet-style header with credits and subscription
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title section
                Text(
                  'Projects Dashboard',
                  style: GoogleFonts.inter(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onBackground(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your projects and track your progress',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: AppColors.secondaryText(context),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Credits and subscription section
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Credits badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.muted(context),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Icon(
                            Icons.eco,
                            color: AppColors.successGreen,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '9,625 Credits available',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: MediaQuery.of(context).size.width * 0.035),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.muted(context),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        '+ Buy Credits',
                        style: GoogleFonts.inter(
                          color: AppColors.secondaryText(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Create New Project button - Full width at the top
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
              ),
              child: InkWell(
                onTap: widget.onNewProject,
                borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create New Project',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Remove old linear status bar in favor of grid placeholders

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: _grid(),
        ),
        
        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  Widget _buildUploadStatusBar(BuildContext context) {
    if (_uploadStatuses.isEmpty) return const SizedBox.shrink();
    final e = _uploadStatuses.first; // show latest
    final type = e['type'] as String?;
    final filename = (e['filename'] as String?) ?? '';
    final progress = (e['progress'] as num?)?.toDouble();

    String title;
    Color barColor;
    bool showProgress = false;
    double? progressValue;
    IconData icon;

    if (type == 'failed') {
      title = 'Upload failed: $filename';
      barColor = Colors.red;
      icon = Icons.error_outline;
    } else if (type == 'completed') {
      title = 'Upload complete: $filename';
      barColor = Colors.green;
      icon = Icons.check_circle_outline;
    } else if (type == 'progress') {
      final pct = progress != null ? (progress * 100).clamp(0, 100).toStringAsFixed(0) : '...';
      title = 'Uploading: $filename  ($pct%)';
      barColor = AppColors.primaryPurple;
      showProgress = true;
      progressValue = progress;
      icon = Icons.cloud_upload_outlined;
    } else if (type == 'started') {
      title = 'Uploading: $filename';
      barColor = AppColors.primaryPurple;
      showProgress = true;
      progressValue = null; // indeterminate
      icon = Icons.cloud_upload_outlined;
    } else {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.muted(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.onBackground(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppColors.onBackground(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (showProgress) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 6,
                  backgroundColor: AppColors.muted(context),
                  valueColor: AlwaysStoppedAnimation<Color>(barColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}