import 'package:uni_links/uni_links.dart';
import 'dart:async';

class DeepLinkHelper {
  static StreamSubscription? _linkSubscription;
  
  /// Initialize deep link handling
  static void initialize() {
    _linkSubscription = uriLinkStream.listen((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }, onError: (err) {
      print('Deep link error: $err');
    });

    // Handle deep link that opened the app
    getInitialUri().then((Uri? uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });
  }

  /// Dispose of deep link subscription
  static void dispose() {
    _linkSubscription?.cancel();
  }

  /// Handle incoming deep links
  static void _handleDeepLink(Uri uri) {
    print('Deep link received: $uri');
    
    // Handle OAuth callback
    if (uri.scheme == 'io.supabase.flutter' && uri.host == 'login-callback') {
      print('OAuth callback received: $uri');
      // Supabase will handle this automatically
      return;
    }
    
    // Handle custom deep links
    if (uri.scheme == 'mediaus') {
      _handleCustomDeepLink(uri);
    }
  }

  /// Handle custom deep links for your app
  static void _handleCustomDeepLink(Uri uri) {
    print('Custom deep link: $uri');
    
    switch (uri.host) {
      case 'home':
        print('Navigate to home');
        break;
      case 'auth':
        print('Navigate to auth');
        break;
      case 'profile':
        print('Navigate to profile');
        break;
      case 'project':
        if (uri.pathSegments.isNotEmpty) {
          final projectId = uri.pathSegments[0];
          print('Navigate to project: $projectId');
        }
        break;
      default:
        print('Unknown deep link host: ${uri.host}');
    }
  }

  /// Test deep links (for development)
  static void testDeepLinks() {
    print('Testing deep links...');
    
    // Test OAuth callback
    _handleDeepLink(Uri.parse('io.supabase.flutter://login-callback/'));
    
    // Test custom deep links
    _handleDeepLink(Uri.parse('mediaus://home'));
    _handleDeepLink(Uri.parse('mediaus://auth'));
    _handleDeepLink(Uri.parse('mediaus://profile'));
    _handleDeepLink(Uri.parse('mediaus://project/123'));
  }
}
