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
        _currentStatus = statusData['delivery_status'] ?? 'offline';
        _canChangeManually = statusData['can_change_manually'] ?? true;

        debugPrint('DeliveryStatusProvider: Loaded status: $_currentStatus');
        debugPrint(
          'DeliveryStatusProvider: Can change manually: $_canChangeManually',
        );

        // If status is busy, try to reset it (backend should handle this, but this is a safety check)
        // This ensures the status is reset even if backend auto-reset didn't work
        if (_currentStatus == 'busy') {
          debugPrint(
            'DeliveryStatusProvider: Status is busy, attempting reset as safety check...',
          );
          // Try reset and reload status after to ensure we have the latest value
          try {
            final resetSuccess = await resetStatusIfNoActiveDeliveries();
            if (resetSuccess) {
              debugPrint(
                'DeliveryStatusProvider: Status successfully reset from busy to online',
              );
              // Reload status to get the updated value from backend
              final updatedStatusData =
                  await DeliveryStatusService.getCurrentStatus();
              if (updatedStatusData != null) {
                _currentStatus =
                    updatedStatusData['delivery_status'] ?? 'offline';
                _canChangeManually =
                    updatedStatusData['can_change_manually'] ?? true;
                notifyListeners();
              }
            }
          } catch (e) {
            debugPrint(
              'DeliveryStatusProvider: Reset attempt failed (non-critical): $e',
            );
            // Even if reset fails, the backend should have already handled it
            // So we can continue with the current status
          }
        }
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

  /// Set status locally (for automatic changes from backend)
  void setStatusLocally(String status) {
    if (['online', 'offline', 'busy'].contains(status) &&
        status != _currentStatus) {
      _currentStatus = status;
      _canChangeManually = status != 'busy';

      debugPrint(
        'DeliveryStatusProvider: Status set locally to $_currentStatus',
      );
      notifyListeners();
    }
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
