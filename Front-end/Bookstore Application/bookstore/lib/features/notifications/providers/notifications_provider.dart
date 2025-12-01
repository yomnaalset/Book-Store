import 'package:flutter/foundation.dart';
import '../models/notification.dart';
import '../services/notifications_api_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final NotificationsApiService _apiService;
  List<Notification> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _unreadCount = 0;

  NotificationsProvider(this._apiService);

  // Getters
  List<Notification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Set authentication token
  void setToken(String token) {
    // Token is handled by the API service through getHeaders
  }

  // Load notifications from API
  Future<void> loadNotifications({
    int page = 1,
    int limit = 20,
    String? search,
    String? type,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      debugPrint('NotificationsProvider: Loading notifications...');

      // Load notifications from API
      final notifications = await _apiService.getNotifications(
        page: page,
        limit: limit,
        search: search,
        type: type,
      );

      _notifications = notifications;

      // Get unread count only if we have a valid token
      try {
        final headers = _apiService.getHeaders();
        final authHeader = headers['Authorization'] ?? '';
        
        // Only make API call if we have a valid Bearer token
        if (authHeader.isNotEmpty && authHeader.startsWith('Bearer ') && authHeader.length >= 20) {
          _unreadCount = await _apiService.getUnreadCount();
          debugPrint('NotificationsProvider: Unread count: $_unreadCount');
        } else {
          debugPrint('NotificationsProvider: Skipping unread count - no valid token');
          _unreadCount = 0;
        }
      } catch (e) {
        debugPrint('Failed to get unread count: $e');
        _unreadCount = 0;
      }

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load notifications: $e');
      _setLoading(false);
      debugPrint('NotificationsProvider: Error loading notifications: $e');
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _apiService.markAsRead(notificationId);

      // Update local state
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
        _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        notifyListeners();
      }
      // Refresh unread count from API to ensure accuracy
      await refreshUnreadCount();
    } catch (e) {
      _setError('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.markAllAsRead();

      // Update local state - mark all notifications as read
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
      _unreadCount = 0;
      notifyListeners();
      // Refresh unread count from API to ensure accuracy
      await refreshUnreadCount();
    } catch (e) {
      _setError('Failed to mark all notifications as read: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      // Call the API to delete the notification from the server
      await _apiService.deleteNotification(notificationId);

      // Update local state after successful server deletion
      final index = _notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        final wasUnread = !_notifications[index].isRead;
        _notifications.removeAt(index);
        if (wasUnread) {
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        }
        notifyListeners();

        debugPrint(
          'Successfully deleted notification $notificationId from server and local state',
        );
      }
    } catch (e) {
      _setError('Failed to delete notification: $e');
      debugPrint('Error deleting notification $notificationId: $e');
    }
  }

  List<Notification> getUnreadNotifications() {
    return _notifications.where((n) => !n.isRead).toList();
  }

  List<Notification> getNotificationsByType(String type) {
    return _notifications.where((n) => n.type == type).toList();
  }

  void clearError() {
    _clearError();
  }

  // Refresh unread count only
  Future<void> refreshUnreadCount() async {
    try {
      // Check if we have a valid token before making the API call
      final headers = _apiService.getHeaders();
      final authHeader = headers['Authorization'] ?? '';
      
      // Only make API call if we have a valid Bearer token
      if (authHeader.isEmpty || !authHeader.startsWith('Bearer ') || authHeader.length < 20) {
        debugPrint('NotificationsProvider: Skipping unread count - no valid token');
        _unreadCount = 0;
        notifyListeners();
        return;
      }
      
      debugPrint('NotificationsProvider: Refreshing unread count...');
      _unreadCount = await _apiService.getUnreadCount();
      debugPrint(
        'NotificationsProvider: Updated unread count to: $_unreadCount',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationsProvider: Error refreshing unread count: $e');
      // Set unread count to 0 on error to avoid showing incorrect badge
      _unreadCount = 0;
      notifyListeners();
    }
  }
}
