import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../widgets/web_scaffold.dart';

/// Utility to wrap screens in WebScaffold when running on web platform
class WebScreenWrapper {
  /// Wraps a screen widget in WebScaffold if running on web, otherwise returns as-is
  static Widget wrap({
    required Widget child,
    required String title,
    List<Widget>? actions,
  }) {
    if (kIsWeb) {
      return WebScaffold(title: title, actions: actions, child: child);
    }
    return child;
  }

  /// Extracts title from a Scaffold's AppBar or uses default
  static String extractTitle(Widget widget, String defaultTitle) {
    // For now, just return the default title
    // In the future, we could parse the widget tree to extract AppBar title
    return defaultTitle;
  }
}
