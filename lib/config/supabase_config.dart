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

  // Fallbacks (keep for local dev only). Do NOT use in production.
  static const String _fallbackUrl = 'https://kjpycujguhmsvrcrznrw.supabase.co';
  static const String _fallbackAnon = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqcHljdWpndWhtc3ZyY3J6bnJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYyMjU2NzEsImV4cCI6MjA3MTgwMTY3MX0.iNhc3fihLlXpqn5c63niaPVAQMvWyooK1hibOm2-h6U';

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

  // OAuth redirect URLs - Use web URLs that Google/Facebook accept
  static const String oauthRedirectUrl = 'https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback';

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
      'ANALYTICS_API_KEY': analyticsApiKey.isNotEmpty,
      'SENTRY_DSN': sentryDsn.isNotEmpty,
    };
  }
}
