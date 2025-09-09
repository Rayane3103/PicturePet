import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // Prefer compile-time injection via --dart-define, fallback to .env via flutter_dotenv
  static const String _envUrlDefine = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _envAnonDefine = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
  static String get _envUrlDotenv {
    try {
      // late import via main.dart
      // ignore: avoid_dynamic_calls
      return (dotenv.env['SUPABASE_URL'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }
  static String get _envAnonDotenv {
    try {
      // ignore: avoid_dynamic_calls
      return (dotenv.env['SUPABASE_ANON_KEY'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  // Optional redirect URL from env
  static const String _envRedirectDefine = String.fromEnvironment('SUPABASE_REDIRECT_URL', defaultValue: '');
  static String get _envRedirectDotenv {
    try {
      // ignore: avoid_dynamic_calls
      return (dotenv.env['SUPABASE_REDIRECT_URL'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  // Fallbacks removed; values must come from --dart-define or .env
  static const String _fallbackUrl = '';
  static const String _fallbackAnon = '';

  // Public getters used by the app
  static String get url {
    if (_envUrlDefine.isNotEmpty) return _envUrlDefine;
    if (_envUrlDotenv.isNotEmpty) return _envUrlDotenv;
    return _fallbackUrl;
  }
  static String get anonKey {
    if (_envAnonDefine.isNotEmpty) return _envAnonDefine;
    if (_envAnonDotenv.isNotEmpty) return _envAnonDotenv;
    return _fallbackAnon;
  }

  // OAuth redirect URL (prefers env; falls back to derived from SUPABASE_URL)
  static String get oauthRedirectUrl {
    if (_envRedirectDefine.isNotEmpty) return _envRedirectDefine;
    if (_envRedirectDotenv.isNotEmpty) return _envRedirectDotenv;
    if (url.isNotEmpty) return '$url/auth/v1/callback';
    return '';
  }

  // Mobile app deep link scheme for handling OAuth completion
  static const String mobileAppScheme = 'io.supabase.flutter';
  static const String mobileAppCallback = 'io.supabase.flutter://login-callback/';

  // Deep link schemes for app navigation
  static const String appScheme = 'mediaus';

  // Universal link domain
  static const String universalLinkDomain = 'mediaus.app';

  // Additional secret placeholders (names only, values via dart-define)
  static const String analyticsApiKey = String.fromEnvironment('ANALYTICS_API_KEY', defaultValue: '');
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  static String getOAuthRedirectUrl() {
    return oauthRedirectUrl;
  }

  static String getMobileCallbackUrl() {
    return mobileAppCallback;
  }

  // Report which secret names are provided (never values)
  static Map<String, bool> secretsStatus() {
    return {
      'SUPABASE_URL': _envUrlDefine.isNotEmpty || _envUrlDotenv.isNotEmpty,
      'SUPABASE_ANON_KEY': _envAnonDefine.isNotEmpty || _envAnonDotenv.isNotEmpty,
      'SUPABASE_REDIRECT_URL': _envRedirectDefine.isNotEmpty || _envRedirectDotenv.isNotEmpty,
      'ANALYTICS_API_KEY': analyticsApiKey.isNotEmpty,
      'SENTRY_DSN': sentryDsn.isNotEmpty,
    };
  }
}
