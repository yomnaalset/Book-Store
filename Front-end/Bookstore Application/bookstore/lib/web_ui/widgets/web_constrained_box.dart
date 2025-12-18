import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Constrains content width on web for better readability
/// Centers content and limits width to 900px on web
/// On mobile, allows full width
class WebConstrainedBox extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const WebConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth = 900.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      // On mobile, return child as-is with optional padding
      if (padding != null) {
        return Padding(padding: padding!, child: child);
      }
      return child;
    }

    // On web, center and constrain width
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
        child: child,
      ),
    );
  }
}

/// Responsive container that adapts padding based on platform
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets mobilePadding;
  final EdgeInsets webPadding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.mobilePadding = const EdgeInsets.all(16.0),
    this.webPadding = const EdgeInsets.all(24.0),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(padding: kIsWeb ? webPadding : mobilePadding, child: child);
  }
}
