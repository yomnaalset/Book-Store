import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_service.dart';

/// Service for managing borrowing delivery requests workflow
/// Handles accept/reject/start/complete delivery for borrowing requests
class BorrowingDeliveryService {
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

  /// Get all borrowing delivery requests assigned to the delivery manager
  /// Status: pending_delivery (ready for accept/reject)
  /// Supports optional status and search filtering
  static Future<Map<String, dynamic>> getAssignedBorrowRequests({
    String? status,
    String? search,
  }) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final headers = _getHeaders();
      debugPrint('BorrowingDeliveryService: Request headers: $headers');
      debugPrint(
        'BorrowingDeliveryService: Token: ${_authToken != null ? '${_authToken!.substring(0, 20)}...' : 'null'}',
      );

      // Build query parameters
      final queryParams = <String, String>{};
      if (status != null &&
          status.isNotEmpty &&
          status.toLowerCase() != 'all') {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '${ApiService.baseUrl}/borrow/delivery/orders/',
      ).replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      debugPrint(
        'BorrowingDeliveryService: Requesting with filters - status: $status, search: $search',
      );

      final response = await http.get(uri, headers: headers);

      debugPrint(
        'BorrowingDeliveryService: Get assigned requests response: ${response.statusCode}',
      );
      debugPrint('BorrowingDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint(
          'BorrowingDeliveryService: Response data type: ${data.runtimeType}',
        );
        debugPrint(
          'BorrowingDeliveryService: Response data keys: ${data is Map ? data.keys.toList() : 'Not a Map'}',
        );

        // The API returns: {"success": true, "data": [...]}
        final ordersList = data is List
            ? data
            : (data['data'] ?? data['results'] ?? data['orders'] ?? []);

        debugPrint(
          'BorrowingDeliveryService: Extracted orders count: ${ordersList.length}',
        );
        if (ordersList.isNotEmpty) {
          debugPrint(
            'BorrowingDeliveryService: First order sample: ${ordersList[0]}',
          );
        }

