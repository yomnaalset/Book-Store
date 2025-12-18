import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:readgo/core/services/api_config.dart';

class LocationManagementService {
  static String get _baseUrl => ApiConfig.getBaseUrl();

  /// Update delivery manager's location using the new delivery profile API
  static Future<Map<String, dynamic>> updateLocation({
    required String token,
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/delivery-profiles/update_location/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (address != null) 'address': address,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error':
              data['error'] ?? data['message'] ?? 'Failed to update location',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Get delivery manager's current location using the new delivery profile API
  static Future<Map<String, dynamic>> getCurrentLocation({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/delivery-profiles/my_profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? data['message'] ?? 'Failed to get location',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Get specific delivery manager's location (for admins/customers)
  static Future<Map<String, dynamic>> getDeliveryManagerLocation({
    required String token,
    required int deliveryManagerId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/delivery-profiles/$deliveryManagerId/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error':
              data['error'] ??
              data['message'] ??
              'Failed to get delivery manager location',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Update delivery manager's status using the new delivery profile API
  static Future<Map<String, dynamic>> updateDeliveryStatus({
    required String token,
    required String status, // 'online', 'offline', 'busy'
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/delivery-profiles/update_status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'delivery_status': status}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error':
              data['error'] ??
              data['message'] ??
              'Failed to update delivery status',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Update tracking status using the new delivery profile API
  static Future<Map<String, dynamic>> updateTrackingStatus({
    required String token,
    required bool isTrackingActive,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/delivery-profiles/update_tracking/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'is_tracking_active': isTrackingActive}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error':
              data['error'] ??
              data['message'] ??
              'Failed to update tracking status',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Get all online delivery managers (for admin use)
  static Future<Map<String, dynamic>> getOnlineDeliveryManagers({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/delivery-profiles/online_managers/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error':
              data['error'] ??
              data['message'] ??
              'Failed to get online delivery managers',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }

  /// Get all available delivery managers (for admin use)
  static Future<Map<String, dynamic>> getAvailableDeliveryManagers({
    required String token,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/delivery-profiles/available_managers/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error':
              data['error'] ??
              data['message'] ??
              'Failed to get available delivery managers',
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: ${e.toString()}'};
    }
  }
}
