import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cozy Theme Configuration
/// Inspired by warm, inviting illustration aesthetics with soft creams,
/// golden ambers, deep navy blues, and muted sage greens.

class CozyColors {
  CozyColors._();

  // Primary palette - Warm Amber/Golden (like the scarf and sunlight)
  static const Color primary = Color(0xFFD4915C); // Warm amber
  static const Color primaryLight = Color(0xFFE8B88C); // Light golden
  static const Color primaryDark = Color(0xFFB87333); // Deep copper
  static const Color navigationIndicator = Color(0xFFAD7F51); // Elegant brown

  // Secondary/Accent - Deep Navy Blue (like the mug and plant pot)
  static const Color accent = Color(0xFF2D3B54); // Deep navy
  static const Color accentLight = Color(0xFF4A5B78); // Lighter navy
  static const Color accentDark = Color(0xFF1A2438); // Very dark navy

  // Success/Aligned - Muted Sage Green (like the plant leaves)
  static const Color success = Color(0xFF6B8E6B); // Sage green
  static const Color successLight = Color(0xFF8FB18F); // Light sage
  static const Color successDark = Color(0xFF4A6B4A); // Dark sage

  // Warning/Neutral - Soft Gold
  static const Color warning = Color(0xFFE5C07B); // Soft gold
  static const Color warningLight = Color(0xFFF0D9A8); // Light gold
  static const Color warningDark = Color(0xFFC9A55D); // Deep gold

  // Error/Misaligned - Muted Terracotta
  static const Color error = Color(0xFFBD6B5B); // Terracotta
  static const Color errorLight = Color(0xFFD49586); // Light terracotta
  static const Color errorDark = Color(0xFF9A4F40); // Dark terracotta

  // Neutrals - Warm Creams (like the walls and background)
  static const Color background = Color(0xFFFDF8F3); // Warm cream
  static const Color surface = Color(0xFFFFFAF5); // Light cream white
  static const Color surfaceVariant = Color(0xFFF5EDE4); // Soft beige
  static const Color onBackground = Color(0xFF3D3129); // Warm dark brown
  static const Color onSurface = Color(0xFF4A4038); // Medium brown
  static const Color onSurfaceVariant = Color(0xFF8B7D6B); // Muted brown
  static const Color outline = Color(0xFFE8DFD4); // Beige outline

  // Dark mode colors - Cozy Evening palette
  static const Color backgroundDark = Color(0xFF2A2520); // Dark warm brown
  static const Color surfaceDark = Color(0xFF3A342E); // Medium dark brown
  static const Color surfaceVariantDark = Color(0xFF4A433C); // Lighter brown
  static const Color onBackgroundDark = Color(0xFFF5EDE4); // Light cream
  static const Color onSurfaceDark = Color(0xFFE8DFD4); // Soft beige
  static const Color outlineDark = Color(0xFF5A524A); // Brown outline
}

class CozyTypography {
  CozyTypography._();

  // Using 'Nunito' for a soft, friendly, cozy feel
  static TextStyle get displayLarge => GoogleFonts.nunito(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.1,
  );

