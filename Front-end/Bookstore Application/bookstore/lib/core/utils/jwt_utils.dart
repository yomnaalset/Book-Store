import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Utility class for JWT token operations
class JwtUtils {
  /// Decode JWT token payload without verification
  /// Returns null if token is invalid
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        debugPrint('JwtUtils: Invalid token format');
        return null;
      }

      // Decode the payload (second part)
      final payload = parts[1];
      
      // Add padding if needed
      String normalizedPayload = payload;
      final padding = 4 - (payload.length % 4);
      if (padding != 4) {
        normalizedPayload += '=' * padding;
      }

      final decoded = utf8.decode(base64Url.decode(normalizedPayload));
      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('JwtUtils: Error decoding token: $e');
      return null;
    }
  }

  /// Check if token is expired
  /// Returns true if token is expired or invalid
  static bool isTokenExpired(String token) {
    final payload = decodePayload(token);
    if (payload == null) return true;

    final exp = payload['exp'];
    if (exp == null) return true;

    // exp is in seconds since epoch
    final expirationDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    final now = DateTime.now();
    
    // Consider token expired if it expires within the next 5 minutes
    // This gives us a buffer to refresh before actual expiration
    final bufferTime = const Duration(minutes: 5);
    return now.add(bufferTime).isAfter(expirationDate);
  }

  /// Get token expiration date
  static DateTime? getTokenExpiration(String token) {
    final payload = decodePayload(token);
    if (payload == null) return null;

    final exp = payload['exp'];
    if (exp == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }

  /// Get time until token expires
  /// Returns null if token is invalid or already expired
  static Duration? getTimeUntilExpiration(String token) {
    final expiration = getTokenExpiration(token);
    if (expiration == null) return null;

    final now = DateTime.now();
    if (now.isAfter(expiration)) return null;

    return expiration.difference(now);
  }

  /// Check if token should be refreshed soon (within 1 hour)
  static bool shouldRefreshToken(String token) {
    final timeUntilExpiration = getTimeUntilExpiration(token);
    if (timeUntilExpiration == null) return true;

    // Refresh if token expires within 1 hour
    return timeUntilExpiration.inHours < 1;
  }

  /// Get user ID from token
  static int? getUserId(String token) {
    final payload = decodePayload(token);
    if (payload == null) return null;

    final userId = payload['user_id'];
    if (userId == null) return null;

    return userId is int ? userId : int.tryParse(userId.toString());
  }
}