        return {'success': true, 'data': data, 'orders': ordersList};
      } else if (response.statusCode == 401) {
        return {
          'success': false,
          'message': 'Unauthorized: Please login again',
          'error_code': 'UNAUTHORIZED',
        };
      } else {
        try {
          final data = jsonDecode(response.body);
          return {
            'success': false,
            'message':
                data['message'] ??
                data['detail'] ??
                'Failed to fetch borrow requests',
            'error_code': 'FETCH_FAILED',
          };
        } catch (e) {
          return {
            'success': false,
            'message':
                'Failed to fetch borrow requests (${response.statusCode})',
            'error_code': 'FETCH_FAILED',
          };
        }
      }
    } catch (e) {
      debugPrint('BorrowingDeliveryService: Error fetching requests: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// Accept a borrowing delivery request
  /// This automatically changes delivery manager status to 'busy'
  /// Status transition: pending_delivery -> in_progress
  static Future<Map<String, dynamic>> acceptBorrowRequest(int orderId) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      // Accept the delivery by starting it
      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/borrow/delivery/orders/$orderId/start/',
        ),
        headers: _getHeaders(),
      );

      debugPrint(
        'BorrowingDeliveryService: Accept request response: ${response.statusCode}',
      );
      debugPrint('BorrowingDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Borrow delivery accepted successfully',
          'data': data['data'],
          'delivery_status': 'busy', // Automatically set to busy
          'order_status': 'in_delivery',
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to accept borrow request',
          'error_code': data['error_code'] ?? 'ACCEPT_FAILED',
          'errors': data['errors'],
        };
      }
    } catch (e) {
      debugPrint('BorrowingDeliveryService: Error accepting request: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// Reject a borrowing delivery request
  /// Delivery manager status remains unchanged
  static Future<Map<String, dynamic>> rejectBorrowRequest(
    int orderId,
    String rejectionReason,
  ) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final response = await http.post(
        Uri.parse(
          '${ApiService.baseUrl}/borrow/delivery/orders/$orderId/reject/',
        ),
        headers: _getHeaders(),
        body: jsonEncode({'rejection_reason': rejectionReason}),
      );

      debugPrint(
        'BorrowingDeliveryService: Reject request response: ${response.statusCode}',
      );
      debugPrint('BorrowingDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Borrow delivery rejected successfully',
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to reject borrow request',
          'error_code': 'REJECT_FAILED',
        };
      }
    } catch (e) {
      debugPrint('BorrowingDeliveryService: Error rejecting request: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// Start delivery for a borrowing order
  /// This marks that the book has been picked up and delivery has started
  /// Status transition: in_progress -> on_the_way
  /// Delivery manager status automatically changes to 'busy' (handled by Django)
  static Future<Map<String, dynamic>> startDelivery(
    int orderId,
    int deliveryManagerId,
  ) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      // Call the correct endpoint for starting delivery on a borrow order
      // Endpoint: /api/borrow/delivery/orders/<order_id>/start/
      // Note: baseUrl already includes /api, so we don't add it again
      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/borrow/delivery/orders/$orderId/start/',
        ),
        headers: _getHeaders(),
      );

      debugPrint(
        'BorrowingDeliveryService: Start delivery response: ${response.statusCode}',
      );
      debugPrint('BorrowingDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Delivery started successfully',
          'order_status': data['order_status'] ?? 'in_delivery',
          'delivery_manager_status': data['delivery_manager_status'] ?? 'busy',
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message':
              data['error'] ?? data['message'] ?? 'Failed to start delivery',
          'error_code': 'START_FAILED',
          'errors': data['errors'],
        };
      }
    } catch (e) {
      debugPrint('BorrowingDeliveryService: Error starting delivery: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// Complete delivery for a borrowing order
  /// This marks that the book has been delivered to the customer
  /// Status transition: on_the_way -> delivered
  /// Delivery manager status automatically returns to 'online'
  static Future<Map<String, dynamic>> completeDelivery(int orderId) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/borrow/delivery/orders/$orderId/complete/',
        ),
        headers: _getHeaders(),
      );

      debugPrint(
        'BorrowingDeliveryService: Complete delivery response: ${response.statusCode}',
      );
      debugPrint('BorrowingDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Delivery completed successfully',
          'data': data['data'],
          'order_status': 'delivered',
          'delivery_status': 'online', // Automatically returns to online
        };
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to complete delivery',
          'error_code': 'COMPLETE_FAILED',
          'errors': data['errors'],
        };
      }
    } catch (e) {
      debugPrint('BorrowingDeliveryService: Error completing delivery: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// Get my delivery assignments (in-progress and completed)
  /// This helps track current delivery status
  static Future<Map<String, dynamic>> getMyAssignments() async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/borrow/delivery/orders/?status=in_delivery,delivered',
        ),
        headers: _getHeaders(),
      );

      debugPrint(
        'BorrowingDeliveryService: Get my assignments response: ${response.statusCode}',
      );
      debugPrint('BorrowingDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'data': data is List
              ? data
              : (data['results'] ?? data['orders'] ?? []),
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch assignments',
          'error_code': 'FETCH_FAILED',
        };
      }
    } catch (e) {
      debugPrint('BorrowingDeliveryService: Error fetching assignments: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  /// Check current delivery status to sync with server
  /// This ensures the UI reflects the actual server state
  static Future<String?> getCurrentDeliveryStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/delivery-profiles/current_status/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data']['delivery_status'];
        }
      }
      return null;
    } catch (e) {
      debugPrint('BorrowingDeliveryService: Error getting delivery status: $e');
      return null;
    }
  }

  /// Get detailed information about a specific borrowing order
  static Future<Map<String, dynamic>> getBorrowOrderDetails(int orderId) async {
    if (_authToken == null) {
      return {
        'success': false,
        'message': 'No authentication token available',
        'error_code': 'NO_TOKEN',
      };
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/delivery/orders/$orderId/'),
        headers: _getHeaders(),
      );

      debugPrint(
        'BorrowingDeliveryService: Get order details response: ${response.statusCode}',
      );
      debugPrint('BorrowingDeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': 'Failed to fetch order details',
          'error_code': 'FETCH_FAILED',
        };
      }
    } catch (e) {
      debugPrint('BorrowingDeliveryService: Error fetching order details: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }
}
