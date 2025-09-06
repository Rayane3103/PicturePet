class SupabaseConfig {
  static const String url = 'https://kjpycujguhmsvrcrznrw.supabase.co';
  static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqcHljdWpndWhtc3ZyY3J6bnJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTYyMjU2NzEsImV4cCI6MjA3MTgwMTY3MX0.iNhc3fihLlXpqn5c63niaPVAQMvWyooK1hibOm2-h6U';
  
  // OAuth redirect URLs - Use web URLs that Google/Facebook accept
  static const String oauthRedirectUrl = 'https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback';
  
  // Mobile app deep link scheme for handling OAuth completion
  static const String mobileAppScheme = 'io.supabase.flutter';
  static const String mobileAppCallback = 'io.supabase.flutter://login-callback/';
  
  // Deep link schemes for app navigation
  static const String appScheme = 'mediaus';
  
  // Universal link domain
  static const String universalLinkDomain = 'mediaus.app';
  
  // Get the OAuth redirect URL (web-based for Google/Facebook compatibility)
  static String getOAuthRedirectUrl() {
    return oauthRedirectUrl;
  }
  
  // Get mobile app callback URL for deep linking
  static String getMobileCallbackUrl() {
    return mobileAppCallback;
  }
}
