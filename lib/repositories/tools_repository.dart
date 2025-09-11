import 'package:supabase_flutter/supabase_flutter.dart';

class ToolsRepository {
  ToolsRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  Future<int> getToolIdByName(String name) async {
    final data = await _client.from('tools').select('id').eq('name', name).single();
    return (data['id'] as num).toInt();
  }
}


