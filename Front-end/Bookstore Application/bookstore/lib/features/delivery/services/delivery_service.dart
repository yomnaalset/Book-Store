import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/delivery_task.dart';
import '../models/delivery_task_update_request.dart';
import '../models/delivery_eta.dart';

class DeliveryService {
  final String baseUrl;
  final Map<String, String> headers;
  final String Function()? getAuthToken;
  String? _errorMessage;
  String? _cachedToken;

  DeliveryService({
    required this.baseUrl,
    required this.headers,
    this.getAuthToken,
  });

  // Set the authentication token directly
  void setToken(String? token) {
    debugPrint(
      'DeliveryService: Setting token: ${token != null ? "${token.substring(0, token.length > 20 ? 20 : token.length)}..." : "null"}',
    );
    _cachedToken = token;
  }

  // Get headers with authentication token
  Map<String, String> _getHeaders() {
    final authHeaders = Map<String, String>.from(headers);

    // Add Content-Type for JSON requests
    authHeaders['Content-Type'] = 'application/json';

    // Get token from cache or function
    final token = _cachedToken ?? (getAuthToken?.call());

    if (token != null && token.isNotEmpty) {
      authHeaders['Authorization'] = 'Bearer $token';
      debugPrint('DeliveryService: Added Authorization header with token');
    } else {
      debugPrint(
        'DeliveryService: No token available for Authorization header',
      );
    }

    return authHeaders;
  }

  String? get errorMessage => _errorMessage;

  // Get all tasks for delivery manager
  Future<List<DeliveryTask>> getAllTasks() async {
    _clearError();
    List<DeliveryTask> allTasks = [];

    // First, fetch assigned delivery requests
    try {
      final requestsUrl = '$baseUrl/delivery/managers/assigned-requests/';
      final headers = _getHeaders();

      debugPrint('DeliveryService: Making GET request to: $requestsUrl');
      debugPrint('DeliveryService: Headers: $headers');

      final requestsResponse = await http.get(
        Uri.parse(requestsUrl),
        headers: headers,
      );

      debugPrint(
        'DeliveryService: Requests response status: ${requestsResponse.statusCode}',
      );
      debugPrint(
        'DeliveryService: Requests response body: ${requestsResponse.body}',
      );

      if (requestsResponse.statusCode == 200) {
        final data = jsonDecode(requestsResponse.body);
        if (data is List) {
          final tasks = data
              .map((json) => DeliveryTask.fromJson(json))
              .toList();
          debugPrint(
            'DeliveryService: Successfully parsed ${tasks.length} requests from list response',
          );
          allTasks.addAll(tasks);
        } else if (data['results'] != null) {
          final List<dynamic> tasksJson = data['results'];
          final tasks = tasksJson
              .map((json) => DeliveryTask.fromJson(json))
              .toList();
          debugPrint(
            'DeliveryService: Successfully parsed ${tasks.length} requests from results response',
          );
          allTasks.addAll(tasks);
        }
      }
    } catch (e) {
      debugPrint('DeliveryService: Exception fetching requests: $e');
      // Continue to next request even if this one fails
    }

    // Second, fetch delivery assignments (orders)
    try {
      final assignmentsUrl = '$baseUrl/delivery/assignments/my-assignments/';
      final headers = _getHeaders();

      debugPrint('DeliveryService: Making GET request to: $assignmentsUrl');

      final assignmentsResponse = await http.get(
        Uri.parse(assignmentsUrl),
        headers: headers,
      );

      debugPrint(
        'DeliveryService: Assignments response status: ${assignmentsResponse.statusCode}',
      );
      debugPrint(
        'DeliveryService: Assignments response body: ${assignmentsResponse.body}',
      );

      if (assignmentsResponse.statusCode == 200) {
        final data = jsonDecode(assignmentsResponse.body);
        if (data is List) {
          final assignments = data
              .map((json) => _convertAssignmentToTask(json))
              .whereType<DeliveryTask>() // Filter out nulls
              .toList();
          debugPrint(
            'DeliveryService: Successfully parsed ${assignments.length} assignments from list response',
          );
          allTasks.addAll(assignments);
        } else if (data['results'] != null) {
          final List<dynamic> assignmentsJson = data['results'];
          final assignments = assignmentsJson
              .map((json) => _convertAssignmentToTask(json))
              .whereType<DeliveryTask>() // Filter out nulls
              .toList();
          debugPrint(
            'DeliveryService: Successfully parsed ${assignments.length} assignments from results response',
          );
          allTasks.addAll(assignments);
        }
      }
    } catch (e) {
      debugPrint('DeliveryService: Exception fetching assignments: $e');
      // Continue even if this request fails
    }

    if (allTasks.isEmpty) {
      _setError('Failed to load any tasks');
    } else {
      debugPrint('DeliveryService: Total tasks loaded: ${allTasks.length}');
    }

    return allTasks;
  }

