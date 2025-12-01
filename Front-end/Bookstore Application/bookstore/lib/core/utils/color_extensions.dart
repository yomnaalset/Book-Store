import 'package:flutter/material.dart';

extension ColorExtension on Color {
  /// Creates a new color with the given alpha, red, green, and blue values.
  /// If any parameter is null, the original value is used.
  /// This is a replacement for withOpacity which is deprecated.
  Color withValues({int? alpha, int? red, int? green, int? blue}) {
    return Color.fromARGB(
      alpha ?? (a * 255.0).round(),
      red ?? (r * 255.0).round(),
      green ?? (g * 255.0).round(),
      blue ?? (b * 255.0).round(),
    );
  }

  /// Creates a new color with the given opacity.
  /// This is a more convenient method for common use cases.
  Color withAlpha(int alpha) {
    return Color.fromARGB(
      alpha,
      (r * 255.0).round(),
      (g * 255.0).round(),
      (b * 255.0).round(),
    );
  }

  /// Creates a new color with adjusted brightness
  Color withBrightness(double factor) {
    assert(factor >= -1.0 && factor <= 1.0);

    int r = (this.r * 255.0).round();
    int g = (this.g * 255.0).round();
    int b = (this.b * 255.0).round();

    if (factor < 0) {
      // Darken
      r = (r * (1 + factor)).round();
      g = (g * (1 + factor)).round();
      b = (b * (1 + factor)).round();
    } else {
      // Lighten
      r = (r + ((255 - r) * factor)).round();
      g = (g + ((255 - g) * factor)).round();
      b = (b + ((255 - b) * factor)).round();
    }

    return Color.fromARGB(
      (a * 255.0).round(),
      r.clamp(0, 255),
      g.clamp(0, 255),
      b.clamp(0, 255),
    );
  }

  /// Returns a lighter version of this color
  Color lighten([double amount = 0.1]) => withBrightness(amount);

  /// Returns a darker version of this color
  Color darken([double amount = 0.1]) => withBrightness(-amount);
}
