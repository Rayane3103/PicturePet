import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../theme/app_theme.dart';
import 'dart:async';
import '../repositories/projects_repository.dart';
import '../models/project.dart';
import '../services/upload_queue_service.dart';
import 'project_details_page.dart';
import '../services/projects_events.dart';
import '../services/ai_jobs_service.dart';
import '../models/ai_job.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LibraryPage extends StatefulWidget {
  final void Function()? onNewProject;
  final void Function(String projectId)? onOpenProjectId;

  const LibraryPage({
    super.key,
    this.onNewProject,
    this.onOpenProjectId,
  });

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final ProjectsRepository _projects = ProjectsRepository();
  final List<Project> _items = [];
  final ScrollController _scroll = ScrollController();
  StreamSubscription<Map<String, dynamic>>? _uploadSub;
  StreamSubscription<void>? _projectsSub;
  final List<Map<String, dynamic>> _uploadStatuses = [];
  final Map<String, Timer> _pendingDeleteTimers = {};
  final Map<String, Project> _pendingDeleteProjects = {};
  bool _loading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 20;
  StreamSubscription<AiJob>? _aiJobsSub;
  final List<AiJob> _inProgressJobs = [];
  final Set<String> _processedCompletedJobs = {}; // Track jobs that have already been processed
  bool _isSubscribed = false; // Track if we're already subscribed to avoid duplicate subscriptions

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scroll.addListener(() {
      if (_loading || !_hasMore) return;
      final max = _scroll.position.maxScrollExtent;
      if (max <= 0) return; // avoid triggering on initial layout
      final threshold = max - 300;
      if (_scroll.position.pixels > threshold) {
        _loadMore();
      }
    });
    _restoreAndSubscribeToProjectJobs();
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
    // Listen for project changes (rename/duplicate/delete/save)
    _projectsSub = ProjectsEvents.instance.stream.listen((_) {
      if (mounted) {
        _refresh();
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
        // De-duplicate by project id to avoid showing duplicates
        final existingIds = _items.map((e) => e.id).toSet();
        final uniqueNew = page.where((p) => !existingIds.contains(p.id));
        _items.addAll(uniqueNew);
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

  Future<void> _restoreAndSubscribeToProjectJobs() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    
    // Prevent duplicate subscriptions
    if (_isSubscribed) {
      // Just refresh the job list without re-subscribing
      final jobs = await AiJobsService.instance.fetchInProgressProjectJobsForUser(user.id);
      if (!mounted) return;
      setState(() {
        _inProgressJobs.clear();
        // Only add jobs that are actually in-progress and not already processed
        _inProgressJobs.addAll(jobs.where((j) => 
          (j.status == 'queued' || j.status == 'running') && 
          !_processedCompletedJobs.contains(j.id)
        ));
      });
      return;
    }
    
    // Fetch only in-progress jobs (queued or running)
    final jobs = await AiJobsService.instance.fetchInProgressProjectJobsForUser(user.id);
    if (!mounted) return;
    
    setState(() {
      _inProgressJobs.clear();
      // Only add jobs that are actually in-progress
      _inProgressJobs.addAll(jobs.where((j) => j.status == 'queued' || j.status == 'running'));
    });
    
    // Subscribe to real-time updates for all user's jobs (only once)
    AiJobsService.instance.subscribeToUserJobs(user.id);
    _isSubscribed = true;
    
    _aiJobsSub?.cancel();
    _aiJobsSub = AiJobsService.instance.jobUpdates.listen((AiJob job) {
      if (!mounted) return;
      
      // Skip if we've already processed this job as completed
      if (_processedCompletedJobs.contains(job.id) && 
          (job.status == 'completed' || job.status == 'failed' || job.status == 'cancelled')) {
        return;
      }
      
      final idx = _inProgressJobs.indexWhere((j) => j.id == job.id);
      final isCompleted = job.status == 'completed' || job.status == 'failed' || job.status == 'cancelled';
      
      setState(() {
        if (isCompleted) {
          // Remove from in-progress list
          if (idx != -1) {
            _inProgressJobs.removeAt(idx);
          }
          
          // Only process completion once and only if it's a completed job (not failed/cancelled)
          if (job.status == 'completed' && !_processedCompletedJobs.contains(job.id)) {
            _processedCompletedJobs.add(job.id);
            
            // Check if this job should trigger navigation to editor
            // Only navigate for jobs that have a result URL and project_id
            // This typically happens for initial generation jobs or jobs that create new content
            final shouldNavigate = job.resultUrl != null && 
                                  job.projectId.isNotEmpty &&
                                  // Only navigate if we're not already on the editor for this project
                                  // (this prevents navigation when user is already viewing the project)
                                  !_isCurrentlyViewingProject(job.projectId);
            
            if (shouldNavigate) {
              // Navigate to editor after a short delay to allow UI to update
              Future.delayed(const Duration(milliseconds: 500), () {
                if (mounted && widget.onOpenProjectId != null) {
                  widget.onOpenProjectId!(job.projectId);
                }
              });
            }
            
            // Refresh project list to show the newly generated/updated project
            _refresh();
          } else if ((job.status == 'failed' || job.status == 'cancelled') && 
                     !_processedCompletedJobs.contains(job.id)) {
            _processedCompletedJobs.add(job.id);
            // Just refresh to update UI, don't navigate
            _refresh();
          }
        } else if (job.status == 'queued' || job.status == 'running') {
          // Update or add in-progress job
          if (idx != -1) {
            _inProgressJobs[idx] = job;
          } else {
            // Only add if it's not already processed as completed
            if (!_processedCompletedJobs.contains(job.id)) {
              _inProgressJobs.add(job);
            }
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _aiJobsSub?.cancel();
    if (_isSubscribed) {
      AiJobsService.instance.unsubscribeUserJobs();
      _isSubscribed = false;
    }
    _uploadSub?.cancel();
    _projectsSub?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _open(Project p) {
    widget.onOpenProjectId?.call(p.id);
  }

  // Helper to check if we're currently viewing a specific project
  // This is a simple check - in a more complex app, you might want to track the current route
  bool _isCurrentlyViewingProject(String projectId) {
    // For now, we'll assume we're not viewing any project
    // This prevents unnecessary navigation when jobs complete
    // In the future, you could track the current route or project being viewed
    return false;
  }

  Widget _card(Project p) {
    final imageUrl = p.thumbnailUrl ?? p.outputImageUrl ?? p.originalImageUrl;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(p),
        onLongPress: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProjectDetailsPage(projectId: p.id)),
          );
        },
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
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    height: 36,
                    width: 36,
                    child: _projectActions(p),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _projectActions(Project p) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 18),
      onSelected: (v) async {
        switch (v) {
          case 'rename':
            final newName = await _promptRename(p.name);
            if (newName != null) {
              final oldName = p.name;
              await _projects.rename(projectId: p.id, newName: newName);
              _refresh();
              _showUndoSnack('Renamed to "$newName"', () async {
                await _projects.rename(projectId: p.id, newName: oldName);
                _refresh();
              });
            }
            break;
          case 'duplicate':
            final newName = await _promptRename('${p.name} (copy)');
            if (newName != null) {
              final dup = await _projects.duplicate(projectId: p.id, newName: newName);
              _refresh();
              _showUndoSnack('Duplicated as "$newName"', () async {
                await _projects.deleteProjectCascade(projectId: dup.id);
                _refresh();
              });
            }
            break;
          case 'delete':
            final ok = await _confirmDelete(p.name);
            if (ok == true) {
              // Optimistic UI: remove from list and schedule actual delete after grace period
              _pendingDeleteProjects[p.id] = p;
              setState(() {
                _items.removeWhere((it) => it.id == p.id);
              });
              _showUndoSnack('Project deleted', () async {
                final t = _pendingDeleteTimers.remove(p.id);
                t?.cancel();
                final proj = _pendingDeleteProjects.remove(p.id);
                if (proj != null) {
                  // Add back and refresh ordering
                  setState(() {
                    _items.insert(0, proj);
                  });
                  _refresh();
                }
              });
              _pendingDeleteTimers[p.id]?.cancel();
              _pendingDeleteTimers[p.id] = Timer(const Duration(seconds: 3), () async {
                try {
                  await _projects.deleteProjectCascade(projectId: p.id);
                } finally {
                  _pendingDeleteTimers.remove(p.id);
                  _pendingDeleteProjects.remove(p.id);
                  _refresh();
                }
              });
            }
            break;
        }
      },
      itemBuilder: (ctx) => const [
        PopupMenuItem(value: 'rename', child: Text('Rename')),
        PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
        PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<String?> _promptRename(String current) async {
    String value = current;
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Rename project'),
          content: TextField(
            autofocus: true,
            controller: TextEditingController(text: current),
            onChanged: (v) => value = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, value.trim().isEmpty ? null : value.trim()), child: const Text('Save')),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmDelete(String name) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete project'),
          content: Text('This will permanently delete "$name" and its edit history.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent), onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
          ],
        );
      },
    );
  }

  void _showUndoSnack(String message, Future<void> Function() onUndo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            onUndo();
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _uploadPlaceholderCard(Map<String, dynamic> e) {
    final type = e['type'] as String?;
    final filename = (e['filename'] as String?) ?? '';
    final progress = (e['progress'] as num?)?.toDouble();
    final isFailed = type == 'failed';
    final isOffline = (e['code'] as String?) == 'offline';
    final isPreparing = type == 'preparing';
    final stage = (e['stage'] as String?) ?? (isPreparing ? 'generating' : 'uploading');
    final isGeneratingStage = stage == 'generating';
    final isProcessingStage = stage == 'processing';
    final isFinalizingStage = stage == 'finalizing';
    final bool showIndeterminate = isPreparing || (isGeneratingStage && (progress == null || progress <= 0));
    final double? indicatorValue = showIndeterminate ? null : progress?.clamp(0, 1);

    String statusLabel;
    if (isPreparing || isGeneratingStage) {
      statusLabel = 'Generating...';
    } else if (isProcessingStage) {
      statusLabel = 'Processing...';
    } else if (isFinalizingStage) {
      statusLabel = 'Finalizing...';
    } else {
      statusLabel = 'Uploading';
    }

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
                            value: indicatorValue,
                            strokeWidth: 6,
                            color: AppColors.primaryPurple,
                            backgroundColor: AppColors.surface(context),
                          ),
                        ),
                        if (showIndeterminate)
                          Icon(
                            Icons.auto_awesome,
                            color: AppColors.primaryPurple,
                            size: 32,
                          )
                        else
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
                    statusLabel,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiJobProgressCard(AiJob job) {
    final stage = job.status;
    final String statusLabel;
    IconData statusIcon;
    if (stage == 'queued') {
      statusLabel = 'Queued';
      statusIcon = Icons.hourglass_empty_rounded;
    } else if (stage == 'running') {
      statusLabel = 'Generating';
      statusIcon = Icons.auto_awesome_rounded;
    } else {
      statusLabel = 'Processing';
      statusIcon = Icons.sync_rounded;
    }
    
    final prompt = job.payload['prompt']?.toString() ?? 'AI Generation';
    
    return Container(
      height: 300,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryPurple.withOpacity(0.15),
            AppColors.primaryBlue.withOpacity(0.12),
            AppColors.card(context),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
        border: Border.all(
          color: AppColors.primaryPurple.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.cardCornerRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryPurple.withOpacity(0.08),
                    Colors.transparent,
                    AppColors.primaryBlue.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with animated gradient circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 0,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated circular progress indicator (spinning animation)
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          backgroundColor: Colors.white.withOpacity(0.15),
                        ),
                      ),
                      // Icon
                      Icon(
                        statusIcon,
                        color: Colors.white,
                        size: 36,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Status label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primaryPurple.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      color: AppColors.primaryPurple,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Prompt text
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.card(context).withOpacity(0.6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.muted(context).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      prompt,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppColors.onBackground(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _grid() {
    // Compose grid: in-progress AI jobs, uploading placeholders, then project cards
    // Filter out projects that have associated in-progress AI jobs to avoid showing placeholder cards
    final inProgressProjectIds = _inProgressJobs.map((j) => j.projectId).toSet();
    final filteredProjects = _items.where((p) => !inProgressProjectIds.contains(p.id)).toList();
    
    final placeholders = _uploadStatuses
        .where((e) => e['type'] == 'progress' || e['type'] == 'started' || e['type'] == 'failed' || e['type'] == 'preparing')
        .toList();
    final totalCount = _inProgressJobs.length + placeholders.length + filteredProjects.length;
    return SliverMasonryGrid.count(
      crossAxisCount: 2,
      mainAxisSpacing: 20,
      crossAxisSpacing: 20,
      childCount: totalCount,
      itemBuilder: (context, index) {
        if (index < _inProgressJobs.length) {
          return _aiJobProgressCard(_inProgressJobs[index]);
        }
        if (index < _inProgressJobs.length + placeholders.length) {
          return _uploadPlaceholderCard(placeholders[index - _inProgressJobs.length]);
        }
        final proj = filteredProjects[index - _inProgressJobs.length - placeholders.length];
        return KeyedSubtree(key: ValueKey(proj.id), child: _card(proj));
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
              // crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Title section with brand logo
                Row(
                  // crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(24),
                     
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.card(context),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Image.asset(
                            'assets/images/logo.png',
                            fit: BoxFit.contain,
                          
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          
                          Text(
                            'Projects Dashboard',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Manage your projects and track your progress',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: AppColors.secondaryText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                            '50 Credits available',
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
          child: SizedBox(height: 150),
        ),
        
      ],
    );
  }

}