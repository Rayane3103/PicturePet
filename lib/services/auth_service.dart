import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import '../config/supabase_config.dart';
import '../repositories/profile_repository.dart';
import '../models/user_profile.dart';
import '../utils/logger.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  final ProfileRepository _profiles = ProfileRepository();

  // Check if running on mobile platform
  bool get isMobilePlatform {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      // Web platform will throw an error when accessing Platform
      return false;
    }
  }

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Get current session
  Session? get currentSession => _supabase.auth.currentSession;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Stream of auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      print('Starting signup for email: $email');
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );

      print('Signup response: user=${response.user != null}, session=${response.session != null}');

      if (response.user != null && response.session != null) {
        // Create profile in profiles table
        await _createProfile(response.user!);
      }

      return response;
    } catch (e) {
      print('Signup error in AuthService: $e');
      print('Error type: ${e.runtimeType}');
      print('Error toString: ${e.toString()}');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      Logger.info('AuthService: Starting sign out...');
      _profiles.invalidateCache();
      await _supabase.auth.signOut();
      Logger.info('AuthService: Sign out completed successfully');
    } catch (e) {
      Logger.error('AuthService: Sign out error', context: {'error': e.toString()});
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  // Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Create user profile in profiles table
  Future<void> _createProfile(User user) async {
    try {
      Logger.info('Creating profile for user', context: {'userId': user.id});
      
      // Handle different auth providers
      String? username;
      if (user.userMetadata?['full_name'] != null) {
        username = user.userMetadata!['full_name'];
      } else if (user.userMetadata?['name'] != null) {
        username = user.userMetadata!['name'];
      } else if (user.userMetadata?['preferred_username'] != null) {
        username = user.userMetadata!['preferred_username'];
      } else if (user.email != null) {
        username = user.email!.split('@')[0];
      } else {
        username = 'user_${user.id.substring(0, 8)}';
      }

      final avatarUrl = user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'];
      final profile = UserProfile(
        id: user.id,
        email: user.email,
        username: username,
        fullName: user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
        avatarUrl: avatarUrl is String ? avatarUrl : null,
        tier: 'free_trial',
        credits: 50,
        storageUsedGb: 0,
        maxStorageGb: 2,
        maxProjects: 5,
        trialStartedAt: DateTime.now(),
        trialEndsAt: DateTime.now().add(const Duration(days: 7)),
        isTrialActive: true,
        metadata: user.userMetadata is Map<String, dynamic>
            ? Map<String, dynamic>.from(user.userMetadata!)
            : <String, dynamic>{},
      );

      await _profiles.upsertProfile(profile);
      Logger.info('Profile created successfully for user', context: {'userId': user.id});
    } catch (e) {
      Logger.error('Error creating profile', context: {
        'error': e.toString(),
        'type': e.runtimeType.toString(),
      });
      
      // If profile creation fails due to duplicate key, this might indicate
      // the user already exists but the auth signup succeeded
      if (e.toString().contains('duplicate key') || 
          e.toString().contains('unique constraint') ||
          e.toString().contains('already exists')) {
        Logger.warn('Profile already exists for user', context: {'userId': user.id});
        // This is not a critical error - the user can still proceed
      } else {
        // Re-throw other profile creation errors
        rethrow;
      }
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (currentUser == null) return null;

      final profile = await _profiles.getCurrentUserProfile();
      return profile?.toMap();
    } catch (e) {
      Logger.error('Error getting user profile', context: {'error': e.toString()});
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      if (currentUser == null) return;

      await _profiles.updateProfileFields(Map<String, Object?>.from(updates));
    } catch (e) {
      rethrow;
    }
  }

  // Typed helpers for profile access
  Future<UserProfile?> fetchCurrentUserProfile({bool forceRefresh = false}) {
    return _profiles.getCurrentUserProfile(forceRefresh: forceRefresh);
  }

  Future<UserProfile?> updateProfile({
    String? fullName,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
  }) async {
    final updates = <String, Object?>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (metadata != null) updates['metadata'] = metadata;
    return _profiles.updateProfileFields(updates);
  }

  // Check if user can use a specific tool
  Future<bool> canUseTool(int toolId) async {
    try {
      if (currentUser == null) return false;
      
      final response = await _supabase.rpc('can_use_tool', params: {
        'user_uuid': currentUser!.id,
        'tool_id_param': toolId,
      });
      
      return response == true;
    } catch (e) {
      print('Error checking tool availability: $e');
      return false;
    }
  }

  // Get user's available tools
  Future<List<Map<String, dynamic>>> getAvailableTools() async {
    try {
      if (currentUser == null) return [];
      
      final response = await _supabase.rpc('get_user_available_tools', params: {
        'user_uuid': currentUser!.id,
      });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting available tools: $e');
      return [];
    }
  }

  // Get user's credit summary
  Future<Map<String, dynamic>?> getCreditSummary({int days = 30}) async {
    try {
      if (currentUser == null) return null;
      
      final response = await _supabase.rpc('get_user_credit_summary', params: {
        'user_uuid': currentUser!.id,
        'days_back': days,
      });
      
      if (response.isNotEmpty) {
        return response[0];
      }
      return null;
    } catch (e) {
      print('Error getting credit summary: $e');
      return null;
    }
  }

  // Use a tool (deducts credits)
  Future<Map<String, dynamic>?> useTool({
    required int toolId,
    required String projectId,
    required Map<String, dynamic> parameters,
    String? inputImageUrl,
    String? editName,
  }) async {
    try {
      if (currentUser == null) return null;
      
      final response = await _supabase.rpc('use_tool', params: {
        'user_uuid': currentUser!.id,
        'tool_id_param': toolId,
        'project_id_param': projectId,
        'parameters_json': parameters,
        'input_image_url_param': inputImageUrl,
        'edit_name_param': editName,
      });
      
      if (response.isNotEmpty) {
        return response[0];
      }
      return null;
    } catch (e) {
      print('Error using tool: $e');
      return null;
    }
  }

  // Upgrade user tier
  Future<bool> upgradeTier(String newTier) async {
    try {
      if (currentUser == null) return false;
      
      final response = await _supabase.rpc('upgrade_user_tier', params: {
        'user_uuid': currentUser!.id,
        'new_tier': newTier,
      });
      
      return response == true;
    } catch (e) {
      print('Error upgrading tier: $e');
      return false;
    }
  }

  // Add credits to user (admin function)
  Future<bool> addCredits({
    required int amount,
    required String description,
    String? referenceId,
    String? referenceType,
  }) async {
    try {
      if (currentUser == null) return false;
      
      final response = await _supabase.rpc('add_credits', params: {
        'user_uuid': currentUser!.id,
        'amount': amount,
        'description_text': description,
        'reference_id_param': referenceId,
        'reference_type_param': referenceType,
      });
      
      return response == true;
    } catch (e) {
      print('Error adding credits: $e');
      return false;
    }
  }

  // Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      print('Starting Google sign in...');
      print('Platform: ${isMobilePlatform ? "Mobile" : "Web"}');
      
      final redirectUrl = isMobilePlatform
          // Use app deep link on mobile so it returns to the app
          ? SupabaseConfig.getMobileCallbackUrl()
          // Use hosted callback on web/desktop
          : SupabaseConfig.getOAuthRedirectUrl();
      print('Using redirect URL: $redirectUrl');
      
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        queryParams: const {
          'access_type': 'offline',
          'prompt': 'consent',
        },
        authScreenLaunchMode: isMobilePlatform
            ? LaunchMode.inAppWebView
            : LaunchMode.platformDefault,
      );
      print('Google sign in initiated successfully');
    } catch (e) {
      print('Google sign in error: $e');
      print('Error type: ${e.runtimeType}');
      print('Error toString: ${e.toString()}');
      rethrow;
    }
  }

  // Sign in with Facebook
  Future<void> signInWithFacebook() async {
    try {
      print('Starting Facebook sign in...');
      print('Platform: ${isMobilePlatform ? "Mobile" : "Web"}');
      
      final redirectUrl = isMobilePlatform
          ? SupabaseConfig.getMobileCallbackUrl()
          : SupabaseConfig.getOAuthRedirectUrl();
      print('Using redirect URL: $redirectUrl');
      
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: redirectUrl,
        authScreenLaunchMode: isMobilePlatform
            ? LaunchMode.inAppWebView
            : LaunchMode.platformDefault,
      );
      print('Facebook sign in initiated successfully');
    } catch (e) {
      print('Facebook sign in error: $e');
      print('Error type: ${e.runtimeType}');
      print('Error toString: ${e.toString()}');
      rethrow;
    }
  }
}
