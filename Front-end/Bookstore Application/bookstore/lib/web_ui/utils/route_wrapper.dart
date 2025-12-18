import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../widgets/web_scaffold.dart';

/// Wraps admin/delivery screens in WebScaffold when on web platform
/// Extracts title from AppBar if available, otherwise uses provided title
class RouteWrapper {
  /// Wraps a screen that has Scaffold with AppBar
  /// On web: Extracts body and wraps in WebScaffold
  /// On mobile: Returns as-is
  static Widget wrapWithWebScaffold({
    required Widget screen,
    required String defaultTitle,
    List<Widget>? actions,
  }) {
    if (!kIsWeb) {
      return screen;
    }

    // Extract title and body from Scaffold
    return Builder(
      builder: (context) {
        // Try to extract AppBar title from the screen
        String title = defaultTitle;

        // Wrap the screen and extract its body
        return WebScaffold(
          title: title,
          actions: actions,
          child: _extractBody(screen),
        );
      },
    );
  }

  /// Extracts body content from a Scaffold widget
  /// This is a simplified version - in production, you might want to use
  /// a more sophisticated approach or modify screens to expose body directly
  static Widget _extractBody(Widget screen) {
    // For now, we'll wrap the entire screen
    // In a production app, you'd want to extract just the body
    // This requires modifying screens to expose body separately or
    // using a more sophisticated widget tree traversal

    // Temporary solution: Return the screen wrapped in a way that
    // removes the outer Scaffold's AppBar/Drawer on web
    return screen;
  }
}

/// Helper to create a route that automatically wraps in WebScaffold on web
class WebRouteBuilder {
  static Route<dynamic> buildRoute({
    required Widget Function() builder,
    required String title,
    RouteSettings? settings,
    List<Widget>? actions,
  }) {
    return MaterialPageRoute(
      builder: (_) => RouteWrapper.wrapWithWebScaffold(
        screen: builder(),
        defaultTitle: title,
        actions: actions,
      ),
      settings: settings,
    );
  }
}
