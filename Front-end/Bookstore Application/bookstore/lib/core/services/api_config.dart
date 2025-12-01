import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// ================================
  /// FORCE EMULATOR MODE (for testing)
  /// Set to true to always use emulator URL (10.0.2.2)
  /// Set to false for automatic detection
  /// ================================
  static const bool forceEmulatorMode =
      true; // <<< Set to false for auto-detection

  /// ================================
  /// 1) Base IP for real Android device (WiFi)
  /// Replace with your laptop IPv4 (without http://)
  /// ================================
  static String getBaseIp() {
    return "192.168.1.106"; // <<< CHANGE THIS TO YOUR IPv4 (no http://)
  }

  /// ================================
  /// 2) URL for backend running on Windows
  /// ================================
  static String getWindowsUrl() {
    return "http://${getBaseIp()}:8000/api";
  }

  /// ================================
  /// 3) URL for Android physical device
  /// ================================
  static String getAndroidPhoneUrl() {
    return "http://${getBaseIp()}:8000/api";
  }

  /// ================================
  /// 4) URL for Android Emulator
  /// DO NOT CHANGE THIS
  /// ================================
  static String getAndroidEmulatorUrl() {
    return "http://10.0.2.2:8000/api";
  }

  /// ================================
  /// 5) iOS Simulator (if needed later)
  /// ================================
  static String getiOSUrl() {
    return "http://127.0.0.1:8000/api";
  }

  /// ================================
  /// 6) Main method used everywhere
  /// Automatically selects correct URL
  /// ================================
  static String getBaseUrl() {
    try {
      if (Platform.isAndroid) {
        // Check for manual override first
        if (forceEmulatorMode) {
          final url = getAndroidEmulatorUrl();
          debugPrint('=== API CONFIG ===');
          debugPrint('Platform: Android');
          debugPrint('Force Emulator Mode: ENABLED');
          debugPrint('Using Emulator URL: $url');
          return url;
        }

        // Distinguish emulator vs real device
        final isEmulator = _isRunningOnEmulator();
        debugPrint('=== API CONFIG ===');
        debugPrint('Platform: Android');
        debugPrint('Is Emulator: $isEmulator');

        if (isEmulator) {
          final url = getAndroidEmulatorUrl();
          debugPrint('Using Emulator URL: $url');
          return url;
        } else {
          final url = getAndroidPhoneUrl();
          debugPrint('Using Phone URL: $url');
          return url;
        }
      }

      if (Platform.isIOS) {
        final url = getiOSUrl();
        debugPrint('Using iOS URL: $url');
        return url;
      }

      if (Platform.isWindows) {
        final url = getWindowsUrl();
        debugPrint('Using Windows URL: $url');
        return url;
      }

      // Default fallback
      final url = getWindowsUrl();
      debugPrint('Using Default URL: $url');
      return url;
    } catch (e) {
      debugPrint('Error in getBaseUrl: $e');
      // Fallback if platform detection fails
      final url = getWindowsUrl();
      debugPrint('Using Fallback URL: $url');
      return url;
    }
  }

  /// ================================
  /// 7) Emulator detection helper
  /// Uses device_info_plus for reliable detection
  /// ================================
  static bool _isRunningOnEmulator() {
    if (!Platform.isAndroid) return false;

    try {
      // Check environment variables for emulator detection
      // Note: device_info_plus requires async, so we use environment variables for synchronous check
      const emulatorIndicators = [
        'generic',
        'sdk',
        'emulator',
        'google_sdk',
        'unknown',
      ];

      // Check ANDROID_MODEL
      final model = Platform.environment['ANDROID_MODEL'] ?? "";
      for (var keyword in emulatorIndicators) {
        if (model.toLowerCase().contains(keyword)) {
          debugPrint('Emulator detected via ANDROID_MODEL: $model');
          return true;
        }
      }

      // Check ANDROID_BRAND
      final brand = Platform.environment['ANDROID_BRAND'] ?? "";
      if (brand.toLowerCase().contains('generic') ||
          brand.toLowerCase().contains('unknown')) {
        debugPrint('Emulator detected via ANDROID_BRAND: $brand');
        return true;
      }

      // Check ANDROID_DEVICE
      final device = Platform.environment['ANDROID_DEVICE'] ?? "";
      if (device.toLowerCase().contains('generic') ||
          device.toLowerCase().contains('emulator')) {
        debugPrint('Emulator detected via ANDROID_DEVICE: $device');
        return true;
      }

      // Check ANDROID_PRODUCT
      final product = Platform.environment['ANDROID_PRODUCT'] ?? "";
      if (product.toLowerCase().contains('sdk') ||
          product.toLowerCase().contains('emulator')) {
        debugPrint('Emulator detected via ANDROID_PRODUCT: $product');
        return true;
      }

      // Check ANDROID_HARDWARE
      final hardware = Platform.environment['ANDROID_HARDWARE'] ?? "";
      if (hardware.toLowerCase().contains('goldfish') ||
          hardware.toLowerCase().contains('ranchu')) {
        debugPrint('Emulator detected via ANDROID_HARDWARE: $hardware');
        return true;
      }

      // If we can't detect, and we're in debug mode, default to emulator for development
      if (kDebugMode) {
        debugPrint(
          'Cannot determine if emulator - defaulting to emulator URL in debug mode',
        );
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('Error detecting emulator: $e');
      // In debug mode, default to emulator
      if (kDebugMode) {
        return true;
      }
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
}
