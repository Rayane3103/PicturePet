import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:async';
import 'dart:io';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
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

  @override
  void initState() {
    super.initState();
    _checkPlatform();
    _initDeepLinkHandling();
    _initMobileOAuth();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    MobileOAuthHandler.dispose();
    super.dispose();
  }

  void _checkPlatform() {
    try {
      _isMobilePlatform = Platform.isAndroid || Platform.isIOS;
      print('Platform detected: ${_isMobilePlatform ? "Mobile" : "Web"}');
    } catch (e) {
      _isMobilePlatform = false;
      print('Platform detected: Web (Platform.isAndroid/iOS not available)');
    }
  }

  void _initDeepLinkHandling() {
    if (!_isMobilePlatform) {
      print('Deep link handling: Not initializing on web platform');
      return;
    }
    
    try {
      // Handle deep links when app is already running
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
      
      print('Deep link handling initialized successfully');
    } catch (e) {
      print('Error initializing deep link handling: $e');
    }
  }

  void _initMobileOAuth() {
    // Initialize mobile OAuth handler (will check platform internally)
    MobileOAuthHandler.initialize();
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

  void _setThemeMode(ThemeMode mode) {
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediaPet Mobile',
      debugShowCheckedModeBanner: false,
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
      },
    );
  }
}
