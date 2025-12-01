import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/order.dart';
import '../services/orders_service.dart';

class OrdersProvider extends ChangeNotifier {
  final OrdersService _ordersService;
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  OrdersProvider(this._ordersService) {
    _loadOrdersFromLocal();
  }

  // Getters
  List<Order> get orders => List.unmodifiable(_orders);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  int get count => _orders.length;

  // Get orders by status
  List<Order> getOrdersByStatus(String status) {
    return _orders
        .where((order) => order.status.toLowerCase() == status.toLowerCase())
        .toList();
  }

  // Get pending orders
  List<Order> get pendingOrders => getOrdersByStatus('pending');

  // Get confirmed orders
  List<Order> get confirmedOrders => getOrdersByStatus('confirmed');

  // Get in delivery orders
  List<Order> get inDeliveryOrders => getOrdersByStatus('in_delivery');

  // Get delivered orders
  List<Order> get deliveredOrders => getOrdersByStatus('delivered');

  // Get returned orders
  List<Order> get returnedOrders => getOrdersByStatus('returned');

  // Get orders by type
  List<Order> getOrdersByType(String orderType) {
    return _orders
        .where(
          (order) => order.orderType.toLowerCase() == orderType.toLowerCase(),
        )
        .toList();
  }

  // Get purchase orders
  List<Order> get purchaseOrders => getOrdersByType('purchase');

  // Get borrowing orders
  List<Order> get borrowingOrders => getOrdersByType('borrowing');

  // Get return orders
  List<Order> get returnOrders => getOrdersByType('return_collection');

  // Search and filter functionality
  List<Order> searchAndFilterOrders(
    String query, {
    String? orderType,
    String? status,
  }) {
    List<Order> filteredOrders = _orders;

    // Filter by order type if specified
    if (orderType != null && orderType.isNotEmpty) {
      filteredOrders = filteredOrders
          .where(
            (order) => order.orderType.toLowerCase() == orderType.toLowerCase(),
          )
          .toList();
    }

    // Filter by status if specified (skip if status is 'all')
    if (status != null && status.isNotEmpty && status.toLowerCase() != 'all') {
      filteredOrders = filteredOrders
          .where((order) => order.status.toLowerCase() == status.toLowerCase())
          .toList();
    }

    // Search by query if provided
    if (query.isNotEmpty) {
      filteredOrders = filteredOrders.where((order) {
        final searchQuery = query.toLowerCase();
        return order.id.toString().contains(searchQuery) ||
            order.customerName.toLowerCase().contains(searchQuery) ||
            order.customerEmail.toLowerCase().contains(searchQuery) ||
            order.orderType.toLowerCase().contains(searchQuery) ||
            order.status.toLowerCase().contains(searchQuery);
      }).toList();
    }

    return filteredOrders;
  }

  // Get available filter options for order types
  List<String> get orderTypeFilterOptions => [
    'purchase',
    'borrowing',
    'return_collection',
  ];

  // Get available filter options for statuses
  List<String> get statusFilterOptions => [
    'all',
    'pending',
    'waiting_for_delivery_manager',
    'rejected_by_admin',
    'rejected_by_delivery_manager',
    'in_delivery',
    'completed',
    'confirmed',
    'delivered',
  ];

  // Get filtered status options for delivery managers (only relevant statuses)
  // Based on backend OrderViewSet - delivery managers can see these statuses
  // Note: 'all' is not included as the dropdown already has a separate "All" option
  List<String> get deliveryManagerStatusFilterOptions => [
    'waiting_for_delivery_manager', // New orders waiting for their confirmation
    'assigned_to_delivery', // Orders assigned to them
    'in_delivery', // Orders currently being delivered
    'delivery_in_progress', // Alternative status for in-progress deliveries
    'in_progress', // General in-progress status
    'delivered', // Completed deliveries
    'completed', // Fully completed orders
    'rejected_by_delivery_manager', // Orders they rejected (for reference)
  ];

