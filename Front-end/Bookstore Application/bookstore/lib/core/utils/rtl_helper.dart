import 'package:flutter/material.dart';

/// Helper class for RTL-aware widgets and utilities
class RTLHelper {
  /// Get RTL-aware alignment start (left in LTR, right in RTL)
  static AlignmentGeometry getAlignmentStart(BuildContext context) {
    return const AlignmentDirectional(-1.0, 0.0);
  }

  /// Get RTL-aware alignment end (right in LTR, left in RTL)
  static AlignmentGeometry getAlignmentEnd(BuildContext context) {
    return const AlignmentDirectional(1.0, 0.0);
  }

  /// Get RTL-aware alignment center start
  static AlignmentGeometry getAlignmentCenterStart(BuildContext context) {
    return AlignmentDirectional.centerStart;
  }

  /// Get RTL-aware alignment center end
  static AlignmentGeometry getAlignmentCenterEnd(BuildContext context) {
    return AlignmentDirectional.centerEnd;
  }

  /// Get RTL-aware EdgeInsets for start (left in LTR, right in RTL)
  static EdgeInsetsDirectional getEdgeInsetsStart(double value) {
    return EdgeInsetsDirectional.only(start: value);
  }

  /// Get RTL-aware EdgeInsets for end (right in LTR, left in RTL)
  static EdgeInsetsDirectional getEdgeInsetsEnd(double value) {
    return EdgeInsetsDirectional.only(end: value);
  }

  /// Get RTL-aware EdgeInsets with start and end
  static EdgeInsetsDirectional getEdgeInsetsStartEnd({
    double? start,
    double? end,
    double? top,
    double? bottom,
  }) {
    return EdgeInsetsDirectional.only(
      start: start ?? 0,
      end: end ?? 0,
      top: top ?? 0,
      bottom: bottom ?? 0,
    );
  }

  /// Check if current locale is RTL
  static bool isRTL(BuildContext context) {
    return Directionality.of(context) == TextDirection.rtl;
  }

  /// Get text direction from locale
  static TextDirection getTextDirection(Locale locale) {
    return locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr;
  }
}
