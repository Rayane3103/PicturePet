# Social Authentication Setup Guide

## Overview
This guide explains how to set up Google and Facebook OAuth authentication in your Supabase project.

## Prerequisites
- Supabase project already created
- Flutter app with social auth dependencies installed

## Step 1: Configure Google OAuth

### 1.1 Create Google OAuth Credentials
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google+ API
4. Go to "Credentials" → "Create Credentials" → "OAuth 2.0 Client IDs"
5. Choose "Web application"
6. Add authorized redirect URIs:
   - `https://[YOUR_PROJECT_REF].supabase.co/auth/v1/callback`
   - `io.supabase.flutter://login-callback/`
7. Copy the Client ID and Client Secret

### 1.2 Configure in Supabase
1. Go to your Supabase Dashboard
2. Navigate to Authentication → Providers
3. Enable Google provider
4. Enter your Google Client ID and Client Secret
5. Save changes

## Step 2: Configure Facebook OAuth

### 2.1 Create Facebook App
1. Go to [Facebook Developers](https://developers.facebook.com/)
2. Create a new app
3. Add Facebook Login product
4. Go to Facebook Login → Settings
5. Add Valid OAuth Redirect URIs:
   - `https://[YOUR_PROJECT_REF].supabase.co/auth/v1/callback`
6. Copy the App ID and App Secret

### 2.2 Configure in Supabase
1. In your Supabase Dashboard
2. Navigate to Authentication → Providers
3. Enable Facebook provider
4. Enter your Facebook App ID and App Secret
5. Save changes

## Step 3: Update Supabase URL Configuration

Make sure your Supabase project URL is correctly set in:
```dart
// lib/config/supabase_config.dart
class SupabaseConfig {
  static const String url = 'https://[YOUR_PROJECT_REF].supabase.co';
  static const String anonKey = '[YOUR_ANON_KEY]';
}
```

## Step 4: Test Social Authentication

1. Run your Flutter app
2. Go to the auth page
3. Tap "Continue with Google" or "Continue with Facebook"
4. Complete the OAuth flow
5. Verify you're redirected back to the app and authenticated

## Troubleshooting

### Common Issues:
1. **"Invalid redirect URI"**: Check that your redirect URIs match exactly in both Google/Facebook and Supabase
2. **"Provider not enabled"**: Ensure the provider is enabled in Supabase Authentication → Providers
3. **"App not verified"**: For production, you may need to verify your app with Google/Facebook

### Testing:
- Use test accounts during development
- Check Supabase logs for authentication errors
- Verify OAuth callback URLs are correct

## Security Notes

- Never commit OAuth secrets to version control
- Use environment variables for production
- Regularly rotate OAuth credentials
- Monitor authentication logs for suspicious activity

## Next Steps

After successful setup:
1. Test both providers work correctly
2. Customize the OAuth flow if needed
3. Add error handling for edge cases
4. Consider adding additional providers (Apple, GitHub, etc.)
