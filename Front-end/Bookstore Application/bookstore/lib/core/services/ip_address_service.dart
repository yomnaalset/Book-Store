import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service for managing server IP address configuration
/// Stores IP address in SharedPreferences for dynamic backend configuration
class IpAddressService {
  static const String _ipAddressKey = 'server_ip_address';
  static const String _defaultIpAddress = '192.168.1.106';

  /// Get the stored IP address, or return default if not set
  static Future<String> getIpAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedIp = prefs.getString(_ipAddressKey);
      if (storedIp != null && storedIp.isNotEmpty) {
        debugPrint('IpAddressService: Using stored IP: $storedIp');
        return storedIp;
      }
      debugPrint(
        'IpAddressService: No stored IP found, using default: $_defaultIpAddress',
      );
      return _defaultIpAddress;
    } catch (e) {
      debugPrint('IpAddressService: Error getting IP address: $e');
      return _defaultIpAddress;
    }
  }

  /// Save IP address to SharedPreferences
  static Future<bool> saveIpAddress(String ipAddress) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.setString(_ipAddressKey, ipAddress);
      if (success) {
        debugPrint(
          'IpAddressService: IP address saved successfully: $ipAddress',
        );
      } else {
        debugPrint('IpAddressService: Failed to save IP address');
      }
      return success;
    } catch (e) {
      debugPrint('IpAddressService: Error saving IP address: $e');
      return false;
    }
  }

  /// Validate IP address format using regex
  /// Supports IPv4 format: xxx.xxx.xxx.xxx (0-255 per octet)
  static bool isValidIpAddress(String ip) {
    if (ip.isEmpty) return false;

    // IPv4 regex pattern
    final ipv4Pattern = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$',
    );

    return ipv4Pattern.hasMatch(ip);
  }

  /// Clear stored IP address (reset to default)
  static Future<bool> clearIpAddress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final success = await prefs.remove(_ipAddressKey);
      if (success) {
        debugPrint('IpAddressService: IP address cleared');
      }
      return success;
    } catch (e) {
      debugPrint('IpAddressService: Error clearing IP address: $e');
      return false;
    }
  }
}
