import 'package:flutter/foundation.dart';
import '../services/delivery_status_service.dart';

/// Provider for managing delivery status state
class DeliveryStatusProvider extends ChangeNotifier {
  String _currentStatus = 'offline';
  bool _isLoading = false;
  String? _errorMessage;
  bool _canChangeManually = true;
  String? _authToken;

  // Getters
  String get currentStatus => _currentStatus;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get canChangeManually => _canChangeManually;
  bool get isOnline => _currentStatus == 'online';
  bool get isOffline => _currentStatus == 'offline';
  bool get isBusy => _currentStatus == 'busy';

  /// Set authentication token
  void setToken(String? token) {
    _authToken = token;
    DeliveryStatusService.setToken(token);
    // Clear any previous "no token" errors when token is set
    if (token != null &&
        token.isNotEmpty &&
        _errorMessage == 'No authentication token available') {
      _setError(null);
    }
  }

  /// Load current status from server (for login/app startup)
  Future<void> loadCurrentStatus() async {
    if (_authToken == null) {
      debugPrint(
        'DeliveryStatusProvider: No auth token available - skipping status load',
      );
      // Don't set error, just return silently if token is not available
      // This prevents error messages when user hasn't logged in yet
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final statusData = await DeliveryStatusService.getCurrentStatus();

      if (statusData != null) {
        final previousStatus = _currentStatus;
        _currentStatus = statusData['delivery_status'] ?? 'offline';
        _canChangeManually = statusData['can_change_manually'] ?? true;

        debugPrint('DeliveryStatusProvider: Loaded status: $_currentStatus');
        debugPrint(
          'DeliveryStatusProvider: Can change manually: $_canChangeManually',
        );

        // Notify listeners if status changed
        if (previousStatus != _currentStatus) {
          notifyListeners();
          debugPrint(
            'DeliveryStatusProvider: Status changed from $previousStatus to $_currentStatus - notifying listeners',
          );
        }

        // CRITICAL: Frontend only reads state from backend, never modifies it
        // Backend is the single source of truth for delivery manager status
        // If status is busy, that's what the backend says - we trust it
        // Backend's complete_delivery_task() handles status changes automatically
      } else {
        _setError('Failed to load current status');
      }
    } catch (e) {
      _setError('Error loading status: ${e.toString()}');
    } finally {
      _setLoading(false);
    }
  }

  /// Update status with proper validation - only allows online/offline manual changes
  Future<bool> updateStatus(String newStatus) async {
    if (_authToken == null || _authToken!.isEmpty) {
      _setError('No authentication token available. Please login again.');
      return false;
    }

    // Validate status - only allow online/offline for manual changes
    if (!['online', 'offline'].contains(newStatus)) {
      _setError(
        'Invalid status. You can only manually change between online and offline.',
      );
      return false;
    }

    // Check if status is already the same
    if (_currentStatus == newStatus) {
      debugPrint(
        'DeliveryStatusProvider: Status is already $newStatus, no need to update',
      );
      return true;
    }

    // Check if manual change is allowed (not busy)
    if (_currentStatus == 'busy') {
      _setError(
        'Cannot change status manually while busy. Status will automatically change to online when delivery is completed.',
      );
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      final result = await DeliveryStatusService.updateStatus(newStatus);

      if (result['success'] == true) {
        _currentStatus = result['current_status'] ?? newStatus;
        _canChangeManually = result['data']?['can_change_manually'] ?? true;

        debugPrint('DeliveryStatusProvider: Status updated to $_currentStatus');
        notifyListeners();
        return true;
      } else {
        _setError(result['message'] ?? 'Failed to update status');

        // Update current status from server response if available
        if (result['current_status'] != null) {
          _currentStatus = result['current_status'];
          notifyListeners();
        }

        return false;
      }
    } catch (e) {
      _setError('Error updating status: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reset status if no active deliveries (safety mechanism)
  Future<bool> resetStatusIfNoActiveDeliveries() async {
    _setLoading(true);
    clearError();

    try {
      final result =
          await DeliveryStatusService.resetStatusIfNoActiveDeliveries();

      if (result['success'] == true) {
        _currentStatus = result['current_status'] ?? 'offline';
        _canChangeManually = _currentStatus != 'busy';

        debugPrint(
          'DeliveryStatusProvider: Status reset - ${result['message']}',
        );
        debugPrint('DeliveryStatusProvider: New status: $_currentStatus');

        _setLoading(false);
        notifyListeners();
        return true;
      } else {
        _setError(result['message'] ?? 'Failed to reset status');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Error resetting status: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Refresh status from server (for automatic sync after delivery completion)
  Future<void> refreshStatusFromServer() async {
    if (_authToken == null) return;

    try {
      final newStatus = await DeliveryStatusService.refreshStatusFromServer();
      if (newStatus != null && newStatus != _currentStatus) {
        _currentStatus = newStatus;
        _canChangeManually =
            await DeliveryStatusService.canChangeStatusManually();

        debugPrint(
          'DeliveryStatusProvider: Status refreshed to $_currentStatus',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('DeliveryStatusProvider: Error refreshing status: $e');
    }
  }

  /// DEPRECATED: Do not use setStatusLocally - always reload from server
  /// Frontend should never modify status locally - backend is single source of truth
  /// Use loadCurrentStatus() instead to get fresh data from server
  @Deprecated(
    'Use loadCurrentStatus() instead - backend is single source of truth',
  )
  void setStatusLocally(String status) {
    // This method is deprecated - status should only come from backend
    // Keeping for backward compatibility but should not be used
    debugPrint(
      'WARNING: setStatusLocally called - this should not be used. Use loadCurrentStatus() instead.',
    );
  }

  /// Clear error message
  void clearError() {
    _setError(null);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }
}
