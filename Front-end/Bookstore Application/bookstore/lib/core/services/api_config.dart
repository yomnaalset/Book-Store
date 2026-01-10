import 'dart:io';
import 'package:flutter/foundation.dart';
import 'ip_address_service.dart';

class ApiConfig {
  /// ================================
  /// FORCE EMULATOR MODE (for testing)
  /// Set to false for real device detection
  /// ================================
  static const bool forceEmulatorMode = false;

  /// ================================
  /// FORCE SAME SERVER (ensures same data)
  /// Set to true to force all devices to use the same server IP
  /// ================================
  static const bool forceSameServer = true;
  static const String forcedServerIP = "192.168.1.106"; // Your computer's IP

  // Cached base URL to avoid async calls everywhere
  static String? _cachedBaseUrl;
  static String? _cachedBaseIp;

  /// ================================
  /// Initialize base URL cache
  /// Call this on app startup
  /// ================================
  static Future<void> initialize() async {
    await _refreshBaseUrl();
  }

  /// ================================
  /// Refresh base URL cache
  /// Call this when IP address changes
  /// ================================
  static Future<void> refreshBaseUrl() async {
    await _refreshBaseUrl();
  }

  static Future<void> _refreshBaseUrl() async {
    try {
      _cachedBaseIp = await IpAddressService.getIpAddress();
      _cachedBaseUrl = await _computeBaseUrl();
      debugPrint('✅ ApiConfig: Base URL refreshed successfully');
      debugPrint('✅ ApiConfig: Using IP: $_cachedBaseIp');
      debugPrint('✅ ApiConfig: Base URL: $_cachedBaseUrl');
      debugPrint('✅ ApiConfig: Platform: ${Platform.operatingSystem}');
      debugPrint('✅ ApiConfig: Is Emulator: ${_isRunningOnEmulator()}');
    } catch (e) {
      debugPrint('❌ ApiConfig: Error refreshing base URL: $e');
      // Use fallback IP of your computer on Wi-Fi
      _cachedBaseIp = '192.168.1.106';
      _cachedBaseUrl = await _computeBaseUrl();
      debugPrint('⚠️ ApiConfig: Using fallback base URL: $_cachedBaseUrl');
      debugPrint('⚠️ ApiConfig: Please set the correct IP address in Settings');
    }
  }

  /// ================================
  /// Base IP for real Android device (Wi-Fi)
  /// ================================
  static Future<String> getBaseIp() async {
    if (_cachedBaseIp != null) {
      return _cachedBaseIp!;
    }
    _cachedBaseIp = await IpAddressService.getIpAddress();
    return _cachedBaseIp!;
  }

  static String getBaseIpSync() {
    return _cachedBaseIp ?? '192.168.1.106';
  }

  /// ================================
  /// URLs for different platforms
  /// ================================
  static String getWindowsUrl() => "http://${getBaseIpSync()}:8000/api";

  static String getAndroidPhoneUrl() => "http://${getBaseIpSync()}:8000/api";

  static String getAndroidEmulatorUrl() => "http://10.0.2.2:8000/api";

  static String getiOSUrl() => "http://${getBaseIpSync()}:8000/api";

  /// ================================
  /// Compute base URL based on platform
  /// ================================
  static Future<String> _computeBaseUrl() async {
    try {
      if (Platform.isAndroid) {
        if (forceEmulatorMode) {
          return getAndroidEmulatorUrl();
        }
        final isEmulator = _isRunningOnEmulator();
        return isEmulator ? getAndroidEmulatorUrl() : getAndroidPhoneUrl();
      }

      if (Platform.isIOS) return getiOSUrl();
      if (Platform.isWindows) return getWindowsUrl();

      return getWindowsUrl(); // fallback
    } catch (e) {
      debugPrint('Error in _computeBaseUrl: $e');
      return getWindowsUrl();
    }
  }

  /// ================================
  /// Main method used everywhere
  /// ================================
  ///
  /// IMPORTANT FOR REAL DEVICES:
  /// - Emulator: Uses http://10.0.2.2:8000/api (points to localhost)
  /// - Real Device: Uses http://YOUR_IP:8000/api (e.g., http://192.168.1.106:8000/api)
  ///
  /// To set IP address on real device:
  /// 1. Go to Settings > Server IP Address
  /// 2. Enter your computer's IP address on the local network
  /// 3. Make sure phone and computer are on the same Wi-Fi network
  /// 4. Make sure backend server is running on 0.0.0.0:8000 (not 127.0.0.1:8000)
  ///
  /// To find your computer's IP:
  /// - Windows: ipconfig (look for IPv4 Address)
  /// - Mac/Linux: ifconfig or ip addr (look for inet)
  static String getBaseUrl() {
    if (_cachedBaseUrl != null) {
      debugPrint('📡 ApiConfig: Using cached base URL: $_cachedBaseUrl');
      return _cachedBaseUrl!;
    }

    // Force same server for consistent data across all devices
    if (forceSameServer) {
      final url = "http://$forcedServerIP:8000/api";
      debugPrint('📡 ApiConfig: Force same server - using: $url');
      debugPrint('📡 ApiConfig: This ensures same data on phone and emulator');
      return url;
    }

    final ip = getBaseIpSync();
    if (Platform.isAndroid && forceEmulatorMode) {
      debugPrint(
        '📡 ApiConfig: Force emulator mode - using: ${getAndroidEmulatorUrl()}',
      );
      return getAndroidEmulatorUrl();
    }
    final url = "http://$ip:8000/api";
    debugPrint('📡 ApiConfig: Computed base URL: $url');
    return url;
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
        if (model.toLowerCase().contains(keyword)) {
          return true;
        }
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
      return false;
    } catch (e) {
      debugPrint('Error detecting emulator: $e');
      return false;
    }
  }

  /// ================================
  /// Standard headers
  /// ================================
  static Map<String, String> getStandardHeaders() => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

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
  /// ================================
  static String? buildImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;

    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    String baseUrl = getBaseUrl();
    if (baseUrl.endsWith('/api')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 4);
    }

    if (!baseUrl.endsWith('/') && !imagePath.startsWith('/')) {
      return '$baseUrl/$imagePath';
    } else if (baseUrl.endsWith('/') && imagePath.startsWith('/')) {
      return '$baseUrl${imagePath.substring(1)}';
    } else {
      return '$baseUrl$imagePath';
    }
  }
}
