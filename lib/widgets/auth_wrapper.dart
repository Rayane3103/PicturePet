import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class AuthWrapper extends StatefulWidget {
  final Widget child;
  final Widget? loadingWidget;
  final Widget? unauthenticatedWidget;

  const AuthWrapper({
    super.key,
    required this.child,
    this.loadingWidget,
    this.unauthenticatedWidget,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Check current session
    _currentUser = _authService.currentUser;
    
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }

    // Listen to auth state changes
    _authService.authStateChanges.listen((data) {
      print('AuthWrapper: Auth state changed - Session: ${data.session != null}, User: ${data.session?.user?.id}');
      
      if (mounted) {
        setState(() {
          _currentUser = data.session?.user;
          _isLoading = false;
        });
        
        // If user signed out, navigate to auth page
        if (data.session == null && _currentUser == null) {
          print('AuthWrapper: User signed out, navigating to auth page');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.of(context).canPop()) {
              Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
            }
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ?? 
        Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.pets,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ],
            ),
          ),
        );
    }

    // If user is authenticated, show the main app
    if (_currentUser != null) {
      return widget.child;
    }

    // If user is not authenticated, navigate to auth page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
    });

    // Return loading while navigating
    return widget.loadingWidget ?? 
      Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pets,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      );
  }
}
