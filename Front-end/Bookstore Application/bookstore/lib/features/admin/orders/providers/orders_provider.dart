import 'package:flutter/foundation.dart';
import '../../../orders/models/order.dart';
import '../../services/manager_api_service.dart';

class OrdersProvider with ChangeNotifier {
  final ManagerApiService _apiService;

  List<Order> _orders = [];
  bool _isLoading = false;
  String? _error;

  OrdersProvider(this._apiService);

  // Getters
  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ManagerApiService get apiService => _apiService;

  // Get orders (alias for loadOrders)
  Future<void> getOrders({
    String? search,
    String? status,
    String? orderType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return loadOrders(
      search: search,
      status: status,
      orderType: orderType,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Load orders
  Future<void> loadOrders({
    String? search,
    String? status,
    String? orderType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    debugPrint('DEBUG: OrdersProvider.loadOrders called with:');
    debugPrint('  - search: $search');
    debugPrint('  - status: $status');
    debugPrint('  - orderType: $orderType');
    debugPrint('  - startDate: $startDate');
    debugPrint('  - endDate: $endDate');

    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.getOrders(
        search: search,
        status: status,
        orderType: orderType,
      );

      debugPrint(
        'DEBUG: OrdersProvider received response type: ${response.runtimeType}',
      );
      debugPrint('DEBUG: OrdersProvider response data: $response');

      // Handle different response formats
      if (response is List) {
        // Backend returns a list directly
        debugPrint(
          'DEBUG: OrdersProvider - Processing list response with ${response.length} items',
        );
        _orders = response.map((orderData) {
          try {
            if (orderData is! Map<String, dynamic>) {
              debugPrint(
                'AdminOrdersProvider: Order item is not a Map: ${orderData.runtimeType}',
              );
              debugPrint('AdminOrdersProvider: Order item data: $orderData');
              throw Exception(
                'Order item is not a Map: ${orderData.runtimeType}',
              );
            }
            return Order.fromJson(orderData);
          } catch (e) {
            debugPrint('AdminOrdersProvider: Error parsing order item: $e');
            debugPrint(
              'AdminOrdersProvider: Problematic order data: $orderData',
            );
            rethrow;
          }
        }).toList();
      } else if (response is Map<String, dynamic>) {
        // Backend returns a map response
        debugPrint('DEBUG: OrdersProvider - Processing map response');
        final results = response['results'] as List?;
        debugPrint(
          'DEBUG: OrdersProvider - Results list length: ${results?.length ?? 0}',
        );

        _orders =
            results?.map((orderData) {
              try {
                if (orderData is! Map<String, dynamic>) {
                  debugPrint(
                    'AdminOrdersProvider: Order item is not a Map: ${orderData.runtimeType}',
                  );
                  debugPrint(
                    'AdminOrdersProvider: Order item data: $orderData',
                  );
                  throw Exception(
                    'Order item is not a Map: ${orderData.runtimeType}',
                  );
                }
                return Order.fromJson(orderData);
              } catch (e) {
                debugPrint('AdminOrdersProvider: Error parsing order item: $e');
                debugPrint(
                  'AdminOrdersProvider: Problematic order data: $orderData',
                );
                rethrow;
              }
            }).toList() ??
            [];
      } else {
        debugPrint(
          'AdminOrdersProvider: Unexpected response format: ${response.runtimeType}',
        );
        debugPrint('AdminOrdersProvider: Response data: $response');
        throw Exception(
          'Unexpected response format from orders API: ${response.runtimeType}',
        );
      }

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load orders: $e');
      _setLoading(false);
    }
  }

  // Get order by ID
  Future<Order?> getOrderById(dynamic orderId) async {
    // Convert id to string if needed
    String orderIdStr = orderId.toString();
    _setLoading(true);
    _clearError();

    try {
      final order = await _apiService.getOrder(int.parse(orderIdStr));
      _setLoading(false);
      return order;
    } catch (e) {
      _setError('Failed to get order: $e');
      _setLoading(false);
      return null;
    }
  }

  // Update order status
  Future<bool> updateOrderStatus(int orderId, String status) async {
    _clearError();

    try {
      await _apiService.updateOrderStatus(orderId, status);

      // Update local data
      final index = _orders.indexWhere(
        (order) => order.id == orderId.toString(),
      );
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to update order status: $e');
      return false;
    }
  }

  // Start delivery (for delivery managers)
  // Returns the response data containing updated order and manager status
  Future<Map<String, dynamic>?> startDelivery(int orderId) async {
    _clearError();
    debugPrint('DEBUG: OrdersProvider.startDelivery called for order $orderId');

    try {
      final result = await _apiService.startDelivery(orderId);
      debugPrint('DEBUG: Start delivery result: $result');

      // Update local cache with fresh data from server response
      if (result['success'] == true) {
        // If order data is in response, update immediately
        if (result['order'] != null) {
          try {
            final orderData = result['order'] as Map<String, dynamic>;
            final updatedOrder = Order.fromJson(orderData);
            final index = _orders.indexWhere(
              (order) => order.id == orderId.toString(),
            );
            if (index != -1) {
              _orders[index] = updatedOrder;
            } else {
              _orders.add(updatedOrder);
            }
            notifyListeners();
            debugPrint(
              'DEBUG: Local order data updated from start delivery response',
            );
          } catch (e) {
            debugPrint('DEBUG: Error parsing order from response: $e');
          }
        }

        // Refresh order data from server to ensure we have latest
        await loadOrders();
      }

      return result;
    } catch (e) {
      debugPrint('DEBUG: Error starting delivery: $e');
      _setError('Failed to start delivery: $e');
      return null;
    }
  }

  // Complete delivery (for delivery managers)
  Future<bool> completeDelivery(int orderId) async {
    _clearError();
    debugPrint(
      'DEBUG: OrdersProvider.completeDelivery called for order $orderId',
    );

    try {
      final result = await _apiService.completeDelivery(orderId);
      debugPrint('DEBUG: Complete delivery result: $result');

      // Refresh order data
      await loadOrders();

      return true;
    } catch (e) {
      debugPrint('DEBUG: Error completing delivery: $e');
      _setError('Failed to complete delivery: $e');
      return false;
    }
  }

  // Approve order with delivery manager
  // Returns the updated order data from the response
  Future<Map<String, dynamic>?> approveOrder(
    int orderId,
    int deliveryManagerId,
  ) async {
    _clearError();
    debugPrint(
      'DEBUG: Approving order $orderId with delivery manager $deliveryManagerId',
    );

    try {
      final result = await _apiService.approveOrder(orderId, deliveryManagerId);
      debugPrint('DEBUG: Order approval result: $result');

      // Return the order data from the response immediately
      // This ensures the UI can update with fresh data from server
      if (result['success'] == true && result['order'] != null) {
        final orderData = result['order'] as Map<String, dynamic>;

        // Update local cache with fresh data from server
        try {
          final updatedOrder = Order.fromJson(orderData);
          final index = _orders.indexWhere(
            (order) => order.id == orderId.toString(),
          );
          if (index != -1) {
            _orders[index] = updatedOrder;
          } else {
            _orders.add(updatedOrder);
          }
          notifyListeners();
          debugPrint('DEBUG: Local order data updated from server response');
        } catch (e) {
          debugPrint('DEBUG: Error parsing order from response: $e');
        }

        return result;
      }

      return result;
    } catch (e) {
      debugPrint('DEBUG: Error approving order: $e');
      _setError('Failed to approve order: $e');
      return null;
    }
  }

  // Assign delivery manager to a confirmed order
  Future<bool> assignDeliveryManager(int orderId, int deliveryManagerId) async {
    _clearError();
    debugPrint(
      'DEBUG: Assigning delivery manager $deliveryManagerId to order $orderId',
    );

    try {
      final result = await _apiService.assignDeliveryManager(
        orderId,
        deliveryManagerId,
      );
      debugPrint('DEBUG: Delivery manager assignment result: $result');

      // Refresh order data
      await loadOrders();

      return true;
    } catch (e) {
      debugPrint('DEBUG: Error assigning delivery manager: $e');
      _setError('Failed to assign delivery manager: $e');
      return false;
    }
  }

  // Reject order with reason
  Future<bool> rejectOrder(int orderId, String rejectionReason) async {
    _clearError();

    try {
      await _apiService.rejectOrder(orderId, rejectionReason);

      // Update local data
      final index = _orders.indexWhere(
        (order) => order.id == orderId.toString(),
      );
      if (index != -1) {
        _orders[index] = _orders[index].copyWith(
          status: 'cancelled',
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to reject order: $e');
      return false;
    }
  }

  // Accept delivery assignment (for delivery managers)
  Future<bool> acceptAssignment(int assignmentId) async {
    _clearError();
    debugPrint(
      'DEBUG: OrdersProvider.acceptAssignment called for assignment $assignmentId',
    );

    try {
      await _apiService.updateDeliveryStatus(assignmentId, 'accepted');
      debugPrint('DEBUG: Assignment accepted successfully');

      // Refresh order data
      await loadOrders();

      return true;
    } catch (e) {
      debugPrint('DEBUG: Error accepting assignment: $e');
      _setError('Failed to accept assignment: $e');
      return false;
    }
  }

  // Reject delivery assignment (for delivery managers)
  Future<bool> rejectAssignment(int assignmentId, {String? reason}) async {
    _clearError();
    debugPrint(
      'DEBUG: OrdersProvider.rejectAssignment called for assignment $assignmentId',
    );

    try {
      await _apiService.updateDeliveryStatus(
        assignmentId,
        'cancelled',
        failureReason: reason,
      );
      debugPrint('DEBUG: Assignment rejected successfully');

      // Refresh order data
      await loadOrders();

      return true;
    } catch (e) {
      debugPrint('DEBUG: Error rejecting assignment: $e');
      _setError('Failed to reject assignment: $e');
      return false;
    }
  }

  // Cancel order
  Future<bool> cancelOrder(int orderId, String reason) async {
    return await updateOrderStatus(orderId, 'cancelled');
  }

  // Confirm order
  Future<bool> confirmOrder(int orderId) async {
    return await updateOrderStatus(orderId, 'confirmed');
  }

  // confirmed order
  Future<bool> processOrder(int orderId) async {
    return await updateOrderStatus(orderId, 'confirmed');
  }

  // delivered order
  Future<bool> completeOrder(int orderId) async {
    return await updateOrderStatus(orderId, 'delivered');
  }

  // Get delivery location for an order
  Future<Map<String, dynamic>?> getOrderDeliveryLocation(int orderId) async {
    _clearError();
    try {
      final result = await _apiService.getOrderDeliveryLocation(orderId);
      return result;
    } catch (e) {
      _setError('Failed to get delivery location: $e');
      return null;
    }
  }

  // Add notes to an order
  Future<bool> addOrderNotes(String orderId, String notes) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.addOrderNotes(orderId, notes);

      // Reload order to get updated notes
      await getOrderById(orderId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to add notes: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Edit notes for an order
  Future<bool> editOrderNotes(
    String orderId,
    String notes, {
    int? noteId,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.editOrderNotes(orderId, notes, noteId: noteId);

      // Reload order to get updated notes
      await getOrderById(orderId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to edit notes: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Delete notes for an order
  Future<bool> deleteOrderNotes(String orderId, {int? noteId}) async {
    _setLoading(true);
    _clearError();

    try {
      await _apiService.deleteOrderNotes(orderId, noteId: noteId);

      // Reload order to get updated notes
      await getOrderById(orderId);

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Failed to delete notes: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Search orders
  Future<void> searchOrders(String query) async {
    await loadOrders(search: query);
  }

  // Filter by status
  Future<void> filterByStatus(String? status) async {
    await loadOrders(status: status);
  }

  // Filter by date range
  Future<void> filterByDateRange(DateTime? startDate, DateTime? endDate) async {
    await loadOrders(startDate: startDate, endDate: endDate);
  }

  // Refresh orders
  Future<void> refresh() async {
    await loadOrders();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // Clear all data
  void clear() {
    _orders.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // Update the API service with a new token
  void setToken(String? token) {
    debugPrint(
      'DEBUG: AdminOrdersProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    if (token != null && token.isNotEmpty) {
      _apiService.setToken(token);
      debugPrint('DEBUG: AdminOrdersProvider token set successfully');
    } else {
      debugPrint('DEBUG: AdminOrdersProvider token is null or empty');
    }
  }
}

// Response model for API calls
class OrdersResponse {
  final List<Order> results;
  final int totalItems;
  final int totalPages;

  OrdersResponse({
    required this.results,
    required this.totalItems,
    required this.totalPages,
  });
}