  // Load orders from server with optional filters (server-side filtering)
  Future<void> loadOrders({
    String? status,
    String? orderType,
    String? search,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Ensure we have the latest auth token
      _ensureAuthToken();

      debugPrint(
        'OrdersProvider: Loading orders with filters - status: $status, orderType: $orderType, search: $search',
      );
      final serverOrders = await _ordersService.getOrders(
        status: status,
        orderType: orderType,
        search: search,
      );
      _orders = serverOrders;
      await _saveOrdersToLocal();
      debugPrint(
        'OrdersProvider: Loaded ${serverOrders.length} orders from server',
      );
      notifyListeners();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load orders: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Load orders by type from server with optional additional filters
  Future<void> loadOrdersByType(
    String orderType, {
    String? status,
    String? search,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Ensure we have the latest auth token
      _ensureAuthToken();

      debugPrint(
        'OrdersProvider: Loading orders by type: $orderType with filters - status: $status, search: $search',
      );
      final serverOrders = await _ordersService.getOrdersByType(
        orderType,
        status: status,
        search: search,
      );
      _orders = serverOrders;
      await _saveOrdersToLocal();
      debugPrint(
        'OrdersProvider: Loaded ${serverOrders.length} orders from server',
      );
      notifyListeners();
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load orders: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Load orders from local storage
  Future<void> _loadOrdersFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersDataString = prefs.getString('orders_data');

      if (ordersDataString != null) {
        final List<dynamic> ordersJson = json.decode(ordersDataString);
        _orders = ordersJson.map((json) => Order.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load orders from local storage: $e');
    }
  }

  // Save orders to local storage
  Future<void> _saveOrdersToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = _orders.map((order) => order.toJson()).toList();
      await prefs.setString('orders_data', json.encode(ordersJson));
    } catch (e) {
      debugPrint('Failed to save orders to local storage: $e');
    }
  }

  // Get order by ID
  Future<Order?> getOrderById(
    String orderId, {
    bool forceRefresh = false,
  }) async {
    try {
      // If force refresh is requested, always fetch from server
      if (forceRefresh) {
        try {
          final serverOrder = await _ordersService.getOrderById(orderId);

          // Update local cache with fresh data
          final orderIndex = _orders.indexWhere((order) => order.id == orderId);
          if (orderIndex != -1) {
            _orders[orderIndex] = serverOrder;
            await _saveOrdersToLocal();
            notifyListeners();
          }

          return serverOrder;
        } catch (e) {
          debugPrint('Failed to fetch order from server: $e');
          // Fall back to local order if server fetch fails
        }
      }

      // First try to find in local orders
      final localOrder = _orders
          .where((order) => order.id == orderId)
          .firstOrNull;
      if (localOrder != null) {
        return localOrder;
      }

      // If not found locally, fetch from server
      try {
        final serverOrder = await _ordersService.getOrderById(orderId);
        return serverOrder;
      } catch (e) {
        debugPrint('Failed to fetch order from server: $e');
        return null;
      }
    } catch (e) {
      debugPrint('Error getting order by ID: $e');
      return null;
    }
  }

  // Get order by order number
  Order? getOrderByNumber(String orderNumber) {
    try {
      return _orders.firstWhere((order) => order.orderNumber == orderNumber);
    } catch (e) {
      return null;
    }
  }

  // Cancel order
  Future<void> cancelOrder(String orderId) async {
    _setLoading(true);
    _clearError();

    try {
      await _ordersService.cancelOrder(orderId);

      // Update local order status
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex != -1) {
        final updatedOrder = Order(
          id: _orders[orderIndex].id,
          orderNumber: _orders[orderIndex].orderNumber,
          userId: _orders[orderIndex].userId,
          customerName: _orders[orderIndex].customerName,
          customerEmail: _orders[orderIndex].customerEmail,
          status: 'cancelled',
          orderType: _orders[orderIndex].orderType,
          totalAmount: _orders[orderIndex].totalAmount,
          shippingCost: _orders[orderIndex].shippingCost,
          taxAmount: _orders[orderIndex].taxAmount,
          couponCode: _orders[orderIndex].couponCode,
          discountAmount: _orders[orderIndex].discountAmount,
          notes: _orders[orderIndex].notes,
          createdAt: _orders[orderIndex].createdAt,
          updatedAt: DateTime.now(),
          items: _orders[orderIndex].items,
          shippingAddress: _orders[orderIndex].shippingAddress,
          billingAddress: _orders[orderIndex].billingAddress,
          paymentInfo: _orders[orderIndex].paymentInfo,
        );

        _orders[orderIndex] = updatedOrder;
        await _saveOrdersToLocal();
        notifyListeners();
      }

      _setLoading(false);
    } catch (e) {
      _setError('Failed to cancel order: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Track order
  Future<Map<String, dynamic>?> trackOrder(String orderNumber) async {
    _setLoading(true);
    _clearError();

    try {
      final trackingInfo = await _ordersService.trackOrder(orderNumber);
      _setLoading(false);
      return trackingInfo;
    } catch (e) {
      _setError('Failed to track order: ${e.toString()}');
      _setLoading(false);
      return null;
    }
  }

  // Search orders
  List<Order> searchOrders(String query) {
    if (query.isEmpty) return _orders;

    final lowerQuery = query.toLowerCase();
    return _orders.where((order) {
      return order.orderNumber.toLowerCase().contains(lowerQuery) ||
          order.items.any(
            (item) =>
                item.book.title.toLowerCase().contains(lowerQuery) ||
                (item.book.author?.name.toLowerCase().contains(lowerQuery) ??
                    false),
          );
    }).toList();
  }

  // Filter orders by date range
  List<Order> filterOrdersByDateRange(DateTime startDate, DateTime endDate) {
    return _orders.where((order) {
      return order.createdAt.isAfter(startDate) &&
          order.createdAt.isBefore(endDate);
    }).toList();
  }

  // Get orders statistics
  Map<String, dynamic> getOrderStatistics() {
    final totalOrders = _orders.length;
    final pendingCount = pendingOrders.length;
    final confirmedCount = confirmedOrders.length;
    final inDeliveryCount = inDeliveryOrders.length;
    final deliveredCount = deliveredOrders.length;
    final returnedCount = returnedOrders.length;

    final totalAmount = _orders.fold(
      0.0,
      (sum, order) => sum + order.totalAmount,
    );
    final averageOrderValue = totalOrders > 0 ? totalAmount / totalOrders : 0.0;

    return {
      'total_orders': totalOrders,
      'pending_orders': pendingCount,
      'confirmed_orders': confirmedCount,
      'in_delivery_orders': inDeliveryCount,
      'delivered_orders': deliveredCount,
      'returned_orders': returnedCount,
      'total_amount': totalAmount,
      'average_order_value': averageOrderValue,
    };
  }

  // Clear all data
  void clear() {
    _orders.clear();
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  // Clear all local storage data
  Future<void> clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('orders_data');
      clear();
    } catch (e) {
      debugPrint('Failed to clear local orders data: $e');
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Ensure auth token is set from AuthProvider
  void _ensureAuthToken() {
    // This method will be called by the screens that have access to AuthProvider
    // The actual token setting should be done by the screens using setToken()
  }

  // Update the API service with a new token
  void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      _ordersService.setAuthToken(token);
    }
  }

  // Accept delivery assignment (for delivery managers)
  Future<bool> acceptAssignment(int assignmentId) async {
    _clearError();
    debugPrint(
      'DEBUG: OrdersProvider.acceptAssignment called for assignment $assignmentId',
    );

    try {
      await _ordersService.updateDeliveryAssignmentStatus(
        assignmentId,
        'accepted',
      );
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
      await _ordersService.updateDeliveryAssignmentStatus(
        assignmentId,
        'cancelled', // Backend accepts 'cancelled' or 'rejected' - using 'cancelled' to match admin provider
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

  // Complete delivery (for delivery managers)
  Future<bool> completeDelivery(int orderId) async {
    _clearError();
    debugPrint(
      'DEBUG: OrdersProvider.completeDelivery called for order $orderId',
    );

    try {
      await _ordersService.completeDelivery(orderId);
      debugPrint('DEBUG: Delivery completed successfully');

      // Refresh order data
      await loadOrders();

      return true;
    } catch (e) {
      debugPrint('DEBUG: Error completing delivery: $e');
      _setError('Failed to complete delivery: $e');
      return false;
    }
  }

  // Add notes to an order
  Future<bool> addOrderNotes(String orderId, String notes) async {
    _setLoading(true);
    _clearError();

    try {
      await _ordersService.addOrderNotes(orderId, notes);

      // Update local order with new notes
      final orderIndex = _orders.indexWhere((order) => order.id == orderId);
      if (orderIndex != -1) {
        final updatedOrder = _orders[orderIndex].copyWith(
          notes: notes,
          updatedAt: DateTime.now(),
        );
        _orders[orderIndex] = updatedOrder;
        await _saveOrdersToLocal();
        notifyListeners();
      }

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
      await _ordersService.editOrderNotes(orderId, notes, noteId: noteId);

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
      await _ordersService.deleteOrderNotes(orderId, noteId: noteId);

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

  // Get order delivery location (for customers and admins)
  Future<Map<String, dynamic>?> getOrderDeliveryLocation(int orderId) async {
    _clearError();

    try {
      final locationData = await _ordersService.getOrderDeliveryLocation(
        orderId,
      );
      return locationData;
    } catch (e) {
      _setError('Failed to get delivery location: ${e.toString()}');
      return null;
    }
  }
}
