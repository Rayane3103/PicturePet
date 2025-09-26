import 'package:supabase_flutter/supabase_flutter.dart';

class ToolsRepository {
  ToolsRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<int?> getToolIdByName(String name) async {
    // Read-only: return existing id if present; otherwise return null to avoid RLS issues
    final existing = await _client.from('tools').select('id').eq('name', name).maybeSingle();
    if (existing != null && existing['id'] != null) {
      return (existing['id'] as num).toInt();
    }
    return null;
  }
}


