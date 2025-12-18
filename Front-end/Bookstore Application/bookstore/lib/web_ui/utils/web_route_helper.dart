import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../widgets/web_scaffold.dart';

/// Helper to wrap admin/delivery screens in WebScaffold when on web
class WebRouteHelper {
  /// Wraps a screen in WebScaffold if on web, otherwise returns as-is
  /// Note: This creates nested Scaffolds on web, but Flutter handles this gracefully
  /// The inner Scaffold's AppBar/Drawer will be hidden, only body is shown
  static Widget wrapScreen({
    required Widget screen,
    required String title,
    List<Widget>? actions,
  }) {
    if (kIsWeb) {
      return WebScaffold(title: title, actions: actions, child: screen);
    }
    return screen;
  }

  /// Creates a route that wraps the screen appropriately
  static Route<dynamic> createRoute({
    required Widget Function() builder,
    required String title,
    RouteSettings? settings,
    List<Widget>? actions,
  }) {
    return MaterialPageRoute(
      builder: (_) =>
          wrapScreen(screen: builder(), title: title, actions: actions),
      settings: settings,
    );
  }
}
