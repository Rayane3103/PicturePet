import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      image: 'assets/images/onboarding_1.png',
      title: 'Edit your images simply in just one click',
      description: 'Transform your images with powerful AI tools. No complex editing required - just select and let our AI do the magic.',
      icon: Icons.auto_fix_high_rounded,
    ),
    OnboardingStep(
      image: 'assets/images/onboarding_2.png',
      title: 'Unleash your creativity with AI toolbox',
      description: 'Access cutting-edge AI tools for video editing, scene generation, and creative transformations.',
      icon: Icons.psychology_rounded,
    ),
    OnboardingStep(
      image: 'assets/images/onboarding_3.png',
      title: 'Professional results in minutes',
      description: 'Get studio-quality images edits without the learning curve. Perfect for creators, marketers, and professionals.',
      icon: Icons.star_rounded,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  void _skipOnboarding() {
    Navigator.of(context).pushReplacementNamed('/auth');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: Icon(
                        Icons.arrow_back_ios_rounded,
                        color: AppColors.onBackground(context),
                      ),
                    ),
                  if (_currentPage > 0) const Spacer(),
                  Text(
                    'Welcome to PicturePet',
                    style: GoogleFonts.inter(
                      color: AppColors.onBackground(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_currentPage == 0)
                    IconButton(
                      onPressed: _skipOnboarding,
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.onBackground(context),
                      ),
                    ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  return _buildStep(_steps[index]);
                },
              ),
            ),

            // Bottom navigation
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Page indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _steps.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index == _currentPage
                              ? AppColors.primaryPurple
                              : AppColors.muted(context),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Navigation buttons
                  Row(
                    children: [
                      if (_currentPage < _steps.length - 1) ...[
                        Expanded(
                          child: Container(
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.muted(context),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TextButton(
                              onPressed: _skipOnboarding,
                              child: Text(
                                'Skip',
                                style: GoogleFonts.inter(
                                  color: AppColors.onBackground(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Container(
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
                            onPressed: _nextPage,
                            child: Text(
                              _currentPage < _steps.length - 1 ? 'Next' : 'Get Started',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
                     // App logo with gradient background
           Container(
             width: 200,
             height: 200,
             decoration: BoxDecoration(
               gradient: AppGradients.primary,
               borderRadius: BorderRadius.circular(24),
               boxShadow: [
                 BoxShadow(
                   color: AppColors.primaryPurple.withOpacity(0.2),
                   blurRadius: 30,
                   spreadRadius: 0,
                   offset: const Offset(0, 15),
                 ),
               ],
             ),
             child: Padding(
               padding: const EdgeInsets.all(40),
               child: Image.asset(
                 'assets/images/app_logo.png',
                 width: 120,
                 height: 120,
                 fit: BoxFit.contain,
                 errorBuilder: (context, error, stackTrace) {
                   return Icon(
                     step.icon,
                     color: Colors.white,
                     size: 80,
                   );
                 },
               ),
             ),
           ),
          
          const SizedBox(height: 48),
          
          // Title
          Text(
            step.title,
            style: GoogleFonts.inter(
              color: AppColors.onBackground(context),
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Description
          Text(
            step.description,
            style: GoogleFonts.inter(
              color: AppColors.secondaryText(context),
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class OnboardingStep {
  final String image;
  final String title;
  final String description;
  final IconData icon;

  OnboardingStep({
    required this.image,
    required this.title,
    required this.description,
    required this.icon,
  });
}
