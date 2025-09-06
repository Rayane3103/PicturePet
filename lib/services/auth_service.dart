import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../config/supabase_config.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

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
      print('AuthService: Starting sign out...');
      await _supabase.auth.signOut();
      print('AuthService: Sign out completed successfully');
    } catch (e) {
      print('AuthService: Sign out error: $e');
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
      print('Creating profile for user: ${user.id}');
      
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
      
      await _supabase.from('profiles').insert({
        'id': user.id,
        'email': user.email,
        'username': username,
        'tier': 'free_trial',
        'credits': 50,
        'storage_used_gb': 0,
        'max_storage_gb': 2,
        'max_projects': 5,
        'trial_started_at': DateTime.now().toIso8601String(),
        'trial_ends_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'is_trial_active': true,
      });
      print('Profile created successfully for user: ${user.id}');
    } catch (e) {
      print('Error creating profile: $e');
      print('Error type: ${e.runtimeType}');
      
      // If profile creation fails due to duplicate key, this might indicate
      // the user already exists but the auth signup succeeded
      if (e.toString().contains('duplicate key') || 
          e.toString().contains('unique constraint') ||
          e.toString().contains('already exists')) {
        print('Profile already exists for user: ${user.id}');
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
      
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();
      
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      if (currentUser == null) return;
      
      await _supabase
          .from('profiles')
          .update(updates)
          .eq('id', currentUser!.id);
    } catch (e) {
      rethrow;
    }
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
        Provider.google,
        redirectTo: redirectUrl,
        queryParams: const {
          'access_type': 'offline',
          'prompt': 'consent',
        },
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
        Provider.facebook,
        redirectTo: redirectUrl,
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
