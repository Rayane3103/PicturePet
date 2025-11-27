import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/profile_repository.dart';
import '../utils/logger.dart';

@immutable
class CreditsState {
  final bool isLoading;
  final int? amount;
  final String? error;

  const CreditsState._({
    required this.isLoading,
    this.amount,
    this.error,
  });

  const CreditsState.loading() : this._(isLoading: true);
  const CreditsState.loaded(int value) : this._(isLoading: false, amount: value);
  const CreditsState.error(String message)
      : this._(isLoading: false, error: message);
  const CreditsState.unauthenticated()
      : this._(isLoading: false, amount: 0);

  bool get hasError => error != null;
}

class CreditsService {
  CreditsService._internal();
  static final CreditsService instance = CreditsService._internal();

  final ProfileRepository _profiles = ProfileRepository();
  final SupabaseClient _client = Supabase.instance.client;
  final ValueNotifier<CreditsState> _state =
      ValueNotifier<CreditsState>(const CreditsState.loading());

  ValueListenable<CreditsState> get notifier => _state;
  CreditsState get currentState => _state.value;

  Future<int?> refresh({bool force = true}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _state.value = const CreditsState.unauthenticated();
      return 0;
    }

    try {
      final profile =
          await _profiles.getCurrentUserProfile(forceRefresh: force);
      final credits = profile?.credits ?? 0;
      _state.value = CreditsState.loaded(credits);
      return credits;
    } catch (e, st) {
      Logger.error('Failed to refresh credits',
          context: {'error': e.toString(), 'stackTrace': st.toString()});
      _state.value =
          const CreditsState.error('Unable to load credits right now.');
      rethrow;
    }
  }

  Future<void> ensureLoaded() async {
    final state = _state.value;
    if (!state.isLoading && state.amount != null) return;
    await refresh(force: true);
  }

  Future<bool> purchaseCredits({
    required int amount,
    required String description,
    String? referenceType,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _state.value = const CreditsState.error('Please sign in to buy credits.');
      return false;
    }

    try {
      final result = await _client.rpc('add_credits', params: {
        'user_uuid': user.id,
        'amount': amount,
        'description_text': description,
        'reference_type_param': referenceType ?? 'purchase',
        'reference_id_param': null,
      });

      if (result == true) {
        await refresh(force: true);
        return true;
      }
      throw Exception('add_credits RPC returned unexpected payload');
    } catch (e, st) {
      Logger.error('Failed to purchase credits',
          context: {'error': e.toString(), 'stackTrace': st.toString()});
      _state.value =
          const CreditsState.error('Purchase failed. Please try again.');
      rethrow;
    }
  }

  void applyRemoteBalance(int? amount) {
    if (amount == null) return;
    _state.value = CreditsState.loaded(amount);
  }
}

