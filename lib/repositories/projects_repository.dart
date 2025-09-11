import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/projects_events.dart';
import '../models/project.dart';

class ProjectsRepository {
  ProjectsRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<List<Project>> list({int limit = 20, int offset = 0}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final rows = await _client
        .from('projects')
        .select()
        .eq('user_id', user.id)
        .order('updated_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows).map(Project.fromMap).toList();
  }

  Future<Project> rename({required String projectId, required String newName}) async {
    final data = await _client
        .from('projects')
        .update({'name': newName})
        .eq('id', projectId)
        .select()
        .single();
    ProjectsEvents.instance.notifyChanged();
    return Project.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> deleteProjectCascade({required String projectId}) async {
    // Deleting the project will cascade delete project_edits due to FK on delete cascade.
    await _client.from('projects').delete().eq('id', projectId);
    ProjectsEvents.instance.notifyChanged();
  }

  Future<Project> duplicate({required String projectId, required String newName}) async {
    // Simple duplicate: copy key fields; edits are not copied by default.
    final src = await getById(projectId);
    if (src == null) {
      throw StateError('Project not found');
    }
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    final data = await _client
        .from('projects')
        .insert({
          'user_id': user.id,
          'name': newName,
          'original_image_url': src.originalImageUrl,
          'output_image_url': src.outputImageUrl,
          'thumbnail_url': src.thumbnailUrl,
          'file_size_bytes': src.fileSizeBytes,
        })
        .select()
        .single();
    ProjectsEvents.instance.notifyChanged();
    return Project.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Project> create({required String name, String? originalImageUrl, String? thumbnailUrl, int? fileSizeBytes}) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    final data = await _client
        .from('projects')
        .insert({
          'user_id': user.id,
          'name': name,
          'original_image_url': originalImageUrl,
          'thumbnail_url': thumbnailUrl,
          'file_size_bytes': fileSizeBytes,
        })
        .select()
        .single();
    return Project.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Project> updateOutputUrl({required String projectId, required String outputImageUrl, String? thumbnailUrl}) async {
    final Map<String, dynamic> updates = {'output_image_url': outputImageUrl};
    if (thumbnailUrl != null) {
      updates['thumbnail_url'] = thumbnailUrl;
    }
    final data = await _client
        .from('projects')
        .update(updates)
        .eq('id', projectId)
        .select()
        .single();
    return Project.fromMap(Map<String, dynamic>.from(data));
  }

  Future<Project?> getById(String projectId) async {
    final rows = await _client.from('projects').select().eq('id', projectId).maybeSingle();
    if (rows == null) return null;
    return Project.fromMap(Map<String, dynamic>.from(rows));
  }
}


