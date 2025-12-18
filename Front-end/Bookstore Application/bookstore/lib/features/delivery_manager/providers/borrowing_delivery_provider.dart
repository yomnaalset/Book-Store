import 'package:flutter/foundation.dart';
import '../services/borrowing_delivery_service.dart';
import '../services/delivery_status_service.dart';
import '../../orders/models/order.dart';

/// Provider for managing borrowing delivery workflow
/// Handles the complete flow: pending -> accept -> start -> complete
class BorrowingDeliveryProvider extends ChangeNotifier {
  List<Order> _pendingRequests = [];
  List<Order> _inProgressRequests = [];
  List<Order> _completedRequests = [];

  bool _isLoading = false;
  String? _errorMessage;
  String _currentDeliveryStatus = 'offline'; // online, busy, offline

  // Getters
  List<Order> get pendingRequests => List.unmodifiable(_pendingRequests);
  List<Order> get inProgressRequests => List.unmodifiable(_inProgressRequests);
  List<Order> get completedRequests => List.unmodifiable(_completedRequests);

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;
  String get currentDeliveryStatus => _currentDeliveryStatus;
  bool get isBusy => _currentDeliveryStatus == 'busy';
  bool get canChangeStatusManually => _currentDeliveryStatus != 'busy';

  // Get all borrow requests combined
  List<Order> get allRequests {
    return [..._pendingRequests, ..._inProgressRequests, ..._completedRequests];
  }

  // Get available filter options for statuses
  // These map to BorrowRequest status values on the backend
  List<String> get statusFilterOptions => [
    'pending',
    'confirmed',
    'in_delivery',
    'delivered',
    'active',
    'returned',
  ];

