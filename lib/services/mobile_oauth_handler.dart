import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';
import 'dart:io';
import '../config/supabase_config.dart';

class MobileOAuthHandler {
  static StreamSubscription? _linkSubscription;
  static Completer<AuthResponse>? _authCompleter;
  
  /// Check if running on mobile platform
  static bool get isMobilePlatform {
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (e) {
      // Web platform will throw an error when accessing Platform
      return false;
    }
  }
  
  /// Initialize mobile OAuth handling (only on mobile platforms)
  static void initialize() {
    if (!isMobilePlatform) {
      print('Mobile OAuth handler: Not initializing on web platform');
      return;
    }
    
    try {
      _linkSubscription = uriLinkStream.listen((Uri? uri) {
        if (uri != null) {
          _handleOAuthCallback(uri);
        }
      }, onError: (err) {
        print('Mobile OAuth error: $err');
        _authCompleter?.completeError(err);
      });

      // Handle OAuth callback that opened the app
      getInitialUri().then((Uri? uri) {
        if (uri != null) {
          _handleOAuthCallback(uri);
        }
      });
      
      print('Mobile OAuth handler initialized successfully');
    } catch (e) {
      print('Error initializing mobile OAuth handler: $e');
    }
  }

  /// Dispose of OAuth handler
  static void dispose() {
    _linkSubscription?.cancel();
    _authCompleter = null;
  }

  /// Handle OAuth callback from web redirect
  static void _handleOAuthCallback(Uri uri) {
    print('OAuth callback received: $uri');
    
    // Handle Supabase OAuth callback
    if (uri.scheme == 'io.supabase.flutter' && uri.host == 'login-callback') {
      print('Processing Supabase OAuth callback...');
      
      // Extract auth parameters from the callback
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];
      
      if (error != null) {
        print('OAuth error: $error');
        _authCompleter?.completeError(Exception('OAuth error: $error'));
        return;
      }
      
      if (code != null) {
        print('OAuth code received, processing authentication...');
        _processOAuthCode(code);
      }
    }
  }

  /// Process OAuth authorization code
  static Future<void> _processOAuthCode(String code) async {
    try {
      // Supabase should handle this automatically, but we can add custom logic here
      print('OAuth code processed successfully');
      
      // Check if user is authenticated
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        print('User authenticated: ${user.email}');
        _authCompleter?.complete(AuthResponse(
          user: user,
          session: Supabase.instance.client.auth.currentSession,
        ));
      } else {
        print('User not authenticated after OAuth');
        _authCompleter?.completeError(Exception('Authentication failed'));
      }
    } catch (e) {
      print('Error processing OAuth code: $e');
      _authCompleter?.completeError(e);
    }
  }

  /// Start OAuth flow with web redirect
  static Future<AuthResponse> startOAuthFlow(Provider provider) async {
    if (!isMobilePlatform) {
      throw UnsupportedError('OAuth flow not supported on web platform');
    }
    
    _authCompleter = Completer<AuthResponse>();
    
    try {
      print('Starting OAuth flow for provider: $provider');
      
      // Start OAuth with web redirect
      await Supabase.instance.client.auth.signInWithOAuth(
        provider,
        redirectTo: SupabaseConfig.getMobileCallbackUrl(),
        queryParams: provider == Provider.google ? {
          'access_type': 'offline',
          'prompt': 'consent',
        } : null,
      );
      
      print('OAuth flow initiated, waiting for callback...');
      
      // Wait for OAuth callback
      return await _authCompleter!.future;
    } catch (e) {
      print('Error starting OAuth flow: $e');
      rethrow;
    }
  }

  /// Check if OAuth callback is pending
  static bool get isOAuthPending => _authCompleter != null && !_authCompleter!.isCompleted;
}
