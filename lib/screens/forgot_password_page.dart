import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _handleResetPassword() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _authService.resetPassword(_emailController.text.trim());
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _emailSent = true;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showErrorDialog(_getErrorMessage(e.toString()));
        }
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('User not found')) {
      return 'No account found with this email address.';
    } else if (error.contains('Too many requests')) {
      return 'Too many password reset attempts. Please try again later.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        title: Text(
          'Reset Password Error',
          style: GoogleFonts.inter(
            color: AppColors.onBackground(context),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(
            color: AppColors.secondaryText(context),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                color: AppColors.primaryPurple,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_emailSent) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              return SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 24 + bottomInset,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
              children: [
                // Header with back button
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: AppColors.onBackground(context),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Check Your Email',
                      style: GoogleFonts.inter(
                        color: AppColors.onBackground(context),
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 48), // Balance the header
                  ],
                ),
                
                const Spacer(),
                
                // Success icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                Text(
                  'Reset Link Sent!',
                  style: GoogleFonts.inter(
                    color: AppColors.onBackground(context),
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  'We\'ve sent a password reset link to:',
                  style: GoogleFonts.inter(
                    color: AppColors.secondaryText(context),
                    fontSize: 16,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.muted(context).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _emailController.text.trim(),
                    style: GoogleFonts.inter(
                      color: AppColors.primaryPurple,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Text(
                  'Please check your email and click the link to reset your password. If you don\'t see it, check your spam folder.',
                  style: GoogleFonts.inter(
                    color: AppColors.secondaryText(context),
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const Spacer(),
                
                // Back to login button
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
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Back to Login',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + bottomInset,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
            children: [
              // Header with back button
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_rounded,
                      color: AppColors.onBackground(context),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Reset Password',
                    style: GoogleFonts.inter(
                      color: AppColors.onBackground(context),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance the header
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Logo and welcome text
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.pets,
                      color: Colors.white,
                      size: 40,
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Forgot Password?',
                style: GoogleFonts.inter(
                  color: AppColors.onBackground(context),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: GoogleFonts.inter(
                  color: AppColors.secondaryText(context),
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 40),
              
              // Reset password form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email',
                          style: GoogleFonts.inter(
                            color: AppColors.onBackground(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.muted(context).withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'example@mail.com',
                              hintStyle: GoogleFonts.inter(
                                color: AppColors.mutedText(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Reset password button
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
                        onPressed: _isLoading ? null : _handleResetPassword,
                        child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Send Reset Link',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Back to login link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Remember your password? ',
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryText(context),
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Sign in',
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
          },
        ),
      ),
    );
  }
}
