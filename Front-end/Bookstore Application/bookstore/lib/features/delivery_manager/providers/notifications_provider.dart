import 'package:flutter/foundation.dart';
import '../../delivery/services/delivery_service.dart';

class DeliveryNotificationsProvider extends ChangeNotifier {
  final DeliveryService _deliveryService;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;
  String? _cachedToken;
  int _unreadCount = 0;

  DeliveryNotificationsProvider(this._deliveryService);

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  // Set authentication token
  void setToken(String? token) {
    _cachedToken = token;
    _deliveryService.setToken(token);
  }

  Future<void> loadNotifications() async {
    // Only load notifications if we have a valid token (user is authenticated)
    if (_cachedToken == null || _cachedToken!.isEmpty) {
      debugPrint(
        'DeliveryNotificationsProvider: No token available, skipping loadNotifications',
      );
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Load notifications from real API
      _notifications = await _loadNotificationsFromAPI();
      // Also fetch unread count from API
      await refreshUnreadCount();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> _loadNotificationsFromAPI() async {
    try {
      // Use the proper notifications endpoint
      final response = await _deliveryService.getNotificationsx();
      return response;
    } catch (e) {
      // If notifications endpoint fails, return empty list
      debugPrint('Failed to load notifications: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _deliveryService.markNotificationAsReadx(int.parse(notificationId));
      // Update local state
      final index = _notifications.indexWhere(
        (notification) => notification['id'].toString() == notificationId,
      );
      if (index != -1) {
        final wasUnread = !_notifications[index]['is_read'];
        _notifications[index]['is_read'] = true;
        if (wasUnread) {
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
        }
        notifyListeners();
      }
      // Refresh unread count from API to ensure accuracy
      await refreshUnreadCount();
    } catch (e) {
      debugPrint('Failed to mark notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      for (final notification in _notifications) {
        if (!notification['is_read']) {
          await markAsRead(notification['id'].toString());
        }
      }
      // Refresh unread count after marking all as read
      await refreshUnreadCount();
    } catch (e) {
      debugPrint('Failed to mark all notifications as read: $e');
    }
  }

  // Refresh unread count from API
  Future<void> refreshUnreadCount() async {
    try {
      _unreadCount = await _deliveryService.getUnreadNotificationsCount();
      debugPrint(
        'DeliveryNotificationsProvider: Unread count refreshed: $_unreadCount',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh unread count: $e');
      // Fallback to local count if API fails
      _unreadCount = _notifications
          .where((notification) => !notification['is_read'])
          .length;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> get urgentNotifications {
    return _notifications
        .where(
          (notification) =>
              notification['type'] == 'urgent' ||
              notification['priority'] == 'high',
        )
        .toList();
  }

  List<Map<String, dynamic>> get recentNotifications {
    final now = DateTime.now();
    return _notifications.where((notification) {
      final createdAt = DateTime.tryParse(notification['created_at'] ?? '');
      if (createdAt == null) return false;
      return createdAt.isAfter(now.subtract(const Duration(days: 7)));
    }).toList();
  }

  // Delete a notification
  Future<bool> deleteNotification(String notificationId) async {
    try {
      final success = await _deliveryService.deleteNotification(
        int.parse(notificationId),
      );
      if (success) {
        // Remove from local state
        final index = _notifications.indexWhere(
          (notification) => notification['id'].toString() == notificationId,
        );
        if (index != -1) {
          final wasUnread = !_notifications[index]['is_read'];
          _notifications.removeAt(index);
          if (wasUnread) {
            _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
          }
          notifyListeners();
        }
        // Refresh unread count from API
        await refreshUnreadCount();
      }
      return success;
    } catch (e) {
      debugPrint('Failed to delete notification: $e');
      return false;
    }
  }

  // Delete all notifications
  Future<bool> deleteAllNotifications() async {
    try {
      final success = await _deliveryService.deleteAllNotifications();
      if (success) {
        // Clear local state
        _notifications.clear();
        _unreadCount = 0;
        notifyListeners();
        // Refresh unread count from API
        await refreshUnreadCount();
      }
      return success;
    } catch (e) {
      debugPrint('Failed to delete all notifications: $e');
      return false;
    }
  }
}
