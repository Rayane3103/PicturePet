import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OnboardingSplash extends StatefulWidget {
  const OnboardingSplash({super.key});

  @override
  State<OnboardingSplash> createState() => _OnboardingSplashState();
}

class _OnboardingSplashState extends State<OnboardingSplash>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();

    // Decide next screen after short splash
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo with animation
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Center(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          shape: BoxShape.circle,
                          // boxShadow: [
                          //   BoxShadow(
                          //     color: AppColors.primaryPurple.withOpacity(0.3),
                          //     blurRadius: 30,
                          //     spreadRadius: 0,
                          //     offset: const Offset(0, 10),
                          //   ),
                          // ],
                        ),
                        child: Center(
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 100,
                            height: 100,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.pets,
                                color: Colors.white,
                                size: 60,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 32),
            
            // App name
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'MediaPet',
                style: GoogleFonts.inter(
                  color: AppColors.onBackground(context),
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Tagline
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'Professional AI Image Editor',
                style: GoogleFonts.inter(
                  color: AppColors.secondaryText(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
SizedBox(height: 200,)    ,        
            // Loading spinner
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  strokeWidth: 5,
                ),
              ),
            ),
            
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}
