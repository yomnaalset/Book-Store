import 'package:flutter/foundation.dart';
import '../models/delivery_request.dart';
import '../models/delivery_assignment.dart';
import '../models/delivery_order.dart';
import '../models/delivery_agent.dart';
import '../services/manager_api_service.dart';

class DeliveryProvider with ChangeNotifier {
  final ManagerApiService _apiService;

  List<DeliveryRequest> _deliveryRequests = [];
  List<DeliveryAssignment> _deliveryAssignments = [];
  List<DeliveryOrder> _orders = [];
  List<DeliveryAgent> _availableAgents = [];
  bool _isLoading = false;
  String? _error;

  DeliveryProvider(this._apiService);

  // Getters
  List<DeliveryRequest> get deliveryRequests => _deliveryRequests;
  List<DeliveryAssignment> get deliveryAssignments => _deliveryAssignments;
  List<DeliveryOrder> get orders => _orders;
  List<DeliveryAgent> get availableAgents => _availableAgents;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load delivery requests
  Future<void> loadDeliveryRequests({String? search, String? status}) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.getDeliveryRequests(
        page: 1,
        limit: 1000, // Load all items
        search: search,
        status: status,
      );

      _deliveryRequests = response.results;
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load delivery requests: $e');
      _setLoading(false);
    }
  }

  // Load delivery assignments
  Future<void> loadDeliveryAssignments({String? search, String? status}) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.getDeliveryAssignments(
        page: 1,
        limit: 1000, // Load all items
        search: search,
        status: status,
      );

      _deliveryAssignments = response.results;
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load delivery assignments: $e');
      _setLoading(false);
    }
  }

  // Load delivery orders
  Future<void> loadDeliveryOrders({String? search, String? status}) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.getDeliveryOrders(
        page: 1,
        limit: 1000, // Load all items
        search: search,
        status: status,
      );

      _orders = response.results;
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load delivery orders: $e');
      _setLoading(false);
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

  // Assign agent to delivery request
  Future<bool> assignAgent(int requestId, int agentId) async {
    _clearError();

    try {
      await _apiService.assignDeliveryAgent(requestId, agentId);

      // Update local data
      final index = _deliveryRequests.indexWhere(
        (request) => request.id == requestId.toString(),
      );
      if (index != -1) {
        _deliveryRequests[index] = DeliveryRequest(
          id: _deliveryRequests[index].id,
          orderId: _deliveryRequests[index].orderId,
          order: _deliveryRequests[index].order,
          status: 'assigned',
          deliveryAgentId: agentId.toString(),
          requestDate: _deliveryRequests[index].requestDate,
          scheduledDate: _deliveryRequests[index].scheduledDate,
          deliveredDate: _deliveryRequests[index].deliveredDate,
          notes: _deliveryRequests[index].notes,
          isUrgent: _deliveryRequests[index].isUrgent,
          createdAt: _deliveryRequests[index].createdAt,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to assign agent: $e');
      return false;
    }
  }

  // Unassign agent from delivery request
  Future<bool> unassignAgent(int requestId) async {
    _clearError();

    try {
      // Update local data
      final index = _deliveryRequests.indexWhere(
        (request) => request.id == requestId.toString(),
      );
      if (index != -1) {
        _deliveryRequests[index] = DeliveryRequest(
          id: _deliveryRequests[index].id,
          orderId: _deliveryRequests[index].orderId,
          order: _deliveryRequests[index].order,
          status: 'pending',
          deliveryAgentId: null,
          requestDate: _deliveryRequests[index].requestDate,
          scheduledDate: _deliveryRequests[index].scheduledDate,
          deliveredDate: _deliveryRequests[index].deliveredDate,
          notes: _deliveryRequests[index].notes,
          isUrgent: _deliveryRequests[index].isUrgent,
          createdAt: _deliveryRequests[index].createdAt,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to unassign agent: $e');
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

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
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

  // Clear data
  void clear() {
    _deliveryRequests.clear();
    _deliveryAssignments.clear();
    _orders.clear();
    _availableAgents.clear();
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // Update the API service with a new token
  void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      // Set the token directly on the existing API service
      _apiService.setToken(token);
    }
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
