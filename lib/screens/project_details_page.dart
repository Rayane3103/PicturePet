import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../repositories/projects_repository.dart';
import '../repositories/project_edits_repository.dart';
import '../models/project.dart';
import '../models/project_edit.dart';

class ProjectDetailsPage extends StatefulWidget {
  final String projectId;
  const ProjectDetailsPage({super.key, required this.projectId});

  @override
  State<ProjectDetailsPage> createState() => _ProjectDetailsPageState();
}

class _ProjectDetailsPageState extends State<ProjectDetailsPage> {
  final ProjectsRepository _projects = ProjectsRepository();
  final ProjectEditsRepository _edits = ProjectEditsRepository();
  Project? _project;
  List<ProjectEdit> _history = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = await _projects.getById(widget.projectId);
      final h = await _edits.listForProject(widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = p;
        _history = h;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project details')),
      backgroundColor: AppColors.background(context),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_project != null) _header(_project!),
                  const SizedBox(height: 16),
                  Text('Edit history', style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  ..._history.map(_historyTile),
                ],
              ),
            ),
    );
  }

  Widget _header(Project p) {
    final imageUrl = p.outputImageUrl ?? p.thumbnailUrl ?? p.originalImageUrl;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 6),
                Text(p.createdAt.toLocal().toString(), style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyTile(ProjectEdit e) {
    return Card(
      color: AppColors.card(context),
      child: ListTile(
        title: Text(e.editName, style: GoogleFonts.inter(color: AppColors.onBackground(context), fontWeight: FontWeight.w600)),
        subtitle: Text(e.createdAt.toLocal().toString(), style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12)),
        trailing: Text('${e.creditCost} cr', style: GoogleFonts.inter(color: AppColors.secondaryText(context), fontSize: 12)),
      ),
    );
  }
}


