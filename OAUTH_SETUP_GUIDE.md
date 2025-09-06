# OAuth Configuration Guide - MediaPet

## 🎯 **Problème résolu : Redirection non valide**

L'erreur "Redirection non valide : l'URI doit se terminer par une extension de domaine public de premier niveau" a été corrigée en utilisant des URLs de redirection valides.

## 🔗 **URLs de redirection corrigées**

### **URLs valides à utiliser :**
```
https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback
```

### **URLs à NE PAS utiliser (invalides) :**
```
❌ io.supabase.flutter://login-callback/
❌ mediaus://login-callback
```

## 🔧 **Configuration étape par étape**

### **Étape 1 : Configuration Supabase Dashboard**

1. **Aller dans Supabase Dashboard :**
   - Visitez : `https://supabase.com/dashboard`
   - Sélectionnez votre projet : `kjpycujguhmsvrcrznrw`

2. **Configurer l'URL de redirection :**
   - **Authentication** → **URL Configuration**
   - **Site URL** : `https://kjpycujguhmsvrcrznrw.supabase.co`
   - **Redirect URLs** : `https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback`

### **Étape 2 : Configuration Google OAuth**

1. **Dans Supabase Dashboard :**
   - **Authentication** → **Providers** → **Google**
   - Cliquer sur **Enable**
   - **Client ID** : [Votre Google Client ID]
   - **Client Secret** : [Votre Google Client Secret]
   - **Redirect URL** : `https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback`

2. **Dans Google Cloud Console :**
   - Aller dans **APIs & Services** → **Credentials**
   - Modifier votre **OAuth 2.0 Client ID**
   - **Authorized redirect URIs** : 
     ```
     https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback
     ```

### **Étape 3 : Configuration Facebook OAuth**

1. **Dans Supabase Dashboard :**
   - **Authentication** → **Providers** → **Facebook**
   - Cliquer sur **Enable**
   - **App ID** : [Votre Facebook App ID]
   - **App Secret** : [Votre Facebook App Secret]
   - **Redirect URL** : `https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback`

2. **Dans Facebook Developers :**
   - Aller dans votre app Facebook
   - **Facebook Login** → **Settings**
   - **Valid OAuth Redirect URIs** :
     ```
     https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback
     ```

## 🚀 **Test de l'authentification**

### **1. Tester Google OAuth :**
```bash
# Dans votre app Flutter
# Appuyer sur "Continue with Google"
# Vérifier que vous êtes redirigé vers Google
# Après authentification, vous devriez être redirigé vers Supabase
# Puis automatiquement connecté dans votre app
```

### **2. Vérifier les logs :**
```dart
// Dans votre console Flutter
print('Starting Google sign in...');
print('Google sign in initiated');
// Pas d'erreur de redirection
```

### **3. Vérifier l'état d'authentification :**
```dart
final user = Supabase.instance.client.auth.currentUser;
if (user != null) {
  print('✅ Utilisateur connecté : ${user.email}');
} else {
  print('❌ Aucun utilisateur connecté');
}
```

## 🔍 **Dépannage**

### **Erreur : "Provider is not enabled"**
- Vérifier que Google/Facebook est activé dans Supabase
- Vérifier que les credentials sont corrects

### **Erreur : "Invalid redirect URI"**
- Vérifier que l'URL de redirection est exactement :
  ```
  https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback
  ```

### **Erreur : "OAuth callback failed"**
- Vérifier la configuration dans Google Cloud Console
- Vérifier que l'API Google+ est activée

### **L'utilisateur n'est pas connecté après OAuth**
- Vérifier les logs Supabase
- Vérifier que la redirection fonctionne
- Vérifier la configuration des URLs

## 📱 **Configuration de l'app Flutter**

### **Fichier de configuration :**
```dart
// lib/config/supabase_config.dart
class SupabaseConfig {
  static const String url = 'https://kjpycujguhmsvrcrznrw.supabase.co';
  static const String anonKey = 'your-anon-key';
  static const String oauthRedirectUrl = 'https://kjpycujguhmsvrcrznrw.supabase.co/auth/v1/callback';
}
```

### **Service d'authentification :**
```dart
// lib/services/auth_service.dart
Future<void> signInWithGoogle() async {
  await _supabase.auth.signInWithOAuth(
    Provider.google,
    redirectTo: SupabaseConfig.oauthRedirectUrl,
    queryParams: {
      'access_type': 'offline',
      'prompt': 'consent',
    },
  );
}
```

## 🎉 **Avantages de cette approche**

✅ **URLs de redirection valides** (pas d'erreur de domaine)  
✅ **Configuration centralisée** dans Supabase  
✅ **Gestion automatique** des callbacks OAuth  
✅ **Sécurité renforcée** avec des URLs HTTPS  
✅ **Compatibilité** avec tous les navigateurs  

## 📋 **Checklist de configuration**

- [ ] URLs de redirection configurées dans Supabase
- [ ] Google OAuth activé avec bonnes credentials
- [ ] Facebook OAuth activé avec bonnes credentials
- [ ] URLs de redirection mises à jour dans Google Cloud Console
- [ ] URLs de redirection mises à jour dans Facebook Developers
- [ ] App Flutter testée avec OAuth
- [ ] Utilisateur connecté après authentification

## 🆘 **Besoin d'aide ?**

Si vous rencontrez encore des problèmes :
1. Vérifiez que toutes les URLs de redirection sont identiques
2. Vérifiez que les providers sont activés dans Supabase
3. Vérifiez les logs dans la console Flutter
4. Vérifiez les logs dans Supabase Dashboard

---

**🎯 Objectif :** OAuth Google et Facebook fonctionnels avec redirection automatique vers votre app !
