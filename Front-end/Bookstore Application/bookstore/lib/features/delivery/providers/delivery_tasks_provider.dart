import 'package:flutter/foundation.dart';
import '../models/delivery_task.dart';
import '../services/delivery_service.dart';

class DeliveryTasksProvider with ChangeNotifier {
  final DeliveryService _deliveryService;
  List<DeliveryTask> _allTasks = [];
  List<DeliveryTask> _assignedTasks = [];
  List<DeliveryTask> _completedTasks = [];
  List<DeliveryTask> _inTransitTasks = [];
  List<DeliveryTask> _urgentTasks = [];
  List<DeliveryTask> _overdueTasks = [];
  List<DeliveryTask> _recentTasks = [];
  bool _isLoading = false;
  String? _error;

  DeliveryTasksProvider(this._deliveryService);

  // Getters
  List<DeliveryTask> get allTasks => _allTasks;
  List<DeliveryTask> get tasks => _allTasks;
  List<DeliveryTask> get assignedTasks => _assignedTasks;
  List<DeliveryTask> get completedTasks => _completedTasks;
  List<DeliveryTask> get inTransitTasks => _inTransitTasks;
  List<DeliveryTask> get urgentTasks => _urgentTasks;
  List<DeliveryTask> get overdueTasks => _overdueTasks;
  List<DeliveryTask> get recentTasks => _recentTasks;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get errorMessage => _error;

  int get assignedTasksCount => _assignedTasks.length;
  int get completedTasksCount => _completedTasks.length;
  int get inTransitTasksCount => _inTransitTasks.length;
  int get urgentTasksCount => _urgentTasks.length;
  int get overdueTasksCount => _overdueTasks.length;

  // Load all tasks
  Future<void> loadAllTasks() async {
    _setLoading(true);
    _clearError();

    try {
      final tasks = await _deliveryService.getAllTasks();
      _allTasks = tasks;
      _filterTasks();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load tasks: $e');
      _setLoading(false);
    }
  }

  // Get urgent tasks
  List<DeliveryTask> getUrgentTasks({int limit = 5}) {
    return _urgentTasks.take(limit).toList();
  }

  // Get recent tasks
  List<DeliveryTask> getRecentTasks({int limit = 5}) {
    return _recentTasks.take(limit).toList();
  }

  // Update task status
  Future<bool> updateTaskStatus(String taskId, String status) async {
    _clearError();

    try {
      final success = await _deliveryService.updateTaskStatus(taskId, status);

      if (success) {
        // Update the task in our local list
        final index = _allTasks.indexWhere((task) => task.id == taskId);
        if (index != -1) {
          _allTasks[index] = _allTasks[index].copyWith(status: status);
          _filterTasks();
          notifyListeners();
        }
        return true;
      } else {
        _setError('Failed to update task status');
        return false;
      }
    } catch (e) {
      _setError('Error updating task status: $e');
      return false;
    }
  }

  // Filter tasks into different categories
  void _filterTasks() {
    _assignedTasks = _allTasks
        .where((task) => task.status == DeliveryTask.statusAssigned)
        .toList();

    _completedTasks = _allTasks
        .where((task) => task.status == DeliveryTask.statusDelivered)
        .toList();

    _inTransitTasks = _allTasks
        .where((task) => task.status == DeliveryTask.statusInTransit)
        .toList();

    _urgentTasks = _allTasks.where((task) => task.isUrgent).toList();

    _overdueTasks = _allTasks
        .where((task) => task.status == DeliveryTask.statusOverdue)
        .toList();

    // Sort recent tasks by createdAt date (newest first)
    _recentTasks = List.from(_allTasks)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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

  // Additional methods required by the UI
  Future<void> getDeliveryTasks() async {
    await loadAllTasks();
  }

  Future<void> refresh() async {
    await loadAllTasks();
  }

  void clearSearch() {
    // Implementation for clearing search filters
    _allTasks = _allTasks;
    _filterTasks();
    notifyListeners();
  }

  Future<void> searchTasks(String query) async {
    // Implementation for searching tasks
    if (query.isEmpty) {
      await loadAllTasks();
      return;
    }

    final filteredTasks = _allTasks
        .where(
          (task) =>
              task.customerName?.toLowerCase().contains(query.toLowerCase()) ==
                  true ||
              task.orderId.toLowerCase().contains(query.toLowerCase()) ||
              task.taskNumber?.toLowerCase().contains(query.toLowerCase()) ==
                  true,
        )
        .toList();

    _allTasks = filteredTasks;
    _filterTasks();
    notifyListeners();
  }

  void filterTasks(String status) {
    // Implementation for filtering tasks by status
    if (status == 'all') {
      _filterTasks();
    } else {
      final filteredTasks = _allTasks
          .where((task) => task.status == status)
          .toList();
      _allTasks = filteredTasks;
      _filterTasks();
    }
    notifyListeners();
  }

  Future<bool> acceptTask(String taskId) async {
    return await updateTaskStatus(taskId, DeliveryTask.statusAccepted);
  }

  Future<bool> markAsInTransit(String taskId) async {
    return await updateTaskStatus(taskId, DeliveryTask.statusInTransit);
  }

  Future<bool> markAsCompleted(String taskId) async {
    return await updateTaskStatus(taskId, DeliveryTask.statusCompleted);
  }
}
