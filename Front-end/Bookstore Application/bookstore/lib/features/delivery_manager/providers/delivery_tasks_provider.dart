import 'package:flutter/foundation.dart';
import '../../delivery/services/delivery_service.dart';
import '../../delivery/models/delivery_task.dart' as delivery_models;
import '../models/delivery_task.dart';

class DeliveryTasksProvider extends ChangeNotifier {
  final DeliveryService _deliveryService;
  List<DeliveryTask> _tasks = [];
  bool _isLoading = false;
  String? _error;
  String? _cachedToken;

  DeliveryTasksProvider(this._deliveryService);

  List<DeliveryTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Set authentication token
  void setToken(String? token) {
    debugPrint(
      'DeliveryTasksProvider: setToken called with token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    _cachedToken = token;
    _deliveryService.setToken(token);
    debugPrint('DeliveryTasksProvider: Token set successfully');
  }

  Future<void> loadTasks() async {
    debugPrint('DeliveryTasksProvider: loadTasks called');
    debugPrint(
      'DeliveryTasksProvider: _cachedToken = ${_cachedToken != null ? '${_cachedToken!.substring(0, _cachedToken!.length > 20 ? 20 : _cachedToken!.length)}...' : 'null'}',
    );

    // Only load tasks if we have a valid token (user is authenticated)
    if (_cachedToken == null || _cachedToken!.isEmpty) {
      debugPrint(
        'DeliveryTasksProvider: No token available, skipping loadTasks',
      );
      _error = "No authentication token available. Please login again.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('DeliveryTasksProvider: Calling _loadTasksFromAPI');
      // Load tasks from real API
      _tasks = await _loadTasksFromAPI();
      debugPrint(
        'DeliveryTasksProvider: Successfully loaded ${_tasks.length} tasks',
      );

      if (_tasks.isEmpty) {
        debugPrint('DeliveryTasksProvider: No tasks were returned from API');
      } else {
        debugPrint('DeliveryTasksProvider: Task statuses:');
        for (var task in _tasks) {
          debugPrint('Task ${task.id}: ${task.status} (${task.taskType})');
        }
        // Log counts for debugging
        debugPrint(
          'DeliveryTasksProvider: Assigned tasks count: $assignedTasksCount',
        );
        debugPrint(
          'DeliveryTasksProvider: Completed tasks count: $completedTasksCount',
        );
        debugPrint(
          'DeliveryTasksProvider: In progress tasks count: $inTransitTasksCount',
        );
      }
    } catch (e, stackTrace) {
      debugPrint('DeliveryTasksProvider: Error loading tasks: $e');
      debugPrint('DeliveryTasksProvider: Stack trace: $stackTrace');
      _error = "Failed to load tasks: ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<DeliveryTask>> _loadTasksFromAPI() async {
    final deliveryTasks = await _deliveryService.getAllTasks();
    return deliveryTasks
        .map((task) => _convertToDeliveryManagerTask(task))
        .toList();
  }

  DeliveryTask _convertToDeliveryManagerTask(
    delivery_models.DeliveryTask deliveryTask,
  ) {
    return DeliveryTask(
      id: deliveryTask.id,
      taskNumber: deliveryTask.taskNumber ?? 'TASK-${deliveryTask.id}',
      taskType: deliveryTask.taskType ?? 'delivery',
      status: deliveryTask.status,
      orderId: deliveryTask.orderId,
      customerId: deliveryTask.customerId ?? '',
      customerName: deliveryTask.customerName ?? 'Unknown Customer',
      customerPhone: deliveryTask.customerPhone ?? '',
      customerEmail: deliveryTask.customerEmail ?? '',
      customerAddress: deliveryTask.customerAddress ?? '',
      deliveryAddress:
          deliveryTask.deliveryAddress ?? deliveryTask.customerAddress ?? '',
      deliveryCity: deliveryTask.deliveryCity ?? 'City',
      notes: deliveryTask.notes ?? '',
      assignedAt: deliveryTask.assignedAt,
      acceptedAt: deliveryTask.acceptedAt,
      pickedUpAt: deliveryTask.pickedUpAt,
      deliveredAt: deliveryTask.deliveredAt,
      completedAt: deliveryTask.completedAt,
      estimatedDeliveryTime: deliveryTask.estimatedDeliveryTime,
      deliveryNotes: deliveryTask.deliveryNotes ?? deliveryTask.notes ?? '',
      failureReason: deliveryTask.failureReason,
      retryCount: deliveryTask.retryCount ?? 0,
      items: deliveryTask.orderItems != null
          ? deliveryTask.orderItems!
                .map(
                  (item) => {
                    'bookTitle': item['bookTitle'] ?? 'Unknown Book',
                    'bookAuthor': item['bookAuthor'] ?? 'Unknown Author',
                    'quantity': item['quantity'] ?? 1,
                    'unitPrice': item['unitPrice'] ?? 0.0,
                    'totalPrice': item['totalPrice'] ?? 0.0,
                  },
                )
                .toList()
          : <Map<String, dynamic>>[],
      eta: deliveryTask.eta,
      statusHistory: deliveryTask.statusHistory ?? <Map<String, dynamic>>[],
      proofOfDelivery: deliveryTask.proofOfDelivery != null
          ? {'data': deliveryTask.proofOfDelivery}
          : null,
      createdAt: deliveryTask.createdAt,
      updatedAt: deliveryTask.updatedAt,
      assignedTo: deliveryTask.deliveryPersonId ?? '',
      scheduledDate: deliveryTask.scheduledDate,
      completedDate: deliveryTask.deliveredAt,
      latitude: deliveryTask.latitude,
      longitude: deliveryTask.longitude,
    );
  }

  Future<bool> updateTaskStatus(String taskId, String status) async {
    try {
      debugPrint('🚀 DeliveryTasksProvider: Starting status update...');
      debugPrint('🚀 DeliveryTasksProvider: TaskId: $taskId');
      debugPrint('🚀 DeliveryTasksProvider: Status: $status');
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      // First, update the backend via API
      final success = await _deliveryService.updateTaskStatus(taskId, status);

      debugPrint('🚀 DeliveryTasksProvider: API call result: $success');
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error after call: ${_deliveryService.errorMessage}',
      );

      if (success) {
        // Only update local state if backend update was successful
        final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
        if (taskIndex != -1) {
          debugPrint(
            '🚀 DeliveryTasksProvider: Updating local task at index $taskIndex',
          );
          _tasks[taskIndex] = _tasks[taskIndex].copyWith(
            status: status,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
          debugPrint(
            '🚀 DeliveryTasksProvider: Local state updated successfully',
          );
        } else {
          debugPrint(
            '🚀 DeliveryTasksProvider: Task not found in local list: $taskId',
          );
          _error = 'Task not found in local list';
          notifyListeners();
          return false;
        }
      } else {
        _error =
            _deliveryService.errorMessage ??
            'Failed to update task status on server';
        debugPrint('🚀 DeliveryTasksProvider: API call failed: $_error');
        notifyListeners();
        return false;
      }

      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint('🚀 DeliveryTasksProvider: Exception: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptTask(String taskId) async {
    try {
      await updateTaskStatus(taskId, 'accepted');
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> markAsInTransit(DeliveryTask task) async {
    await updateTaskStatus(task.id, 'in_transit');
  }

  Future<void> markAsCompleted(DeliveryTask task) async {
    await updateTaskStatus(task.id, 'completed');
  }

  Future<bool> updateLocation(
    String taskId,
    double latitude,
    double longitude,
  ) async {
    try {
      debugPrint(
        '🚀 DeliveryTasksProvider: Updating location for task $taskId',
      );
      debugPrint(
        '🚀 DeliveryTasksProvider: Latitude: $latitude, Longitude: $longitude',
      );

      final success = await _deliveryService.updateLocation(
        taskId,
        latitude,
        longitude,
      );

      debugPrint('🚀 DeliveryTasksProvider: Location update result: $success');
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (success) {
        // Update local task with new location
        final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
        if (taskIndex != -1) {
          _tasks[taskIndex] = _tasks[taskIndex].copyWith(
            latitude: latitude,
            longitude: longitude,
            updatedAt: DateTime.now(),
          );
          notifyListeners();

          // Location update activity is already logged via logLocationUpdateActivity method
        }
      } else {
        _error = _deliveryService.errorMessage ?? 'Failed to update location';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint('🚀 DeliveryTasksProvider: Exception updating location: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateETA(String taskId, DateTime eta) async {
    try {
      debugPrint('🚀 DeliveryTasksProvider: Updating ETA for task $taskId');
      debugPrint('🚀 DeliveryTasksProvider: ETA: $eta');

      final success = await _deliveryService.updateETA(taskId, eta);

      debugPrint('🚀 DeliveryTasksProvider: ETA update result: $success');
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (success) {
        // Update local task with new ETA
        final taskIndex = _tasks.indexWhere((task) => task.id == taskId);
        if (taskIndex != -1) {
          _tasks[taskIndex] = _tasks[taskIndex].copyWith(
            estimatedDeliveryTime: eta,
            updatedAt: DateTime.now(),
          );
          notifyListeners();
        }
      } else {
        _error = _deliveryService.errorMessage ?? 'Failed to update ETA';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint('🚀 DeliveryTasksProvider: Exception updating ETA: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> addOrderNotes(String orderId, String notes) async {
    try {
      debugPrint('🚀 DeliveryTasksProvider: Adding notes to order $orderId');
      debugPrint('🚀 DeliveryTasksProvider: Notes: $notes');

      final success = await _deliveryService.addOrderNotes(orderId, notes);

      debugPrint('🚀 DeliveryTasksProvider: Notes addition result: $success');
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (success) {
        // Reload tasks to get updated data
        await loadTasks();
      } else {
        _error = _deliveryService.errorMessage ?? 'Failed to add notes';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint('🚀 DeliveryTasksProvider: Exception adding notes: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> editOrderNotes(String orderId, String notes) async {
    try {
      debugPrint('🚀 DeliveryTasksProvider: Editing notes for order $orderId');
      debugPrint('🚀 DeliveryTasksProvider: Notes: $notes');

      final success = await _deliveryService.editOrderNotes(orderId, notes);

      debugPrint('🚀 DeliveryTasksProvider: Notes edit result: $success');
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (success) {
        // Reload tasks to get updated data
        await loadTasks();
      } else {
        _error = _deliveryService.errorMessage ?? 'Failed to edit notes';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint('🚀 DeliveryTasksProvider: Exception editing notes: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteOrderNotes(String orderId) async {
    try {
      debugPrint('🚀 DeliveryTasksProvider: Deleting notes for order $orderId');

      final success = await _deliveryService.deleteOrderNotes(orderId);

      debugPrint('🚀 DeliveryTasksProvider: Notes deletion result: $success');
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (success) {
        // Reload tasks to get updated data
        await loadTasks();
      } else {
        _error = _deliveryService.errorMessage ?? 'Failed to delete notes';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint('🚀 DeliveryTasksProvider: Exception deleting notes: $e');
      notifyListeners();
      return false;
    }
  }

  // Log contact customer activity
  Future<bool> logContactCustomerActivity(
    String orderId,
    String contactMethod,
  ) async {
    try {
      debugPrint(
        '🚀 DeliveryTasksProvider: Logging contact customer activity for order $orderId',
      );
      debugPrint('🚀 DeliveryTasksProvider: ContactMethod: $contactMethod');

      final success = await _deliveryService.logContactCustomerActivity(
        orderId,
        contactMethod,
      );

      debugPrint(
        '🚀 DeliveryTasksProvider: Contact activity logging result: $success',
      );
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (!success) {
        _error =
            _deliveryService.errorMessage ?? 'Failed to log contact activity';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint(
        '🚀 DeliveryTasksProvider: Exception logging contact activity: $e',
      );
      notifyListeners();
      return false;
    }
  }

  // Log location update activity
  Future<bool> logLocationUpdateActivity(
    String orderId,
    double latitude,
    double longitude,
  ) async {
    try {
      debugPrint(
        '🚀 DeliveryTasksProvider: Logging location update activity for order $orderId',
      );
      debugPrint(
        '🚀 DeliveryTasksProvider: Latitude: $latitude, Longitude: $longitude',
      );

      final success = await _deliveryService.logLocationUpdateActivity(
        orderId,
        latitude,
        longitude,
      );

      debugPrint(
        '🚀 DeliveryTasksProvider: Location activity logging result: $success',
      );
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (!success) {
        _error =
            _deliveryService.errorMessage ?? 'Failed to log location activity';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint(
        '🚀 DeliveryTasksProvider: Exception logging location activity: $e',
      );
      notifyListeners();
      return false;
    }
  }

  // Log route update activity
  Future<bool> logRouteUpdateActivity(
    String orderId,
    List<Map<String, double>> routePoints,
  ) async {
    try {
      debugPrint(
        '🚀 DeliveryTasksProvider: Logging route update activity for order $orderId',
      );
      debugPrint(
        '🚀 DeliveryTasksProvider: RoutePoints: ${routePoints.length} points',
      );

      final success = await _deliveryService.logRouteUpdateActivity(
        orderId,
        routePoints,
      );

      debugPrint(
        '🚀 DeliveryTasksProvider: Route activity logging result: $success',
      );
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (!success) {
        _error =
            _deliveryService.errorMessage ?? 'Failed to log route activity';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint(
        '🚀 DeliveryTasksProvider: Exception logging route activity: $e',
      );
      notifyListeners();
      return false;
    }
  }

  // Log ETA update activity
  Future<bool> logETAUpdateActivity(
    String orderId,
    DateTime estimatedArrivalTime,
  ) async {
    try {
      debugPrint(
        '🚀 DeliveryTasksProvider: Logging ETA update activity for order $orderId',
      );
      debugPrint('🚀 DeliveryTasksProvider: ETA: $estimatedArrivalTime');

      final success = await _deliveryService.logETAUpdateActivity(
        orderId,
        estimatedArrivalTime,
      );

      debugPrint(
        '🚀 DeliveryTasksProvider: ETA activity logging result: $success',
      );
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (!success) {
        _error = _deliveryService.errorMessage ?? 'Failed to log ETA activity';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint(
        '🚀 DeliveryTasksProvider: Exception logging ETA activity: $e',
      );
      notifyListeners();
      return false;
    }
  }

  // Log delivery record activity
  Future<bool> logDeliveryRecordActivity(
    String orderId,
    String status,
    DateTime deliveredAt,
  ) async {
    try {
      debugPrint(
        '🚀 DeliveryTasksProvider: Logging delivery record activity for order $orderId',
      );
      debugPrint(
        '🚀 DeliveryTasksProvider: Status: $status, DeliveredAt: $deliveredAt',
      );

      final success = await _deliveryService.logDeliveryRecordActivity(
        orderId,
        status,
        deliveredAt,
      );

      debugPrint(
        '🚀 DeliveryTasksProvider: Delivery record activity logging result: $success',
      );
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (!success) {
        _error =
            _deliveryService.errorMessage ??
            'Failed to log delivery record activity';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint(
        '🚀 DeliveryTasksProvider: Exception logging delivery record activity: $e',
      );
      notifyListeners();
      return false;
    }
  }

  // Log delivery activity (legacy method for backward compatibility)
  Future<bool> logDeliveryActivity(
    String orderId,
    String activityType,
    Map<String, dynamic>? activityData,
  ) async {
    try {
      debugPrint(
        '🚀 DeliveryTasksProvider: Logging activity for order $orderId',
      );
      debugPrint('🚀 DeliveryTasksProvider: ActivityType: $activityType');

      final success = await _deliveryService.logDeliveryActivity(
        orderId,
        activityType,
        activityData,
      );

      debugPrint('🚀 DeliveryTasksProvider: Activity logging result: $success');
      debugPrint(
        '🚀 DeliveryTasksProvider: Service error: ${_deliveryService.errorMessage}',
      );

      if (!success) {
        _error = _deliveryService.errorMessage ?? 'Failed to log activity';
        notifyListeners();
      }

      return success;
    } catch (e) {
      _error = e.toString();
      debugPrint('🚀 DeliveryTasksProvider: Exception logging activity: $e');
      notifyListeners();
      return false;
    }
  }

  // Additional methods needed by the dashboard
  List<DeliveryTask> getDeliveryTasks() {
    return _tasks;
  }

  List<DeliveryTask> getUrgentTasks() {
    return _tasks
        .where((task) => task.status == DeliveryTask.statusFailed)
        .toList();
  }

  int get assignedTasksCount {
    return _tasks
        .where(
          (task) =>
              task.status == DeliveryTask.statusAssigned ||
              task.status == DeliveryTask.statusAccepted ||
              task.status == DeliveryTask.statusInProgress ||
              task.status == DeliveryTask.statusInTransit ||
              task.status == DeliveryTask.statusPickedUp,
        )
        .length;
  }

  int get completedTasksCount {
    return _tasks
        .where(
          (task) =>
              task.status == DeliveryTask.statusCompleted ||
              task.status == DeliveryTask.statusDelivered,
        )
        .length;
  }

  int get inTransitTasksCount {
    return _tasks
        .where(
          (task) =>
              task.status == DeliveryTask.statusInProgress ||
              task.status == DeliveryTask.statusInTransit ||
              task.status == DeliveryTask.statusPickedUp,
        )
        .length;
  }
}
