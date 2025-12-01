import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_service.dart';

/// Service for managing delivery status operations
class DeliveryStatusService {
  static String? _authToken;

  /// Set authentication token
  static void setToken(String? token) {
    _authToken = token;
  }

  /// Get current delivery status from server
  static Future<Map<String, dynamic>?> getCurrentStatus() async {
    if (_authToken == null || _authToken!.isEmpty) {
      debugPrint('DeliveryStatusService: No auth token available - returning null');
      // Return null silently instead of showing error
      // The provider will handle the case when status data is null
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/delivery-profiles/current_status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }

      debugPrint(
        'DeliveryStatusService: Failed to get current status: ${response.statusCode}',
      );
      return null;
    } catch (e) {
      debugPrint('DeliveryStatusService: Error getting current status: $e');
      return null;
    }
  }

  /// Update delivery status with proper validation
  /// Note: For 'busy' status, use updateStatusToBusy() instead
  static Future<Map<String, dynamic>> updateStatus(String newStatus) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    // Validate status - only allow online/offline for manual changes
    if (!['online', 'offline'].contains(newStatus)) {
      return {
        'success': false,
        'message':
            'Invalid status. You can only manually change between online and offline.',
        'error_code': 'INVALID_STATUS',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/delivery-profiles/update_status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({'delivery_status': newStatus}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
          'current_status': data['data']['delivery_status'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to update status',
          'error_code': data['error_code'] ?? 'UPDATE_FAILED',
          'current_status': data['current_status'],
        };
      }
    } catch (e) {
      debugPrint('DeliveryStatusService: Error updating status: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// Refresh status from server (for automatic sync)
  static Future<String?> refreshStatusFromServer() async {
    final statusData = await getCurrentStatus();
    if (statusData != null) {
      return statusData['delivery_status'];
    }
    return null;
  }

  /// Reset status if no active deliveries (safety mechanism)
  static Future<Map<String, dynamic>> resetStatusIfNoActiveDeliveries() async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/delivery-profiles/reset_status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'data': data['data'],
          'current_status': data['data']['delivery_status'],
          'was_reset': data['data']['was_reset'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to reset status',
          'error_code': 'RESET_FAILED',
          'current_status': data['data']?['delivery_status'],
        };
      }
    } catch (e) {
      debugPrint('DeliveryStatusService: Error resetting status: $e');
      return {
        'success': false,
        'message': 'Network error occurred',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// Check if manual status change is allowed
  static Future<bool> canChangeStatusManually() async {
    final statusData = await getCurrentStatus();
    if (statusData != null) {
      return statusData['can_change_manually'] ?? false;
    }
    return false;
  }

  /// Update status to busy (for system use when accepting/starting delivery)
  /// This calls the delivery update-status endpoint
  static Future<Map<String, dynamic>> updateStatusToBusy() async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      // Use the delivery manager status update endpoint
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/delivery/managers/update-status/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({'status': 'busy'}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data.get('success') == true) {
        // After updating, refresh from current_status endpoint
        final refreshedStatus = await getCurrentStatus();
        return {
          'success': true,
          'message': data['message'] ?? 'Status updated to busy',
          'current_status': refreshedStatus?['delivery_status'] ?? 'busy',
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? data['error'] ?? 'Failed to update status',
          'error_code': data['error_code'] ?? 'UPDATE_FAILED',
        };
      }
    } catch (e) {
      debugPrint('DeliveryStatusService: Error updating status to busy: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }
}