  // Convert a delivery assignment to a delivery task
  DeliveryTask? _convertAssignmentToTask(Map<String, dynamic> json) {
    try {
      debugPrint('DeliveryService: Converting assignment to task: $json');

      // Check if order is an integer (ID) or an object
      final orderId = json['order'] is int
          ? json['order'].toString()
          : (json['order'] as Map<String, dynamic>?)?['id']?.toString() ?? '';

      final orderNumber = json['order_number'] ?? 'ORDER-$orderId';

      // If order is just an ID, we have limited information
      // We'll create a basic task with the available data
      if (json['order'] is int) {
        debugPrint('DeliveryService: Order is an ID, creating basic task');
        return DeliveryTask(
          id: json['id']?.toString() ?? '',
          taskNumber: orderNumber,
          taskType: 'delivery',
          status: json['status'] ?? 'assigned',
          orderId: orderId,
          customerId: '',
          customerName: 'Order $orderNumber',
          customerPhone: '',
          customerEmail: '',
          customerAddress: '',
          deliveryAddress: '',
          deliveryCity: '',
          notes: '',
          assignedAt: json['assigned_at'] != null
              ? DateTime.parse(json['assigned_at'])
              : DateTime.now(),
          acceptedAt: json['started_at'] != null
              ? DateTime.parse(json['started_at'])
              : null,
          pickedUpAt: null,
          deliveredAt: json['completed_at'] != null
              ? DateTime.parse(json['completed_at'])
              : null,
          completedAt: json['completed_at'] != null
              ? DateTime.parse(json['completed_at'])
              : null,
          estimatedDeliveryTime: json['estimated_delivery_time'] != null
              ? DateTime.parse(json['estimated_delivery_time'])
              : null,
          deliveryNotes: '',
          failureReason: null,
          retryCount: 0,
          items: <String>[],
          eta: json['estimated_delivery_time'] != null
              ? DateTime.parse(json['estimated_delivery_time'])
              : null,
          statusHistory: <Map<String, dynamic>>[],
          proofOfDelivery: null,
          createdAt: json['assigned_at'] != null
              ? DateTime.parse(json['assigned_at'])
              : DateTime.now(),
          updatedAt: DateTime.now(),
          deliveryPersonId: json['delivery_manager']?.toString() ?? '',
          scheduledDate: json['assigned_at'] != null
              ? DateTime.parse(json['assigned_at'])
              : null,
          deliveredDate: json['completed_at'] != null
              ? DateTime.parse(json['completed_at'])
              : null,
          latitude: null,
          longitude: null,
        );
      }

      // Extract order data if it's an object
      final orderData = json['order'] as Map<String, dynamic>?;
      if (orderData == null) {
        debugPrint('DeliveryService: No order data in assignment');
        return null;
      }

      debugPrint('📚 DeliveryService: Order data: $orderData');
      debugPrint('📚 DeliveryService: Order items: ${orderData['items']}');

      // Debug each item individually
      if (orderData['items'] != null) {
        final items = orderData['items'] as List;
        debugPrint('📚 DeliveryService: Found ${items.length} items');
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          debugPrint('📚 DeliveryService: Item $i: $item');
          debugPrint(
            '📚 DeliveryService: Item $i book_title: ${item['book_title']}',
          );
          debugPrint(
            '📚 DeliveryService: Item $i book_author: ${item['book_author']}',
          );
          debugPrint('📚 DeliveryService: Item $i book: ${item['book']}');
        }
      }

      // Extract customer data if available
      final customerData = orderData['customer'] as Map<String, dynamic>?;

      return DeliveryTask(
        id: json['id']?.toString() ?? '',
        taskNumber:
            orderData['order_number'] ?? 'ORDER-${orderData['id'] ?? ''}',
        taskType: 'delivery',
        status: json['status'] ?? 'assigned',
        orderId: orderData['id']?.toString() ?? '',
        customerId: customerData?['id']?.toString() ?? '',
        customerName:
            customerData?['full_name'] ??
            customerData?['get_full_name'] ??
            'Unknown Customer',
        customerPhone: customerData?['phone_number'] ?? '',
        customerEmail: customerData?['email'] ?? '',
        customerAddress: orderData['delivery_address'] ?? '',
        deliveryAddress: orderData['delivery_address'] ?? '',
        deliveryCity: orderData['delivery_city'] ?? '',
        notes: orderData['notes'] ?? '',
        assignedAt: json['assigned_at'] != null
            ? DateTime.parse(json['assigned_at'])
            : DateTime.now(),
        acceptedAt: null,
        pickedUpAt: null,
        deliveredAt: null,
        completedAt: null,
        estimatedDeliveryTime: null,
        deliveryNotes: orderData['delivery_notes'] ?? '',
        failureReason: null,
        retryCount: 0,
        orderItems: orderData['items'] != null
            ? (orderData['items'] as List).map((item) {
                debugPrint('📚 DeliveryService: Processing item: $item');
                final processedItem = {
                  'bookTitle':
                      item['book_title'] ??
                      item['book']?['name'] ??
                      'Unknown Book',
                  'bookAuthor':
                      item['book_author'] ??
                      item['book']?['author']?['name'] ??
                      'Unknown Author',
                  'quantity': item['quantity'] ?? 1,
                  'unitPrice': item['unit_price'] ?? 0.0,
                  'totalPrice': item['total_price'] ?? 0.0,
                };
                debugPrint(
                  '📚 DeliveryService: Processed item: $processedItem',
                );
                return processedItem;
              }).toList()
            : <Map<String, dynamic>>[],
        eta: null,
        statusHistory: <Map<String, dynamic>>[],
        proofOfDelivery: null,
        createdAt: orderData['created_at'] != null
            ? DateTime.parse(orderData['created_at'])
            : DateTime.now(),
        updatedAt: orderData['updated_at'] != null
            ? DateTime.parse(orderData['updated_at'])
            : DateTime.now(),
      );
    } catch (e, stackTrace) {
      debugPrint('DeliveryService: Error converting assignment to task: $e');
      debugPrint('DeliveryService: Stack trace: $stackTrace');
      return null;
    }
  }

  // Update task status
  Future<bool> updateTaskStatus(String taskId, String status) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/assignments/$taskId/update-status/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'status': status,
        'notes': 'Status updated via mobile app',
      });

      debugPrint('🚀 DeliveryService: Starting status update...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');
      debugPrint('🚀 DeliveryService: TaskId: $taskId');
      debugPrint('🚀 DeliveryService: Status: $status');

      // Use the delivery assignment status update endpoint
      final response = await http.patch(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: Status update response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response headers: ${response.headers}');
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🚀 DeliveryService: Success! Data: $data');
        return data['success'] == true || data['message'] != null;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid status transition');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      } else if (response.statusCode == 403) {
        _setError(
          'Permission denied: Only assigned delivery manager can update status',
        );
        debugPrint('🚀 DeliveryService: Permission denied');
        return false;
      } else if (response.statusCode == 404) {
        _setError('Task not found: $taskId');
        debugPrint('🚀 DeliveryService: Task not found: $taskId');
        return false;
      }

      _setError('Failed to update task status: ${response.statusCode}');
      debugPrint(
        '🚀 DeliveryService: Unexpected status code: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Update delivery manager location
  Future<bool> updateLocation(
    String taskId,
    double latitude,
    double longitude,
  ) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/location/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'task_id': taskId,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
      });

      debugPrint('🚀 DeliveryService: Starting location update...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');
      debugPrint('🚀 DeliveryService: TaskId: $taskId');
      debugPrint(
        '🚀 DeliveryService: Latitude: $latitude, Longitude: $longitude',
      );

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: Location update response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🚀 DeliveryService: Location update success! Data: $data');
        return data['success'] == true || data['message'] != null;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid location data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      } else if (response.statusCode == 403) {
        _setError(
          'Permission denied: Only delivery managers can update location',
        );
        debugPrint('🚀 DeliveryService: Permission denied');
        return false;
      }

      _setError('Failed to update location: ${response.statusCode}');
      debugPrint(
        '🚀 DeliveryService: Unexpected status code: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Get availability status
  Future<String?> getAvailabilityStatus() async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery/managers/available/'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Check if current user is in the available managers list
        final managers = data['delivery_managers'] as List?;
        if (managers != null && managers.isNotEmpty) {
          return 'available';
        }
        return 'unavailable';
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        // User doesn't have permission to access this endpoint
        // This means they're not a delivery manager
        return null;
      }

      return null;
    } catch (e) {
      // If there's an error, user is likely not a delivery manager
      // Return null to indicate no availability status
      return null;
    }
  }

  // Update availability status using the new delivery profile API
  Future<bool> updateAvailabilityStatus(String status) async {
    _clearError();

    try {
      // Convert availability status to delivery manager status
      String managerStatus;
      if (status == 'available') {
        managerStatus = 'online';
      } else if (status == 'busy') {
        managerStatus = 'busy';
      } else {
        managerStatus = 'offline';
      }

      debugPrint('DeliveryService: Updating status to: $managerStatus');

      final response = await http.post(
        Uri.parse('$baseUrl/delivery-profiles/update_status/'),
        headers: _getHeaders(),
        body: jsonEncode({'delivery_status': managerStatus}),
      );

      debugPrint(
        'DeliveryService: Status update response: ${response.statusCode}',
      );
      debugPrint('DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true || data['message'] != null;
      }

      _setError('Failed to update availability status: ${response.statusCode}');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      return false;
    }
  }

  // Helper methods
  void _setError(String error) {
    _errorMessage = error;
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Get delivery tasks for a delivery manager
  Future<List<DeliveryTask>> getDeliveryTasks({
    String? status,
    String? taskType,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (taskType != null) queryParams['task_type'] = taskType;
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final uri = Uri.parse(
        '$baseUrl/delivery/tasks/',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['tasks'] != null) {
          return (data['tasks'] as List)
              .map((task) => DeliveryTask.fromJson(task))
              .toList();
        }
        throw Exception(data['message'] ?? 'Failed to fetch delivery tasks');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching delivery tasks: $e');
    }
  }

  // Get a specific delivery task by ID
  Future<DeliveryTask?> getDeliveryTask(int taskId) async {
    try {
      final uri = Uri.parse('$baseUrl/delivery/tasks/$taskId/');
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['task'] != null) {
          return DeliveryTask.fromJson(data['task']);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching delivery task: $e');
    }
  }

  // Update delivery task status
  Future<bool> updateDeliveryTaskStatus(
    int taskId,
    DeliveryTaskUpdateRequest updateRequest,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/delivery/tasks/$taskId/update-status/');
      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: json.encode(updateRequest.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to update task status');
      }
    } catch (e) {
      throw Exception('Error updating delivery task status: $e');
    }
  }

  // Accept a delivery task
  Future<bool> acceptDeliveryTask(int taskId, {String? notes}) async {
    final updateRequest = DeliveryTaskUpdateRequest(
      status: DeliveryTask.statusAccepted,
      notes: notes,
    );
    return await updateDeliveryTaskStatus(taskId, updateRequest);
  }

  // Mark task as picked up
  Future<bool> markTaskAsPickedUp(int taskId, {String? notes}) async {
    final updateRequest = DeliveryTaskUpdateRequest(
      status: DeliveryTask.statusPickedUp,
      notes: notes,
    );
    return await updateDeliveryTaskStatus(taskId, updateRequest);
  }

  // Mark task as in transit
  Future<bool> markTaskAsInTransit(int taskId, {String? notes}) async {
    final updateRequest = DeliveryTaskUpdateRequest(
      status: DeliveryTask.statusInTransit,
      notes: notes,
    );
    return await updateDeliveryTaskStatus(taskId, updateRequest);
  }

  // Mark task as delivered
  Future<bool> markTaskAsDelivered(
    int taskId, {
    String? proofOfDelivery,
    String? notes,
  }) async {
    final updateRequest = DeliveryTaskUpdateRequest(
      status: DeliveryTask.statusDelivered,
      notes: notes,
      proofOfDelivery: proofOfDelivery,
    );
    return await updateDeliveryTaskStatus(taskId, updateRequest);
  }

  // Mark task as completed
  Future<bool> markTaskAsCompleted(int taskId, {String? notes}) async {
    final updateRequest = DeliveryTaskUpdateRequest(
      status: DeliveryTask.statusCompleted,
      notes: notes,
    );
    return await updateDeliveryTaskStatus(taskId, updateRequest);
  }

  // Mark task as failed
  Future<bool> markTaskAsFailed(
    int taskId, {
    String? failureReason,
    String? notes,
  }) async {
    final updateRequest = DeliveryTaskUpdateRequest(
      status: DeliveryTask.statusFailed,
      notes: notes,
      failureReason: failureReason,
    );
    return await updateDeliveryTaskStatus(taskId, updateRequest);
  }

  // Update delivery ETA
  Future<DeliveryETA?> updateDeliveryETA(
    int taskId,
    DeliveryETACalculation etaCalculation,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl/delivery/tasks/$taskId/update-eta/');
      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: json.encode(etaCalculation.toJson()),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['eta'] != null) {
          return DeliveryETA.fromJson(data['eta']);
        }
        throw Exception(data['message'] ?? 'Failed to update ETA');
      } else {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to update ETA');
      }
    } catch (e) {
      throw Exception('Error updating delivery ETA: $e');
    }
  }

  // Get delivery manager dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final uri = Uri.parse('$baseUrl/delivery/dashboard/stats/');
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return data['statistics'] ?? {};
        }
        throw Exception(data['message'] ?? 'Failed to fetch dashboard stats');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching dashboard stats: $e');
    }
  }

  // Get delivery manager availability status
  Future<String> getAvailabilityStatusx() async {
    try {
      final uri = Uri.parse('$baseUrl/delivery/availability/status/');
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] ?? 'offline';
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching availability status: $e');
    }
  }

  // Update delivery manager availability status
  Future<bool> updateAvailabilityStatusx(String status) async {
    try {
      final uri = Uri.parse('$baseUrl/delivery/availability/update/');
      final response = await http.post(
        uri,
        headers: _getHeaders(),
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        final data = json.decode(response.body);
        throw Exception(
          data['message'] ?? 'Failed to update availability status',
        );
      }
    } catch (e) {
      throw Exception('Error updating availability status: $e');
    }
  }

  // Get delivery notifications
  Future<List<Map<String, dynamic>>> getNotificationsx({
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (limit != null) queryParams['limit'] = limit.toString();
      if (offset != null) queryParams['offset'] = offset.toString();

      final uri = Uri.parse(
        '$baseUrl/delivery/notifications/',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['notifications'] != null) {
          // The response now includes unread_count, but we'll still use the
          // dedicated endpoint for consistency
          return List<Map<String, dynamic>>.from(data['notifications']);
        }
        return [];
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching notifications: $e');
    }
  }

  // Mark notification as read
  Future<bool> markNotificationAsReadx(int notificationId) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/delivery/notifications/$notificationId/mark-read/',
      );
      final response = await http.post(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['success'] == true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Get unread notifications count for delivery notifications
  // This uses the delivery-specific endpoint that filters by delivery notification types
  // to ensure the count matches what's shown in the notifications list
  Future<int> getUnreadNotificationsCount() async {
    try {
      final uri = Uri.parse('$baseUrl/delivery/notifications/unread-count/');
      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['unread_count'] ?? 0;
      } else {
        debugPrint(
          'Failed to get delivery unread count: ${response.statusCode} - ${response.body}',
        );
        return 0;
      }
    } catch (e) {
      debugPrint('Error getting delivery unread count: $e');
      return 0;
    }
  }

  // Delete a notification
  Future<bool> deleteNotification(int notificationId) async {
    try {
      final uri = Uri.parse('$baseUrl/notifications/$notificationId/');
      final response = await http.delete(uri, headers: _getHeaders());

      if (response.statusCode == 204 || response.statusCode == 200) {
        return true;
      } else {
        debugPrint(
          'Failed to delete notification: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      return false;
    }
  }

  // Delete all notifications
  Future<bool> deleteAllNotifications() async {
    try {
      final uri = Uri.parse('$baseUrl/notifications/delete_all/');
      final response = await http.delete(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Deleted ${data['deleted_count'] ?? 0} notifications');
        return true;
      } else {
        debugPrint(
          'Failed to delete all notifications: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      debugPrint('Error deleting all notifications: $e');
      return false;
    }
  }

  // Get delivery task history
  Future<List<DeliveryTask>> getDeliveryTaskHistoryx({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int? offset,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null) queryParams['status'] = status;
      if (fromDate != null) {
        queryParams['from_date'] = fromDate.toIso8601String();
      }
      if (toDate != null) {
        queryParams['to_date'] = toDate.toIso8601String();
      }
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }
      if (offset != null) {
        queryParams['offset'] = offset.toString();
      }

      final uri = Uri.parse(
        '$baseUrl/delivery/tasks/history/',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['tasks'] != null) {
          return (data['tasks'] as List)
              .map((task) => DeliveryTask.fromJson(task))
              .toList();
        }
        return [];
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error fetching delivery task history: $e');
    }
  }

  // Search delivery tasks
  Future<List<DeliveryTask>> searchDeliveryTasksx(String query) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/delivery/tasks/search/',
      ).replace(queryParameters: {'q': query});

      final response = await http.get(uri, headers: _getHeaders());

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['tasks'] != null) {
          return (data['tasks'] as List)
              .map((task) => DeliveryTask.fromJson(task))
              .toList();
        }
        return [];
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error searching delivery tasks: $e');
    }
  }

  // Assign delivery agent to task
  Future<bool> assignDeliveryAgentx(
    String taskId, {
    required String deliveryAgentId,
    String? notes,
  }) async {
    _clearError();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/delivery/tasks/$taskId/assign'),
        headers: _getHeaders(),
        body: jsonEncode({'deliveryAgentId': deliveryAgentId, 'notes': notes}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }

      _setError('Failed to assign delivery agent');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      return false;
    }
  }

  Future<bool> updateETA(String taskId, DateTime eta) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/tasks/$taskId/eta/';
      final headers = _getHeaders();

      // Format date and time as expected by backend
      final dateStr =
          '${eta.day.toString().padLeft(2, '0')}/${eta.month.toString().padLeft(2, '0')}/${eta.year}';
      final timeStr =
          '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';

      final body = jsonEncode({
        'eta': {'date': dateStr, 'time': timeStr},
      });

      debugPrint('🚀 DeliveryService: Starting ETA update...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');
      debugPrint('🚀 DeliveryService: TaskId: $taskId');
      debugPrint('🚀 DeliveryService: ETA: $eta');
      debugPrint('🚀 DeliveryService: Formatted date: $dateStr');
      debugPrint('🚀 DeliveryService: Formatted time: $timeStr');

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: ETA update response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🚀 DeliveryService: ETA update success! Data: $data');
        return data['message'] != null;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid ETA data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      } else if (response.statusCode == 403) {
        _setError('Permission denied: Only delivery managers can update ETA');
        debugPrint('🚀 DeliveryService: Permission denied');
        return false;
      } else if (response.statusCode == 404) {
        _setError('Task not found: $taskId');
        debugPrint('🚀 DeliveryService: Task not found: $taskId');
        return false;
      }

      _setError('Failed to update ETA: ${response.statusCode}');
      debugPrint(
        '🚀 DeliveryService: Unexpected status code: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Add notes to an order
  Future<bool> addOrderNotes(String orderId, String notes) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/activities/log/note/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'order_id': int.parse(orderId),
        'notes_content': notes,
        'action': 'add',
      });

      debugPrint('🚀 DeliveryService: Starting notes addition...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');
      debugPrint('🚀 DeliveryService: OrderId: $orderId');
      debugPrint('🚀 DeliveryService: Notes: $notes');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: Notes addition response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🚀 DeliveryService: Notes addition success! Data: $data');
        return data['message'] != null;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid notes data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      } else if (response.statusCode == 403) {
        _setError('Permission denied: You cannot add notes to this order');
        debugPrint('🚀 DeliveryService: Permission denied');
        return false;
      } else if (response.statusCode == 404) {
        _setError('Order not found: $orderId');
        debugPrint('🚀 DeliveryService: Order not found: $orderId');
        return false;
      }

      _setError('Failed to add notes: ${response.statusCode}');
      debugPrint(
        '🚀 DeliveryService: Unexpected status code: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Edit notes for an order
  Future<bool> editOrderNotes(String orderId, String notes, {int? noteId}) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/activities/log/note/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'order_id': int.parse(orderId),
        'notes_content': notes,
        'action': 'edit',
        if (noteId != null) 'note_id': noteId,
      });

      debugPrint('🚀 DeliveryService: Starting notes edit...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: Notes edit response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🚀 DeliveryService: Notes edit success! Data: $data');
        return data['message'] != null;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid notes data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      }

      _setError('Failed to edit notes: ${response.statusCode}');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Delete notes for an order
  Future<bool> deleteOrderNotes(String orderId, {int? noteId}) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/activities/log/note/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'order_id': int.parse(orderId),
        'action': 'delete',
        if (noteId != null) 'note_id': noteId,
      });

      debugPrint('🚀 DeliveryService: Starting notes deletion...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: Notes deletion response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('🚀 DeliveryService: Notes deletion success! Data: $data');
        return data['message'] != null;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid notes data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      }

      _setError('Failed to delete notes: ${response.statusCode}');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Get delivery tracking information
  Future<Map<String, dynamic>?> getDeliveryTrackingx(String taskId) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/delivery/tasks/$taskId/tracking'),
        headers: _getHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        }
      }

      _setError('Failed to get delivery tracking');
      return null;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      return null;
    }
  }

  // Contact customer activity
  Future<bool> logContactCustomerActivity(
    String orderId,
    String contactMethod,
  ) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/activities/log/contact/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'order_id': int.parse(orderId),
        'contact_method': contactMethod,
      });

      debugPrint('🚀 DeliveryService: Logging contact customer activity...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: Contact activity response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint(
          '🚀 DeliveryService: Contact activity logged successfully! Data: $data',
        );
        return true;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid contact data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      }

      _setError('Failed to log contact activity: ${response.statusCode}');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Update location activity
  Future<bool> logLocationUpdateActivity(
    String orderId,
    double latitude,
    double longitude,
  ) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/activities/log/location/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'order_id': int.parse(orderId),
        'latitude': latitude,
        'longitude': longitude,
      });

      debugPrint('🚀 DeliveryService: Logging location update activity...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: Location activity response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint(
          '🚀 DeliveryService: Location activity logged successfully! Data: $data',
        );
        return true;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid location data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      }

      _setError('Failed to log location activity: ${response.statusCode}');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Update route activity
  Future<bool> logRouteUpdateActivity(
    String orderId,
    List<Map<String, double>> routePoints,
  ) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/activities/log/route/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'order_id': int.parse(orderId),
        'route_points': routePoints,
      });

      debugPrint('🚀 DeliveryService: Logging route update activity...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: Route activity response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint(
          '🚀 DeliveryService: Route activity logged successfully! Data: $data',
        );
        return true;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid route data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      }

      _setError('Failed to log route activity: ${response.statusCode}');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Update ETA activity
  Future<bool> logETAUpdateActivity(
    String orderId,
    DateTime estimatedArrivalTime,
  ) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/activities/log/eta/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'order_id': int.parse(orderId),
        'estimated_delivery_time': estimatedArrivalTime.toIso8601String(),
      });

      debugPrint('🚀 DeliveryService: Logging ETA update activity...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: ETA activity response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint(
          '🚀 DeliveryService: ETA activity logged successfully! Data: $data',
        );
        return true;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid ETA data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      }

      _setError('Failed to log ETA activity: ${response.statusCode}');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Record delivery activity
  Future<bool> logDeliveryRecordActivity(
    String orderId,
    String status,
    DateTime deliveredAt,
  ) async {
    _clearError();

    try {
      final url = '$baseUrl/delivery/activities/log/delivery/';
      final headers = _getHeaders();
      final body = jsonEncode({
        'order_id': int.parse(orderId),
        'status': status,
        'delivered_at': deliveredAt.toIso8601String(),
      });

      debugPrint('🚀 DeliveryService: Logging delivery record activity...');
      debugPrint('🚀 DeliveryService: URL: $url');
      debugPrint('🚀 DeliveryService: Headers: $headers');
      debugPrint('🚀 DeliveryService: Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint(
        '🚀 DeliveryService: Delivery record activity response: ${response.statusCode}',
      );
      debugPrint('🚀 DeliveryService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint(
          '🚀 DeliveryService: Delivery record activity logged successfully! Data: $data',
        );
        return true;
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        _setError(data['error'] ?? 'Invalid delivery data');
        debugPrint('🚀 DeliveryService: Bad request - ${data['error']}');
        return false;
      }

      _setError(
        'Failed to log delivery record activity: ${response.statusCode}',
      );
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('🚀 DeliveryService: Exception: $e');
      return false;
    }
  }

  // Log delivery activity (legacy method for backward compatibility)
  Future<bool> logDeliveryActivity(
    String orderId,
    String activityType,
    Map<String, dynamic>? activityData,
  ) async {
    // This method is deprecated - use specific activity logging methods instead
    debugPrint(
      '🚀 DeliveryService: logDeliveryActivity is deprecated - use specific activity logging methods',
    );
    return true; // Return success to avoid breaking existing code
  }
}
