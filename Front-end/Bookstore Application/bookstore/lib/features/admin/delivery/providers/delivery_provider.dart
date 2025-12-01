import 'package:flutter/foundation.dart';
import '../../models/delivery_request.dart';
import '../../models/delivery_assignment.dart';
import '../../models/delivery_order.dart';
import '../../models/delivery_agent.dart';
import '../../services/manager_api_service.dart';

class DeliveryProvider with ChangeNotifier {
  ManagerApiService _apiService;

  List<DeliveryRequest> _deliveryRequests = [];
  List<DeliveryAssignment> _deliveryAssignments = [];
  List<DeliveryOrder> _orders = [];
  List<DeliveryAgent> _availableAgents = [];
  bool _isLoading = false;
  String? _error;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  DeliveryProvider(this._apiService);

  // Getters
  List<DeliveryRequest> get deliveryRequests => _deliveryRequests;
  List<DeliveryAssignment> get deliveryAssignments => _deliveryAssignments;
  List<DeliveryOrder> get orders => _orders;
  List<DeliveryAgent> get availableAgents => _availableAgents;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  // Load delivery requests
  Future<void> loadDeliveryRequests({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.getDeliveryRequests(
        page: page,
        limit: limit,
        search: search,
        status: status,
      );

      _deliveryRequests = response.results;
      _currentPage = page;
      _totalPages = response.totalPages;
      _totalItems = response.totalItems;
      _itemsPerPage = limit;

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load delivery requests: $e');
      _setLoading(false);
    }
  }

  // Load delivery assignments
  Future<void> loadDeliveryAssignments({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.getDeliveryAssignments(
        page: page,
        limit: limit,
        search: search,
        status: status,
      );

      _deliveryAssignments = response.results;
      _currentPage = page;
      _totalPages = response.totalPages;
      _totalItems = response.totalItems;
      _itemsPerPage = limit;

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load delivery assignments: $e');
      _setLoading(false);
    }
  }

  // Load delivery orders
  Future<void> loadDeliveryOrders({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.getDeliveryOrders(
        page: page,
        limit: limit,
        search: search,
        status: status,
      );

      _orders = response.results;
      _currentPage = page;
      _totalPages = response.totalPages;
      _totalItems = response.totalItems;
      _itemsPerPage = limit;

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load delivery orders: $e');
      _setLoading(false);
    }
  }

  // Create delivery assignment
  Future<bool> createDeliveryAssignment({
    required int orderId,
    required int deliveryPersonId,
    required String deliveryAddress,
    required DateTime scheduledDate,
    String? notes,
  }) async {
    _clearError();

    try {
      final assignment = await _apiService.createDeliveryAssignment(
        orderId: orderId,
        deliveryPersonId: deliveryPersonId,
        deliveryAddress: deliveryAddress,
        scheduledDate: scheduledDate,
        notes: notes,
      );

      _deliveryAssignments.insert(0, assignment);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to create delivery assignment: $e');
      return false;
    }
  }

  // Update delivery status
  Future<bool> updateDeliveryStatus(int assignmentId, String status) async {
    _clearError();

    try {
      await _apiService.updateDeliveryStatus(assignmentId, status);

      // Update local data
      final index = _deliveryAssignments.indexWhere(
        (assignment) => assignment.id == assignmentId,
      );
      if (index != -1) {
        _deliveryAssignments[index] = _deliveryAssignments[index].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to update delivery status: $e');
      return false;
    }
  }

  // Get delivery tracking
  Future<Map<String, dynamic>?> getDeliveryTracking(int assignmentId) async {
    try {
      return await _apiService.getDeliveryTracking(assignmentId);
    } catch (e) {
      _setError('Failed to get delivery tracking: $e');
      return null;
    }
  }

  // Get orders for delivery
  Future<void> getOrdersForDelivery() async {
    _setLoading(true);
    _clearError();

    try {
      final orders = await _apiService.getOrdersForDelivery();
      _orders = orders;
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load orders for delivery: $e');
      _setLoading(false);
    }
  }

  // Get available agents
  Future<void> getAvailableAgents() async {
    // Only load agents if they haven't been loaded yet to prevent unnecessary calls
    if (_availableAgents.isNotEmpty) {
      return; // Already loaded
    }

    _setLoading(true);
    _clearError();

    try {
      final agents = await _apiService.getAvailableDeliveryAgents();
      _availableAgents = agents;
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load available agents: $e');
      _setLoading(false);
    }
  }

  // Force refresh available agents (bypasses cache)
  Future<void> refreshAvailableAgents() async {
    _availableAgents.clear(); // Clear cache
    await getAvailableAgents();
  }

  // Assign agent to order
  Future<bool> assignAgent(int orderId, int agentId) async {
    _clearError();

    try {
      await _apiService.assignDeliveryAgent(orderId, agentId);

      // Update local data
      final orderIndex = _orders.indexWhere(
        (order) => order.id == orderId.toString(),
      );
      if (orderIndex != -1) {
        final agent = _availableAgents.firstWhere((a) => a.id == agentId);
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          deliveryAgent: agent,
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to assign agent: $e');
      return false;
    }
  }

  // Unassign agent from order
  Future<bool> unassignAgent(int orderId) async {
    _clearError();

    try {
      // Since there's no unassign method, we'll create a new assignment with null agent
      await _apiService.assignDeliveryAgent(
        orderId,
        0,
      ); // Use 0 or null to unassign

      // Update local data
      final orderIndex = _orders.indexWhere(
        (order) => order.id == orderId.toString(),
      );
      if (orderIndex != -1) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(deliveryAgent: null);
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to unassign agent: $e');
      return false;
    }
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

  void clearError() {
    _clearError();
    notifyListeners();
  }

  // Update the API service with a new token
  void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      // Create a new API service instance with the updated token
      _apiService = ManagerApiService(
        baseUrl: _apiService.baseUrl,
        headers: _apiService.headers,
        getAuthToken: () => token,
      );
    }
  }

  // Clear data
  void clear() {
    _deliveryRequests.clear();
    _deliveryAssignments.clear();
    _orders.clear();
    _availableAgents.clear();
    _currentPage = 1;
    _totalPages = 1;
    _totalItems = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

// Response models for API calls
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
  final List<DeliveryAssignment> results;
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
