import 'package:flutter/material.dart';
import 'library_page.dart';
import 'profile_page.dart';
import 'editor_page.dart';
import '../widgets/app_drawer.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/media_pipeline_service.dart';
// Removed unused import
import 'dart:async';
import '../services/upload_queue_service.dart';

class HomeShell extends StatefulWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeModeChanged;

  const HomeShell({super.key, required this.themeMode, required this.onThemeModeChanged});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final MediaPipelineService _pipeline = MediaPipelineService();
  StreamSubscription<Map<String, dynamic>>? _uploadSub;

  void _openAddSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Create New Project',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onBackground(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to start your project',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.secondaryText(context),
                ),
              ),
              const SizedBox(height: 24),
              
              // Options
              Container(
                decoration: BoxDecoration(
                  color: AppColors.muted(context),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryPurple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.upload_file,
                          color: AppColors.primaryPurple,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Upload photo',
                        style: GoogleFonts.inter(
                          color: AppColors.onBackground(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Choose from your gallery',
                        style: GoogleFonts.inter(
                          color: AppColors.secondaryText(context),
                          fontSize: 14,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        final name = await _promptProjectName();
                        if (name == null) return;
                        await _pipeline.pickFromGalleryAndQueue(projectName: name);
                      },
                    ),
                    Divider(
                      color: AppColors.background(context),
                      height: 1,
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.photo_camera,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        'Take photo',
                        style: GoogleFonts.inter(
                          color: AppColors.onBackground(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Use your camera',
                        style: GoogleFonts.inter(
                          color: AppColors.secondaryText(context),
                          fontSize: 14,
                        ),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        final name = await _promptProjectName();
                        if (name == null) return;
                        await _pipeline.captureFromCameraAndQueue(projectName: name);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _promptProjectName() async {
    String value = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Project name'),
          content: TextField(
            autofocus: true,
            onChanged: (v) => value = v,
            decoration: const InputDecoration(hintText: 'Enter a name'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, value.trim().isEmpty ? null : value.trim()), child: const Text('Continue')),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _uploadSub = UploadQueueService.instance.events.listen((event) {
      if (event['type'] == 'completed' && event['media'] is Map<String, dynamic>) {
        final media = event['media'] as Map<String, dynamic>;
        final url = media['url'] as String?;
        if (url != null && mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EditorPage(imageAsset: url, projectName: 'Project'),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      LibraryPage(
        onNewProject: _openAddSheet,
        onOpenProject: (asset) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EditorPage(imageAsset: asset, projectName: 'Project'),
            ),
          );
        },
      ),
      const SizedBox.shrink(),
      ProfilePage(
        themeMode: widget.themeMode,
        onModeChanged: widget.onThemeModeChanged,
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(
              Icons.menu,
              color: AppColors.onBackground(context),
              size: 24,
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'PicturePet',
          style: GoogleFonts.inter(
            color: AppColors.onBackground(context),
            fontWeight: FontWeight.w700,
            fontSize: 26,
          ),
        ),
        centerTitle: true,
      ),
      drawer: AppDrawer(
        themeMode: widget.themeMode,
        onThemeChanged: widget.onThemeModeChanged,
        onNewProject: _openAddSheet,
        onGoLibrary: () => setState(() => _index = 0),
        onGoProfile: () => setState(() => _index = 2),
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface(context).withOpacity(0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.muted(context).withOpacity(0.3),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.collections_bookmark_outlined,
                    activeIcon: Icons.collections_bookmark,
                    label: 'Projects',
                    selected: _index == 0,
                    onTap: () => setState(() => _index = 0),
                  ),
                  const SizedBox(width: 16),
                  _AddButton(onTap: _openAddSheet),
                  const SizedBox(width: 16),
                  _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profile',
                    selected: _index == 2,
                    onTap: () => setState(() => _index = 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    super.dispose();
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.onBackground(context) : AppColors.secondaryText(context);
    final backgroundColor = selected ? AppColors.primaryPurple.withOpacity(0.2) : Colors.transparent;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [mediaPetShadow(context)],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}


