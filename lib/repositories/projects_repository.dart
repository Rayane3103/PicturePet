import 'package:supabase_flutter/supabase_flutter.dart';
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
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows).map(Project.fromMap).toList();
  }
}


