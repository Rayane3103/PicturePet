import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isSignIn = true;
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              
              // Logo and app name
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                  // boxShadow: [
                  //   BoxShadow(
                  //     color: AppColors.primaryPurple.withOpacity(0.3),
                  //     blurRadius: 30,
                  //     spreadRadius: 0,
                  //     offset: const Offset(0, 15),
                  //   ),
                  // ],
                ),
                                 child: Image.asset(
                   'assets/images/logo.png',
                   width: 80,
                   height: 80,
                   fit: BoxFit.contain,
                   errorBuilder: (context, error, stackTrace) {
                     return const Icon(
                       Icons.pets,
                       color: Colors.white,
                       size: 50,
                     );
                   },
                 ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'PicturePet',
                style: GoogleFonts.inter(
                  color: AppColors.onBackground(context),
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              
              const SizedBox(height: 8),
              
              Text(
                _isSignIn 
                    ? 'Welcome back! Let\'s dive into your account!'
                    : 'Join us! Create your account to get started!',
                style: GoogleFonts.inter(
                  color: AppColors.secondaryText(context),
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 48),
              
                                                                                                                       // Social login buttons
                 _buildSocialButton(
                   icon: 'assets/images/google.png',
                   text: 'Continue with Google',
                   onTap: _handleGoogleSignIn,
                 ),
                 
                 const SizedBox(height: 16),
                 
                 _buildSocialButton(
                   icon: 'assets/images/apple.png',
                   text: 'Continue with Apple',
                   onTap: () {},
                 ),
                 
                 const SizedBox(height: 16),
                 
                 _buildSocialButton(
                   icon: 'assets/images/facebook.png',
                   text: 'Continue with Facebook',
                   onTap: _handleFacebookSignIn,
                 ),
               
               const SizedBox(height: 16),
               
              
              
              const SizedBox(height: 32),
              
              // Divider
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.muted(context),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: GoogleFonts.inter(
                        color: AppColors.secondaryText(context),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: AppColors.muted(context),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Main action button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPurple.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 0,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                                 child: TextButton(
                   onPressed: () {
                     if (_isSignIn) {
                       Navigator.of(context).pushNamed('/login');
                     } else {
                       Navigator.of(context).pushNamed('/signup');
                     }
                   },
                  child: Text(
                    _isSignIn ? 'Sign in with password' : 'Create account',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Toggle between sign in and sign up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignIn ? 'Don\'t have an account? ' : 'Already have an account? ',
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryText(context),
                      fontSize: 14,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSignIn = !_isSignIn;
                      });
                    },
                    child: Text(
                      _isSignIn ? 'Sign up' : 'Sign in',
                      style: GoogleFonts.inter(
                        color: AppColors.primaryPurple,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.muted(context).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                                                                   // Social media icon
                  Container(
                    width: 30,
                    height: 30,
                   
                                         child: ClipRRect(
                       borderRadius: BorderRadius.circular(6),
                       child: icon.startsWith('assets/') 
                         ? Image.asset(
                             icon,
                             width: 30,
                             height: 30,
                             fit: BoxFit.contain,
                             errorBuilder: (context, error, stackTrace) {
                               return Container(
                                 width: 24,
                                 height: 24,
                                 decoration: BoxDecoration(
                                   color: AppColors.muted(context),
                                   borderRadius: BorderRadius.circular(6),
                                 ),
                                 child: Icon(
                                   Icons.account_circle_rounded,
                                   color: AppColors.onBackground(context),
                                   size: 16,
                                 ),
                               );
                             },
                           )
                         : Image.network(
                             icon,
                             width: 24,
                             height: 24,
                             fit: BoxFit.contain,
                             loadingBuilder: (context, child, loadingProgress) {
                               if (loadingProgress == null) return child;
                               return Container(
                                 width: 24,
                                 height: 24,
                                 decoration: BoxDecoration(
                                   color: AppColors.muted(context),
                                   borderRadius: BorderRadius.circular(6),
                                 ),
                                 child: const Center(
                                   child: SizedBox(
                                     width: 12,
                                     height: 12,
                                     child: CircularProgressIndicator(
                                       strokeWidth: 2,
                                       valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                     ),
                                   ),
                                 ),
                               );
                             },
                             errorBuilder: (context, error, stackTrace) {
                               return Container(
                                 width: 24,
                                 height: 24,
                                 decoration: BoxDecoration(
                                   color: AppColors.muted(context),
                                   borderRadius: BorderRadius.circular(6),
                                 ),
                                 child: Icon(
                                   Icons.account_circle_rounded,
                                   color: AppColors.onBackground(context),
                                   size: 16,
                                 ),
                               );
                             },
                           ),
                     ),
                  ),
                
                const SizedBox(width: 16),
                
                Text(
                  text,
                  style: GoogleFonts.inter(
                    color: AppColors.onBackground(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const Spacer(),
                
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.secondaryText(context),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Handle Google sign in
  void _handleGoogleSignIn() async {
    try {
      await _authService.signInWithGoogle();
      // The AuthWrapper will handle navigation when auth state changes
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle Facebook sign in
  void _handleFacebookSignIn() async {
    try {
      await _authService.signInWithFacebook();
      // The AuthWrapper will handle navigation when auth state changes
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facebook sign in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
