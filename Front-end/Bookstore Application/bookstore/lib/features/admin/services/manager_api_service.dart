import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import '../models/category.dart';
import '../models/author.dart';
import '../models/book.dart';
import '../models/discount.dart';
import '../models/book_discount.dart';
import '../models/ad.dart';
import '../models/complaint.dart';
import '../models/dashboard_card.dart';
import '../../orders/models/order.dart';
import '../models/delivery_request.dart';
import '../models/delivery_assignment.dart' as admin_delivery;
import '../models/delivery_order.dart';
import '../models/borrow_request.dart';
import '../models/borrow_extension.dart';
import '../models/borrow_fine.dart';
import '../models/delivery_agent.dart';
import '../models/notification.dart';
import '../models/library.dart';

// Utility function to create a URI without a trailing question mark when no parameters are provided
Uri createUri(String baseUrl, Map<String, String> queryParams) {
  if (queryParams.isEmpty) {
    return Uri.parse(baseUrl);
  } else {
    return Uri.parse(baseUrl).replace(queryParameters: queryParams);
  }
}

class ManagerApiService {
  final String baseUrl;
  final Map<String, String> headers;
  final String Function()? getAuthToken;
  final String Function()? getRefreshToken;
  final Function(String)? onTokenRefreshed;
  String? _cachedToken;

  ManagerApiService({
    required this.baseUrl,
    required this.headers,
    this.getAuthToken,
    this.getRefreshToken,
    this.onTokenRefreshed,
  });

  // Set the authentication token directly
  void setToken(String? token) {
    _cachedToken = token;
    debugPrint(
      'DEBUG: ManagerApiService setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
  }

  // Check if we have a valid token
  bool get isAuthenticated => _cachedToken != null && _cachedToken!.isNotEmpty;

  // Attempt to refresh the token
  Future<bool> _refreshToken() async {
    try {
      if (getRefreshToken == null) {
        debugPrint('DEBUG: No refresh token callback available');
        return false;
      }

      final refreshToken = getRefreshToken!();
      if (refreshToken.isEmpty) {
        debugPrint('DEBUG: No refresh token available');
        return false;
      }

      debugPrint('DEBUG: Attempting to refresh token...');

      // Use the correct JWT refresh endpoint: /api/token/refresh/
      final response = await http.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refresh': refreshToken}),
      );

      debugPrint(
        'DEBUG: Token refresh response status: ${response.statusCode}',
      );
      debugPrint('DEBUG: Token refresh response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access'];

        if (newAccessToken != null && newAccessToken is String) {
          _cachedToken = newAccessToken;
          debugPrint('DEBUG: Token refreshed successfully');

          // Notify the callback about the new token
          if (onTokenRefreshed != null) {
            onTokenRefreshed!(newAccessToken);
          }

          return true;
        } else {
          debugPrint(
            'DEBUG: Token refresh failed: No access token in response',
          );
          return false;
        }
      } else {
        debugPrint(
          'DEBUG: Token refresh failed with status: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('DEBUG: Token refresh error: $e');
      return false;
    }
  }

  // Get headers with authentication token
  Map<String, String> _getHeaders() {
    final authHeaders = Map<String, String>.from(headers);

    // First try to use the cached token
    String? token = _cachedToken;

    // If no cached token, try the getAuthToken function
    if ((token == null || token.isEmpty) && getAuthToken != null) {
      token = getAuthToken!();
      debugPrint(
        'DEBUG: Got token from getAuthToken function: ${token.substring(0, 20)}...',
      );
    }

    if (token != null && token.isNotEmpty) {
      authHeaders['Authorization'] = 'Bearer $token';
      debugPrint('DEBUG: Token added to headers: ${token.substring(0, 20)}...');
      debugPrint(
        'DEBUG: Full Authorization header: Bearer ${token.substring(0, 50)}...',
      );
    } else {
      debugPrint('DEBUG: No token available for API request');
      debugPrint(
        'DEBUG: _cachedToken: ${_cachedToken != null ? '${_cachedToken!.substring(0, 20)}...' : 'null'}',
      );
      debugPrint(
        'DEBUG: getAuthToken function: ${getAuthToken != null ? 'available' : 'null'}',
      );
    }

    return authHeaders;
  }

  // Helper method to make HTTP requests with automatic token refresh
  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    String? body,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$endpoint',
    ).replace(queryParameters: queryParams);

    final requestHeaders = _getHeaders();
    if (headers != null) {
      requestHeaders.addAll(headers);
    }

    http.Response response;

    if (method.toUpperCase() == 'GET') {
      response = await http.get(uri, headers: requestHeaders);
    } else if (method.toUpperCase() == 'POST') {
      response = await http.post(uri, headers: requestHeaders, body: body);
    } else if (method.toUpperCase() == 'PUT') {
      response = await http.put(uri, headers: requestHeaders, body: body);
    } else if (method.toUpperCase() == 'PATCH') {
      response = await http.patch(uri, headers: requestHeaders, body: body);
    } else if (method.toUpperCase() == 'DELETE') {
      response = await http.delete(uri, headers: requestHeaders);
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }

    // If we get a 401 and have refresh token capability, try to refresh
    if (response.statusCode == 401 && getRefreshToken != null) {
      debugPrint('DEBUG: Received 401, attempting token refresh...');
      final refreshSuccess = await _refreshToken();

      if (refreshSuccess) {
        // Retry the request with the new token
        final newHeaders = _getHeaders();
        if (headers != null) {
          newHeaders.addAll(headers);
        }

        if (method.toUpperCase() == 'GET') {
          response = await http.get(uri, headers: newHeaders);
        } else if (method.toUpperCase() == 'POST') {
          response = await http.post(uri, headers: newHeaders, body: body);
        } else if (method.toUpperCase() == 'PUT') {
          response = await http.put(uri, headers: newHeaders, body: body);
        } else if (method.toUpperCase() == 'PATCH') {
          response = await http.patch(uri, headers: newHeaders, body: body);
        } else if (method.toUpperCase() == 'DELETE') {
          response = await http.delete(uri, headers: newHeaders);
        }

        debugPrint(
          'DEBUG: Retried request after token refresh, status: ${response.statusCode}',
        );
      }
    }

