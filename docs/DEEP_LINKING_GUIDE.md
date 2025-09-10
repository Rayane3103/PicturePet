# Deep Linking Configuration Guide

## 🎯 Overview

This guide explains how deep linking is configured in your MediaPet Flutter app and how to test it.

## 🔗 Supported Deep Link Schemes

### **1. OAuth Callback URLs**
- **Primary**: `io.supabase.flutter://login-callback/`
- **Alternative**: `mediaus://login-callback`

### **2. Custom App Deep Links**
- **Home**: `mediaus://home`
- **Authentication**: `mediaus://auth`
- **Profile**: `mediaus://profile`
- **Project**: `mediaus://project/{projectId}`

### **3. Universal Links (iOS)**
- **Domain**: `https://mediaus.app`
- **Example**: `https://mediaus.app/project/123`

## 📱 Platform Configuration

### **Android (AndroidManifest.xml)**
```xml
<!-- OAuth callback for Supabase social auth -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="io.supabase.flutter" />
</intent-filter>

<!-- Alternative OAuth callback schemes -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="mediaus" />
</intent-filter>

<!-- Deep link for app-specific URLs -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" 
          android:host="mediaus.app" />
</intent-filter>
```

### **iOS (Info.plist)**
```xml
<!-- Deep Linking Configuration -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>io.supabase.flutter</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.flutter</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleURLName</key>
        <string>mediaus</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>mediaus</string>
        </array>
    </dict>
</array>

<!-- Associated Domains for Universal Links -->
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:mediaus.app</string>
</array>
```

## 🧪 Testing Deep Links

### **Method 1: ADB Commands (Android)**
```bash
# Test OAuth callback
adb shell am start -W -a android.intent.action.VIEW -d "io.supabase.flutter://login-callback/" com.example.media_us

# Test custom deep links
adb shell am start -W -a android.intent.action.VIEW -d "mediaus://home" com.example.media_us
adb shell am start -W -a android.intent.action.VIEW -d "mediaus://auth" com.example.media_us
adb shell am start -W -a android.intent.action.VIEW -d "mediaus://profile" com.example.media_us
adb shell am start -W -a android.intent.action.VIEW -d "mediaus://project/123" com.example.media_us
```

### **Method 2: iOS Simulator (iOS)**
```bash
# Test OAuth callback
xcrun simctl openurl booted "io.supabase.flutter://login-callback/"

# Test custom deep links
xcrun simctl openurl booted "mediaus://home"
xcrun simctl openurl booted "mediaus://auth"
xcrun simctl openurl booted "mediaus://profile"
xcrun simctl openurl booted "mediaus://project/123"
```

### **Method 3: Browser Testing**
1. Open a browser on your device
2. Navigate to: `mediaus://home`
3. The app should open and navigate to the home screen

### **Method 4: In-App Testing**
Use the `DeepLinkHelper.testDeepLinks()` method in your code:
```dart
import 'package:your_app/utils/deep_link_helper.dart';

// Test deep links
DeepLinkHelper.testDeepLinks();
```

## 🔧 OAuth Configuration

### **Google OAuth Setup**
1. **Google Cloud Console:**
   - Add redirect URI: `io.supabase.flutter://login-callback/`
   - Alternative: `mediaus://login-callback`

2. **Supabase Dashboard:**
   - Authentication → Providers → Google
   - Enable Google provider
   - Add Client ID and Client Secret

### **Facebook OAuth Setup**
1. **Facebook Developers:**
   - Add redirect URI: `io.supabase.flutter://login-callback/`

2. **Supabase Dashboard:**
   - Authentication → Providers → Facebook
   - Enable Facebook provider
   - Add App ID and App Secret

## 🚀 Implementation Details

### **Main App (main.dart)**
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  runApp(const MediaUsApp());
}
```

### **Deep Link Handling**
```dart
void _initDeepLinkHandling() {
  // Handle deep links when app is already running
  _linkSubscription = uriLinkStream.listen((Uri? uri) {
    if (uri != null) {
      _handleDeepLink(uri);
    }
  });

  // Handle deep link that opened the app
  getInitialUri().then((Uri? uri) {
    if (uri != null) {
      _handleDeepLink(uri);
    }
  });
}
```

### **Auth Service Integration**
```dart
Future<void> signInWithGoogle() async {
  await _supabase.auth.signInWithOAuth(
    Provider.google,
    redirectTo: 'io.supabase.flutter://login-callback/',
    queryParams: {
      'access_type': 'offline',
      'prompt': 'consent',
    },
  );
}
```

## 🔍 Debugging Deep Links

### **Enable Logging**
```dart
// In your deep link handler
void _handleDeepLink(Uri uri) {
  print('Deep link received: $uri');
  print('Scheme: ${uri.scheme}');
  print('Host: ${uri.host}');
  print('Path: ${uri.path}');
  print('Query parameters: ${uri.queryParameters}');
}
```

### **Common Issues**
1. **Deep link not working:**
   - Check if the scheme is correctly configured
   - Verify intent filters in AndroidManifest.xml
   - Check URL types in Info.plist

2. **OAuth callback not working:**
   - Verify redirect URI in Google/Facebook console
   - Check if provider is enabled in Supabase
   - Ensure deep link scheme matches exactly

3. **App not opening:**
   - Check if the app is installed
   - Verify the deep link format
   - Test with ADB or simulator first

## 📋 Testing Checklist

- [ ] Android deep links work with ADB
- [ ] iOS deep links work with simulator
- [ ] OAuth callback opens app correctly
- [ ] Custom deep links navigate to correct screens
- [ ] Deep links work when app is closed
- [ ] Deep links work when app is in background
- [ ] Deep links work when app is already open

## 🎉 Next Steps

After testing deep links:
1. **Customize navigation logic** for your specific needs
2. **Add analytics** to track deep link usage
3. **Implement universal links** for web-to-app navigation
4. **Add deep link validation** and error handling
5. **Create marketing materials** with deep link examples

---

## 🆘 Need Help?

If you encounter issues:
1. Check the console logs for error messages
2. Verify all configuration files are correct
3. Test with simple deep links first
4. Ensure all dependencies are properly installed
5. Check platform-specific requirements
