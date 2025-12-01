import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/delivery_service.dart';

class DeliverySettingsProvider with ChangeNotifier {
  final DeliveryService _deliveryService;
  bool _isAvailable = false;
  bool _isLoading = false;
  String? _error;
  String _currentStatus =
      'offline'; // Track current status: 'online', 'busy', 'offline'

  // Notification preferences
  bool _newTaskAssignments = true;
  bool _taskUpdates = true;
  bool _urgentTasks = true;
  bool _systemUpdates = false;

  DeliverySettingsProvider(this._deliveryService) {
    // Don't load availability status immediately - wait for token to be set
    // _loadAvailabilityStatus();
  }

  // Getters
  bool get isAvailable => _isAvailable;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get availabilityStatus {
    // Return the current status directly
    return _currentStatus;
  }

  // Notification getters
  bool get newTaskAssignments => _newTaskAssignments;
  bool get taskUpdates => _taskUpdates;
  bool get urgentTasks => _urgentTasks;
  bool get systemUpdates => _systemUpdates;

  // Set authentication token
  void setToken(String? token, {BuildContext? context}) {
    _deliveryService.setToken(token);
    // Only load availability status if we have a valid token
    // and the user is a delivery manager (not admin)
    if (token != null && token.isNotEmpty) {
      // Check if this is a delivery manager before loading availability status
      _checkAndLoadAvailabilityStatus(context);
    }
  }

  // Check if user is delivery manager before loading availability status
  Future<void> _checkAndLoadAvailabilityStatus(BuildContext? context) async {
    // Check if user is a delivery manager before making API calls
    if (context != null) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.userRole != 'delivery_admin') {
          debugPrint(
            'User is not a delivery manager (role: ${authProvider.userRole}), skipping availability check',
          );
          return;
        }
      } catch (e) {
        debugPrint(
          'Could not check user role, skipping availability check: $e',
        );
        return;
      }
    }

    try {
      // Try to load availability status
      // The service will handle the case where user is not a delivery manager
      await _loadAvailabilityStatus();
    } catch (e) {
      // If there's an error, user is likely not a delivery manager
      // Skip loading availability status silently
      debugPrint(
        'User is not a delivery manager, skipping availability check: $e',
      );
    }
  }

  // Load availability status from SharedPreferences
  Future<void> _loadAvailabilityStatus() async {
    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      _isAvailable = prefs.getBool('delivery_availability') ?? false;

      // For delivery managers, we'll use local storage primarily
      // and only sync with server when updating status
      debugPrint(
        'Delivery availability status loaded from local storage: $_isAvailable',
      );

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load availability status: $e');
      _setLoading(false);
    }
  }

  // Save availability status to SharedPreferences
  Future<void> _saveAvailabilityStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('delivery_availability', _isAvailable);
    } catch (e) {
      debugPrint('Error saving availability status: $e');
    }
  }

  // Update availability status
  Future<bool> updateAvailabilityStatus(bool isAvailable) async {
    _setLoading(true);
    _clearError();

    try {
      // Update local state first
      _isAvailable = isAvailable;
      await _saveAvailabilityStatus();

      // Try to sync with server (optional)
      try {
        await _deliveryService.updateAvailabilityStatus(
          isAvailable ? 'available' : 'unavailable',
        );
        debugPrint('Availability status synced with server');
      } catch (e) {
        // If server sync fails, continue with local update
        debugPrint('Server sync failed, but local update succeeded: $e');
      }

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error updating availability status: $e');
      _setLoading(false);
      return false;
    }
  }

  // Update availability status from string (for UI compatibility)
  Future<bool> updateAvailabilityStatusFromString(String status) async {
    _setLoading(true);
    _clearError();

    try {
      // Update current status
      _currentStatus = status;

      // Convert string status to boolean for backward compatibility
      bool isAvailable = status == 'online' || status == 'busy';

      // Update local state
      _isAvailable = isAvailable;
      await _saveAvailabilityStatus();

      // Note: Server status updates are now handled automatically by the backend
      // when delivery tasks are started/completed. No manual status sync needed.
      debugPrint('Availability status updated locally: $status');

      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Error updating availability status: $e');
      _setLoading(false);
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

  // Load notification preferences from SharedPreferences
  Future<void> _loadNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _newTaskAssignments =
          prefs.getBool('notification_new_task_assignments') ?? true;
      _taskUpdates = prefs.getBool('notification_task_updates') ?? true;
      _urgentTasks = prefs.getBool('notification_urgent_tasks') ?? true;
      _systemUpdates = prefs.getBool('notification_system_updates') ?? false;
    } catch (e) {
      debugPrint('Error loading notification preferences: $e');
    }
  }

  // Save notification preferences to SharedPreferences
  Future<void> _saveNotificationPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        'notification_new_task_assignments',
        _newTaskAssignments,
      );
      await prefs.setBool('notification_task_updates', _taskUpdates);
      await prefs.setBool('notification_urgent_tasks', _urgentTasks);
      await prefs.setBool('notification_system_updates', _systemUpdates);
    } catch (e) {
      debugPrint('Error saving notification preferences: $e');
    }
  }

  // Update notification preferences
  Future<void> updateNotificationPreference(
    String preference,
    bool value,
  ) async {
    switch (preference) {
      case 'new_task_assignments':
        _newTaskAssignments = value;
        break;
      case 'task_updates':
        _taskUpdates = value;
        break;
      case 'urgent_tasks':
        _urgentTasks = value;
        break;
      case 'system_updates':
        _systemUpdates = value;
        break;
    }

    await _saveNotificationPreferences();
    notifyListeners();
  }

  // Additional methods required by the UI
  Future<void> getDeliverySettings() async {
    await _loadAvailabilityStatus();
    await _loadNotificationPreferences();
  }
}
