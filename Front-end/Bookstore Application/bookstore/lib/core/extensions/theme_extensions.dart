import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Extension methods to make it easier to access theme colors
/// This helps with dark mode support by using context-aware colors
extension ThemeExtensions on BuildContext {
  /// Get the current theme
  ThemeData get theme => Theme.of(this);

  /// Get the current color scheme
  ColorScheme get colorScheme => theme.colorScheme;

  /// Get the current text theme
  TextTheme get textTheme => theme.textTheme;

  /// Check if dark mode is active
  bool get isDarkMode => theme.brightness == Brightness.dark;

  // Commonly used colors that adapt to theme

  /// Primary color
  Color get primaryColor => colorScheme.primary;

  /// Background color that adapts to theme
  Color get backgroundColor => colorScheme.surface;

  /// Surface color (for cards, etc.)
  Color get surfaceColor => colorScheme.surface;

  /// Text color that adapts to theme
  Color get textColor => colorScheme.onSurface;

  /// Secondary text color that adapts to theme
  Color get secondaryTextColor => colorScheme.onSurfaceVariant;

  /// Card color that adapts to theme
  Color get cardColor => isDarkMode ? AppColors.darkCard : AppColors.surface;

  /// Divider color that adapts to theme
  Color get dividerColor =>
      isDarkMode ? AppColors.darkDivider : AppColors.border;

  /// Error color
  Color get errorColor => colorScheme.error;

  /// Success color (doesn't change with theme)
  Color get successColor => AppColors.success;

  /// Warning color (doesn't change with theme)
  Color get warningColor => AppColors.warning;

  /// White color (use sparingly, prefer theme colors)
  Color get whiteColor => Colors.white;

  /// Black color (use sparingly, prefer theme colors)
  Color get blackColor => Colors.black;

  /// Scaffold background color that adapts to theme
  Color get scaffoldBackgroundColor =>
      isDarkMode ? AppColors.darkBackground : AppColors.background;
}

/// Extension for getting theme-aware AppColors
extension AppColorsThemeExtension on AppColors {
  /// Get background color based on brightness
  static Color getBackground(BuildContext context) {
    return context.isDarkMode ? AppColors.darkBackground : AppColors.background;
  }

  /// Get surface color based on brightness
  static Color getSurface(BuildContext context) {
    return context.isDarkMode ? AppColors.darkSurface : AppColors.surface;
  }

  /// Get text primary color based on brightness
  static Color getTextPrimary(BuildContext context) {
    return context.isDarkMode
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
  }

  /// Get text secondary color based on brightness
  static Color getTextSecondary(BuildContext context) {
    return context.isDarkMode
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
  }

  /// Get card color based on brightness
  static Color getCard(BuildContext context) {
    return context.isDarkMode ? AppColors.darkCard : AppColors.surface;
  }

  /// Get divider color based on brightness
  static Color getDivider(BuildContext context) {
    return context.isDarkMode ? AppColors.darkDivider : AppColors.border;
  }
}

/// Helper function to get theme-aware text primary color
/// Use this instead of AppColors.textPrimary for dark mode support
Color getTextPrimaryColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkTextPrimary
      : AppColors.textPrimary;
}

/// Helper function to get theme-aware text secondary color
/// Use this instead of AppColors.textSecondary for dark mode support
Color getTextSecondaryColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? AppColors.darkTextSecondary
      : AppColors.textSecondary;
}
