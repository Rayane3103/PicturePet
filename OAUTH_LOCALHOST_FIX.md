# 🔧 Fix OAuth Localhost Redirect Issue

## 🚨 **Problem: OAuth Redirects to Localhost**

When you try to sign up with Google, it redirects you to a localhost link and shows "This site can't be reached".

## 🔍 **Root Causes**

1. **Google Cloud Console** has wrong redirect URIs
2. **Supabase Dashboard** OAuth configuration is incorrect
3. **Mobile app** needs custom scheme redirects
4. **Redirect URL mismatch** between services

## 🛠️ **Solution: Step-by-Step Fix**

### **Step 1: Fix Google Cloud Console**

1. **Go to Google Cloud Console:**
   - Visit: `https://console.cloud.google.com/`
   - Select your project

2. **Update OAuth 2.0 Client ID:**
   - **APIs & Services** → **Credentials**
   - Click on your **OAuth 2.0 Client ID**
   - **Authorized redirect URIs** should include:
   ```
   https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback
   io.supabase.flutter://login-callback/
   ```

3. **Save changes**

### **Step 2: Fix Supabase Dashboard**

1. **Go to Supabase Dashboard:**
   - Visit: `https://supabase.com/dashboard`
   - Select project: `kjpycujguhmsvrcrznrw`

2. **Authentication Settings:**
   - **Authentication** → **URL Configuration**
   - **Site URL**: `https://kjpycujguhmsvrcrznrw.supabase.co`
   - **Redirect URLs**: 
   ```
   https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback
   io.supabase.flutter://login-callback/
   ```

3. **Google Provider Configuration:**
   - **Authentication** → **Providers** → **Google**
   - **Enable** if not already enabled
   - **Client ID**: [Your Google Client ID]
   - **Client Secret**: [Your Google Client Secret]
   - **Redirect URL**: `io.supabase.flutter://login-callback/`

### **Step 3: Verify Flutter App Configuration**

Your app is now configured to use:
```dart
// Mobile OAuth redirect
static const String mobileOAuthRedirect = 'io.supabase.flutter://login-callback/';
```

### **Step 4: Test the Fix**

1. **Clean and rebuild your app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Try Google sign-in again**
3. **Check console logs** for redirect URL being used

## 🔗 **Why This Fixes the Issue**

### **Before (Broken):**
- Google OAuth tried to redirect to localhost
- Supabase couldn't handle the callback
- User got "site can't be reached" error

### **After (Fixed):**
- Google OAuth redirects to `io.supabase.flutter://login-callback/`
- Flutter app handles the custom scheme
- Supabase processes the OAuth callback properly
- User gets authenticated successfully

## 📱 **Mobile OAuth Flow**

```
1. User taps "Continue with Google"
2. Flutter app calls Supabase OAuth
3. Supabase redirects to Google
4. User authenticates with Google
5. Google redirects to: io.supabase.flutter://login-callback/
6. Flutter app receives the callback
7. Supabase processes the authentication
8. User is logged in
```

## 🧪 **Testing Commands**

### **Test Deep Link (Android):**
```bash
adb shell am start -W -a android.intent.action.VIEW -d "io.supabase.flutter://login-callback/" com.example.media_us
```

### **Test Deep Link (iOS):**
```bash
xcrun simctl openurl booted "io.supabase.flutter://login-callback/"
```

## 🔍 **Debugging Steps**

### **1. Check Console Logs:**
```dart
// You should see:
print('Starting Google sign in...');
print('Using redirect URL: io.supabase.flutter://login-callback/');
print('Google sign in initiated');
```

### **2. Check Supabase Logs:**
- Go to Supabase Dashboard
- **Logs** → **API** or **Auth**
- Look for OAuth-related errors

### **3. Check Google Cloud Console:**
- Verify redirect URIs are correct
- Check if OAuth consent screen is configured

## 🚨 **Common Issues & Solutions**

### **Issue: Still redirecting to localhost**
**Solution:** Double-check Google Cloud Console redirect URIs

### **Issue: "Invalid redirect URI" error**
**Solution:** Ensure redirect URI matches exactly in both Google and Supabase

### **Issue: App not opening after OAuth**
**Solution:** Verify deep link configuration in AndroidManifest.xml and Info.plist

### **Issue: OAuth callback not working**
**Solution:** Check if Supabase provider is enabled and configured correctly

## 📋 **Checklist**

- [ ] Google Cloud Console redirect URIs updated
- [ ] Supabase Dashboard redirect URLs configured
- [ ] Google provider enabled in Supabase
- [ ] Flutter app using mobile OAuth redirect
- [ ] Deep links configured in platform files
- [ ] App rebuilt and tested
- [ ] OAuth flow working without localhost redirect

## 🎯 **Expected Result**

After implementing these fixes:
1. ✅ Google OAuth opens properly
2. ✅ User can select account
3. ✅ OAuth callback works correctly
4. ✅ User gets authenticated in your app
5. ✅ No more localhost redirect errors

## 🆘 **Still Having Issues?**

If the problem persists:
1. **Clear browser cache** and cookies
2. **Check network tab** in browser dev tools
3. **Verify all URLs** are exactly the same
4. **Test with a fresh browser session**
5. **Check Supabase project status**

---

**🎉 Goal:** OAuth working smoothly without localhost redirects!
