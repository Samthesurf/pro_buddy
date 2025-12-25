import 'package:flutter/material.dart';
import 'theme.dart';
import 'cozy_theme.dart';

/// Dynamic colors that adapt based on the current theme
/// Use this instead of hardcoding AppColors when you need theme-specific colors
class ThemeColors {
  ThemeColors._();

  /// Get colors that adapt to the current theme (Cozy for light, App for dark)
  static _DynamicColors of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final scheme = Theme.of(context).colorScheme;
    return _DynamicColors._(brightness, scheme);
  }
}

class _DynamicColors {
  final Brightness brightness;
  final ColorScheme scheme;

  _DynamicColors._(this.brightness, this.scheme);

  bool get isLight => brightness == Brightness.light;
  bool get isDark => brightness == Brightness.dark;

  // Primary colors
  Color get primary => scheme.primary;
  Color get primaryLight =>
      isLight ? CozyColors.primaryLight : AppColors.primaryLight;
  Color get primaryDark =>
      isLight ? CozyColors.primaryDark : AppColors.primaryDark;

  // Secondary/Accent colors
  Color get accent => scheme.secondary;
  Color get accentLight =>
      isLight ? CozyColors.accentLight : AppColors.accentLight;
  Color get accentDark =>
      isLight ? CozyColors.accentDark : AppColors.accentDark;

  // Success colors
  Color get success => scheme.tertiary;
  Color get successLight =>
      isLight ? CozyColors.successLight : AppColors.successLight;
  Color get successDark =>
      isLight ? CozyColors.successDark : AppColors.successDark;

  // Warning colors
  Color get warning => isLight ? CozyColors.warning : AppColors.warning;
  Color get warningLight =>
      isLight ? CozyColors.warningLight : AppColors.warningLight;
  Color get warningDark =>
      isLight ? CozyColors.warningDark : AppColors.warningDark;

  // Error colors
  Color get error => scheme.error;
  Color get errorLight =>
      isLight ? CozyColors.errorLight : AppColors.errorLight;
  Color get errorDark => isLight ? CozyColors.errorDark : AppColors.errorDark;

  // Background colors
  Color get background =>
      isLight ? CozyColors.background : AppColors.backgroundDark;
  Color get backgroundDark => AppColors.backgroundDark;
  Color get surface => scheme.surface;
  Color get surfaceDark => AppColors.surfaceDark;
  Color get surfaceVariant => scheme.surfaceContainerHighest;
  Color get surfaceVariantDark => AppColors.surfaceVariantDark;

  // Text colors
  Color get onBackground => scheme.onSurface;
  Color get onSurface => scheme.onSurface;
  Color get onSurfaceVariant => scheme.onSurfaceVariant;

  // Outline
  Color get outline => scheme.outline;
  Color get outlineDark => AppColors.outlineDark;
}
