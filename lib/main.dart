import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'theme/app_theme.dart';
import 'screens/onboarding_splash.dart';
import 'screens/onboarding_page.dart';
import 'screens/auth_page.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/forgot_password_page.dart';
import 'screens/home_shell.dart';
import 'widgets/auth_wrapper.dart';
import 'config/supabase_config.dart';
import 'services/mobile_oauth_handler.dart';
import 'utils/logger.dart';
import 'screens/media_history_page.dart';
import 'services/upload_queue_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// comment to test the sync of the replit, yes it's working fine.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    Logger.error('FlutterError', context: {
      'exception': details.exceptionAsString(),
      'stack': details.stack?.toString(),
    });
  };
  
  // Load .env (optional; ignores missing)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Log which secret names are present (never values)
  Logger.info('Secrets status', context: SupabaseConfig.secretsStatus());
  
  runApp(const MediaUsApp());
}

class MediaUsApp extends StatefulWidget {
  const MediaUsApp({super.key});

  @override
  State<MediaUsApp> createState() => _MediaUsAppState();
}

class _MediaUsAppState extends State<MediaUsApp> {
  ThemeMode _mode = ThemeMode.dark; // Default to dark theme
  StreamSubscription? _linkSubscription;
  bool _isMobilePlatform = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _checkPlatform();
    _initDeepLinkHandling();
    _initMobileOAuth();
    _initAuthListener();
    // Restore any pending uploads
    UploadQueueService.instance.restoreQueue();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    MobileOAuthHandler.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  void _checkPlatform() {
    try {
      _isMobilePlatform = !kIsWeb;
      print('Platform detected: ${_isMobilePlatform ? "Mobile" : "Web"}');
    } catch (e) {
      _isMobilePlatform = false;

    }
  }

  void _initDeepLinkHandling() {
    if (!_isMobilePlatform) {
      print('Deep link handling: Not initializing on web platform');
      return;
    }
    
    try {
      final appLinks = AppLinks();
      _linkSubscription = appLinks.uriLinkStream.listen((Uri uri) {
        _handleDeepLink(uri);
      }, onError: (err) {
        print('Deep link error: $err');
      });

      appLinks.getInitialLink().then((Uri? uri) {
        if (uri != null) {
          _handleDeepLink(uri);
        }
      });
      
      print('Deep link handling initialized successfully');
    } catch (e) {
      print('Error initializing deep link handling: $e');
    }
  }

  void _initMobileOAuth() {
    // Initialize mobile OAuth handler (will check platform internally)
    MobileOAuthHandler.initialize();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Restore any pending uploads from previous sessions
    UploadQueueService.instance.restoreQueue();
  }

  void _handleDeepLink(Uri uri) {
    print('Handling deep link: $uri');
    
    // Handle OAuth callback
    if (uri.scheme == 'io.supabase.flutter' && uri.host == 'login-callback') {
      print('OAuth callback received, processing...');
      // MobileOAuthHandler will handle this
    }
    
    // Handle custom deep links
    if (uri.scheme == 'mediaus') {
      _handleCustomDeepLink(uri);
    }
  }

  void _handleCustomDeepLink(Uri uri) {
    switch (uri.host) {
      case 'home':
        Navigator.of(context).pushReplacementNamed('/home');
        break;
      case 'auth':
        Navigator.of(context).pushReplacementNamed('/auth');
        break;
      case 'profile':
        Navigator.of(context).pushReplacementNamed('/home');
        // You can add additional logic to navigate to profile section
        break;
      default:
        print('Unknown deep link: $uri');
    }
  }

  void _initAuthListener() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((AuthState data) {
      final session = data.session;
      final event = data.event;

      // Navigate on login/logout changes
      if (session != null) {
        // Signed in or token refreshed
        if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
          final currentRoute = _navigatorKey.currentState?.context.mounted == true
              ? ModalRoute.of(_navigatorKey.currentState!.context)?.settings.name
              : null;
          if (currentRoute != '/home') {
            _navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
          }
        }
      } else {
        // Signed out
        if (event == AuthChangeEvent.signedOut || event == AuthChangeEvent.userDeleted) {
          final currentRoute = _navigatorKey.currentState?.context.mounted == true
              ? ModalRoute.of(_navigatorKey.currentState!.context)?.settings.name
              : null;
          if (currentRoute != '/auth') {
            _navigatorKey.currentState?.pushNamedAndRemoveUntil('/auth', (route) => false);
          }
        }
      }
    });
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaPet Mobile',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _mode,
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const OnboardingSplash(),
        '/onboarding': (context) => const OnboardingPage(),
        '/auth': (context) => const AuthPage(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignupPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/home': (context) => AuthWrapper(
          child: HomeShell(
            themeMode: _mode,
            onThemeModeChanged: _setThemeMode,
          ),
        ),
        '/media': (context) => const MediaHistoryPage(),
      },
    );
  }
}
