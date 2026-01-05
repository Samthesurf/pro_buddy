import 'package:flutter/material.dart';

import 'cozy_theme.dart';
import 'theme.dart' as app_theme;

/// Extension to access semantic colors that adapt to the current theme.
/// This allows widgets to use colors that work well in both Cozy and Material themes.
extension AppSemanticColors on ThemeData {
  /// Get the primary color for the current theme
  Color get primaryColor => colorScheme.primary;

  /// Get the primary color variant (darker/lighter)
  Color get primaryColorVariant {
    if (brightness == Brightness.light) {
      return _isCozyTheme ? CozyColors.primaryDark : colorScheme.primary;
    }
    return _isCozyTheme ? CozyColors.primaryLight : colorScheme.primary;
  }

  /// Success color (for completed steps, positive feedback)
  Color get successColor {
    if (_isCozyTheme) {
      return CozyColors.success;
    }
    return app_theme.AppColors.success;
  }

  /// Warning color (for in-progress, attention needed)
  Color get warningColor {
    if (_isCozyTheme) {
      return CozyColors.warning;
    }
    return app_theme.AppColors.warning;
  }

  /// Error/Danger color (for errors, destructive actions, destination)
  Color get errorColor => colorScheme.error;

  /// Outline/Border color
  Color get outlineColor {
    if (_isCozyTheme) {
      return CozyColors.outline;
    }
    return colorScheme.outline;
  }

  /// Surface variant for subtle backgrounds
  Color get surfaceVariantColor => colorScheme.surfaceContainerHighest;

  /// Muted text color
  Color get mutedTextColor {
    if (_isCozyTheme) {
      return CozyColors.onSurfaceVariant;
    }
    return colorScheme.onSurfaceVariant;
  }

  /// Check if the current theme is the Cozy theme
  bool get _isCozyTheme {
    // Cozy theme has the distinctive warm amber primary
    return colorScheme.primary == CozyColors.primary ||
        colorScheme.primary == CozyColors.primaryLight;
  }

  /// Get a gradient for goal/journey cards
  Gradient get goalCardGradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colorScheme.primary, primaryColorVariant],
    );
  }

  /// Get a destination gradient (for the goal/end point)
  Gradient get destinationGradient {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [errorColor, errorColor.withValues(alpha: 0.8)],
    );
  }
}

/// Extension for ColorScheme to add semantic journey colors
extension JourneyColors on ColorScheme {
  /// Color for completed items
  Color get completedColor => brightness == Brightness.light
      ? CozyColors.success
      : CozyColors.successLight;

  /// Color for in-progress items
  Color get inProgressColor => brightness == Brightness.light
      ? CozyColors.warning
      : CozyColors.warningLight;

  /// Color for available (ready to start) items
  Color get availableColor => primary;

  /// Color for locked items
  Color get lockedColor => onSurfaceVariant;

  /// Color for the journey destination
  Color get destinationColor => error;
}
