import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Helper class to ensure proper Unicode input support for Arabic and English
class UnicodeInputHelper {
  /// Get input formatters that allow Unicode characters (Arabic, English, etc.)
  /// Returns empty list to allow all Unicode characters
  static List<TextInputFormatter> getUnicodeFormatters() {
    // Return empty list to allow all Unicode characters
    // No restrictions for multilingual text input
    return [];
  }

  /// Get keyboard type that supports Unicode input
  /// For text fields that should support Arabic and English
  static TextInputType getUnicodeKeyboardType() {
    // TextInputType.text supports full Unicode including Arabic
    return TextInputType.text;
  }

  /// Check if a string contains Arabic characters
  static bool containsArabic(String text) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    return arabicRegex.hasMatch(text);
  }

  /// Check if a string contains English characters
  static bool containsEnglish(String text) {
    final englishRegex = RegExp(r'[a-zA-Z]');
    return englishRegex.hasMatch(text);
  }

  /// Get text direction based on content
  /// Returns RTL if Arabic is detected, LTR otherwise
  static TextDirection? getTextDirection(String? text) {
    if (text == null || text.isEmpty) return null;

    // Check if text contains Arabic characters
    if (containsArabic(text)) {
      return TextDirection.rtl;
    }

    // Default to LTR for English or mixed content
    return TextDirection.ltr;
  }

  /// Validate that text input is working properly
  /// Use this for debugging Unicode input issues
  static void debugInput(String text, String fieldName) {
    debugPrint('=== Unicode Input Debug ===');
    debugPrint('Field: $fieldName');
    debugPrint('Text: $text');
    debugPrint('Length: ${text.length}');
    debugPrint('Contains Arabic: ${containsArabic(text)}');
    debugPrint('Contains English: ${containsEnglish(text)}');
    debugPrint('Text Direction: ${getTextDirection(text)}');
    debugPrint('UTF-16 Code Units: ${text.codeUnits}');
    debugPrint('========================');
  }
}
