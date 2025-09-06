import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatelessWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onModeChanged;

  const ProfilePage({super.key, required this.themeMode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: CustomScrollView(
        slivers: [
          // Header section
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(24),
                      //boxShadow: [mediaPetShadow(context)],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Center(
                            child: Text(
                              'RM',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 32,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rayane Moumine',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'rayane@mediapet.com',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  'Premium Member',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Stats section
                  Text(
                    'Account Statistics',
                    style: GoogleFonts.inter(
                      color: AppColors.onBackground(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.video_library,
                                color: AppColors.primaryPurple,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '24',
                                style: GoogleFonts.inter(
                                  color: AppColors.onBackground(context),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Projects',
                                style: GoogleFonts.inter(
                                  color: AppColors.secondaryText(context),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.card(context),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.eco,
                                color: AppColors.successGreen,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '9,625',
                                style: GoogleFonts.inter(
                                  color: AppColors.onBackground(context),
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                'Credits',
                                style: GoogleFonts.inter(
                                  color: AppColors.secondaryText(context),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Settings section
                  Text(
                    'Settings',
                    style: GoogleFonts.inter(
                      color: AppColors.onBackground(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryPurple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.palette,
                              color: AppColors.primaryPurple,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Appearance',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Customize your app theme',
                            style: GoogleFonts.inter(
                              color: AppColors.secondaryText(context),
                              fontSize: 14,
                            ),
                          ),
                          trailing: _buildThemeSelector(context),
                        ),
                        Divider(color: AppColors.muted(context), height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.notifications,
                              color: AppColors.primaryBlue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Notifications',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Manage your notifications',
                            style: GoogleFonts.inter(
                              color: AppColors.secondaryText(context),
                              fontSize: 14,
                            ),
                          ),
                          trailing: Switch(
                            value: true,
                            onChanged: (value) {},
                            activeColor: AppColors.primaryPurple,
                          ),
                        ),
                        Divider(color: AppColors.muted(context), height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.warningOrange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.security,
                              color: AppColors.warningOrange,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Privacy & Security',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Manage your privacy settings',
                            style: GoogleFonts.inter(
                              color: AppColors.secondaryText(context),
                              fontSize: 14,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: AppColors.secondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Support section
                  Text(
                    'Support',
                    style: GoogleFonts.inter(
                      color: AppColors.onBackground(context),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card(context),
                      borderRadius: BorderRadius.circular(16),
                    ),
        child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.infoBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.help,
                              color: AppColors.infoBlue,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Help Center',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Get help and support',
                            style: GoogleFonts.inter(
                              color: AppColors.secondaryText(context),
                              fontSize: 14,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: AppColors.secondaryText(context),
                          ),
                        ),
                        Divider(color: AppColors.muted(context), height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.feedback,
                              color: AppColors.successGreen,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            'Send Feedback',
                            style: GoogleFonts.inter(
                              color: AppColors.onBackground(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Help us improve MediaPet',
                            style: GoogleFonts.inter(
                              color: AppColors.secondaryText(context),
                              fontSize: 14,
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right,
                            color: AppColors.secondaryText(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildThemeSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
          _buildThemeChip(context, 'Light', ThemeMode.light, Icons.wb_sunny_outlined),
          const SizedBox(width: 4),
          _buildThemeChip(context, 'Dark', ThemeMode.dark, Icons.nightlight_round),
        ],
      ),
    );
  }
  
  Widget _buildThemeChip(BuildContext context, String label, ThemeMode mode, IconData icon) {
    final isSelected = themeMode == mode;
    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected ? AppGradients.primary : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.secondaryText(context),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: isSelected ? Colors.white : AppColors.secondaryText(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


