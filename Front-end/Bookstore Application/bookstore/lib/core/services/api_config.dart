import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// ================================
  /// FORCE EMULATOR MODE (for testing)
  /// Set to false for automatic detection
  /// ================================
  static const bool forceEmulatorMode =
      true; // Force emulator mode for Android emulator

  /// ================================
  /// Base IP for real Android device (WiFi)
  /// Replace with your laptop IPv4 (without http://)
  /// ================================
  static String getBaseIp() {
    return "192.168.1.106"; // <<< CHANGE THIS TO YOUR IPv4
  }

  /// ================================
  /// URL for backend running on Windows
  /// ================================
  static String getWindowsUrl() {
    return "http://${getBaseIp()}:8000/api";
  }

  /// ================================
  /// URL for Android physical device
  /// ================================
  static String getAndroidPhoneUrl() {
    return "http://${getBaseIp()}:8000/api";
  }

  /// ================================
  /// URL for Android Emulator
  /// ================================
  static String getAndroidEmulatorUrl() {
    return "http://10.0.2.2:8000/api";
  }

  /// ================================
  /// URL for iOS Simulator
  /// ================================
  static String getiOSUrl() {
    return "http://${getBaseIp()}:8000/api";
  }

  /// ================================
  /// Main method used everywhere
  /// Automatically selects correct URL
  /// ================================
  static String getBaseUrl() {
    try {
      if (Platform.isAndroid) {
        // Emulator or Phone detection
        if (forceEmulatorMode) {
          final url = getAndroidEmulatorUrl();
          debugPrint('=== API CONFIG ===');
          debugPrint('Platform: Android');
          debugPrint('Force Emulator Mode: ENABLED');
          debugPrint('Using Emulator URL: $url');
          return url;
        }

        final isEmulator = _isRunningOnEmulator();
        debugPrint('=== API CONFIG ===');
        debugPrint('Platform: Android');
        debugPrint('Is Emulator: $isEmulator');

        final url = isEmulator ? getAndroidEmulatorUrl() : getAndroidPhoneUrl();
        debugPrint('Using URL: $url');
        return url;
      }

      if (Platform.isIOS) {
        final url = getiOSUrl();
        debugPrint('Platform: iOS');
        debugPrint('Using URL: $url');
        return url;
      }

      if (Platform.isWindows) {
        final url = getWindowsUrl();
        debugPrint('Platform: Windows');
        debugPrint('Using URL: $url');
        return url;
      }

      // Default fallback
      final url = getWindowsUrl();
      debugPrint('Using Default URL: $url');
      return url;
    } catch (e) {
      debugPrint('Error in getBaseUrl: $e');
      final url = getWindowsUrl();
      debugPrint('Using Fallback URL: $url');
      return url;
    }
  }

  /// ================================
  /// Emulator detection helper
  /// ================================
  static bool _isRunningOnEmulator() {
    if (!Platform.isAndroid) return false;

    try {
      const emulatorIndicators = [
        'generic',
        'sdk',
        'emulator',
        'google_sdk',
        'unknown',
      ];

      final model = Platform.environment['ANDROID_MODEL'] ?? "";
      for (var keyword in emulatorIndicators) {
        if (model.toLowerCase().contains(keyword)) return true;
      }

      final brand = Platform.environment['ANDROID_BRAND'] ?? "";
      if (brand.toLowerCase().contains('generic') ||
          brand.toLowerCase().contains('unknown')) {
        return true;
      }

      final device = Platform.environment['ANDROID_DEVICE'] ?? "";
      if (device.toLowerCase().contains('generic') ||
          device.toLowerCase().contains('emulator')) {
        return true;
      }

      final product = Platform.environment['ANDROID_PRODUCT'] ?? "";
      if (product.toLowerCase().contains('sdk') ||
          product.toLowerCase().contains('emulator')) {
        return true;
      }

      final hardware = Platform.environment['ANDROID_HARDWARE'] ?? "";
      if (hardware.toLowerCase().contains('goldfish') ||
          hardware.toLowerCase().contains('ranchu')) {
        return true;
      }

      if (kDebugMode) {
        return false; // assume real device in debug if unsure
      }

      return false;
    } catch (e) {
      debugPrint('Error detecting emulator: $e');
      return false;
    }
  }

  /// ================================
  /// Standard headers
  /// ================================
  static Map<String, String> getStandardHeaders() {
    return {'Content-Type': 'application/json', 'Accept': 'application/json'};
  }

  /// ================================
  /// Authorization header
  /// ================================
  static Map<String, String> addAuthHeader(
    Map<String, String> headers,
    String token,
  ) {
    return {...headers, 'Authorization': 'Bearer $token'};
  }

  /// ================================
  /// Build full image URL from relative path
  /// Handles both absolute and relative URLs
  /// ================================
  static String? buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return null;
    }

    // If already an absolute URL, return as-is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Get base URL and remove /api suffix to get server root
    String baseUrl = getBaseUrl();
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    }

    // Ensure baseUrl doesn't end with / and imagePath starts with /
    if (!baseUrl.endsWith('/') && !imagePath.startsWith('/')) {
      return '$baseUrl/$imagePath';
    } else if (baseUrl.endsWith('/') && imagePath.startsWith('/')) {
      return '$baseUrl${imagePath.substring(1)}';
    } else {
      return '$baseUrl$imagePath';
    }
  }
}
