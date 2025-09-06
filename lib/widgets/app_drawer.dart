import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import 'package:google_fonts/google_fonts.dart';

class AppDrawer extends StatelessWidget {
  final ThemeMode themeMode;
  final void Function(ThemeMode) onThemeChanged;
  final VoidCallback onNewProject;
  final VoidCallback onGoLibrary;
  final VoidCallback onGoProfile;

  const AppDrawer({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    required this.onNewProject,
    required this.onGoLibrary,
    required this.onGoProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.background(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(themeMode: themeMode),
            const SizedBox(height: 24),
            
            // Navigation items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _DrawerTile(
                    icon: Icons.collections_bookmark_outlined,
                    label: 'My Projects',
                    onTap: onGoLibrary,
                    isActive: true,
                  ),
                  const SizedBox(height: 8),
                  _DrawerTile(
                    icon: Icons.photo_library_outlined,
                    label: 'My Uploads',
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _DrawerTile(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    onTap: () {},
                  ),
                  const SizedBox(height: 8),
                  _DrawerTile(
                    icon: Icons.contact_support_rounded,
                    label: 'Contact Us',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
             Divider(color: AppColors.muted(context), height: 1),
            const SizedBox(height: 24),
            
            // Appearance section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AppearancePicker(
                    value: themeMode,
                    onChanged: onThemeChanged,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Divider(color: AppColors.muted(context), height: 1),
            const SizedBox(height: 24),
            
            // Account section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Account',
                    style: GoogleFonts.inter(
                      color: AppColors.secondaryText(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DrawerTile(
                    icon: Icons.logout_rounded,
                    label: 'Sign Out',
                    onTap: () => _showSignOutDialog(context),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Footer
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.muted(context).withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.pets,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PicturePet Pro',
                          style: GoogleFonts.inter(
                            color: AppColors.onBackground(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Free Trial',
                          style: GoogleFonts.inter(
                            color: AppColors.secondaryText(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'UPGRADE',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card(context),
        title: Text(
          'Sign Out',
          style: GoogleFonts.inter(
            color: AppColors.onBackground(context),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.inter(
            color: AppColors.secondaryText(context),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: AppColors.secondaryText(context),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _signOut(context);
            },
            child: Text(
              'Sign Out',
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

  void _signOut(BuildContext context) async {
    try {
      print('AppDrawer: Starting sign out process...');
      
      // Close the drawer first
      Navigator.of(context).pop();
      print('AppDrawer: Drawer closed');
      
      // Sign out from Supabase
      await AuthService().signOut();
      print('AppDrawer: Sign out completed, AuthWrapper should handle navigation');
      
      // The AuthWrapper will automatically handle navigation when auth state changes
      // No need to manually navigate - just close the drawer
      
    } catch (e) {
      print('AppDrawer: Sign out error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class _Header extends StatelessWidget {
  final ThemeMode themeMode;
  const _Header({required this.themeMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppGradients.primary,
        borderRadius: BorderRadius.circular(24),
        //boxShadow: [mediaPetShadow(context)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo section
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  //color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'PicturePet',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Professional AI Image Editor',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isActive;
  
  const _DrawerTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryPurple.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryPurple : AppColors.muted(context),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : AppColors.secondaryText(context),
            size: 20,
          ),
        ),
        title: Text(
          label,
          style: GoogleFonts.inter(
            color: isActive ? AppColors.primaryPurple : AppColors.onBackground(context),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _AppearancePicker extends StatelessWidget {
  final ThemeMode value;
  final void Function(ThemeMode) onChanged;
  const _AppearancePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget buildChip(IconData icon, String label, ThemeMode mode) {
      final selected = value == mode;
      return InkWell(
        onTap: () => onChanged(mode),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.primary : null,
            color: selected ? null : AppColors.muted(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? Colors.white : AppColors.secondaryText(context),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: selected ? Colors.white : AppColors.secondaryText(context),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: buildChip(Icons.wb_sunny_outlined, 'Light', ThemeMode.light)),
        const SizedBox(width: 8),
        Expanded(child: buildChip(Icons.nightlight_round, 'Dark', ThemeMode.dark)),
      ],
    );
  }
}