  static TextStyle get displayMedium => GoogleFonts.nunito(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get displaySmall => GoogleFonts.nunito(
    fontSize: 30,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
  );

  static TextStyle get headlineLarge => GoogleFonts.nunito(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.2,
  );

  static TextStyle get headlineMedium => GoogleFonts.nunito(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static TextStyle get headlineSmall => GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static TextStyle get titleLarge => GoogleFonts.nunito(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static TextStyle get titleMedium => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static TextStyle get titleSmall => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static TextStyle get bodyLarge => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.5,
  );

  static TextStyle get labelLarge => GoogleFonts.nunito(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static TextStyle get labelMedium => GoogleFonts.nunito(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static TextStyle get labelSmall => GoogleFonts.nunito(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    height: 1.4,
  );
}

class CozyTheme {
  CozyTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: CozyColors.primary,
        onPrimary: Colors.white,
        primaryContainer: CozyColors
            .navigationIndicator, // Darker brown for navigation indicator
        onPrimaryContainer: Colors.white,
        secondary: CozyColors.accent,
        onSecondary: Colors.white,
        secondaryContainer: CozyColors.accentLight,
        onSecondaryContainer: Colors.white,
        tertiary: CozyColors.success,
        onTertiary: Colors.white,
        error: CozyColors.error,
        onError: Colors.white,
        surface: CozyColors.surface,
        onSurface: CozyColors.onSurface,
        surfaceContainerHighest: CozyColors.surfaceVariant,
        onSurfaceVariant: CozyColors.onSurfaceVariant,
        outline: CozyColors.outline,
      ),
      scaffoldBackgroundColor: CozyColors.background,
      textTheme: _textTheme(CozyColors.onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: CozyColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: CozyColors.onSurface,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: CozyColors.surface,
        elevation: 0,
        shadowColor: CozyColors.primary.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: CozyColors.outline, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CozyColors.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: CozyColors.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: CozyTypography.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: CozyColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: const BorderSide(color: CozyColors.primary, width: 2),
          textStyle: CozyTypography.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: CozyColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: CozyTypography.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CozyColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: CozyColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: CozyColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CozyColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: CozyColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 18,
        ),
        hintStyle: CozyTypography.bodyMedium.copyWith(
          color: CozyColors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: CozyColors.primary,
        foregroundColor: Colors.white,
        elevation: 8,
        focusElevation: 10,
        hoverElevation: 10,
        splashColor: Colors.white.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CozyColors.surface,
        selectedItemColor: CozyColors.primary,
        unselectedItemColor: CozyColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: CozyColors.surface,
        indicatorColor: CozyColors.navigationIndicator,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white);
          }
          return const IconThemeData(color: CozyColors.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return CozyTypography.labelMedium.copyWith(
              color: CozyColors.onSurface,
              fontWeight: FontWeight.w600,
            );
          }
          return CozyTypography.labelMedium.copyWith(
            color: CozyColors.onSurfaceVariant,
          );
        }),
        elevation: 0,
        height: 80,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: CozyColors.accent,
        contentTextStyle: CozyTypography.bodyMedium.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(24),
      ),
      dividerTheme: const DividerThemeData(
        color: CozyColors.outline,
        thickness: 1,
      ),
    );
  }

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: CozyColors.primaryLight,
        onPrimary: CozyColors.backgroundDark,
        primaryContainer: CozyColors.primaryDark,
        onPrimaryContainer: Colors.white,
        secondary: CozyColors.accentLight,
        onSecondary: CozyColors.backgroundDark,
        secondaryContainer: CozyColors.accentDark,
        onSecondaryContainer: Colors.white,
        tertiary: CozyColors.successLight,
        onTertiary: CozyColors.backgroundDark,
        error: CozyColors.errorLight,
        onError: CozyColors.backgroundDark,
        surface: CozyColors.surfaceDark,
        onSurface: CozyColors.onSurfaceDark,
        surfaceContainerHighest: CozyColors.surfaceVariantDark,
        onSurfaceVariant: CozyColors.onSurfaceVariant,
        outline: CozyColors.outlineDark,
      ),
      scaffoldBackgroundColor: CozyColors.backgroundDark,
      textTheme: _textTheme(CozyColors.onSurfaceDark),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: CozyColors.onSurfaceDark,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: CozyColors.onSurfaceDark,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: CozyColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: CozyColors.outlineDark, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: CozyColors.primaryLight,
          foregroundColor: CozyColors.backgroundDark,
          elevation: 4,
          shadowColor: CozyColors.primaryLight.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: CozyTypography.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: CozyColors.surfaceVariantDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: CozyColors.primaryLight,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 18,
        ),
        hintStyle: CozyTypography.bodyMedium.copyWith(
          color: CozyColors.onSurfaceDark.withValues(alpha: 0.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: CozyColors.primaryLight,
        foregroundColor: CozyColors.backgroundDark,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CozyColors.surfaceDark,
        selectedItemColor: CozyColors.primaryLight,
        unselectedItemColor: CozyColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static TextTheme _textTheme(Color color) {
    return TextTheme(
      displayLarge: CozyTypography.displayLarge.copyWith(color: color),
      displayMedium: CozyTypography.displayMedium.copyWith(color: color),
      displaySmall: CozyTypography.displaySmall.copyWith(color: color),
      headlineLarge: CozyTypography.headlineLarge.copyWith(color: color),
      headlineMedium: CozyTypography.headlineMedium.copyWith(color: color),
      headlineSmall: CozyTypography.headlineSmall.copyWith(color: color),
      titleLarge: CozyTypography.titleLarge.copyWith(color: color),
      titleMedium: CozyTypography.titleMedium.copyWith(color: color),
      titleSmall: CozyTypography.titleSmall.copyWith(color: color),
      bodyLarge: CozyTypography.bodyLarge.copyWith(color: color),
      bodyMedium: CozyTypography.bodyMedium.copyWith(color: color),
      bodySmall: CozyTypography.bodySmall.copyWith(color: color),
      labelLarge: CozyTypography.labelLarge.copyWith(color: color),
      labelMedium: CozyTypography.labelMedium.copyWith(color: color),
      labelSmall: CozyTypography.labelSmall.copyWith(color: color),
    );
  }
}

/// Extension for quick access to custom cozy colors
extension CozyCustomColors on ColorScheme {
  Color get cozySuccess => brightness == Brightness.light
      ? CozyColors.success
      : CozyColors.successLight;

  Color get cozyWarning => brightness == Brightness.light
      ? CozyColors.warning
      : CozyColors.warningLight;

  Color get cozyAligned => cozySuccess;
  Color get cozyMisaligned => error;
  Color get cozyNeutral => cozyWarning;
}
