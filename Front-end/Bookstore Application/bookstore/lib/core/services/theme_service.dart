import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme';
  static const String _useDynamicColorsKey = 'use_dynamic_colors';
  ThemeMode _themeMode = ThemeMode.light;
  bool _useDynamicColors = false;

  ThemeService() {
    loadThemePreference();
  }

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColors => _useDynamicColors;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Load theme preference
  Future<void> loadThemePreference() async {
    debugPrint('ThemeService.loadThemePreference called');
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeKey);

    debugPrint('Loaded theme index from SharedPreferences: $themeModeIndex');

    // Ensure we have a valid theme mode index
    if (themeModeIndex != null &&
        themeModeIndex >= 0 &&
        themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
      debugPrint('Set theme mode to: $_themeMode');
    } else {
      _themeMode = ThemeMode.light; // Default to light mode
      debugPrint('Using default theme mode: $_themeMode');
    }
    _useDynamicColors = prefs.getBool(_useDynamicColorsKey) ?? false;
    debugPrint('loadThemePreference complete, notifying listeners');
    notifyListeners();
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    debugPrint('ThemeService.setThemeMode called with mode: $mode');
    debugPrint('Current mode before change: $_themeMode');

    if (mode == _themeMode) {
      debugPrint('Mode unchanged, returning early');
      return;
    }

    _themeMode = mode;
    debugPrint('Updated _themeMode to: $_themeMode');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    debugPrint('Saved theme index ${mode.index} to SharedPreferences');

    // Update system UI overlay
    _updateSystemUIOverlayStyle();

    debugPrint('Calling notifyListeners()');
    notifyListeners();
    debugPrint('Theme mode change complete');
  }

  // Toggle between light and dark mode
  Future<void> toggleThemeMode() async {
    final newMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    await setThemeMode(newMode);
  }

  // Force reset to light mode (useful for debugging)
  Future<void> resetToLightMode() async {
    await setThemeMode(ThemeMode.light);
  }

  // Force light mode and clear any cached preferences
  Future<void> forceLightMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
    _themeMode = ThemeMode.light;
    _updateSystemUIOverlayStyle();
    notifyListeners();
  }

  // Set whether to use dynamic colors (Material You)
  Future<void> setUseDynamicColors(bool value) async {
    if (value == _useDynamicColors) return;

    _useDynamicColors = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useDynamicColorsKey, value);

    notifyListeners();
  }

  // Update system UI overlay based on theme
  void _updateSystemUIOverlayStyle() {
    final isDark = _themeMode == ThemeMode.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: isDark
            ? AppColors.darkBackground
            : AppColors.background,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
    );
  }

  // Get the current app theme (deprecated - use getLightTheme/getDarkTheme with themeMode)
  ThemeData getTheme() {
    // This method is kept for backward compatibility
    // The MaterialApp should use theme, darkTheme, and themeMode instead
    return getLightTheme();
  }

  // Light theme
  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        secondary: AppColors.secondary,
        onSecondary: AppColors.white,
        error: AppColors.error,
        onError: AppColors.white,
        surface: AppColors.background,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: AppDimensions.elevationS,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingM,
        ),
        filled: true,
        fillColor: AppColors.surface,
      ),
      cardTheme: CardThemeData(
        elevation: AppDimensions.elevationS,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeXXXL,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeXXL,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeXL,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeL,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeM,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeM,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeM,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeS,
        ),
        bodySmall: TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppDimensions.fontSizeXS,
        ),
      ),
    );
  }

  // Dark theme
  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.white,
        secondary: AppColors.secondary,
        onSecondary: AppColors.white,
        error: AppColors.error,
        onError: AppColors.white,
        surface: AppColors.darkBackground,
        onSurface: AppColors.darkTextPrimary,
        surfaceContainerHighest: AppColors.darkCard,
        onSurfaceVariant: AppColors.darkTextSecondary,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkTextPrimary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: AppDimensions.elevationS,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingL,
            vertical: AppDimensions.paddingM,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(color: AppColors.darkCard),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(color: AppColors.darkCard),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingM,
        ),
        filled: true,
        fillColor: AppColors.darkSurface,
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: AppDimensions.elevationS,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeXXXL,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeXXL,
          fontWeight: FontWeight.bold,
        ),
        displaySmall: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeXL,
          fontWeight: FontWeight.bold,
        ),
        headlineLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeL,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeL,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeM,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeL,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeM,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeS,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeM,
        ),
        bodyMedium: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeS,
        ),
        bodySmall: TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: AppDimensions.fontSizeXS,
        ),
        labelLarge: TextStyle(
          color: AppColors.darkTextPrimary,
          fontSize: AppDimensions.fontSizeS,
          fontWeight: FontWeight.w500,
        ),
        labelMedium: TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: AppDimensions.fontSizeXS,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: AppDimensions.fontSizeXS,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
