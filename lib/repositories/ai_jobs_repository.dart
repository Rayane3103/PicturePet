import 'package:supabase_flutter/supabase_flutter.dart';

import '../exceptions/credits_exceptions.dart';
import '../models/ai_job.dart';
import '../services/credits_service.dart';
import '../utils/logger.dart';

/// Handles enqueueing AI jobs while coordinating credits.
/// Credit pricing (mirrors Supabase `tools.credit_cost`):
/// - 50 credits: imagen4, nano_banana, seedvr_upscale, elements
/// - 25 credits: remove_background, style_transfer, ideogram_v3_reframe,
///   ideogram_character_edit, ideogram_character_remix, calligrapher
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

    final response = await _client.rpc(
      'enqueue_ai_job_with_credits',
      params: {
        'user_uuid': user.id,
        'project_id_param': projectId,
        'tool_name_param': toolName,
        'payload_json': payload,
        'input_image_url_param': inputImageUrl,
      },
    );

    final List<dynamic> rows = response is List ? response : [response];
    if (rows.isEmpty) {
      throw const AiJobException('Unable to start AI job (empty response)');
    }

    final Map<String, dynamic> result =
        Map<String, dynamic>.from(rows.first as Map);
    final bool success = result['success'] == true;

    if (!success) {
      final String message =
          (result['message'] as String?) ?? 'Unable to start AI job';
      final String code = (result['code'] as String?) ?? 'UNKNOWN';
      Logger.warn('enqueue_ai_job_with_credits failed',
          context: {'code': code, 'message': message});
      if (code == 'INSUFFICIENT_CREDITS') {
        throw InsufficientCreditsException(
          message: message,
          requiredCredits: (result['charged_credits'] as num?)?.toInt(),
          toolName: toolName,
        );
      }
      if (code == 'TOOL_NOT_FOUND' || code == 'INVALID_TOOL') {
        throw ToolUnavailableException(message);
      }
      throw AiJobException(message);
    }

    final jobPayload = Map<String, dynamic>.from(result['job'] as Map);
    final job = AiJob.fromMap(jobPayload);
    final remaining = (result['remaining_credits'] as num?)?.toInt();
    CreditsService.instance.applyRemoteBalance(remaining);

    return job;
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


