import 'package:flutter/material.dart'; 
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ import for AuthException

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  void _handleSignup() async {
    print('Signup button pressed');

    if (!_formKey.currentState!.validate()) {
      print('Form validation failed');
      return;
    }

    if (!_agreeToTerms) {
      print('Terms not agreed to');
      return;
    }

    print('Starting signup process...');

    setState(() => _isLoading = true);

    try {
      final response = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
      );

      print('Signup response received: ${response.user != null ? 'User created' : 'No user'}');

      if (mounted) {
        setState(() => _isLoading = false);

        if (response.user != null && response.session != null) {
          print('Navigating to home page');
          Navigator.of(context).pushReplacementNamed('/home');
        } else {
          print('Showing email confirmation dialog');
          _showEmailConfirmationDialog();
        }
      }
    } on AuthException catch (e) {
      print('Supabase AuthException: ${e.message}');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog(_getErrorMessage(e.message));
      }
    } catch (e) {
      print('Unknown error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('An unexpected error occurred. Please try again.');
      }
    }
  }

  String _getErrorMessage(String error) {
    print('Processing error message: "$error"');

    final lower = error.toLowerCase();

    if (lower.contains('user already registered') ||
        lower.contains('already exists') ||
        lower.contains('duplicate key')) {
      return 'An account with this email already exists. Please try signing in instead.';
    }

    if (lower.contains('password')) {
      return 'Password must be at least 6 characters long.';
    }

    if (lower.contains('invalid email')) {
      return 'Please enter a valid email address.';
    }

    if (lower.contains('email not confirmed')) {
      return 'Please check your email and confirm your account.';
    }

    return error; // fallback
  }

  void _showErrorDialog(String message) {
    final isEmailExistsError = message.contains('already exists') ||
        message.contains('already registered');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        title: Text(
          isEmailExistsError ? 'Account Already Exists' : 'Signup Error',
          style: GoogleFonts.inter(
            color: AppColors.onBackground(context),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.inter(
                color: AppColors.secondaryText(context),
                fontSize: 14,
              ),
            ),
            if (isEmailExistsError) ...[
              const SizedBox(height: 16),
              Text(
                'Would you like to sign in instead?',
                style: GoogleFonts.inter(
                  color: AppColors.onBackground(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
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
          if (isEmailExistsError)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to auth page
              },
              child: Text(
                'Sign In',
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

  void _showEmailConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        title: Text(
          'Check Your Email',
          style: GoogleFonts.inter(
            color: AppColors.onBackground(context),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'We\'ve sent a confirmation link to ${_emailController.text.trim()}. Please check your email and click the link to verify your account.',
          style: GoogleFonts.inter(
            color: AppColors.secondaryText(context),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to auth page
            },
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
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with back button
              Row(
                mainAxisSize: MainAxisSize.min,
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
                    'Create Account',
                    style: GoogleFonts.inter(
                      color: AppColors.onBackground(context),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),

              const SizedBox(height: 32),

              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.pets, color: Colors.white, size: 40);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Join MediaPet!',
                style: GoogleFonts.inter(
                  color: AppColors.onBackground(context),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              Text(
                'Create your account to start editing photos',
                style: GoogleFonts.inter(
                  color: AppColors.secondaryText(context),
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // Signup form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Full Name
                        _buildInputField(
                          label: 'Full Name',
                          controller: _fullNameController,
                          hint: 'Enter your full name',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your full name';
                            }
                            if (value.trim().length < 2) {
                              return 'Name must be at least 2 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Email
                        _buildInputField(
                          label: 'Email',
                          controller: _emailController,
                          hint: 'example@mail.com',
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                .hasMatch(value.trim())) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Password
                        _buildPasswordField(
                          label: 'Password',
                          controller: _passwordController,
                          isVisible: _isPasswordVisible,
                          toggleVisibility: () =>
                              setState(() => _isPasswordVisible = !_isPasswordVisible),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Confirm Password
                        _buildPasswordField(
                          label: 'Confirm Password',
                          controller: _confirmPasswordController,
                          isVisible: _isConfirmPasswordVisible,
                          toggleVisibility: () => setState(() =>
                              _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Terms
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: _agreeToTerms
                                      ? AppColors.primaryPurple
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: _agreeToTerms
                                        ? AppColors.primaryPurple
                                        : AppColors.muted(context).withOpacity(0.5),
                                    width: 1,
                                  ),
                                ),
                                child: _agreeToTerms
                                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'I agree to the Terms of Service and Privacy Policy',
                                style: GoogleFonts.inter(
                                  color: AppColors.onBackground(context),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 32),

                        // Signup button
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
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed:
                                (!_agreeToTerms || _isLoading) ? null : _handleSignup,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Create Account',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Sign in link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: GoogleFonts.inter(
                                color: AppColors.secondaryText(context),
                                fontSize: 14,
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
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
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
              color: AppColors.onBackground(context),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: AppColors.mutedText(context),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isVisible,
    required VoidCallback toggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
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
            controller: controller,
            obscureText: !isVisible,
            style: GoogleFonts.inter(
              color: AppColors.onBackground(context),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: '•••••••••••',
              hintStyle: GoogleFonts.inter(
                color: AppColors.mutedText(context),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              suffixIcon: IconButton(
                onPressed: toggleVisibility,
                icon: Icon(
                  isVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.mutedText(context),
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}
