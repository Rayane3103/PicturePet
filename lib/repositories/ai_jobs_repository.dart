import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_job.dart';

class AiJobsRepository {
  AiJobsRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<AiJob> enqueueJob({
    required String projectId,
    required String toolName,
    required Map<String, dynamic> payload,
    String? inputImageUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not authenticated');
    final data = await _client
        .from('ai_jobs')
        .insert({
          'user_id': user.id,
          'project_id': projectId,
          'tool_name': toolName,
          'payload': payload,
          if (inputImageUrl != null) 'input_image_url': inputImageUrl,
          'status': 'queued',
        })
        .select()
        .single();
    return AiJob.fromMap(Map<String, dynamic>.from(data));
  }

  Future<List<AiJob>> listForProject(String projectId, {int limit = 50}) async {
    final rows = await _client
        .from('ai_jobs')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows).map(AiJob.fromMap).toList();
  }

  Future<void> cancelQueuedJob(String jobId) async {
    await _client
        .from('ai_jobs')
        .update({'status': 'cancelled'})
        .eq('id', jobId)
        .eq('status', 'queued');
  }
}


