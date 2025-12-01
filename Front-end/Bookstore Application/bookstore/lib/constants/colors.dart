import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFFBBDEFB);

  // Secondary colors
  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryDark = Color(0xFF018786);
  static const Color secondaryLight = Color(0xFFB2DFDB);

  // Accent colors
  static const Color accent = Color(0xFFFF4081);
  static const Color accentDark = Color(0xFFE91E63);
  static const Color accentLight = Color(0xFFF8BBD9);

  // Background colors
  static const Color background = Color(0xFFFAFAFA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);

  // Dark theme colors
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);

  // Text colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textDisabled = Color(0xFFE0E0E0);

  // Dark theme text colors
  static const Color darkTextPrimary = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFB3B3B3);
  static const Color darkTextHint = Color(0xFF666666);
  static const Color darkTextDisabled = Color(0xFF404040);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Neutral colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey50 = Color(0xFFFAFAFA);
  static const Color grey100 = Color(0xFFF5F5F5);
  static const Color grey200 = Color(0xFFEEEEEE);
  static const Color grey300 = Color(0xFFE0E0E0);
  static const Color grey400 = Color(0xFFBDBDBD);
  static const Color grey500 = Color(0xFF9E9E9E);
  static const Color grey600 = Color(0xFF757575);
  static const Color grey700 = Color(0xFF616161);
  static const Color grey800 = Color(0xFF424242);
  static const Color grey900 = Color(0xFF212121);

  // Delivery status colors
  static const Color pending = Color(0xFFFF9800);
  static const Color assigned = Color(0xFF2196F3);
  static const Color inProgress = Color(0xFF9C27B0);
  static const Color delivered = Color(0xFF4CAF50);
  static const Color cancelled = Color(0xFFF44336);

  // Order status colors
  static const Color orderPending = Color(0xFFFF9800);
  static const Color orderConfirmed = Color(0xFF2196F3);
  static const Color orderShipped = Color(0xFF9C27B0);
  static const Color orderDelivered = Color(0xFF4CAF50);
  static const Color orderCancelled = Color(0xFFF44336);

  // Borrow status colors
  static const Color borrowRequested = Color(0xFFFF9800);
  static const Color borrowApproved = Color(0xFF2196F3);
  static const Color borrowActive = Color(0xFF4CAF50);
  static const Color borrowOverdue = Color(0xFFF44336);
  static const Color borrowReturned = Color(0xFF9E9E9E);

  // Priority colors
  static const Color lowPriority = Color(0xFF4CAF50);
  static const Color mediumPriority = Color(0xFFFF9800);
  static const Color highPriority = Color(0xFFF44336);
  static const Color urgentPriority = Color(0xFF9C27B0);

  // Rating colors
  static const Color rating1 = Color(0xFFF44336);
  static const Color rating2 = Color(0xFFFF5722);
  static const Color rating3 = Color(0xFFFF9800);
  static const Color rating4 = Color(0xFFFFC107);
  static const Color rating5 = Color(0xFF4CAF50);

  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accentDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shadow colors
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowMedium = Color(0x33000000);
  static const Color shadowDark = Color(0x4D000000);

  // Border colors
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFBDBDBD);
  static const Color borderDark = Color(0xFF757575);

  // Overlay colors
  static const Color overlayLight = Color(0x1A000000);
  static const Color overlayMedium = Color(0x33000000);
  static const Color overlayDark = Color(0x4D000000);

  // Helper methods
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return pending;
      case 'assigned':
        return assigned;
      case 'in_progress':
      case 'in progress':
        return inProgress;
      case 'delivered':
        return delivered;
      case 'cancelled':
        return cancelled;
      default:
        return grey500;
    }
  }

  static Color getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return orderPending;
      case 'confirmed':
        return orderConfirmed;
      case 'shipped':
        return orderShipped;
      case 'delivered':
        return orderDelivered;
      case 'cancelled':
        return orderCancelled;
      default:
        return grey500;
    }
  }

  static Color getBorrowStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'requested':
        return borrowRequested;
      case 'approved':
        return borrowApproved;
      case 'active':
        return borrowActive;
      case 'overdue':
        return borrowOverdue;
      case 'returned':
        return borrowReturned;
      default:
        return grey500;
    }
  }

  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return lowPriority;
      case 'medium':
        return mediumPriority;
      case 'high':
        return highPriority;
      case 'urgent':
        return urgentPriority;
      default:
        return grey500;
    }
  }

  static Color getRatingColor(double rating) {
    if (rating >= 4.5) return rating5;
    if (rating >= 3.5) return rating4;
    if (rating >= 2.5) return rating3;
    if (rating >= 1.5) return rating2;
    return rating1;
  }
}
