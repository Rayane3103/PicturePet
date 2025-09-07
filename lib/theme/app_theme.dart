import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // MediaPet Design System Colors
  static const Color primaryPurple = Color(0xFF6366F1); // Deep purple
  static const Color primaryBlue = Color(0xFF4A90E2); // Bright blue
  static const Color accentPurple = Color(0xFF8B5CF6); // Lighter purple
  static const Color accentBlue = Color(0xFF60A5FA); // Lighter blue

  // Dark theme colors (MediaPet style)
  static const Color darkBackground = Color(0xFF1A1A2E); // Deep dark purple-blue
  static const Color darkSurface = Color(0xFF2C2C4A); // Slightly lighter surface
  static const Color darkMuted = Color(0xFF3F3F5F); // Muted accent
  static const Color darkCard = Color(0xFF2A2A3E); // Card background

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF); // White text
  static const Color textSecondary = Color(0xFFE2E8F0); // Light gray text
  static const Color textMuted = Color(0xFF94A3B8); // Muted text

  // Accent colors
  static const Color successGreen = Color(0xFF10B981); // Green for credits
  static const Color warningOrange = Color(0xFFF59E0B); // Orange for premium features
  static const Color infoBlue = Color(0xFF3B82F6); // Info blue

  // Light theme colors (based on MediaPet design)
  static const Color lightBackground = Color(0xFFF8FAFC); // Cool light blue-grey background
  static const Color lightCard = Colors.white; // Pure white for cards
  static const Color lightMuted = Color(0xFFE0E7FF); // Light indigo tint for muted areas
  static const Color lightSurface = Color(0xFFF1F5F9); // Slightly darker surface
  static const Color lightSelected = Color(0xFFEEF2FF); // Very light indigo for selected states

  // Theme-aware helper methods
  static Color background(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBackground
        : const Color.fromARGB(255, 244, 245, 247);
  }

  static Color surface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color card(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : lightCard;
  }

  static Color muted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkMuted
        : lightMuted;
  }

  static Color selectedBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryPurple.withOpacity(0.2)
        : lightSelected;
  }

  static Color onBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : const Color(0xFF222222); // Dark grey/black for better contrast
  }

  static Color onSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : Colors.black87;
  }

  static Color onCard(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textPrimary
        : Colors.black87;
  }

  static Color secondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textSecondary
        : const Color(0xFF666666); // Medium-dark grey for better readability
  }

  static Color mutedText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? textMuted
        : const Color(0xFF94A3B8); // Medium-light grey for muted text
  }
}

class AppGradients {
  AppGradients._();

  // MediaPet signature gradient - Enhanced with three colors
  static LinearGradient primary = const LinearGradient(
    colors: [
      Color.fromARGB(255, 161, 92, 246),    // Light purple
      AppColors.primaryPurple,   // Deep purple (middle)
      AppColors.primaryBlue,     // Bright blue
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Alternative gradients
  static LinearGradient purpleToPink = const LinearGradient(
    colors: [AppColors.primaryPurple, Color(0xFFEC4899)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static LinearGradient blueToPurple = const LinearGradient(
    colors: [AppColors.primaryBlue, AppColors.primaryPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // New beautiful three-color gradients
  static LinearGradient vibrant = const LinearGradient(
    colors: [
      AppColors.primaryPurple,
      Color(0xFFE91E63), // Vibrant pink
      AppColors.accentBlue,
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient sunset = const LinearGradient(
    colors: [
      AppColors.primaryPurple,
      Color(0xFFFF6B35), // Vibrant orange
      AppColors.primaryBlue,
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTheme {
  AppTheme._();

  static const double cornerRadius = 16; // MediaPet uses 16px radius
  static const double cardCornerRadius = 12; // Smaller radius for cards

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryPurple,
      brightness: Brightness.light,
      primary: AppColors.primaryPurple,
      secondary: AppColors.primaryBlue,
      surface: AppColors.lightSurface,
      onSurface: const Color(0xFF222222),
      onBackground: const Color(0xFF222222),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
             scaffoldBackgroundColor: AppColors.lightBackground,
      cardColor: AppColors.lightCard,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: GoogleFonts.interTextTheme().copyWith(
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF222222)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF222222)),
        titleLarge: GoogleFonts.inter(color: const Color(0xFF222222)),
        titleMedium: GoogleFonts.inter(color: const Color(0xFF222222)),
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
      bottomAppBarTheme: BottomAppBarTheme(color: AppColors.lightCard),
             cardTheme: CardTheme(
         color: AppColors.lightCard,
         elevation: 1,
         margin: const EdgeInsets.all(0),
         shadowColor: const Color(0xFF64748B).withOpacity(0.08),
         shape: RoundedRectangleBorder(
           borderRadius: BorderRadius.circular(cardCornerRadius),
         ),
       ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
        ),
      ),
      tabBarTheme: TabBarTheme(
        indicator: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF666666),
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryPurple,
      brightness: Brightness.dark,
      primary: AppColors.primaryPurple,
      secondary: AppColors.primaryBlue,
      surface: AppColors.darkBackground,
      onSurface: AppColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkCard,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      textTheme: GoogleFonts.interTextTheme(
        ThemeData.dark().textTheme,
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      bottomAppBarTheme: BottomAppBarTheme(color: AppColors.darkSurface),
      cardTheme: CardTheme(
        color: AppColors.darkCard,
        elevation: 0,
        margin: const EdgeInsets.all(0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardCornerRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cornerRadius),
          ),
        ),
      ),
      tabBarTheme: TabBarTheme(
        indicator: BoxDecoration(
          gradient: AppGradients.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(cornerRadius),
          borderSide: const BorderSide(color: AppColors.primaryPurple, width: 2),
        ),
        hintStyle: TextStyle(color: AppColors.textMuted),
        labelStyle: TextStyle(color: AppColors.textSecondary),
      ),
    );
  }
}

BoxShadow softShadow(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxShadow(
    color: (isDark ? Colors.black : Colors.black12).withOpacity(isDark ? 0.4 : 0.08),
    blurRadius: 2,
    spreadRadius: 2,
    offset: const Offset(2, 2),
  );
}

// MediaPet specific shadows
BoxShadow mediaPetShadow(BuildContext context) {
  return BoxShadow(
    color: Colors.black.withOpacity(0.25),
    blurRadius: 20,
    spreadRadius: 0,
    offset: const Offset(0, 8),
  );
}