  // Get display labels for filter options - DEPRECATED: Use AppLocalizations.getBorrowStatusLabel instead
  // This method is kept for backward compatibility but should not be used in UI
  @Deprecated('Use AppLocalizations.getBorrowStatusLabel instead')
  String getStatusFilterLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_delivery':
        return 'In Delivery';
      case 'delivered':
        return 'Delivered';
      case 'active':
        return 'Active';
      case 'returned':
        return 'Returned';
      default:
        return status
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) {
              return word.isEmpty
                  ? ''
                  : word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
    }
  }

  /// Set authentication token for both services
  void setToken(String? token) {
    BorrowingDeliveryService.setToken(token);
    DeliveryStatusService.setToken(token);
  }

  /// Load all borrowing delivery requests
  /// Supports optional status and search filtering
  Future<void> loadBorrowRequests({String? status, String? search}) async {
    _setLoading(true);
    _clearError();

    try {
      // Get assigned borrow requests with filters
      final result = await BorrowingDeliveryService.getAssignedBorrowRequests(
        status: status,
        search: search,
      );

      if (result['success'] == true) {
        final orders = result['orders'] as List;
        debugPrint(
          'BorrowingDeliveryProvider: Raw orders count: ${orders.length}',
        );

        // Parse orders into Order objects, keeping raw JSON for status extraction
        final parsedOrdersWithJson = orders.map((json) {
          final order = Order.fromJson(json);
          return {'order': order, 'rawJson': json};
        }).toList();

        // Debug: Print each order's status and customer_email (from both order.status and borrowRequest.status if available)
        for (var item in parsedOrdersWithJson) {
          final order = item['order'] as Order;
          final rawJson = item['rawJson'] as Map<String, dynamic>;
          final borrowRequestStatus = rawJson['borrow_request']?['status'];
          final customerEmailFromJson =
              rawJson['customer_email'] ?? 'NOT IN JSON';
          debugPrint(
            'BorrowingDeliveryProvider: Order ${order.orderNumber} - Order.status: ${order.status}, BorrowRequest.status: $borrowRequestStatus, customer_email in JSON: $customerEmailFromJson, order.customerEmail: ${order.customerEmail}',
          );
        }

        // Extract just the orders for categorization
        final parsedOrders = parsedOrdersWithJson
            .map((item) => item['order'] as Order)
            .toList();

        // Categorize orders by status (will check both order.status and borrowRequest.status)
        _categorizeRequests(parsedOrders, orders);

        // Also load current delivery status
        await _syncDeliveryStatus();

        debugPrint(
          'BorrowingDeliveryProvider: Loaded ${parsedOrders.length} borrow requests',
        );
        debugPrint(
          'BorrowingDeliveryProvider: Pending: ${_pendingRequests.length}',
        );
        debugPrint(
          'BorrowingDeliveryProvider: In Progress: ${_inProgressRequests.length}',
        );
        debugPrint(
          'BorrowingDeliveryProvider: Completed: ${_completedRequests.length}',
        );
      } else {
        _setError(result['message'] ?? 'Failed to load borrow requests');
      }
    } catch (e) {
      _setError('Error loading borrow requests: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Accept a borrow request
  /// Automatically changes status to 'busy'
  Future<bool> acceptRequest(String orderId) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await BorrowingDeliveryService.acceptBorrowRequest(
        int.parse(orderId),
      );

      if (result['success'] == true) {
        // Update local state
        final order = _pendingRequests.firstWhere(
          (o) => o.id == orderId,
          orElse: () => throw Exception('Order not found'),
        );

        // Create updated order with new status
        final updatedOrder = order.copyWith(status: 'in_delivery');

        // Move from pending to in-progress
        _pendingRequests.removeWhere((o) => o.id == orderId);
        _inProgressRequests.add(updatedOrder);

        // Sync delivery status from server (Django handles status changes)
        await _syncDeliveryStatus();

        debugPrint(
          'BorrowingDeliveryProvider: Request accepted, status synced from server',
        );

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(result['message'] ?? 'Failed to accept request');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Error accepting request: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Reject a borrow request
  /// Status remains unchanged
  Future<bool> rejectRequest(String orderId, String reason) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await BorrowingDeliveryService.rejectBorrowRequest(
        int.parse(orderId),
        reason,
      );

      if (result['success'] == true) {
        // Remove from pending list
        _pendingRequests.removeWhere((o) => o.id == orderId);

        debugPrint('BorrowingDeliveryProvider: Request rejected');

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        // Check if the error is because the order is already unassigned
        final errorMessage = result['message'] ?? '';
        if (errorMessage.contains('not currently assigned') ||
            errorMessage.contains('already been unassigned')) {
          // Order is already unassigned, remove it from the list and treat as success
          _pendingRequests.removeWhere((o) => o.id == orderId);
          _inProgressRequests.removeWhere((o) => o.id == orderId);
          debugPrint(
            'BorrowingDeliveryProvider: Request already unassigned, removing from list',
          );
          _setLoading(false);
          notifyListeners();
          return true;
        }

        _setError(errorMessage);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Error rejecting request: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Start delivery for an order
  /// Django automatically changes delivery manager status to 'busy'
  /// Flutter should NOT manually change the status
  Future<bool> startDelivery(String orderId, int deliveryManagerId) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await BorrowingDeliveryService.startDelivery(
        int.parse(orderId),
        deliveryManagerId,
      );

      if (result['success'] == true) {
        // Update order status to in_delivery
        final orderIndex = _inProgressRequests.indexWhere(
          (o) => o.id == orderId,
        );

        if (orderIndex != -1) {
          final order = _inProgressRequests[orderIndex];
          _inProgressRequests[orderIndex] = order.copyWith(
            status: 'in_delivery',
          );
        }

        // Sync delivery status from server (Django has already changed it to busy)
        await _syncDeliveryStatus();

        debugPrint(
          'BorrowingDeliveryProvider: Delivery started, status synced from server',
        );

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        // Handle 403 Forbidden - don't retry
        if (result['error_code'] == 'FORBIDDEN' ||
            result['status_code'] == 403) {
          _setError(
            result['message'] ??
                'You do not have permission to perform this action. Only delivery managers can start deliveries.',
          );
          debugPrint(
            'BorrowingDeliveryProvider: 403 Forbidden - User does not have permission',
          );
        } else {
          _setError(result['message'] ?? 'Failed to start delivery');
        }
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Error starting delivery: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  /// Complete delivery
  /// Automatically changes status from 'busy' to 'online'
  Future<bool> completeDelivery(String orderId) async {
    _setLoading(true);
    _clearError();

    try {
      final result = await BorrowingDeliveryService.completeDelivery(
        int.parse(orderId),
      );

      if (result['success'] == true) {
        // Find and move order from in-progress to completed
        final order = _inProgressRequests.firstWhere(
          (o) => o.id == orderId,
          orElse: () => throw Exception('Order not found'),
        );

        final completedOrder = order.copyWith(status: 'delivered');

        _inProgressRequests.removeWhere((o) => o.id == orderId);
        _completedRequests.insert(0, completedOrder); // Add to beginning

        // Sync delivery status from server (backend determines if status should be online or busy)
        await _syncDeliveryStatus();

        debugPrint(
          'BorrowingDeliveryProvider: Delivery completed, status now online',
        );

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        // Handle 403 Forbidden - don't retry
        if (result['error_code'] == 'FORBIDDEN' ||
            result['status_code'] == 403) {
          _setError(
            result['message'] ??
                'You do not have permission to perform this action. Only delivery managers can complete deliveries.',
          );
          debugPrint(
            'BorrowingDeliveryProvider: 403 Forbidden - User does not have permission',
          );
        } else {
          _setError(result['message'] ?? 'Failed to complete delivery');
        }
        _setLoading(false);
        return false;
      }
    } catch (e) {
      // Check if error contains 403
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('403') || errorString.contains('forbidden')) {
        _setError(
          'You do not have permission to perform this action. Only delivery managers can complete deliveries.',
        );
      } else {
        _setError('Error completing delivery: ${e.toString()}');
      }
      _setLoading(false);
      return false;
    }
  }

  /// Change delivery status (online/offline)
  /// Only allowed when NOT busy
  Future<bool> changeStatus(String newStatus) async {
    // Prevent status change when busy
    if (_currentDeliveryStatus == 'busy') {
      _setError('Cannot change status while delivering an order');
      return false;
    }

    // Prevent setting to same status
    if (newStatus == _currentDeliveryStatus) {
      debugPrint('BorrowingDeliveryProvider: Already in $newStatus state');
      return true;
    }

    // Only allow online/offline
    if (newStatus != 'online' && newStatus != 'offline') {
      _setError('Invalid status. Can only change between online and offline');
      return false;
    }

    _clearError();

    try {
      final result = await DeliveryStatusService.updateStatus(newStatus);

      if (result['success'] == true) {
        _currentDeliveryStatus = result['current_status'] ?? newStatus;
        debugPrint(
          'BorrowingDeliveryProvider: Status changed to $_currentDeliveryStatus',
        );
        notifyListeners();
        return true;
      } else {
        _setError(result['message'] ?? 'Failed to change status');
        return false;
      }
    } catch (e) {
      _setError('Error changing status: ${e.toString()}');
      return false;
    }
  }

  /// Sync delivery status from server
  /// This ensures the UI reflects the actual server state
  Future<void> _syncDeliveryStatus() async {
    try {
      final status = await BorrowingDeliveryService.getCurrentDeliveryStatus();
      if (status != null) {
        _currentDeliveryStatus = status;
        debugPrint(
          'BorrowingDeliveryProvider: Synced status: $_currentDeliveryStatus',
        );
      }
    } catch (e) {
      debugPrint('BorrowingDeliveryProvider: Error syncing status: $e');
    }
  }

  /// Refresh current status from server
  Future<void> refreshStatus() async {
    await _syncDeliveryStatus();
    notifyListeners();
  }

  /// Get order by ID
  Order? getOrderById(String orderId) {
    // Search in all lists
    try {
      return _pendingRequests.firstWhere((o) => o.id == orderId);
    } catch (e) {
      try {
        return _inProgressRequests.firstWhere((o) => o.id == orderId);
      } catch (e) {
        try {
          return _completedRequests.firstWhere((o) => o.id == orderId);
        } catch (e) {
          return null;
        }
      }
    }
  }

  /// Get statistics
  Map<String, int> getStatistics() {
    return {
      'pending': _pendingRequests.length,
      'in_progress': _inProgressRequests.length,
      'completed': _completedRequests.length,
      'total':
          _pendingRequests.length +
          _inProgressRequests.length +
          _completedRequests.length,
    };
  }

  /// Search and filter borrow requests
  List<Order> searchAndFilterRequests(String query, {String? status}) {
    List<Order> filteredOrders = allRequests;

    // Filter by status if specified
    if (status != null && status.isNotEmpty) {
      filteredOrders = allRequests.where((order) {
        return order.status.toLowerCase() == status.toLowerCase();
      }).toList();
    }

    // Search by query if provided
    if (query.isNotEmpty) {
      filteredOrders = filteredOrders.where((order) {
        final searchQuery = query.toLowerCase();
        return order.id.toString().contains(searchQuery) ||
            order.orderNumber.toLowerCase().contains(searchQuery) ||
            order.customerName.toLowerCase().contains(searchQuery) ||
            order.customerEmail.toLowerCase().contains(searchQuery);
      }).toList();
    }

    return filteredOrders;
  }

  /// Clear all data
  void clear() {
    _pendingRequests.clear();
    _inProgressRequests.clear();
    _completedRequests.clear();
    _currentDeliveryStatus = 'offline';
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    debugPrint('BorrowingDeliveryProvider ERROR: $error');
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  /// Categorize orders by status into pending, in-progress, and completed lists
  /// Also checks borrowRequest.status from raw JSON if available
  void _categorizeRequests(
    List<Order> allOrders, [
    List<dynamic>? rawOrdersJson,
  ]) {
    // 1. Reset lists
    _pendingRequests = [];
    _inProgressRequests = [];
    _completedRequests = [];

    for (int i = 0; i < allOrders.length; i++) {
      final order = allOrders[i];

      // Get the status from the order object
      // The serializer now returns borrow_request.status in the status field
      // So order.status should already contain the correct status from the database
      String status = order.status.toLowerCase();

      // Fallback: Check borrowRequest.status from raw JSON if order.status is not available
      // This should rarely be needed now since the serializer handles it
      if (status.isEmpty || status == 'null') {
        if (rawOrdersJson != null &&
            i < rawOrdersJson.length &&
            rawOrdersJson[i] is Map<String, dynamic>) {
          final rawJson = rawOrdersJson[i] as Map<String, dynamic>;
          final borrowRequestStatus = rawJson['borrow_request']?['status'];
          if (borrowRequestStatus != null && borrowRequestStatus is String) {
            status = borrowRequestStatus.toLowerCase();
            debugPrint(
              'BorrowingDeliveryProvider: Using BorrowRequest.status from raw JSON "$status" for Order ${order.id}',
            );
          }
        }
      }

      debugPrint(
        'BorrowingDeliveryProvider: Processing Order ID: ${order.id} with Status: $status (from database)',
      ); // Debug print

      // 2. Map 'assigned_to_delivery' to the Pending List
      if (status == 'assigned' ||
          status == 'assigned_to_delivery' || // <<< THIS IS THE MISSING KEY
          status == 'pending' ||
          status == 'confirmed') {
        _pendingRequests.add(order);
      }
      // 3. Map In-Progress statuses
      else if (status == 'preparing' ||
          status ==
              'pending_delivery' || // Order accepted, waiting for delivery
          status == 'out_for_delivery' ||
          status == 'out_for_return_pickup' ||
          status == 'in_delivery') {
        _inProgressRequests.add(order);
      }
      // 4. Map Completed statuses
      else if (status == 'delivered' ||
          status == 'returned' ||
          status == 'completed') {
        _completedRequests.add(order);
      } else {
        // Log unhandled statuses for debugging
        debugPrint(
          'BorrowingDeliveryProvider: Unhandled status "$status" for Order ${order.id}',
        );
      }
    }

    notifyListeners();
  }
}
