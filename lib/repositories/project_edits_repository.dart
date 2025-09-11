import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/project_edit.dart';

class ProjectEditsRepository {
  ProjectEditsRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<ProjectEdit> insert({
    required String projectId,
    required int toolId,
    required String editName,
    required Map<String, dynamic> parameters,
    String? inputImageUrl,
    String? outputImageUrl,
    int creditCost = 0,
    String status = 'completed',
  }) async {
    final Map<String, dynamic> payload = {
      'project_id': projectId,
      'tool_id': toolId,
      'edit_name': editName,
      'parameters': parameters,
      'input_image_url': inputImageUrl,
      'output_image_url': outputImageUrl,
      'credit_cost': creditCost,
      'status': status,
    };

    final data = await _client.from('project_edits').insert(payload).select().single();
    return ProjectEdit.fromMap(Map<String, dynamic>.from(data));
  }

  Future<List<ProjectEdit>> listForProject(String projectId, {int limit = 50, int offset = 0}) async {
    final rows = await _client
        .from('project_edits')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows).map(ProjectEdit.fromMap).toList();
  }
}


