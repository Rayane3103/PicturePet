import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_job.dart';
import '../utils/logger.dart';

class AiJobsService {
  AiJobsService._internal();
  static final AiJobsService instance = AiJobsService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  RealtimeChannel? _projectChannel;
  RealtimeChannel? _userJobsChannel;

  StreamSubscription? _aiJobsSubscription;
  final StreamController<AiJob> _jobUpdates = StreamController<AiJob>.broadcast();
  Stream<AiJob> get jobUpdates => _jobUpdates.stream;

  void dispose() {
    _aiJobsSubscription?.cancel();
    _projectChannel?.unsubscribe();
    _userJobsChannel?.unsubscribe();
    _jobUpdates.close();
  }

  /// Subscribe to jobs for a specific project (used in editor page)
  void subscribeToProjectJobs(String projectId) {
    _projectChannel?.unsubscribe();
    final channel = _client.channel('ai_jobs_project_$projectId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'ai_jobs',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'project_id', value: projectId),
      callback: (payload) {
        try {
          final record = Map<String, dynamic>.from(payload.newRecord as Map);
          final job = AiJob.fromMap(record);
          _jobUpdates.add(job);
        } catch (e) {
          Logger.warn('Failed to parse ai_job update', context: {'error': e.toString()});
        }
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'ai_jobs',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'project_id', value: projectId),
      callback: (payload) {
        try {
          final record = Map<String, dynamic>.from(payload.newRecord as Map);
          final job = AiJob.fromMap(record);
          _jobUpdates.add(job);
        } catch (e) {
          Logger.warn('Failed to parse ai_job insert', context: {'error': e.toString()});
        }
      },
    );

    _projectChannel = channel.subscribe();
  }

  /// Subscribe to all jobs for the current user (used in library page)
  void subscribeToUserJobs(String userId) {
    _userJobsChannel?.unsubscribe();
    final channel = _client.channel('ai_jobs_user_$userId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'ai_jobs',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
      callback: (payload) {
        try {
          final record = Map<String, dynamic>.from(payload.newRecord as Map);
          final job = AiJob.fromMap(record);
          _jobUpdates.add(job);
        } catch (e) {
          Logger.warn('Failed to parse ai_job update', context: {'error': e.toString()});
        }
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'ai_jobs',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
      callback: (payload) {
        try {
          final record = Map<String, dynamic>.from(payload.newRecord as Map);
          final job = AiJob.fromMap(record);
          _jobUpdates.add(job);
        } catch (e) {
          Logger.warn('Failed to parse ai_job insert', context: {'error': e.toString()});
        }
      },
    );

    _userJobsChannel = channel.subscribe();
  }

  void unsubscribe() {
    _projectChannel?.unsubscribe();
    _projectChannel = null;
  }

  void unsubscribeUserJobs() {
    _userJobsChannel?.unsubscribe();
    _userJobsChannel = null;
  }

  Future<void> triggerProcessing(String jobId) async {
    // Call Edge Function to process job in background
    final res = await _client.functions.invoke('ai-run', body: {'jobId': jobId});
    if (res.data == null) {
      Logger.warn('Edge function ai-run returned null data');
    }
  }

  Future<List<AiJob>> fetchInProgressProjectJobsForUser(String userId) async {
    final rows = await _client
        .from('ai_jobs')
        .select()
        .eq('user_id', userId)
        .filter('status', 'in', '(queued,running)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows).map(AiJob.fromMap).toList();
  }
}


