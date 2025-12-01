import 'package:flutter/foundation.dart';
import '../models/delivery_task.dart';
import '../services/delivery_service.dart';

class DeliveryProvider with ChangeNotifier {
  final DeliveryService _deliveryService;

  List<DeliveryTask> _deliveryTasks = [];
  List<DeliveryTask> _deliveries = [];
  bool _isLoading = false;
  String? _error;

  // Statistics
  int _totalDeliveries = 0;
  int _pendingDeliveries = 0;
  int _completedDeliveries = 0;
  int _failedDeliveries = 0;

  // Filters
  String? _statusFilter;
  String? _searchQuery;
  DateTime? _startDate;
  DateTime? _endDate;

  DeliveryProvider(this._deliveryService);

  // Getters
  List<DeliveryTask> get deliveryTasks => _deliveryTasks;
  List<DeliveryTask> get deliveries => _deliveries;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalDeliveries => _totalDeliveries;
  int get pendingDeliveries => _pendingDeliveries;
  int get completedDeliveries => _completedDeliveries;
  int get failedDeliveries => _failedDeliveries;
  String? get statusFilter => _statusFilter;
  String? get searchQuery => _searchQuery;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  // Load delivery data
  Future<void> loadDeliveryData() async {
    _setLoading(true);
    _clearError();

    try {
      await Future.wait([
        loadDeliveryTasks(),
        loadDeliveries(),
        loadStatistics(),
      ]);

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load delivery data: $e');
      _setLoading(false);
    }
  }

  // Load delivery tasks
  Future<void> loadDeliveryTasks({
    String? status,
    String? search,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _deliveryTasks = await _deliveryService.getDeliveryTasks(status: status);

      _statusFilter = status;
      _searchQuery = search;
      _startDate = startDate;
      _endDate = endDate;

      notifyListeners();
    } catch (e) {
      _setError('Failed to load delivery tasks: $e');
    }
  }

  // Load deliveries
  Future<void> loadDeliveries() async {
    try {
      _deliveries = await _deliveryService.getAllTasks();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load deliveries: $e');
    }
  }

  // Load statistics
  Future<void> loadStatistics() async {
    try {
      final stats = await _deliveryService.getDashboardStats();
      _totalDeliveries = stats['total'] ?? 0;
      _pendingDeliveries = stats['pending'] ?? 0;
      _completedDeliveries = stats['completed'] ?? 0;
      _failedDeliveries = stats['failed'] ?? 0;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load statistics: $e');
    }
  }

  // Create delivery task
  Future<bool> createDeliveryTask({
    required String orderId,
    required String customerId,
    required String deliveryAddress,
    DateTime? scheduledDate,
    String? notes,
  }) async {
    _clearError();

    try {
      final success = await _deliveryService.assignDeliveryAgentx(
        orderId,
        deliveryAgentId:
            customerId, // Using customerId as deliveryAgentId for now
        notes: notes,
      );

      if (success) {
        _pendingDeliveries++;
        notifyListeners();
      }
      return success;
    } catch (e) {
      _setError('Failed to create delivery task: $e');
      return false;
    }
  }