    return response;
  }

  // Delivery Management
  Future<DeliveryRequestsResponse> getDeliveryRequests({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(
      '$baseUrl/delivery/requests/',
    ).replace(queryParameters: queryParams);

    debugPrint('DEBUG: ManagerApiService getDeliveryRequests - URL: $uri');
    debugPrint(
      'DEBUG: ManagerApiService getDeliveryRequests - Search: $search',
    );
    debugPrint(
      'DEBUG: ManagerApiService getDeliveryRequests - Status: $status',
    );

    final response = await http.get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Handle different response structures
      List<dynamic> results;
      int totalPages = 1;
      int totalItems = 0;

      if (data is List) {
        // If the response is directly a list (no pagination)
        results = data;
        totalItems = data.length;
        totalPages = 1;
      } else if (data is Map<String, dynamic>) {
        // If the response has pagination structure
        results = data['results'] ?? data['data'] ?? [];
        totalPages = data['total_pages'] ?? data['totalPages'] ?? 1;
        totalItems =
            data['count'] ??
            data['total'] ??
            data['totalItems'] ??
            results.length;
      } else {
        results = [];
      }

      return DeliveryRequestsResponse(
        results: results.map((json) => DeliveryRequest.fromJson(json)).toList(),
        totalPages: totalPages,
        totalItems: totalItems,
      );
    } else {
      throw Exception(
        'Failed to load delivery requests: ${response.statusCode}',
      );
    }
  }

  Future<DeliveryAssignmentsResponse> getDeliveryAssignments({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(
      '$baseUrl/delivery/assignments/',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return DeliveryAssignmentsResponse(
        results: (data['results'] as List? ?? [])
            .map((json) => admin_delivery.DeliveryAssignment.fromJson(json))
            .toList(),
        totalPages: data['total_pages'] ?? 1,
        totalItems: data['count'] ?? 0,
      );
    } else {
      throw Exception(
        'Failed to load delivery assignments: ${response.statusCode}',
      );
    }
  }

  Future<DeliveryOrdersResponse> getDeliveryOrders({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(
      '$baseUrl/delivery/orders/',
    ).replace(queryParameters: queryParams);
    final response = await http.get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return DeliveryOrdersResponse(
        results: (data['results'] as List? ?? [])
            .map((json) => DeliveryOrder.fromJson(json))
            .toList(),
        totalPages: data['total_pages'] ?? 1,
        totalItems: data['count'] ?? 0,
      );
    } else {
      throw Exception('Failed to load delivery orders: ${response.statusCode}');
    }
  }

  Future<admin_delivery.DeliveryAssignment> createDeliveryAssignment({
    required int orderId,
    required int deliveryPersonId,
    required String deliveryAddress,
    required DateTime scheduledDate,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/delivery/assignments/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({
        'order_id': orderId,
        'delivery_person_id': deliveryPersonId,
        'delivery_address': deliveryAddress,
        'scheduled_date': scheduledDate.toIso8601String(),
        'notes': notes,
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      return admin_delivery.DeliveryAssignment.fromJson(data);
    } else {
      throw Exception(
        'Failed to create delivery assignment: ${response.statusCode}',
      );
    }
  }

  Future<void> updateDeliveryStatus(
    int assignmentId,
    String status, {
    String? notes,
    String? failureReason,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (notes != null) body['notes'] = notes;
    if (failureReason != null) body['failure_reason'] = failureReason;

    final response = await http.patch(
      Uri.parse('$baseUrl/delivery/assignments/$assignmentId/update-status/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      final errorBody = response.body.isNotEmpty
          ? json.decode(response.body)
          : {};
      throw Exception(
        'Failed to update delivery status: ${response.statusCode} - ${errorBody['error'] ?? errorBody['message'] ?? response.body}',
      );
    }
  }

  Future<Map<String, dynamic>> getDeliveryTracking(int assignmentId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/delivery/assignments/$assignmentId/tracking/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'Failed to get delivery tracking: ${response.statusCode}',
      );
    }
  }

  // Orders Management
  Future<dynamic> getOrders({
    String? search,
    String? status,
    String? orderType,
  }) async {
    debugPrint('DEBUG: ManagerApiService.getOrders called with:');
    debugPrint('  - search: $search');
    debugPrint('  - status: $status');
    debugPrint('  - orderType: $orderType');

    final queryParams = <String, String>{};

    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (orderType != null && orderType.isNotEmpty) {
      queryParams['order_type'] = orderType;
    }

    final uri = createUri('$baseUrl/delivery/orders/', queryParams);

    debugPrint('DEBUG: ManagerApiService.getOrders - Final URL: $uri');
    debugPrint(
      'DEBUG: ManagerApiService.getOrders - Query params: $queryParams',
    );

    final response = await http.get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Handle different response formats
      if (data is List) {
        // Backend returns a list directly
        return data;
      } else if (data is Map<String, dynamic>) {
        // Backend returns a map response
        return data;
      } else {
        throw Exception('Unexpected response format from orders API');
      }
    } else {
      throw Exception('Failed to load orders: ${response.statusCode}');
    }
  }

  Future<Order> getOrder(int orderId) async {
    debugPrint('DEBUG: Fetching order with ID: $orderId');
    final response = await http.get(
      Uri.parse('$baseUrl/delivery/orders/$orderId/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint('DEBUG: Raw order data from API: ${json.encode(data)}');
      debugPrint('DEBUG: Discount code from API: ${data['discount_code']}');
      debugPrint('DEBUG: discount code from API: ${data['discount_code']}');
      return Order.fromJson(data);
    } else {
      debugPrint(
        'DEBUG: Failed to load order: ${response.statusCode}, ${response.body}',
      );
      throw Exception('Failed to load order: ${response.statusCode}');
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    final response = await _makeRequest(
      'PATCH',
      '/delivery/orders/$orderId/',
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update order status: ${response.statusCode}');
    }
  }

  // Start delivery for an assigned order (delivery manager only)
  Future<Map<String, dynamic>> startDelivery(int orderId) async {
    debugPrint('DEBUG: Starting delivery for order $orderId');

    final response = await _makeRequest(
      'PATCH',
      '/delivery/orders/$orderId/start_delivery/',
      headers: {'Content-Type': 'application/json'},
    );

    debugPrint('DEBUG: Start delivery response status: ${response.statusCode}');
    debugPrint('DEBUG: Start delivery response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ??
            'Failed to start delivery: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Complete delivery for an assigned order (delivery manager only)
  Future<Map<String, dynamic>> completeDelivery(int orderId) async {
    debugPrint('DEBUG: Completing delivery for order $orderId');

    final response = await _makeRequest(
      'PATCH',
      '/delivery/orders/$orderId/complete_delivery/',
      headers: {'Content-Type': 'application/json'},
    );

    debugPrint(
      'DEBUG: Complete delivery response status: ${response.statusCode}',
    );
    debugPrint('DEBUG: Complete delivery response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ??
            'Failed to complete delivery: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Approve order with delivery manager assignment
  Future<Map<String, dynamic>> approveOrder(
    int orderId,
    int deliveryManagerId,
  ) async {
    debugPrint(
      'DEBUG: Sending approve order request for order $orderId with delivery manager $deliveryManagerId',
    );

    final response = await _makeRequest(
      'PATCH',
      '/delivery/orders/$orderId/approve/',
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'delivery_manager_id': deliveryManagerId}),
    );

    debugPrint('DEBUG: Approve order response status: ${response.statusCode}');
    debugPrint('DEBUG: Approve order response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ??
            'Failed to approve order: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Assign delivery manager to a confirmed order
  Future<Map<String, dynamic>> assignDeliveryManager(
    int orderId,
    int deliveryManagerId,
  ) async {
    debugPrint(
      'DEBUG: Sending assign delivery manager request for order $orderId with delivery manager $deliveryManagerId',
    );

    final response = await _makeRequest(
      'PATCH',
      '/delivery/orders/$orderId/assign_delivery_manager/',
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'delivery_manager_id': deliveryManagerId}),
    );

    debugPrint(
      'DEBUG: Assign delivery manager response status: ${response.statusCode}',
    );
    debugPrint(
      'DEBUG: Assign delivery manager response body: ${response.body}',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ??
            'Failed to assign delivery manager: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Reject order with reason
  Future<void> rejectOrder(int orderId, String rejectionReason) async {
    final response = await _makeRequest(
      'PATCH',
      '/delivery/orders/$orderId/reject/',
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'rejection_reason': rejectionReason}),
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ?? 'Failed to reject order: ${response.statusCode}',
      );
    }
  }

  // Get delivery location for an order (only when status is 'in_delivery')
  Future<Map<String, dynamic>> getOrderDeliveryLocation(int orderId) async {
    final response = await _makeRequest(
      'GET',
      '/delivery/orders/$orderId/delivery-location/',
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ??
            'Failed to get delivery location: ${response.statusCode}',
      );
    }
  }

  // Add order notes
  Future<void> addOrderNotes(String orderId, String notes) async {
    final response = await _makeRequest(
      'POST',
      '/delivery/activities/log/note/',
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'order_id': orderId,
        'notes_content': notes,
        'action': 'add',
      }),
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ?? 'Failed to add notes: ${response.statusCode}',
      );
    }
  }

  // Edit order notes
  Future<void> editOrderNotes(String orderId, String notes, {int? noteId}) async {
    final body = <String, dynamic>{
      'order_id': orderId,
      'notes_content': notes,
      'action': 'edit',
    };
    if (noteId != null) {
      body['note_id'] = noteId;
    }

    final response = await _makeRequest(
      'POST',
      '/delivery/activities/log/note/',
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ?? 'Failed to edit notes: ${response.statusCode}',
      );
    }
  }

  // Delete order notes
  Future<void> deleteOrderNotes(String orderId, {int? noteId}) async {
    final body = <String, dynamic>{
      'order_id': orderId,
      'action': 'delete',
    };
    if (noteId != null) {
      body['note_id'] = noteId;
    }

    final response = await _makeRequest(
      'POST',
      '/delivery/activities/log/note/',
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode != 200) {
      final errorData = json.decode(response.body);
      throw Exception(
        errorData['error'] ?? 'Failed to delete notes: ${response.statusCode}',
      );
    }
  }

  // Library Management
  Future<Library> getLibrary() async {
    final headers = _getHeaders();
    if (kDebugMode) {
      debugPrint('ManagerApiService: Getting library with headers: $headers');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/library/manage/'),
      headers: headers,
    );

    if (kDebugMode) {
      debugPrint(
        'ManagerApiService: Library response status: ${response.statusCode}',
      );
      debugPrint('ManagerApiService: Library response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        if (data['data']['current_library'] != null) {
          return Library.fromJson(data['data']['current_library']);
        } else {
          // No library exists yet - this is a valid state
          throw Exception('NO_LIBRARY_FOUND');
        }
      } else {
        throw Exception(data['message'] ?? 'Failed to get library');
      }
    } else {
      throw Exception('Failed to get library: ${response.statusCode}');
    }
  }

  Future<bool> deleteLibrary() async {
    if (kDebugMode) {
      debugPrint('ManagerApiService: Deleting library');
    }

    // Check authentication first
    final token = getAuthToken?.call();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please log in first.');
    }

    if (kDebugMode) {
      debugPrint('ManagerApiService: Token present: ${token.isNotEmpty}');
      debugPrint('ManagerApiService: Base URL: $baseUrl');
      debugPrint('ManagerApiService: Full URL: $baseUrl/library/delete/');
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/library/delete/'),
        headers: _getHeaders(),
      );

      if (kDebugMode) {
        debugPrint(
          'ManagerApiService: Response status: ${response.statusCode}',
        );
        debugPrint('ManagerApiService: Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception(
          'Access denied. Only library administrators can delete libraries.',
        );
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ??
                'Failed to delete library: ${response.statusCode}',
          );
        } catch (e) {
          throw Exception('Failed to delete library: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ManagerApiService: Exception during library deletion: $e');
      }
      rethrow;
    }
  }

  Future<Library> createLibrary(Library library, {File? logoFile}) async {
    if (kDebugMode) {
      debugPrint(
        'ManagerApiService: Creating library with name: ${library.name}',
      );
      debugPrint('ManagerApiService: Library details: ${library.details}');
      debugPrint('ManagerApiService: Library logo URL: ${library.logoUrl}');
    }

    // Check authentication first
    final token = getAuthToken?.call();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please log in first.');
    }

    if (kDebugMode) {
      debugPrint('ManagerApiService: Token present: ${token.isNotEmpty}');
      debugPrint('ManagerApiService: Base URL: $baseUrl');
      debugPrint('ManagerApiService: Full URL: $baseUrl/library/create/');
    }

    try {
      late http.Response response;

      if (logoFile != null) {
        // Use multipart request for file upload
        var request = http.MultipartRequest(
          'POST',
          Uri.parse('$baseUrl/library/create/'),
        );

        // Add headers
        request.headers.addAll(_getHeaders());

        // Add fields
        request.fields['name'] = library.name;
        request.fields['details'] = library.details;

        // Add file
        request.files.add(
          await http.MultipartFile.fromPath('logo', logoFile.path),
        );

        if (kDebugMode) {
          debugPrint('ManagerApiService: Uploading file: ${logoFile.path}');
          debugPrint('ManagerApiService: Headers: ${request.headers}');
        }

        var streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        // Use regular form data for text-only request
        final Map<String, String> formData = {
          'name': library.name,
          'details': library.details,
        };

        // Encode form data
        final body = formData.entries
            .map(
              (e) =>
                  '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
            )
            .join('&');

        if (kDebugMode) {
          debugPrint('ManagerApiService: Form data body: $body');
          debugPrint('ManagerApiService: Headers: ${_getHeaders()}');
        }

        response = await http.post(
          Uri.parse('$baseUrl/library/create/'),
          headers: {
            ..._getHeaders(),
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: body,
        );
      }

      if (kDebugMode) {
        debugPrint(
          'ManagerApiService: Response status: ${response.statusCode}',
        );
        debugPrint('ManagerApiService: Response body: ${response.body}');
      }

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (kDebugMode) {
          debugPrint('ManagerApiService: Response data: $data');
          debugPrint('ManagerApiService: Data type: ${data.runtimeType}');
          debugPrint('ManagerApiService: Data[\'data\']: ${data['data']}');
          debugPrint(
            'ManagerApiService: Data[\'data\'] type: ${data['data'].runtimeType}',
          );
        }

        if (data['success'] == true) {
          if (data['data'] is Map<String, dynamic>) {
            return Library.fromJson(data['data']);
          } else {
            throw Exception(
              'Invalid response format: data[\'data\'] is not a Map',
            );
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to create library');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception(
          'Access denied. Only library administrators can create libraries.',
        );
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ??
                'Failed to create library: ${response.statusCode}',
          );
        } catch (e) {
          throw Exception('Failed to create library: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ManagerApiService: Exception during library creation: $e');
      }
      rethrow;
    }
  }

  Future<Library> updateLibrary(Library library, {File? logoFile}) async {
    if (kDebugMode) {
      debugPrint(
        'ManagerApiService: Updating library with name: ${library.name}',
      );
      debugPrint('ManagerApiService: Library details: ${library.details}');
      debugPrint('ManagerApiService: Library logo URL: ${library.logoUrl}');
    }

    // Check authentication first
    final token = getAuthToken?.call();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please log in first.');
    }

    if (kDebugMode) {
      debugPrint('ManagerApiService: Token present: ${token.isNotEmpty}');
      debugPrint('ManagerApiService: Base URL: $baseUrl');
      debugPrint('ManagerApiService: Full URL: $baseUrl/library/update/');
    }

    try {
      late http.Response response;

      // Always use multipart request for library updates since logo field expects multipart
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/library/update/'),
      );

      // Add headers
      request.headers.addAll(_getHeaders());

      // Add fields
      request.fields['name'] = library.name;
      request.fields['details'] = library.details;

      // Add file if provided
      if (logoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('logo', logoFile.path),
        );
        if (kDebugMode) {
          debugPrint('ManagerApiService: Uploading file: ${logoFile.path}');
        }
      } else {
        // If no file provided, send a special value to indicate no logo change
        // The backend serializer should handle this as "keep existing logo"
        request.fields['logo'] = 'KEEP_EXISTING';
      }

      if (kDebugMode) {
        debugPrint('ManagerApiService: Headers: ${request.headers}');
        debugPrint('ManagerApiService: Fields: ${request.fields}');
      }

      var streamedResponse = await request.send();
      response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        debugPrint(
          'ManagerApiService: Response status: ${response.statusCode}',
        );
        debugPrint('ManagerApiService: Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return Library.fromJson(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to update library');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Authentication failed. Please log in again.');
      } else if (response.statusCode == 403) {
        throw Exception(
          'Access denied. Only library administrators can update libraries.',
        );
      } else {
        try {
          final errorData = json.decode(response.body);
          throw Exception(
            errorData['message'] ??
                'Failed to update library: ${response.statusCode}',
          );
        } catch (e) {
          throw Exception('Failed to update library: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ManagerApiService: Exception during library update: $e');
      }
      rethrow;
    }
  }

  // Borrowing Management
  Future<List<BorrowRequest>> getPendingBorrowRequests({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final response = await http.get(
      Uri.parse(
        '$baseUrl/borrowing/requests/pending/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List? ?? [])
          .map((item) => BorrowRequest.fromJson(item))
          .toList();
    } else {
      throw Exception(
        'Failed to load pending borrow requests: ${response.statusCode}',
      );
    }
  }

  Future<List<BorrowRequest>> getActiveBorrowings({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final response = await http.get(
      Uri.parse(
        '$baseUrl/borrowing/borrowings/active/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List? ?? [])
          .map((item) => BorrowRequest.fromJson(item))
          .toList();
    } else {
      throw Exception(
        'Failed to load active borrowings: ${response.statusCode}',
      );
    }
  }

  Future<List<BorrowExtension>> getExtensionRequests({
    int page = 1,
    int limit = 10,
  }) async {
    final queryParams = {'page': page.toString(), 'limit': limit.toString()};

    final response = await http.get(
      Uri.parse(
        '$baseUrl/borrowing/extensions/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List)
          .map((item) => BorrowExtension.fromJson(item))
          .toList();
    } else {
      throw Exception(
        'Failed to load extension requests: ${response.statusCode}',
      );
    }
  }

  Future<List<BorrowFine>> getFines({int page = 1, int limit = 10}) async {
    final queryParams = {'page': page.toString(), 'limit': limit.toString()};

    final response = await http.get(
      Uri.parse(
        '$baseUrl/borrowing/fines/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List)
          .map((item) => BorrowFine.fromJson(item))
          .toList();
    } else {
      throw Exception('Failed to load fines: ${response.statusCode}');
    }
  }

  Future<void> approveBorrowRequest(
    int requestId, {
    int borrowPeriodDays = 7,
    DateTime? expectedReturnDate,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/borrowing/requests/$requestId/approve/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({
        'borrow_period_days': borrowPeriodDays,
        if (expectedReturnDate != null)
          'expected_return_date': expectedReturnDate.toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to approve borrow request: ${response.statusCode}',
      );
    }
  }

  Future<void> rejectBorrowRequest(int requestId, String reason) async {
    final response = await http.post(
      Uri.parse('$baseUrl/borrowing/requests/$requestId/reject/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({'rejection_reason': reason}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to reject borrow request: ${response.statusCode}',
      );
    }
  }

  Future<void> approveExtension(int extensionId, int extensionDays) async {
    final response = await http.post(
      Uri.parse('$baseUrl/borrowing/extensions/$extensionId/approve/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({'extension_days': extensionDays}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to approve extension: ${response.statusCode}');
    }
  }

  Future<void> rejectExtension(int extensionId, String reason) async {
    final response = await http.post(
      Uri.parse('$baseUrl/borrowing/extensions/$extensionId/reject/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({'rejection_reason': reason}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reject extension: ${response.statusCode}');
    }
  }

  Future<void> updateFineStatus(int fineId, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/borrowing/fines/$fineId/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update fine status: ${response.statusCode}');
    }
  }

  Future<void> confirmBookReturn(int borrowId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/borrowing/borrowings/$borrowId/return/'),
      headers: {...headers, 'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to confirm book return: ${response.statusCode}');
    }
  }

  Future<List<DeliveryAgent>> getAvailableDeliveryAgents() async {
    debugPrint('DEBUG: Fetching available delivery managers');
    final uri = Uri.parse(
      '$baseUrl/delivery/orders/available_delivery_managers/',
    );
    debugPrint('DEBUG: Request URL: $uri');

    final response = await http.get(uri, headers: _getHeaders());

    debugPrint('DEBUG: Response status: ${response.statusCode}');
    debugPrint('DEBUG: Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // The API returns delivery_managers in the response
      if (data['success'] == true && data['delivery_managers'] != null) {
        final agents = (data['delivery_managers'] as List)
            .map((item) => DeliveryAgent.fromJson(item))
            .toList();
        debugPrint('DEBUG: Found ${agents.length} delivery managers');
        return agents;
      } else {
        debugPrint('DEBUG: No delivery managers found in response');
        return [];
      }
    } else {
      debugPrint('DEBUG: API error: ${response.statusCode} - ${response.body}');
      throw Exception(
        'Failed to load available delivery agents: ${response.statusCode}',
      );
    }
  }

  Future<List<DeliveryOrder>> getOrdersForDelivery({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };

    final response = await http.get(
      Uri.parse(
        '$baseUrl/delivery/orders/ready-for-delivery/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List)
          .map((item) => DeliveryOrder.fromJson(item))
          .toList();
    } else {
      throw Exception(
        'Failed to load orders for delivery: ${response.statusCode}',
      );
    }
  }

  Future<void> assignDeliveryAgent(
    int requestId,
    int agentId, {
    DateTime? estimatedDeliveryTime,
    String? notes,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/delivery/requests/$requestId/assign/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({
        'delivery_person_id': agentId,
        if (estimatedDeliveryTime != null)
          'estimated_delivery_time': estimatedDeliveryTime.toIso8601String(),
        if (notes != null) 'delivery_notes': notes,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to assign delivery agent: ${response.statusCode}',
      );
    }
  }

  // Ads Management
  Future<List<Ad>> getAds({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
    String? targetAudience,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      if (targetAudience != null && targetAudience.isNotEmpty)
        'target_audience': targetAudience,
    };

    final uri = Uri.parse(
      '$baseUrl/ads/',
    ).replace(queryParameters: queryParams);

    debugPrint('DEBUG: ManagerApiService getAds - URL: $uri');
    debugPrint('DEBUG: ManagerApiService getAds - Search: $search');
    debugPrint('DEBUG: ManagerApiService getAds - Status: $status');

    final response = await http.get(uri, headers: _getHeaders());

    debugPrint(
      'DEBUG: ManagerApiService getAds - Response status: ${response.statusCode}',
    );
    debugPrint(
      'DEBUG: ManagerApiService getAds - Response body: ${response.body}',
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Handle different response structures
      List<dynamic> adsList;

      if (data is List) {
        // Direct list response (no pagination)
        adsList = data;
      } else if (data is Map<String, dynamic>) {
        // Check for paginated response structure
        if (data.containsKey('results')) {
          // Paginated response with 'results' field
          adsList = data['results'] ?? [];
        } else if (data.containsKey('data')) {
          // Response with 'data' field
          adsList = data['data'] ?? [];
        } else {
          // Fallback: treat the entire response as a list
          adsList = [data];
        }
      } else {
        // Unexpected response format
        adsList = [];
      }

      return adsList
          .map((item) => Ad.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw Exception('Failed to load ads: ${response.statusCode}');
    }
  }

  Future<Ad?> getAd(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/ads/$id/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Ad.fromJson(data);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load ad: ${response.statusCode}');
    }
  }

  Future<Ad> createAd(Ad ad) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ads/create/'),
      headers: {..._getHeaders(), 'Content-Type': 'application/json'},
      body: json.encode(ad.toJson()),
    );

    if (response.statusCode == 201) {
      return Ad.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create ad: ${response.statusCode}');
    }
  }

  Future<Ad> updateAd(Ad ad) async {
    final response = await http.put(
      Uri.parse('$baseUrl/ads/${ad.id}/update/'),
      headers: {..._getHeaders(), 'Content-Type': 'application/json'},
      body: json.encode(ad.toJson()),
    );

    if (response.statusCode == 200) {
      return Ad.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update ad: ${response.statusCode}');
    }
  }

  Future<void> deleteAd(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/ads/$id/delete/'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete ad: ${response.statusCode}');
    }
  }

  Future<void> publishAd(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ads/$id/publish/'),
      headers: {...headers, 'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to publish ad: ${response.statusCode}');
    }
  }

  Future<void> unpublishAd(int id) async {
    final response = await http.post(
      Uri.parse('$baseUrl/ads/$id/unpublish/'),
      headers: {...headers, 'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to unpublish ad: ${response.statusCode}');
    }
  }

  // Complaints Management
  Future<ComplaintsResponse> getComplaints({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
    String? type,
    String? priority,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status.isNotEmpty) 'status': status,
      if (type != null && type.isNotEmpty) 'type': type,
      if (priority != null && priority.isNotEmpty) 'priority': priority,
    };

    final url = '$baseUrl/complaints/';
    final uri = Uri.parse(url).replace(queryParameters: queryParams);
    final headers = _getHeaders();

    developer.log('ManagerApiService: Making request to: $uri');
    developer.log('ManagerApiService: Headers: $headers');

    final response = await http.get(uri, headers: headers);

    developer.log('ManagerApiService: Response status: ${response.statusCode}');
    developer.log('ManagerApiService: Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return ComplaintsResponse(
        results: (data['data'] as List? ?? [])
            .map((item) => Complaint.fromJson(item))
            .toList(),
        totalPages: data['total_pages'] ?? 1,
        totalItems: data['count'] ?? 0,
        currentPage: data['current_page'] ?? page,
        hasNext: data['has_next'] ?? false,
        hasPrevious: data['has_previous'] ?? false,
      );
    } else {
      throw Exception('Failed to load complaints: ${response.statusCode}');
    }
  }

  Future<Complaint?> getComplaint(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/complaints/$id/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return Complaint.fromJson(data);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('Failed to load complaint: ${response.statusCode}');
    }
  }

  Future<void> updateComplaintStatus(int id, String status) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/complaints/$id/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({'status': status}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update complaint status: ${response.statusCode}',
      );
    }
  }

  Future<void> assignComplaint(int id, int staffId) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/complaints/$id/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({'assigned_to': staffId}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to assign complaint: ${response.statusCode}');
    }
  }

  Future<void> addComplaintResponse(int id, String response) async {
    final responseData = await http.post(
      Uri.parse('$baseUrl/complaints/$id/responses/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({'response': response}),
    );

    if (responseData.statusCode != 201) {
      throw Exception(
        'Failed to add complaint response: ${responseData.statusCode}',
      );
    }
  }

  Future<void> resolveComplaint(int id, String resolution) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/complaints/$id/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode({
        'status': 'resolved',
        'resolution': resolution,
        'resolved_at': DateTime.now().toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to resolve complaint: ${response.statusCode}');
    }
  }

  // Notifications Management
  Future<List<NotificationModel>> getNotifications({
    int page = 1,
    int limit = 1000, // Load all notifications (large limit)
    String? type,
    String? priority,
    bool? isRead,
    String? search,
  }) async {
    debugPrint('ManagerApiService: getNotifications called');
    debugPrint(
      'ManagerApiService: Current token status: ${getAuthToken?.call().isNotEmpty}',
    );

    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (type != null && type.isNotEmpty) 'notification_type': type,
      if (priority != null && priority.isNotEmpty) 'priority': priority,
      if (isRead != null) 'is_read': isRead.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };

    debugPrint(
      'ManagerApiService: Request URL: /notifications/ with params: $queryParams',
    );

    final response = await _makeRequest(
      'GET',
      '/notifications/',
      queryParams: queryParams,
    );

    debugPrint('ManagerApiService: Response status: ${response.statusCode}');
    debugPrint('ManagerApiService: Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      // Backend returns notifications directly as a list
      if (data is List) {
        return data.map((item) => NotificationModel.fromJson(item)).toList();
      } else if (data is Map && data.containsKey('data')) {
        return (data['data'] as List)
            .map((item) => NotificationModel.fromJson(item))
            .toList();
      } else {
        return [];
      }
    } else {
      throw Exception('Failed to load notifications: ${response.statusCode}');
    }
  }

  Future<NotificationModel> markNotificationAsRead(int notificationId) async {
    debugPrint(
      'ManagerApiService: markNotificationAsRead called for notification $notificationId',
    );

    final response = await _makeRequest(
      'POST',
      '/notifications/$notificationId/mark_as_read/',
      headers: {'Content-Type': 'application/json'},
    );

    debugPrint(
      'ManagerApiService: markNotificationAsRead response status: ${response.statusCode}',
    );
    debugPrint(
      'ManagerApiService: markNotificationAsRead response body: ${response.body}',
    );

    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body);
        debugPrint('ManagerApiService: Parsed response data: $data');

        // Handle different response formats
        Map<String, dynamic> notificationData;
        if (data is Map<String, dynamic>) {
          notificationData = data;
        } else if (data is List && data.isNotEmpty) {
          // If response is a list, take the first item
          notificationData = data[0] as Map<String, dynamic>;
        } else {
          throw FormatException(
            'Unexpected response format: ${data.runtimeType}',
          );
        }

        final notification = NotificationModel.fromJson(notificationData);
        debugPrint(
          'ManagerApiService: Successfully parsed notification: id=${notification.id}, isRead=${notification.isRead}',
        );
        return notification;
      } catch (e, stackTrace) {
        debugPrint(
          'ManagerApiService: Error parsing notification response: $e',
        );
        debugPrint('ManagerApiService: Stack trace: $stackTrace');
        debugPrint('ManagerApiService: Response body was: ${response.body}');
        throw FormatException(
          'Failed to parse notification response: $e. Response body: ${response.body}',
        );
      }
    } else {
      final errorMessage =
          'Failed to mark notification as read: ${response.statusCode}';
      try {
        final errorData = json.decode(response.body);
        throw Exception(
          errorData['error'] ?? errorData['message'] ?? errorMessage,
        );
      } catch (e) {
        throw Exception('$errorMessage. Response: ${response.body}');
      }
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    debugPrint('ManagerApiService: markAllNotificationsAsRead called');
    try {
      final response = await _makeRequest(
        'POST',
        '/notifications/mark_all_as_read/',
        headers: {'Content-Type': 'application/json'},
      );

      debugPrint('ManagerApiService: Response status: ${response.statusCode}');
      debugPrint('ManagerApiService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        debugPrint('Successfully marked all notifications as read');
      } else {
        debugPrint(
          'Failed to mark all notifications as read: ${response.statusCode}',
        );
        debugPrint('Response body: ${response.body}');
        throw Exception(
          'Failed to mark all notifications as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error in markAllNotificationsAsRead: $e');
      rethrow;
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final token = _cachedToken ?? getAuthToken?.call() ?? '';
      if (token.isEmpty) {
        throw Exception('No authentication token available');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/delete_all/'),
        headers: {
          ...headers,
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
          'Successfully deleted all notifications: ${data['deleted_count'] ?? 0}',
        );
      } else {
        debugPrint('Failed to delete all notifications: ${response.statusCode}');
        throw Exception(
          'Failed to delete all notifications: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error in deleteAllNotifications: $e');
      rethrow;
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    try {
      debugPrint('Deleting notification with ID: $notificationId');

      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint(
          'Successfully deleted notification $notificationId from server',
        );
      } else {
        debugPrint('Failed to delete notification: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception(
          'Failed to delete notification: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error in deleteNotification: $e');
      rethrow;
    }
  }

  Future<int> getUnreadNotificationsCount() async {
    final response = await _makeRequest('GET', '/notifications/unread_count/');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['count'] ?? data['unread_count'] ?? 0;
    } else {
      throw Exception(
        'Failed to get unread notifications count: ${response.statusCode}',
      );
    }
  }

  // Reports Management
  Future<List<DashboardCard>> getDashboardStats({
    String period = 'this_month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = {
      'period': period,
      if (startDate != null)
        'start_date': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
    };

    final response = await _makeRequest(
      'GET',
      '/reports/dashboard/',
      queryParams: queryParams,
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        // The backend returns a single object with all statistics
        final stats = data['data'] as Map<String, dynamic>;
        return _createDashboardCardsFromStats(stats);
      } else {
        throw Exception(data['message'] ?? 'Failed to load dashboard stats');
      }
    } else {
      throw Exception('Failed to load dashboard stats: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getBorrowingReport({
    String period = 'monthly',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = {
      'period': period,
      if (startDate != null)
        'start_date': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
    };

    final response = await http.get(
      Uri.parse(
        '$baseUrl/reports/borrowing/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to load borrowing report');
      }
    } else {
      throw Exception(
        'Failed to load borrowing report: ${response.statusCode}',
      );
    }
  }

  Future<Map<String, dynamic>> getDeliveryReport({
    String period = 'monthly',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = {
      'period': period,
      if (startDate != null)
        'start_date': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
    };

    final response = await http.get(
      Uri.parse(
        '$baseUrl/reports/delivery/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to load delivery report');
      }
    } else {
      throw Exception('Failed to load delivery report: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getFineReport({
    String period = 'this_month',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = {
      'period': period,
      if (startDate != null)
        'start_date': startDate.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate.toIso8601String().split('T')[0],
    };

    final response = await http.get(
      Uri.parse(
        '$baseUrl/reports/fines/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load fine report: ${response.statusCode}');
    }
  }

  Future<List<Map<String, dynamic>>> getBookPopularityReport({
    String period = 'this_month',
    int limit = 10,
  }) async {
    final queryParams = {'period': period, 'limit': limit.toString()};

    final response = await http.get(
      Uri.parse(
        '$baseUrl/reports/book-popularity/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception(
        'Failed to load book popularity report: ${response.statusCode}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAuthorPopularityReport({
    String period = 'this_month',
    int limit = 10,
  }) async {
    final queryParams = {'period': period, 'limit': limit.toString()};

    final response = await http.get(
      Uri.parse(
        '$baseUrl/reports/author-popularity/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['data'] as List).cast<Map<String, dynamic>>();
    } else {
      throw Exception(
        'Failed to load author popularity report: ${response.statusCode}',
      );
    }
  }

  // Manager Settings Management
  Future<Map<String, dynamic>> getManagerSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/manager/settings/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'Failed to load manager settings: ${response.statusCode}',
      );
    }
  }

  Future<void> updateManagerSettings(Map<String, dynamic> settings) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/manager/settings/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode(settings),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to update manager settings: ${response.statusCode}',
      );
    }
  }

  Future<void> resetManagerSettings() async {
    final response = await http.post(
      Uri.parse('$baseUrl/manager/settings/reset/'),
      headers: {...headers, 'Content-Type': 'application/json'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to reset manager settings: ${response.statusCode}',
      );
    }
  }

  // Categories Management
  Future<List<Category>> getCategories({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse(
        '$baseUrl/library/categories/',
      ).replace(queryParameters: queryParams);

      debugPrint('DEBUG: ManagerApiService getCategories - URL: $uri');
      debugPrint('DEBUG: ManagerApiService getCategories - Search: $search');

      final response = await http.get(uri, headers: _getHeaders());

      debugPrint(
        'DEBUG: ManagerApiService getCategories - Response status: ${response.statusCode}',
      );
      debugPrint(
        'DEBUG: ManagerApiService getCategories - Response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final categories = (data['data'] as List)
            .map((item) => Category.fromJson(item))
            .toList();
        debugPrint(
          'DEBUG: ManagerApiService getCategories - Parsed ${categories.length} categories',
        );
        return categories;
      } else {
        throw Exception('Failed to load categories: ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error fetching categories: $e');
      rethrow;
    }
  }

  Future<Category> createCategory(Category category) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/library/categories/create/'),
        headers: {..._getHeaders(), 'Content-Type': 'application/json'},
        body: json.encode(category.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Category.fromJson(data['data']);
        } else {
          throw Exception('Invalid response format from server');
        }
      } else {
        throw Exception('Failed to create category: ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error creating category: $e');
      rethrow;
    }
  }

  Future<Category> updateCategory(Category category) async {
    try {
      debugPrint(
        'DEBUG: ManagerApiService - Updating category: ${category.toJson()}',
      );

      final response = await http.put(
        Uri.parse('$baseUrl/library/categories/${category.id}/update/'),
        headers: {..._getHeaders(), 'Content-Type': 'application/json'},
        body: json.encode(category.toJson()),
      );

      debugPrint(
        'DEBUG: ManagerApiService - Response status: ${response.statusCode}',
      );
      debugPrint('DEBUG: ManagerApiService - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final updatedCategory = Category.fromJson(data['data']);
          debugPrint(
            'DEBUG: ManagerApiService - Parsed updated category: ${updatedCategory.toJson()}',
          );
          return updatedCategory;
        } else {
          throw Exception('Invalid response format from server');
        }
      } else {
        throw Exception('Failed to update category: ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error updating category: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/library/categories/$id/delete/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        // Parse the response to get the success message
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Category deleted successfully
          return;
        } else {
          // Backend returned an error message
          throw Exception(data['message'] ?? 'Failed to delete category');
        }
      } else if (response.statusCode == 400) {
        // Parse the error response
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Cannot delete category');
      } else {
        throw Exception('Failed to delete category: ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error deleting category: $e');
      rethrow;
    }
  }

  // Authors Management
  Future<List<Author>> getAuthors({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
      };

      final uri = Uri.parse(
        '$baseUrl/library/authors/',
      ).replace(queryParameters: queryParams);

      debugPrint('DEBUG: ManagerApiService getAuthors - URL: $uri');
      debugPrint('DEBUG: ManagerApiService getAuthors - Search: $search');

      final response = await http.get(uri, headers: _getHeaders());

      debugPrint(
        'DEBUG: ManagerApiService getAuthors - Response status: ${response.statusCode}',
      );
      debugPrint(
        'DEBUG: ManagerApiService getAuthors - Response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final authors = (data['data'] as List)
            .map((item) => Author.fromJson(item))
            .toList();
        debugPrint(
          'DEBUG: ManagerApiService getAuthors - Parsed ${authors.length} authors',
        );
        return authors;
      } else {
        throw Exception('Failed to load authors: ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error fetching authors: $e');
      rethrow;
    }
  }

  Future<Author> createAuthor(Author author) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/library/authors/create/'),
        headers: {..._getHeaders(), 'Content-Type': 'application/json'},
        body: json.encode(author.toJson()),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Author.fromJson(data['data']);
        } else {
          throw Exception('Invalid response format from server');
        }
      } else {
        throw Exception('Failed to create author: ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error creating author: $e');
      rethrow;
    }
  }

  Future<Author> updateAuthor(Author author) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/library/authors/${author.id}/update/'),
        headers: {..._getHeaders(), 'Content-Type': 'application/json'},
        body: json.encode(author.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Author.fromJson(data['data']);
        } else {
          throw Exception('Invalid response format from server');
        }
      } else {
        throw Exception('Failed to update author: ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error updating author: $e');
      rethrow;
    }
  }

  Future<void> deleteAuthor(int id) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/library/authors/$id/delete/'),
        headers: _getHeaders(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        // Try to parse error message from response
        try {
          final errorData = json.decode(response.body);
          final errorMessage =
              errorData['message'] ?? 'Failed to delete author';
          throw Exception(errorMessage);
        } catch (e) {
          throw Exception('Failed to delete author: ${response.statusCode}');
        }
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error deleting author: $e');
      rethrow;
    }
  }

  // Books Management
  Future<List<Book>> getBooks({
    int page = 1,
    int limit = 10,
    String? search,
    int? categoryId,
    int? authorId,
    double? minRating,
    double? maxRating,
    double? minPrice,
    double? maxPrice,
    bool? availableToBorrow,
    bool? newOnly,
    String? sortBy,
  }) async {
    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (categoryId != null) 'category': categoryId.toString(),
      if (authorId != null) 'author': authorId.toString(),
      if (minRating != null) 'min_rating': minRating.toString(),
      if (maxRating != null) 'max_rating': maxRating.toString(),
      if (minPrice != null) 'min_price': minPrice.toString(),
      if (maxPrice != null) 'max_price': maxPrice.toString(),
      if (availableToBorrow != null)
        'is_available': availableToBorrow.toString(),
      if (newOnly != null) 'is_new': newOnly.toString(),
      if (sortBy != null) 'ordering': sortBy,
    };

    final response = await http.get(
      Uri.parse(
        '$baseUrl/library/books/',
      ).replace(queryParameters: queryParams),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      debugPrint('DEBUG: getBooks response data: $data');

      if (data['success'] == true) {
        final booksData = data['data'] as List;
        debugPrint('DEBUG: getBooks books count: ${booksData.length}');
        return booksData.map((item) => Book.fromJson(item)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to load books');
      }
    } else if (response.statusCode == 404) {
      final data = json.decode(response.body);
      if (data['error_code'] == 'NO_LIBRARY') {
        throw Exception('NO_LIBRARY_FOUND');
      } else {
        throw Exception('Failed to load books: ${response.statusCode}');
      }
    } else {
      throw Exception('Failed to load books: ${response.statusCode}');
    }
  }

  Future<Book> getBook(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/library/books/$id/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return Book.fromJson(data['data']);
      } else {
        throw Exception('Invalid response format from server');
      }
    } else {
      throw Exception('Failed to load book: ${response.statusCode}');
    }
  }

  Future<Book> createBook(Book book) async {
    try {
      final response = await _makeRequest(
        'POST',
        '/library/books/create/',
        headers: {'Content-Type': 'application/json'},
        body: json.encode(book.toJson()),
      );

      debugPrint('DEBUG: CreateBook response status: ${response.statusCode}');
      debugPrint('DEBUG: CreateBook response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return Book.fromJson(data['data']);
        } else {
          throw Exception(
            'Invalid response format from server: ${data['message'] ?? 'Unknown error'}',
          );
        }
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'Failed to create book: ${errorData['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      debugPrint('DEBUG: CreateBook error: $e');
      rethrow;
    }
  }

  Future<Book> updateBook(Book book) async {
    final response = await http.put(
      Uri.parse('$baseUrl/library/books/${book.id}/update/'),
      headers: {..._getHeaders(), 'Content-Type': 'application/json'},
      body: json.encode(book.toJson()),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return Book.fromJson(data['data']);
      } else {
        throw Exception('Invalid response format from server');
      }
    } else {
      throw Exception('Failed to update book: ${response.statusCode}');
    }
  }

  Future<void> deleteBook(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/library/books/$id/delete/'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      // Try to parse error message from response
      try {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['message'] ?? 'Failed to delete book';
        throw Exception(errorMessage);
      } catch (e) {
        throw Exception('Failed to delete book: ${response.statusCode}');
      }
    }
  }

  // Discount Management
  Future<DiscountsResponse> getDiscounts({
    int page = 1,
    int limit = 10,
    String? search,
    bool? isActive,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (isActive != null) 'is_active': isActive.toString(),
      };

      final response = await http.get(
        Uri.parse(
          '$baseUrl/discounts/admin/codes/',
        ).replace(queryParameters: queryParams),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Handle the actual backend response structure
        List<dynamic> allDiscounts = [];
        if (data['active_codes'] != null) {
          allDiscounts.addAll(data['active_codes'] as List);
        }
        if (data['expired_codes'] != null) {
          allDiscounts.addAll(data['expired_codes'] as List);
        }
        if (data['inactive_codes'] != null) {
          allDiscounts.addAll(data['inactive_codes'] as List);
        }

        return DiscountsResponse(
          results: allDiscounts
              .map((item) => Discount.fromJson(item as Map<String, dynamic>))
              .toList(),
          totalPages: 1, // Backend doesn't paginate, so always 1 page
          totalItems: data['total_count'] ?? allDiscounts.length,
        );
      } else {
        throw Exception('Failed to load discounts: ${response.statusCode}');
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error fetching discounts: $e');
      rethrow;
    }
  }

  Future<Discount> getDiscount(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/discounts/admin/codes/$id/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Discount.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load discount: ${response.statusCode}');
    }
  }

  Future<Discount> createDiscount(Discount discount) async {
    try {
      final discountData = discount.toJson();
      debugPrint('DEBUG: createDiscount - Sending data: $discountData');

      final response = await http.post(
        Uri.parse('$baseUrl/discounts/admin/codes/'),
        headers: {..._getHeaders(), 'Content-Type': 'application/json'},
        body: json.encode(discountData),
      );

      debugPrint(
        'DEBUG: createDiscount - Response status: ${response.statusCode}',
      );
      debugPrint('DEBUG: createDiscount - Response body: ${response.body}');

      if (response.statusCode == 201) {
        return Discount.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'Failed to create discount: ${response.statusCode} - ${errorData['message'] ?? errorData.toString()}',
        );
      }
    } catch (e) {
      // Log error for debugging purposes
      debugPrint('Error creating discount: $e');
      rethrow;
    }
  }

  Future<Discount> updateDiscount(Discount discount) async {
    final response = await http.put(
      Uri.parse('$baseUrl/discounts/admin/codes/${discount.id}/'),
      headers: {..._getHeaders(), 'Content-Type': 'application/json'},
      body: json.encode(discount.toJson()),
    );

    if (response.statusCode == 200) {
      return Discount.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update discount: ${response.statusCode}');
    }
  }

  Future<void> deleteDiscount(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/discounts/admin/codes/$id/'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete discount: ${response.statusCode}');
    }
  }

  // Book Discount Management
  Future<BookDiscountsResponse> getBookDiscounts({
    int page = 1,
    int limit = 10,
    String? search,
    bool? isActive,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (isActive != null) 'is_active': isActive.toString(),
      };

      final uri = Uri.parse(
        '$baseUrl/discounts/admin/book-discounts/',
      ).replace(queryParameters: queryParams);

      debugPrint('DEBUG: getBookDiscounts - URL: $uri');

      final response = await http.get(uri, headers: _getHeaders());

      debugPrint(
        'DEBUG: getBookDiscounts - Response status: ${response.statusCode}',
      );
      debugPrint('DEBUG: getBookDiscounts - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return BookDiscountsResponse.fromJson(data);
      } else {
        throw Exception(
          'Failed to load book discounts: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error loading book discounts: $e');
      rethrow;
    }
  }

  Future<BookDiscount> getBookDiscount(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/discounts/admin/book-discounts/$id/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return BookDiscount.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load book discount: ${response.statusCode}');
    }
  }

  Future<BookDiscount> createBookDiscount(BookDiscount bookDiscount) async {
    try {
      final discountData = bookDiscount.toJson();
      debugPrint('DEBUG: createBookDiscount - Sending data: $discountData');

      final response = await http.post(
        Uri.parse('$baseUrl/discounts/admin/book-discounts/'),
        headers: {..._getHeaders(), 'Content-Type': 'application/json'},
        body: json.encode(discountData),
      );

      debugPrint(
        'DEBUG: createBookDiscount - Response status: ${response.statusCode}',
      );
      debugPrint('DEBUG: createBookDiscount - Response body: ${response.body}');

      if (response.statusCode == 201) {
        return BookDiscount.fromJson(json.decode(response.body));
      } else {
        final errorData = json.decode(response.body);
        throw Exception(
          'Failed to create book discount: ${response.statusCode} - ${errorData['message'] ?? errorData.toString()}',
        );
      }
    } catch (e) {
      debugPrint('Error creating book discount: $e');
      rethrow;
    }
  }

  Future<BookDiscount> updateBookDiscount(BookDiscount bookDiscount) async {
    final response = await http.put(
      Uri.parse('$baseUrl/discounts/admin/book-discounts/${bookDiscount.id}/'),
      headers: {..._getHeaders(), 'Content-Type': 'application/json'},
      body: json.encode(bookDiscount.toJson()),
    );

    if (response.statusCode == 200) {
      return BookDiscount.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update book discount: ${response.statusCode}');
    }
  }

  Future<void> deleteBookDiscount(int id) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/discounts/admin/book-discounts/$id/'),
      headers: _getHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete book discount: ${response.statusCode}');
    }
  }

  Future<List<AvailableBook>> getAvailableBooks() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/discounts/admin/available-books/'),
        headers: _getHeaders(),
      );

      debugPrint(
        'DEBUG: getAvailableBooks - Response status: ${response.statusCode}',
      );
      debugPrint('DEBUG: getAvailableBooks - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final booksData = data['books'] as List;
        return booksData.map((book) => AvailableBook.fromJson(book)).toList();
      } else {
        throw Exception(
          'Failed to load available books: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error loading available books: $e');
      rethrow;
    }
  }

  Future<Order> getOrderById(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/delivery/orders/$id/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      return Order.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load order: ${response.statusCode}');
    }
  }

  // Reports and Analytics
  Future<Map<String, dynamic>> getSalesReport({
    DateTime? startDate,
    DateTime? endDate,
    String? period,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }
    if (period != null) {
      queryParams['period'] = period;
    }

    final uri = Uri.parse(
      '$baseUrl/reports/sales/',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load sales report: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getUserReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }

    final uri = Uri.parse(
      '$baseUrl/reports/users/',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load user report: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getBookReport() async {
    final response = await _makeRequest('GET', '/reports/books/');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to load book report');
      }
    } else {
      throw Exception('Failed to load book report: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getOrderReport({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }
    if (status != null) {
      queryParams['status'] = status;
    }

    final uri = Uri.parse(
      '$baseUrl/reports/orders/',
    ).replace(queryParameters: queryParams);

    final response = await http.get(uri, headers: _getHeaders());

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load order report: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getAuthorReport() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/authors/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to load author report');
      }
    } else {
      throw Exception('Failed to load author report: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getCategoryReport() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/categories/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to load category report');
      }
    } else {
      throw Exception('Failed to load category report: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getRatingReport() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/ratings/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to load rating report');
      }
    } else {
      throw Exception('Failed to load rating report: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> getFinesReport() async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports/fines/'),
      headers: _getHeaders(),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        return data['data'];
      } else {
        throw Exception(data['message'] ?? 'Failed to load fines report');
      }
    } else {
      throw Exception('Failed to load fines report: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> generateCustomReport({
    required String reportType,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? filters,
  }) async {
    final requestData = {
      'report_type': reportType,
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
      if (filters != null) 'filters': filters,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/reports/custom/'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: json.encode(requestData),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
        'Failed to generate custom report: ${response.statusCode}',
      );
    }
  }

  // Helper method to create dashboard cards from statistics
  List<DashboardCard> _createDashboardCardsFromStats(
    Map<String, dynamic> stats,
  ) {
    final List<DashboardCard> cards = [];

    // Revenue card
    if (stats['total_revenue'] != null) {
      cards.add(
        DashboardCard.revenueStats(
          totalRevenue: (stats['total_revenue'] as num).toDouble(),
          monthlyRevenue: (stats['monthly_revenue'] as num?)?.toDouble() ?? 0.0,
          trend: stats['revenue_trend']?.toString(),
          trendValue: (stats['revenue_trend_value'] as num?)?.toDouble(),
        ),
      );
    }

    // User stats card
    if (stats['total_users'] != null) {
      cards.add(
        DashboardCard.userStats(
          totalUsers: stats['total_users'] as int,
          activeUsers: stats['active_users'] as int? ?? 0,
          trend: stats['user_trend']?.toString(),
          trendValue: (stats['user_trend_value'] as num?)?.toDouble(),
        ),
      );
    }

    // Book stats card
    if (stats['total_books'] != null) {
      cards.add(
        DashboardCard.bookStats(
          totalBooks: stats['total_books'] as int,
          availableBooks: stats['available_books'] as int? ?? 0,
          trend: stats['book_trend']?.toString(),
          trendValue: (stats['book_trend_value'] as num?)?.toDouble(),
        ),
      );
    }

    // Order stats card
    if (stats['total_orders'] != null) {
      cards.add(
        DashboardCard.orderStats(
          totalOrders: stats['total_orders'] as int,
          pendingOrders: stats['pending_orders'] as int? ?? 0,
          trend: stats['order_trend']?.toString(),
          trendValue: (stats['order_trend_value'] as num?)?.toDouble(),
        ),
      );
    }

    // Author stats card
    if (stats['total_authors'] != null) {
      cards.add(
        DashboardCard.authorStats(
          totalAuthors: stats['total_authors'] as int,
          trend: stats['author_trend']?.toString(),
          trendValue: (stats['author_trend_value'] as num?)?.toDouble(),
        ),
      );
    }

    // Category stats card
    if (stats['total_categories'] != null) {
      cards.add(
        DashboardCard.categoryStats(
          totalCategories: stats['total_categories'] as int,
          trend: stats['category_trend']?.toString(),
          trendValue: (stats['category_trend_value'] as num?)?.toDouble(),
        ),
      );
    }

    // Rating stats card
    if (stats['total_ratings'] != null) {
      cards.add(
        DashboardCard.ratingStats(
          totalRatings: stats['total_ratings'] as int,
          avgRating: (stats['avg_rating'] as num?)?.toDouble() ?? 0.0,
        ),
      );
    }

    return cards;
  }

  // Get Discounts
  Future<DiscountsResponse> fetchDiscounts({
    int page = 1,
    int limit = 10,
    String? search,
    bool? isActive,
  }) async {
    try {
      final queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (isActive != null) 'is_active': isActive.toString(),
      };

      final uri = Uri.parse(
        '$baseUrl/discounts/admin/codes/',
      ).replace(queryParameters: queryParams);

      debugPrint('DEBUG: getDiscounts - URL: $uri');

      final response = await http.get(uri, headers: _getHeaders());

      debugPrint(
        'DEBUG: getDiscounts - Response status: ${response.statusCode}',
      );
      debugPrint('DEBUG: getDiscounts - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return DiscountsResponse.fromJson(data);
      } else {
        throw Exception('Failed to load discounts: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error loading discounts: $e');
      rethrow;
    }
  }

  // Get Available Books for Discounts
  Future<List<AvailableBook>> fetchAvailableBooks() async {
    try {
      final uri = Uri.parse('$baseUrl/discounts/admin/available-books/');

      debugPrint('DEBUG: getAvailableBooks - URL: $uri');

      final response = await http.get(uri, headers: _getHeaders());

      debugPrint(
        'DEBUG: getAvailableBooks - Response status: ${response.statusCode}',
      );
      debugPrint('DEBUG: getAvailableBooks - Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> booksJson = data['books'] ?? [];
        return booksJson.map((json) => AvailableBook.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load available books: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error loading available books: $e');
      rethrow;
    }
  }
}

// Response classes for delivery API calls
class DeliveryRequestsResponse {
  final List<DeliveryRequest> results;
  final int totalPages;
  final int totalItems;

  DeliveryRequestsResponse({
    required this.results,
    required this.totalPages,
    required this.totalItems,
  });
}

class DeliveryAssignmentsResponse {
  final List<admin_delivery.DeliveryAssignment> results;
  final int totalPages;
  final int totalItems;

  DeliveryAssignmentsResponse({
    required this.results,
    required this.totalPages,
    required this.totalItems,
  });
}

class DeliveryOrdersResponse {
  final List<DeliveryOrder> results;
  final int totalPages;
  final int totalItems;

  DeliveryOrdersResponse({
    required this.results,
    required this.totalPages,
    required this.totalItems,
  });
}

class DiscountsResponse {
  final List<Discount> results;
  final int totalPages;
  final int totalItems;

  DiscountsResponse({
    required this.results,
    required this.totalPages,
    required this.totalItems,
  });

  factory DiscountsResponse.fromJson(Map<String, dynamic> json) {
    // Handle the actual API response structure
    List<dynamic> allDiscounts = [];

    // Combine all discount lists from the response
    if (json['active_codes'] != null) {
      allDiscounts.addAll(json['active_codes'] as List<dynamic>);
    }

    if (json['inactive_codes'] != null) {
      allDiscounts.addAll(json['inactive_codes'] as List<dynamic>);
    }

    // Fallback to 'results' if the above structure doesn't exist
    if (allDiscounts.isEmpty && json['results'] != null) {
      allDiscounts = json['results'] as List<dynamic>;
    }

    return DiscountsResponse(
      results: allDiscounts.map((item) => Discount.fromJson(item)).toList(),
      totalPages: json['total_pages'] ?? 1,
      totalItems: allDiscounts.length,
    );
  }
}

class ComplaintsResponse {
  final List<Complaint> results;
  final int totalPages;
  final int totalItems;
  final int currentPage;
  final bool hasNext;
  final bool hasPrevious;

  ComplaintsResponse({
    required this.results,
    required this.totalPages,
    required this.totalItems,
    required this.currentPage,
    required this.hasNext,
    required this.hasPrevious,
  });
}
