import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);

  // Secondary Colors
  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryDark = Color(0xFF018786);
  static const Color secondaryLight = Color(0xFFB2DFDB);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFDFF8DF);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color greyLight = Color(0xFFF5F5F5);
  static const Color greyDark = Color(0xFF616161);

  // Background Colors
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color scaffoldBackground = Color(0xFFF8F9FA);

  // Dark Theme Colors - Improved contrast
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkCard = Color(0xFF21262D);
  static const Color darkDivider = Color(0xFF30363D);
  static const Color darkTextPrimary = Color(0xFFF0F6FC);
  static const Color darkTextSecondary = Color(0xFF8B949E);
  static const Color darkTextTertiary = Color(0xFF6E7681);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFF000000);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFF0F0F0);
  static const Color borderDark = Color(0xFFBDBDBD);

  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0A000000);
  static const Color shadowDark = Color(0x33000000);

  // Legacy aliases for backward compatibility
  static const Color uranianBlue = primary;
  static const Color primaryText = textPrimary;
  static const Color secondaryText = textSecondary;
  static const Color hintText = textHint;
  static const Color divider = border;
  static const Color disabled = textHint;
  static const Color accent = secondary;
  static const Color canvas = background;
  static const Color card = surface;
  static const Color focus = primary;
  static const Color highlight = primaryLight;
  static const Color hover = primaryLight;
  static const Color selected = primary;
  static const Color splash = primaryLight;
  static const Color unselected = textHint;
  static const Color indicator = primary;
  static const Color onPrimary = textOnPrimary;
  static const Color onSecondary = textOnSecondary;
  static const Color onSurface = textPrimary;
  static const Color onBackground = textPrimary;
  static const Color onError = textOnPrimary;
  static const Color onWarning = textOnPrimary;
  static const Color onSuccess = textOnPrimary;
  static const Color onInfo = textOnPrimary;

  // Additional utility colors
  static const Color transparent = Color(0x00000000);
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);

  // Theme-specific colors
  static const Color fairyTaleColor = Color(0xFFE1BEE7); // Light purple
  static const Color carnationPink = Color(0xFFFF80AB); // Pink
  static const Color thistle = Color(0xFFD8B5FF); // Light purple/lavender

  // Gradient colors
  static const List<Color> primaryGradient = [primary, primaryDark];
  static const List<Color> secondaryGradient = [secondary, secondaryDark];
  static const List<Color> successGradient = [success, Color(0xFF388E3C)];
  static const List<Color> warningGradient = [warning, Color(0xFFF57C00)];
  static const List<Color> errorGradient = [error, Color(0xFFD32F2F)];
}
