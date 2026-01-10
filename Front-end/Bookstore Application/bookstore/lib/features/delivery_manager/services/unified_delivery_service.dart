import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_service.dart';

/// Service for managing unified delivery workflow (Purchase - Borrow - Return)
class UnifiedDeliveryService {
  static String? _authToken;

  /// Set authentication token
  static void setToken(String? token) {
    _authToken = token;
  }

  /// Get headers with authentication
  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_authToken != null) 'Authorization': 'Bearer $_authToken',
    };
  }

  /// 1️⃣ Get delivery list (Delivery Requests / All Deliveries)
  /// Filters: status, delivery_type
  static Future<Map<String, dynamic>> getDeliveryList({
    String? status,
    String? deliveryType,
  }) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (deliveryType != null && deliveryType.isNotEmpty) {
        queryParams['type'] = deliveryType;
      }

      final uri = Uri.parse(
        '${ApiService.baseUrl}/delivery/delivery-requests/',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      debugPrint('UnifiedDeliveryService: Fetching deliveries from $uri');

      final response = await http.get(uri, headers: _getHeaders());

      debugPrint(
        'UnifiedDeliveryService: Response status: ${response.statusCode}',
      );
      debugPrint('UnifiedDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle different response formats
        List<dynamic> deliveriesList;
        if (data is List) {
          deliveriesList = data;
        } else if (data is Map<String, dynamic>) {
          // Check for paginated response
          final results = data['results'];
          if (results is List) {
            deliveriesList = results;
          } else if (results is Map<String, dynamic> &&
              results['results'] is List) {
            // Nested paginated response
            deliveriesList = results['results'] as List;
          } else {
            // Check for other possible keys
            deliveriesList = data['data'] is List ? data['data'] as List : [];
          }
        } else {
          deliveriesList = [];
        }

        return {'success': true, 'data': deliveriesList};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['error'] ??
              errorData['message'] ??
              'Failed to fetch deliveries',
          'error_code': 'FETCH_FAILED',
        };
      }
    } catch (e) {
      debugPrint('UnifiedDeliveryService: Error fetching deliveries: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// 3️⃣ Get delivery details
  static Future<Map<String, dynamic>> getDeliveryDetail(int deliveryId) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/delivery/delivery-requests/$deliveryId/',
      );

      debugPrint('UnifiedDeliveryService: Fetching delivery detail from $uri');

      final response = await http.get(uri, headers: _getHeaders());

      debugPrint(
        'UnifiedDeliveryService: Response status: ${response.statusCode}',
      );
      debugPrint('UnifiedDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['error'] ??
              errorData['message'] ??
              'Failed to fetch delivery details',
          'error_code': 'FETCH_FAILED',
        };
      }
    } catch (e) {
      debugPrint('UnifiedDeliveryService: Error fetching delivery detail: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// 5️⃣ Accept delivery request
  static Future<Map<String, dynamic>> acceptDelivery(int deliveryId) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/delivery/delivery-requests/$deliveryId/accept/',
      );

      debugPrint('UnifiedDeliveryService: Accepting delivery at $uri');

      final response = await http.post(uri, headers: _getHeaders());

      debugPrint(
        'UnifiedDeliveryService: Response status: ${response.statusCode}',
      );
      debugPrint('UnifiedDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Delivery request accepted successfully',
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['error'] ??
              errorData['message'] ??
              'Failed to accept delivery request',
          'error_code': 'ACCEPT_FAILED',
        };
      }
    } catch (e) {
      debugPrint('UnifiedDeliveryService: Error accepting delivery: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// 4️⃣ Reject delivery
  static Future<Map<String, dynamic>> rejectDelivery(
    int deliveryId,
    String rejectionReason,
  ) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    if (rejectionReason.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Rejection reason is required',
        'error_code': 'VALIDATION_ERROR',
      };
    }

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/delivery/delivery-requests/$deliveryId/reject/',
      );

      debugPrint('UnifiedDeliveryService: Rejecting delivery at $uri');
      debugPrint('UnifiedDeliveryService: Rejection reason: $rejectionReason');

      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({'rejection_reason': rejectionReason}),
      );

      debugPrint(
        'UnifiedDeliveryService: Response status: ${response.statusCode}',
      );
      debugPrint('UnifiedDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Delivery rejected successfully',
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['error'] ??
              errorData['message'] ??
              'Failed to reject delivery',
          'error_code': 'REJECT_FAILED',
        };
      }
    } catch (e) {
      debugPrint('UnifiedDeliveryService: Error rejecting delivery: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// 6️⃣ Start delivery
  static Future<Map<String, dynamic>> startDelivery(int deliveryId) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/delivery/delivery-requests/$deliveryId/start/',
      );

      debugPrint('UnifiedDeliveryService: Starting delivery at $uri');

      final response = await http.post(uri, headers: _getHeaders());

      debugPrint(
        'UnifiedDeliveryService: Response status: ${response.statusCode}',
      );
      debugPrint('UnifiedDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Delivery started successfully',
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['error'] ??
              errorData['message'] ??
              'Failed to start delivery',
          'error_code': 'START_FAILED',
        };
      }
    } catch (e) {
      debugPrint('UnifiedDeliveryService: Error starting delivery: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// 7️⃣ Update location
  static Future<Map<String, dynamic>> updateLocation(
    int deliveryId,
    double latitude,
    double longitude,
  ) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/delivery/delivery-requests/$deliveryId/update-location/',
      );

      debugPrint('UnifiedDeliveryService: Updating location at $uri');
      debugPrint(
        'UnifiedDeliveryService: Latitude: $latitude, Longitude: $longitude',
      );

      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      );

      debugPrint(
        'UnifiedDeliveryService: Response status: ${response.statusCode}',
      );
      debugPrint('UnifiedDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Location updated successfully',
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['error'] ??
              errorData['message'] ??
              'Failed to update location',
          'error_code': 'UPDATE_LOCATION_FAILED',
        };
      }
    } catch (e) {
      debugPrint('UnifiedDeliveryService: Error updating location: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// 8️⃣ Complete delivery
  static Future<Map<String, dynamic>> completeDelivery(
    int deliveryId, {
    String? notes,
  }) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/delivery/delivery-requests/$deliveryId/complete/',
      );

      debugPrint('UnifiedDeliveryService: Completing delivery at $uri');

      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: jsonEncode({
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        }),
      );

      debugPrint(
        'UnifiedDeliveryService: Response status: ${response.statusCode}',
      );
      debugPrint('UnifiedDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Delivery completed successfully',
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['error'] ??
              errorData['message'] ??
              'Failed to complete delivery',
          'error_code': 'COMPLETE_FAILED',
        };
      }
    } catch (e) {
      debugPrint('UnifiedDeliveryService: Error completing delivery: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// Update payment status for completed deliveries
  static Future<Map<String, dynamic>> updatePaymentStatus(
    int deliveryId, {
    bool? depositPaid,
    String? fineStatus,
    bool? fineIsPaid,
  }) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/delivery/delivery-requests/$deliveryId/update-payment-status/',
      );

      debugPrint('UnifiedDeliveryService: Updating payment status at $uri');

      final body = <String, dynamic>{};
      if (depositPaid != null) body['deposit_paid'] = depositPaid;
      if (fineStatus != null) body['fine_status'] = fineStatus;
      if (fineIsPaid != null) body['fine_is_paid'] = fineIsPaid;

      final response = await http.patch(
        uri,
        headers: _getHeaders(),
        body: jsonEncode(body),
      );

      debugPrint(
        'UnifiedDeliveryService: Response status: ${response.statusCode}',
      );
      debugPrint('UnifiedDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': 'Payment status updated successfully',
          'data': data,
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              errorData['error'] ??
              errorData['message'] ??
              'Failed to update payment status',
          'error_code': 'UPDATE_FAILED',
        };
      }
    } catch (e) {
      debugPrint('UnifiedDeliveryService: Error updating payment status: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }
}