  // Assign delivery agent
  Future<bool> assignDeliveryAgent(
    String taskId,
    String deliveryAgentId,
  ) async {
    _clearError();

    try {
      final success = await _deliveryService.assignDeliveryAgentx(
        taskId,
        deliveryAgentId: deliveryAgentId,
      );

      if (success) {
        final index = _deliveryTasks.indexWhere((task) => task.id == taskId);
        if (index != -1) {
          _deliveryTasks[index] = _deliveryTasks[index].copyWith(
            deliveryPersonId: deliveryAgentId,
            status: DeliveryTask.statusAssigned,
          );
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to assign delivery agent: $e');
      return false;
    }
  }

  // Update delivery status
  Future<bool> updateDeliveryStatus(String taskId, String status) async {
    _clearError();

    try {
      final success = await _deliveryService.updateTaskStatus(taskId, status);

      if (success) {
        final index = _deliveryTasks.indexWhere((task) => task.id == taskId);
        if (index != -1) {
          final oldStatus = _deliveryTasks[index].status;
          _deliveryTasks[index] = _deliveryTasks[index].copyWith(
            status: status,
            updatedAt: DateTime.now(),
          );

          // Update statistics
          _updateStatistics(oldStatus, status);
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to update delivery status: $e');
      return false;
    }
  }

  // Cancel delivery
  Future<bool> cancelDelivery(String taskId, String reason) async {
    return await updateDeliveryStatus(taskId, DeliveryTask.statusCancelled);
  }

  // Complete delivery
  Future<bool> completeDelivery(String taskId) async {
    return await updateDeliveryStatus(taskId, DeliveryTask.statusCompleted);
  }

  // Get delivery tracking
  Future<Map<String, dynamic>?> getDeliveryTracking(String taskId) async {
    try {
      return await _deliveryService.getDeliveryTrackingx(taskId);
    } catch (e) {
      _setError('Failed to get delivery tracking: $e');
      return null;
    }
  }

  // Search delivery tasks
  Future<void> searchDeliveryTasks(String query) async {
    await loadDeliveryTasks(
      status: _statusFilter,
      search: query,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  // Filter by status
  Future<void> filterByStatus(String? status) async {
    await loadDeliveryTasks(
      status: status,
      search: _searchQuery,
      startDate: _startDate,
      endDate: _endDate,
    );
  }

  // Filter by date range
  Future<void> filterByDateRange(DateTime? startDate, DateTime? endDate) async {
    await loadDeliveryTasks(
      status: _statusFilter,
      search: _searchQuery,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // Get pending tasks
  List<DeliveryTask> getPendingTasks() {
    return _deliveryTasks
        .where((task) => task.status == DeliveryTask.statusPending)
        .toList();
  }

  // Get assigned tasks
  List<DeliveryTask> getAssignedTasks() {
    return _deliveryTasks
        .where((task) => task.status == DeliveryTask.statusAssigned)
        .toList();
  }

  // Get in-transit tasks
  List<DeliveryTask> getInTransitTasks() {
    return _deliveryTasks
        .where((task) => task.status == DeliveryTask.statusInTransit)
        .toList();
  }

  // Get completed tasks
  List<DeliveryTask> getCompletedTasks() {
    return _deliveryTasks
        .where((task) => task.status == DeliveryTask.statusCompleted)
        .toList();
  }

  // Get failed tasks
  List<DeliveryTask> getFailedTasks() {
    return _deliveryTasks
        .where((task) => task.status == DeliveryTask.statusFailed)
        .toList();
  }

  // Get urgent tasks
  List<DeliveryTask> getUrgentTasks() {
    return _deliveryTasks.where((task) => task.isUrgent).toList();
  }

  // Get overdue tasks
  List<DeliveryTask> getOverdueTasks() {
    return _deliveryTasks
        .where((task) => task.status == DeliveryTask.statusOverdue)
        .toList();
  }

  // Get tasks by agent
  List<DeliveryTask> getTasksByAgent(String agentId) {
    return _deliveryTasks
        .where((task) => task.deliveryPersonId == agentId)
        .toList();
  }

  // Clear filters
  Future<void> clearFilters() async {
    await loadDeliveryTasks();
  }

  // Refresh all data
  Future<void> refresh() async {
    await loadDeliveryData();
  }

  // Helper methods
  void _updateStatistics(String oldStatus, String newStatus) {
    // Decrease old status count
    switch (oldStatus) {
      case DeliveryTask.statusPending:
        _pendingDeliveries--;
        break;
      case DeliveryTask.statusCompleted:
        _completedDeliveries--;
        break;
      case DeliveryTask.statusFailed:
        _failedDeliveries--;
        break;
    }

    // Increase new status count
    switch (newStatus) {
      case DeliveryTask.statusPending:
        _pendingDeliveries++;
        break;
      case DeliveryTask.statusCompleted:
        _completedDeliveries++;
        break;
      case DeliveryTask.statusFailed:
        _failedDeliveries++;
        break;
    }
  }

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
    _deliveryTasks.clear();
    _deliveries.clear();
    _totalDeliveries = 0;
    _pendingDeliveries = 0;
    _completedDeliveries = 0;
    _failedDeliveries = 0;
    _statusFilter = null;
    _searchQuery = null;
    _startDate = null;
    _endDate = null;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
