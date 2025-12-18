import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_client.dart';
import '../models/order.dart';

class OrdersService {
  final String baseUrl;
  String? _authToken;

  OrdersService({required this.baseUrl});

  // Get the effective base URL (use ApiClient's baseUrl if empty)
  String get effectiveBaseUrl => baseUrl.isEmpty ? ApiClient.baseUrl : baseUrl;

  // Set authentication token
  void setAuthToken(String? token) {
    _authToken = token;
  }

  // Get orders by type (purchase, borrowing, return_collection) for delivery managers
  // with optional additional filters
  Future<List<Order>> getOrdersByType(
    String orderType, {
    String? status,
    String? search,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{'order_type': orderType};
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      // Build URL with query parameters
      final queryString = queryParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final url = '/delivery/orders/?$queryString';

      final response = await ApiClient.get(
        url,
        token: _authToken,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);

        if (kDebugMode) {
          debugPrint(
            'OrdersService: Response data type: ${responseData.runtimeType}',
          );
          debugPrint('OrdersService: Response data: $responseData');
        }

        // Handle both list and map responses
        List<dynamic> ordersData;
        try {
          // Try to access as map first
          if (responseData is Map<String, dynamic>) {
            ordersData =
                responseData['results'] ?? responseData['orders'] ?? [];
            if (kDebugMode) {
              debugPrint(
                'OrdersService: Parsing as map, ${ordersData.length} items',
              );
            }
          } else if (responseData is List) {
            // If that fails, treat as list
            ordersData = responseData;
            if (kDebugMode) {
              debugPrint(
                'OrdersService: Parsing as list, ${ordersData.length} items',
              );
            }
          } else {
            // Handle unexpected data types
            if (kDebugMode) {
              debugPrint(
                'OrdersService: Unexpected response data type: ${responseData.runtimeType}',
              );
              debugPrint('OrdersService: Response data: $responseData');
            }
            throw Exception(
              'Unexpected response format: ${responseData.runtimeType}',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('OrdersService: Error parsing response: $e');
            debugPrint('OrdersService: Response data: $responseData');
          }
          throw Exception('Failed to parse orders response: $e');
        }

        return ordersData.map((json) {
          try {
            if (kDebugMode) {
              debugPrint(
                'OrdersService: Parsing order item: ${json.runtimeType}',
              );
              debugPrint('OrdersService: Order item data: $json');
            }

            // Ensure json is a Map before passing to Order.fromJson
            if (json is! Map<String, dynamic>) {
              throw Exception('Order item is not a Map: ${json.runtimeType}');
            }

            return Order.fromJson(json);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('OrdersService: Error parsing individual order: $e');
              debugPrint('OrdersService: Problematic order data: $json');
            }
            rethrow;
          }
        }).toList();
      } else {
        final errorData = ApiClient.handleResponse(response);
        String errorMessage = 'Failed to load orders';

        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['error'] ?? 'Request failed';
        } else {
          errorMessage = 'Request failed with status ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  // Get all orders for the current user with optional filters
  Future<List<Order>> getOrders({
    String? status,
    String? orderType,
    String? search,
  }) async {
    try {
      // Build query parameters
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
        queryParams['status'] = status;
      }
      if (orderType != null && orderType.isNotEmpty && orderType.toLowerCase() != 'all') {
        queryParams['order_type'] = orderType;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      // Build URL with query parameters
      String url = '/delivery/orders/';
      if (queryParams.isNotEmpty) {
        final queryString = queryParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        url = '$url?$queryString';
      }

      final response = await ApiClient.get(
        url,
        token: _authToken,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);

        if (kDebugMode) {
          debugPrint(
            'OrdersService: Response data type: ${responseData.runtimeType}',
          );
          debugPrint('OrdersService: Response data: $responseData');
        }

        // Handle both list and map responses
        List<dynamic> ordersData;
        try {
          // Try to access as map first
          if (responseData is Map<String, dynamic>) {
            ordersData = responseData['orders'] ?? [];
            if (kDebugMode) {
              debugPrint(
                'OrdersService: Parsing as map, ${ordersData.length} items',
              );
            }
          } else if (responseData is List) {
            // If that fails, treat as list
            ordersData = responseData;
            if (kDebugMode) {
              debugPrint(
                'OrdersService: Parsing as list, ${ordersData.length} items',
              );
            }
          } else {
            // Handle unexpected data types
            if (kDebugMode) {
              debugPrint(
                'OrdersService: Unexpected response data type: ${responseData.runtimeType}',
              );
              debugPrint('OrdersService: Response data: $responseData');
            }
            throw Exception(
              'Unexpected response format: ${responseData.runtimeType}',
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('OrdersService: Error parsing response: $e');
            debugPrint('OrdersService: Response data: $responseData');
          }
          throw Exception('Failed to parse orders response: $e');
        }

        return ordersData.map((json) {
          try {
            if (kDebugMode) {
              debugPrint(
                'OrdersService: Parsing order item: ${json.runtimeType}',
              );
              debugPrint('OrdersService: Order item data: $json');
            }

            // Ensure json is a Map before passing to Order.fromJson
            if (json is! Map<String, dynamic>) {
              throw Exception('Order item is not a Map: ${json.runtimeType}');
            }

            return Order.fromJson(json);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('OrdersService: Error parsing individual order: $e');
              debugPrint('OrdersService: Problematic order data: $json');
            }
            rethrow;
          }
        }).toList();
      } else {
        final errorData = ApiClient.handleResponse(response);
        String errorMessage = 'Failed to load orders';

        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['error'] ?? 'Request failed';
        } else {
          errorMessage = 'Request failed with status ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to load orders: $e');
    }
  }

  // Get order by ID
  Future<Order> getOrderById(String orderId) async {
    try {
      final response = await ApiClient.get(
        '/delivery/orders/$orderId/',
        token: _authToken,
      );

      if (ApiClient.isSuccess(response)) {
        final Map<String, dynamic> data = ApiClient.handleResponse(response);
        return Order.fromJson(data);
      } else {
        final errorData = ApiClient.handleResponse(response);
        String errorMessage = 'Failed to load order';

        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['error'] ?? 'Request failed';
        } else {
          errorMessage = 'Request failed with status ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to load order: $e');
    }
  }

  // Cancel order
  Future<void> cancelOrder(String orderId) async {
    try {
      final response = await http.post(
        Uri.parse('$effectiveBaseUrl/delivery/orders/$orderId/update-status/'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
        body: json.encode({'status': 'cancelled'}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to cancel order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Track order
  Future<Map<String, dynamic>> trackOrder(String orderNumber) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$effectiveBaseUrl/delivery/customer/orders/track/$orderNumber/',
        ),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to track order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get order delivery contact
  Future<Map<String, dynamic>> getOrderDeliveryContact(String orderId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$effectiveBaseUrl/delivery/customer/orders/$orderId/delivery-contact/',
        ),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Failed to get delivery contact: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Create order from payment
  Future<Order> createOrderFromPayment(Map<String, dynamic> paymentData) async {
    try {
      final response = await http.post(
        Uri.parse('$effectiveBaseUrl/delivery/orders/create-from-payment/'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
        body: json.encode(paymentData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Order.fromJson(data);
      } else {
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update order status
  Future<void> updateOrderStatus(String orderId, String status) async {
    try {
      final response = await http.post(
        Uri.parse('$effectiveBaseUrl/delivery/orders/$orderId/update-status/'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
        body: json.encode({'status': status}),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to update order status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update delivery assignment status (for delivery managers)
  // Accept delivery assignment using the new dedicated endpoint
  // POST /api/delivery/assignments/{id}/accept
  Future<Map<String, dynamic>> acceptDeliveryAssignment(int assignmentId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delivery/assignments/$assignmentId/accept/'),
        headers: {
          'Content-Type': 'application/json',
          if (_authToken != null) 'Authorization': 'Bearer $_authToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Assignment accepted successfully',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? data['message'] ?? 'Failed to accept assignment',
          'error_code': data['error_code'] ?? 'ACCEPT_FAILED',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
        'error_code': 'NETWORK_ERROR',
      };
    }
  }

  Future<void> updateDeliveryAssignmentStatus(
    int assignmentId,
    String status, {
    String? failureReason,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (_authToken != null && _authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final body = <String, dynamic>{'status': status};
      if (failureReason != null && failureReason.isNotEmpty) {
        body['failure_reason'] = failureReason;
      }

      final response = await http.patch(
        Uri.parse(
          '$effectiveBaseUrl/delivery/assignments/$assignmentId/update-status/',
        ),
        headers: headers,
        body: json.encode(body),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorBody = json.decode(response.body);
        throw Exception(
          errorBody['error'] ??
              'Failed to update delivery assignment status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Complete delivery (for delivery managers)
  Future<void> completeDelivery(int orderId) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (_authToken != null && _authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final response = await http.patch(
        Uri.parse(
          '$effectiveBaseUrl/delivery/orders/$orderId/complete_delivery/',
        ),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorBody = json.decode(response.body);
        throw Exception(
          errorBody['error'] ??
              'Failed to complete delivery: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get orders ready for delivery
  Future<List<Order>> getOrdersReadyForDelivery() async {
    try {
      final response = await http.get(
        Uri.parse('$effectiveBaseUrl/delivery/orders/ready-for-delivery/'),
        headers: {
          'Content-Type': 'application/json',
          // Add authorization header if needed
          // 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Order.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load orders ready for delivery: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Add notes to an order
  Future<void> addOrderNotes(String orderId, String notes) async {
    try {
      final response = await ApiClient.post(
        '/delivery/activities/log/note/',
        body: {'order_id': orderId, 'notes_content': notes, 'action': 'add'},
        token: _authToken,
      );

      if (!ApiClient.isSuccess(response)) {
        final errorData = ApiClient.handleResponse(response);
        String errorMessage = 'Failed to add notes';

        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['error'] ?? 'Request failed';
        } else {
          errorMessage = 'Request failed with status ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to add notes: $e');
    }
  }

  // Edit notes for an order
  Future<void> editOrderNotes(String orderId, String notes, {int? noteId}) async {
    try {
      final body = <String, dynamic>{
        'order_id': orderId,
        'notes_content': notes,
        'action': 'edit',
      };
      if (noteId != null) {
        body['note_id'] = noteId;
      }
      
      final response = await ApiClient.post(
        '/delivery/activities/log/note/',
        body: body,
        token: _authToken,
      );

      if (!ApiClient.isSuccess(response)) {
        final errorData = ApiClient.handleResponse(response);
        String errorMessage = 'Failed to edit notes';

        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['error'] ?? 'Request failed';
        } else {
          errorMessage = 'Request failed with status ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to edit notes: $e');
    }
  }

  // Delete notes for an order
  Future<void> deleteOrderNotes(String orderId, {int? noteId}) async {
    try {
      final body = <String, dynamic>{
        'order_id': orderId,
        'action': 'delete',
      };
      if (noteId != null) {
        body['note_id'] = noteId;
      }
      
      final response = await ApiClient.post(
        '/delivery/activities/log/note/',
        body: body,
        token: _authToken,
      );

      if (!ApiClient.isSuccess(response)) {
        final errorData = ApiClient.handleResponse(response);
        String errorMessage = 'Failed to delete notes';

        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['error'] ?? 'Request failed';
        } else {
          errorMessage = 'Request failed with status ${response.statusCode}';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to delete notes: $e');
    }
  }

  // Get order delivery location (for customers and admins)
  Future<Map<String, dynamic>> getOrderDeliveryLocation(int orderId) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (_authToken != null && _authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer $_authToken';
      }

      final response = await http.get(
        Uri.parse(
          '$effectiveBaseUrl/delivery/orders/$orderId/delivery-location/',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(
          errorBody['error'] ??
              'Failed to get delivery location: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get order activities (for admins)
  Future<List<Map<String, dynamic>>> getOrderActivities(int orderId) async {
    try {
      final response = await ApiClient.get(
        '/delivery/activities/order/$orderId/',
        token: _authToken,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        
        if (responseData is Map<String, dynamic>) {
          final activities = responseData['activities'] as List<dynamic>? ?? [];
          return activities.cast<Map<String, dynamic>>();
        } else if (responseData is List) {
          return responseData.cast<Map<String, dynamic>>();
        } else {
          return [];
        }
      } else {
        final errorData = ApiClient.handleResponse(response);
        String errorMessage = 'Failed to fetch activities';

        if (errorData is Map<String, dynamic>) {
          errorMessage = errorData['error'] ?? 'Request failed';
        }

        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to fetch activities: $e');
    }
  }
}
