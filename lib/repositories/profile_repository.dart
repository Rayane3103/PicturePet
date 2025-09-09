import 'dart:collection';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../utils/retry.dart';
import '../utils/logger.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client}) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  UserProfile? _cache;
  DateTime? _cacheTs;
  static const Duration _cacheTtl = Duration(minutes: 5);

  bool get _isCacheValid => _cache != null && _cacheTs != null && DateTime.now().difference(_cacheTs!) < _cacheTtl;

  Future<UserProfile?> getCurrentUserProfile({bool forceRefresh = false}) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    if (!forceRefresh && _isCacheValid) return _cache;

    final profileMap = await retry<Map<String, dynamic>>(() async {
      Logger.debug('Fetching user profile', context: {'userId': user.id});
      final data = await _client.from('profiles').select().eq('id', user.id).single();
      return Map<String, dynamic>.from(data);
    });

    _cache = UserProfile.fromMap(profileMap);
    _cacheTs = DateTime.now();
    return _cache;
  }

  Future<UserProfile> upsertProfile(UserProfile profile) async {
    final map = profile.toMap();
    // Ensure only columns that exist are sent
    final payload = HashMap<String, Object?>.from(map)..removeWhere((key, _) => map[key] == null);

    final upserted = await retry<Map<String, dynamic>>(() async {
      Logger.info('Upserting profile', context: {'userId': profile.id});
      final data = await _client.from('profiles').upsert(payload).select().single();
      return Map<String, dynamic>.from(data);
    });

    _cache = UserProfile.fromMap(upserted);
    _cacheTs = DateTime.now();
    return _cache!;
  }

  Future<UserProfile?> updateProfileFields(Map<String, Object?> updates) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final filtered = HashMap<String, Object?>.from(updates)..removeWhere((_, v) => v == null);

    final updated = await retry<Map<String, dynamic>>(() async {
      Logger.info('Updating profile fields', context: {'userId': user.id});
      final data = await _client.from('profiles').update(filtered).eq('id', user.id).select().single();
      return Map<String, dynamic>.from(data);
    });

    _cache = UserProfile.fromMap(updated);
    _cacheTs = DateTime.now();
    return _cache;
  }

  void invalidateCache() {
    _cache = null;
    _cacheTs = null;
  }
}


