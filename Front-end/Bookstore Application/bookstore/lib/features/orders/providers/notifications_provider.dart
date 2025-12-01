import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/notifications_service.dart';

class NotificationsProvider with ChangeNotifier {
  final NotificationsService _notificationsService;
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  final int _totalPages = 1;
  final int _totalItems = 0;
  final int _itemsPerPage = 10;
  int _unreadCount = 0;

  NotificationsProvider(this._notificationsService);

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;
  int get unreadCount => _unreadCount;

  // Get all notifications
  Future<void> loadNotifications({
    int page = 1,
    bool refresh = false,
    bool unreadOnly = false,
  }) async {
    if (_isLoading) return;

    _setLoading(true);
    _clearError();

    if (refresh || page == 1) {
      _notifications = [];
      _currentPage = 1;
    } else {
      _currentPage = page;
    }

    try {
      final notifications = await _notificationsService.getNotifications(
        page: _currentPage,
        limit: _itemsPerPage,
        unreadOnly: unreadOnly,
      );

      if (refresh || page == 1) {
        _notifications = notifications;
      } else {
        _notifications.addAll(notifications);
      }

      // Update unread count
      await refreshUnreadCount();

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load notifications: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    _clearError();

    try {
      final success = await _notificationsService.markAsRead(notificationId);

      if (success) {
        // Update the notification in the list
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          final updatedNotification = _notifications[index].copyWith(
            isRead: true,
          );
          _notifications[index] = updatedNotification;
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          notifyListeners();
        }
        return true;
      } else {
        _setError(
          _notificationsService.errorMessage ??
              'Failed to mark notification as read',
        );
        return false;
      }
    } catch (e) {
      _setError('Error marking notification as read: ${e.toString()}');
      return false;
    }
  }

  // Mark all notifications as read
  Future<bool> markAllAsRead() async {
    _clearError();

    try {
      final success = await _notificationsService.markAllAsRead();

      if (success) {
        // Update all notifications in the list
        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        _unreadCount = 0;
        notifyListeners();
        return true;
      } else {
        _setError(
          _notificationsService.errorMessage ??
              'Failed to mark all notifications as read',
        );
        return false;
      }
    } catch (e) {
      _setError('Error marking all notifications as read: ${e.toString()}');
      return false;
    }
  }

  // Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    _clearError();

    try {
      final success = await _notificationsService.deleteNotification(
        notificationId,
      );

      if (success) {
        // Remove the notification from the list
        final wasUnread = _notifications.any(
          (n) => n.id == notificationId && !n.isRead,
        );
        _notifications.removeWhere((n) => n.id == notificationId);

        if (wasUnread) {
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        }

        notifyListeners();
        return true;
      } else {
        _setError(
          _notificationsService.errorMessage ?? 'Failed to delete notification',
        );
        return false;
      }
    } catch (e) {
      _setError('Error deleting notification: ${e.toString()}');
      return false;
    }
  }

  // Refresh unread count
  Future<void> refreshUnreadCount() async {
    try {
      final count = await _notificationsService.getUnreadCount();
      _unreadCount = count;
      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing unread count: ${e.toString()}');
    }
  }

  // Load more notifications
  Future<void> loadMore() async {
    if (_isLoading || _currentPage >= _totalPages) return;
    await loadNotifications(page: _currentPage + 1);
  }

  // Private helper methods
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
}
