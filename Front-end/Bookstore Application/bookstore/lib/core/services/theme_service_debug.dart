import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_service.dart';

/// Debug utilities for ThemeService
class ThemeServiceDebug {
  static const String _themeKey = 'app_theme';

  /// Print detailed theme information
  static Future<void> printThemeInfo(ThemeService themeService) async {
    debugPrint('=== THEME SERVICE DEBUG INFO ===');
    debugPrint('Current ThemeMode: ${themeService.themeMode}');
    debugPrint('Is Dark Mode: ${themeService.isDarkMode}');
    debugPrint('Use Dynamic Colors: ${themeService.useDynamicColors}');

    // Read from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeKey);
    debugPrint('SharedPreferences theme index: $themeModeIndex');

    if (themeModeIndex != null) {
      final mode = ThemeMode.values[themeModeIndex];
      debugPrint('SharedPreferences theme mode: $mode');
    } else {
      debugPrint('No theme preference saved in SharedPreferences');
    }

    debugPrint('=== END THEME DEBUG INFO ===');
  }

  /// Reset theme to default (light mode)
  static Future<void> resetTheme() async {
    debugPrint('=== RESETTING THEME ===');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_themeKey);
    debugPrint('Theme preference cleared from SharedPreferences');
    debugPrint('=== THEME RESET COMPLETE ===');
  }

  /// Force set theme in SharedPreferences (for debugging)
  static Future<void> forceSetTheme(ThemeMode mode) async {
    debugPrint('=== FORCE SETTING THEME TO $mode ===');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, mode.index);
    debugPrint('Theme index ${mode.index} saved to SharedPreferences');
    debugPrint('=== FORCE SET COMPLETE ===');
  }

  /// Get all SharedPreferences keys (for debugging)
  static Future<void> printAllPreferences() async {
    debugPrint('=== ALL SHARED PREFERENCES ===');
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (var key in keys) {
      debugPrint('$key: ${prefs.get(key)}');
    }
    debugPrint('=== END SHARED PREFERENCES ===');
  }
}
