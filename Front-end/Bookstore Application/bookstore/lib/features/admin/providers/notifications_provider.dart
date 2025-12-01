import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/manager_api_service.dart';

class NotificationsProvider extends ChangeNotifier {
  final ManagerApiService _apiService;

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _totalItems = 0;
  int _unreadCount = 0;
  // Track notifications that were optimistically marked as read
  // This ensures we preserve the read state even if server hasn't updated yet
  final Set<String> _optimisticallyReadIds = <String>{};

  // Track notifications that were successfully marked as read (API call succeeded)
  // This ensures they stay read even if a refresh happens before server fully commits
  final Set<String> _confirmedReadIds = <String>{};

  // Getters
  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalItems => _totalItems;
  int get unreadCount => _unreadCount;

  NotificationsProvider(this._apiService);

  // Get notifications
  Future<void> getNotifications({
    int page = 1,
    int limit = 1000,
    String? search,
    String? type,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Debug authentication
      debugPrint('NotificationsProvider: Getting notifications...');
      debugPrint(
        'NotificationsProvider: Current token status: ${_apiService.getAuthToken?.call().isNotEmpty ?? false}',
      );

      // Load notifications from API
      final notifications = await _apiService.getNotifications(
        page: page,
        limit: limit,
        type: type,
        search: search,
      );

      debugPrint(
        'NotificationsProvider: Received ${notifications.length} notifications from API',
      );

      // Log isRead status for first few notifications
      for (final n in notifications.take(5)) {
        debugPrint(
          'NotificationsProvider: Notification ${n.id} - isRead: ${n.isRead}, title: ${n.title}',
        );
      }

      // Merge server data with optimistic updates and confirmed read notifications
      // Same logic as refreshNotifications to ensure consistency
      final mergedNotifications = notifications.map((serverNotification) {
        final notificationId = serverNotification.id.toString();

        // Check if this notification was confirmed as read (API call succeeded)
        if (_confirmedReadIds.contains(notificationId)) {
          // Always keep as read if we confirmed it via API
          final converted = NotificationModel.fromJson(
            serverNotification.toJson(),
          );
          return NotificationModel(
            id: converted.id,
            title: converted.title,
            message: converted.message,
            type: converted.type,
            isRead: true, // Always true for confirmed read notifications
            createdAt: converted.createdAt,
            data: converted.data,
          );
        }

        // Check if this notification was optimistically marked as read
        if (_optimisticallyReadIds.contains(notificationId)) {
          // If server confirms it's read, remove from optimistic tracking and add to confirmed
          if (serverNotification.isRead) {
            debugPrint(
              'NotificationsProvider: Server confirmed notification $notificationId is read in getNotifications, moving to confirmed set',
            );
            _optimisticallyReadIds.remove(notificationId);
            _confirmedReadIds.add(notificationId);
            return NotificationModel.fromJson(serverNotification.toJson());
          } else {
            // Server hasn't updated yet, preserve optimistic read state
            debugPrint(
              'NotificationsProvider: Preserving optimistic read state for notification $notificationId in getNotifications',
            );
            final converted = NotificationModel.fromJson(
              serverNotification.toJson(),
            );
            return NotificationModel(
              id: converted.id,
              title: converted.title,
              message: converted.message,
              type: converted.type,
              isRead: true, // Force to read based on optimistic update
              createdAt: converted.createdAt,
              data: converted.data,
            );
          }
        }

        // Not in any tracking, use server state
        return NotificationModel.fromJson(serverNotification.toJson());
      }).toList();

      _notifications = mergedNotifications;
      _totalItems = mergedNotifications.length;

      debugPrint(
        'NotificationsProvider: Updated _notifications with ${_notifications.length} items',
      );

      // Don't automatically fetch unread count - only fetch when explicitly requested

      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      debugPrint('NotificationsProvider: Error getting notifications: $e');
    }
  }

  // Mark notification as read
  Future<void> markAsRead(
    String notificationId, {
    String? search,
    String? type,
  }) async {
    try {
      debugPrint(
        'NotificationsProvider: Marking notification $notificationId as read',
      );

      // Optimistic update: immediately update UI to show notification as read
      final index = _notifications.indexWhere(
        (n) => n.id?.toString() == notificationId.toString(),
      );
      if (index != -1) {
        final oldNotification = _notifications[index];
        if (!oldNotification.isRead) {
          // Create updated notification with isRead = true
          final updatedNotification = NotificationModel(
            id: oldNotification.id,
            title: oldNotification.title,
            message: oldNotification.message,
            type: oldNotification.type,
            isRead: true, // Mark as read immediately
            createdAt: oldNotification.createdAt,
            data: oldNotification.data,
          );

          // Update local state immediately for instant UI feedback
          _notifications[index] = updatedNotification;
          _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;

          // Track this as an optimistic update
          _optimisticallyReadIds.add(notificationId);

          notifyListeners(); // Notify UI to rebuild immediately

          debugPrint(
            'NotificationsProvider: Optimistically updated notification $notificationId to read state',
          );
        }
      }

      // Now call the API to persist the change and get the server's confirmed state
      // Safely parse the notification ID
      int parsedNotificationId;
      try {
        if (notificationId.isEmpty) {
          throw const FormatException('Notification ID cannot be empty');
        }
        parsedNotificationId = int.parse(notificationId);
      } catch (e) {
        debugPrint(
          'NotificationsProvider: Error parsing notification ID "$notificationId": $e',
        );
        throw Exception(
          'Invalid notification ID: $notificationId. Expected a valid integer.',
        );
      }

      final serverConfirmedNotification = await _apiService
          .markNotificationAsRead(parsedNotificationId);
      debugPrint(
        'NotificationsProvider: API call successful for notification $notificationId',
      );
      debugPrint(
        'NotificationsProvider: Server confirmed notification $notificationId - isRead: ${serverConfirmedNotification.isRead}',
      );

      // Update local state with server's confirmed data
      // Since we just successfully called the API to mark it as read, we ALWAYS
      // update it to read state, regardless of what the server response says.
      // This ensures persistence even if there are server-side timing issues.
      final confirmedIndex = _notifications.indexWhere(
        (n) => n.id?.toString() == notificationId.toString(),
      );
      if (confirmedIndex != -1) {
        try {
          // Convert the server's NotificationModel to our NotificationModel
          final confirmedNotificationModel = NotificationModel.fromJson(
            serverConfirmedNotification.toJson(),
          );

          // Verify the conversion worked correctly
          if (confirmedNotificationModel.id?.toString() !=
              notificationId.toString()) {
            debugPrint(
              'NotificationsProvider: Warning - Notification ID mismatch after conversion. Expected: $notificationId, Got: ${confirmedNotificationModel.id}',
            );
          }

          // ALWAYS mark as read since we just successfully called the API
          // Force isRead to true to ensure persistence
          final updatedNotification = NotificationModel(
            id: confirmedNotificationModel.id ?? notificationId,
            title: confirmedNotificationModel.title,
            message: confirmedNotificationModel.message,
            type: confirmedNotificationModel.type,
            isRead: true, // Always true after successful API call
            createdAt: confirmedNotificationModel.createdAt,
            data: confirmedNotificationModel.data,
          );

          _notifications[confirmedIndex] = updatedNotification;

          // Remove from optimistic tracking and add to confirmed read set
          _optimisticallyReadIds.remove(notificationId);
          _confirmedReadIds.add(notificationId);

          notifyListeners();
          debugPrint(
            'NotificationsProvider: Updated local state with server confirmed data for notification $notificationId (forced isRead: true)',
          );

          if (!confirmedNotificationModel.isRead) {
            debugPrint(
              'NotificationsProvider: Warning - Server returned notification $notificationId as unread, but we forced it to read since API call succeeded.',
            );
          }
        } catch (e, stackTrace) {
          debugPrint(
            'NotificationsProvider: Error converting server notification: $e',
          );
          debugPrint('NotificationsProvider: Stack trace: $stackTrace');
          // If conversion fails, still mark as read since API call succeeded
          final currentNotification = _notifications[confirmedIndex];
          _notifications[confirmedIndex] = NotificationModel(
            id: currentNotification.id,
            title: currentNotification.title,
            message: currentNotification.message,
            type: currentNotification.type,
            isRead: true, // Force to read since API call succeeded
            createdAt: currentNotification.createdAt,
            data: currentNotification.data,
          );
          _optimisticallyReadIds.remove(notificationId);
          _confirmedReadIds.add(notificationId);
          notifyListeners();
          debugPrint(
            'NotificationsProvider: Forced notification to read state after conversion error',
          );
        }
      } else {
        debugPrint(
          'NotificationsProvider: Warning - Could not find notification $notificationId in local list after server confirmation',
        );
      }

      // Verify the update was successful
      final finalNotification = _notifications.firstWhere(
        (n) => n.id?.toString() == notificationId.toString(),
        orElse: () {
          debugPrint(
            'NotificationsProvider: Warning - Could not find notification $notificationId after update',
          );
          return _notifications.isNotEmpty
              ? _notifications.first
              : NotificationModel(
                  id: notificationId,
                  title: 'Unknown',
                  message: 'Unknown',
                  type: 'unknown',
                  isRead: false,
                  createdAt: DateTime.now(),
                );
        },
      );
      debugPrint(
        'NotificationsProvider: Notification $notificationId final isRead status: ${finalNotification.isRead}',
      );

      // Note: We do NOT refresh the list here because:
      // 1. We already updated local state with the server's confirmed response
      // 2. Immediate refresh might fetch stale/cached data before server commits
      // 3. The local state is already correct and will persist
      // The list will naturally refresh when:
      // - User manually refreshes
      // - User navigates away and back
      // - Page is reopened (fresh fetch will have correct server state)
    } catch (e) {
      debugPrint('NotificationsProvider: Error in markAsRead: $e');

      // On error, revert optimistic update if it was made
      final index = _notifications.indexWhere(
        (n) => n.id?.toString() == notificationId.toString(),
      );
      if (index != -1 && _notifications[index].isRead) {
        final notification = _notifications[index];
        _notifications[index] = NotificationModel(
          id: notification.id,
          title: notification.title,
          message: notification.message,
          type: notification.type,
          isRead: false, // Revert to unread
          createdAt: notification.createdAt,
          data: notification.data,
        );
        _unreadCount = _unreadCount + 1;
        // Remove from optimistic tracking
        _optimisticallyReadIds.remove(notificationId);
        notifyListeners();
      }

      _setError(e.toString());
      rethrow;
    }
  }

  // Refresh notifications from server without changing filters
  Future<void> refreshNotifications({String? search, String? type}) async {
    try {
      debugPrint(
        'NotificationsProvider: refreshNotifications called with search=$search, type=$type',
      );

      // Get current filters if not provided
      final notifications = await _apiService.getNotifications(
        page: 1,
        limit: 1000,
        type: type,
        search: search,
      );

      debugPrint(
        'NotificationsProvider: Received ${notifications.length} notifications from API',
      );
      debugPrint(
        'NotificationsProvider: Tracking ${_optimisticallyReadIds.length} optimistically read notifications',
      );

      // Log the isRead status of each notification for debugging
      for (final n in notifications.take(5)) {
        debugPrint(
          'NotificationsProvider: Notification ${n.id} - isRead: ${n.isRead}, title: ${n.title.substring(0, n.title.length > 20 ? 20 : n.title.length)}',
        );
      }

      // Merge server data with optimistic updates and confirmed read notifications
      // If a notification was marked as read (optimistically or confirmed), preserve that state
      final mergedNotifications = notifications.map((serverNotification) {
        final notificationId = serverNotification.id.toString();

        // Check if this notification was confirmed as read (API call succeeded)
        if (_confirmedReadIds.contains(notificationId)) {
          // Always keep as read if we confirmed it via API
          if (!serverNotification.isRead) {
            debugPrint(
              'NotificationsProvider: Preserving confirmed read state for notification $notificationId (server may have stale data)',
            );
          }
          // Convert and force to read
          final converted = NotificationModel.fromJson(
            serverNotification.toJson(),
          );
          return NotificationModel(
            id: converted.id,
            title: converted.title,
            message: converted.message,
            type: converted.type,
            isRead: true, // Always true for confirmed read notifications
            createdAt: converted.createdAt,
            data: converted.data,
          );
        }

        // Check if this notification was optimistically marked as read
        if (_optimisticallyReadIds.contains(notificationId)) {
          // If server confirms it's read, remove from optimistic tracking and add to confirmed
          if (serverNotification.isRead) {
            debugPrint(
              'NotificationsProvider: Server confirmed notification $notificationId is read, moving to confirmed set',
            );
            _optimisticallyReadIds.remove(notificationId);
            _confirmedReadIds.add(notificationId);
            // Use server's confirmed read state
            return NotificationModel.fromJson(serverNotification.toJson());
          } else {
            // Server hasn't updated yet, preserve optimistic read state
            debugPrint(
              'NotificationsProvider: Preserving optimistic read state for notification $notificationId (server still says unread)',
            );
            // Convert using fromJson to handle type conversion properly, then override isRead
            final converted = NotificationModel.fromJson(
              serverNotification.toJson(),
            );
            return NotificationModel(
              id: converted.id,
              title: converted.title,
              message: converted.message,
              type: converted.type,
              isRead: true, // Force to read based on optimistic update
              createdAt: converted.createdAt,
              data: converted.data,
            );
          }
        }

        // Not in any tracking, use server state
        return NotificationModel.fromJson(serverNotification.toJson());
      }).toList();

      // Count unread notifications in the merged data
      final unreadCountInMergedData = mergedNotifications
          .where((n) => !n.isRead)
          .length;
      debugPrint(
        'NotificationsProvider: Unread count in merged data: $unreadCountInMergedData',
      );

      // Replace the entire list with merged data
      _notifications = mergedNotifications;
      _totalItems = mergedNotifications.length;

      debugPrint(
        'NotificationsProvider: Updated _notifications list with ${_notifications.length} items (preserved ${_optimisticallyReadIds.length} optimistic read states)',
      );

      // Update unread count based on merged data
      await refreshUnreadCount();

      // Verify the unread count matches
      final actualUnreadCount = _notifications.where((n) => !n.isRead).length;
      debugPrint(
        'NotificationsProvider: Actual unread count in _notifications: $actualUnreadCount',
      );

      notifyListeners();
      debugPrint(
        'NotificationsProvider: Refreshed ${mergedNotifications.length} notifications from server and notified listeners',
      );
    } catch (e, stackTrace) {
      debugPrint('NotificationsProvider: Error refreshing notifications: $e');
      debugPrint('NotificationsProvider: Stack trace: $stackTrace');
      // Re-throw to allow caller to handle the error
      rethrow;
    }
  }

  // Refresh unread count only
  Future<void> refreshUnreadCount() async {
    try {
      debugPrint('NotificationsProvider: Refreshing unread count...');
      _unreadCount = await _apiService.getUnreadNotificationsCount();
      debugPrint(
        'NotificationsProvider: Updated unread count to: $_unreadCount',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationsProvider: Error refreshing unread count: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead({String? search, String? type}) async {
    debugPrint('NotificationsProvider: markAllAsRead called');
    debugPrint('NotificationsProvider: Current unreadCount: $_unreadCount');
    debugPrint(
      'NotificationsProvider: Current notifications count: ${_notifications.length}',
    );

    try {
      await _apiService.markAllNotificationsAsRead();
      debugPrint('NotificationsProvider: API call successful');

      // Update local state - mark all notifications as read
      _notifications = _notifications.map((n) {
        return NotificationModel(
          id: n.id,
          title: n.title,
          message: n.message,
          type: n.type,
          isRead: true, // Mark all as read
          createdAt: n.createdAt,
          data: n.data,
        );
      }).toList();

      _unreadCount = 0;
      debugPrint(
        'NotificationsProvider: Updated unreadCount to: $_unreadCount',
      );
      debugPrint(
        'NotificationsProvider: Updated notifications count: ${_notifications.length}',
      );
      notifyListeners();
      debugPrint('NotificationsProvider: notifyListeners called');

      // Refresh notifications from server to ensure consistency
      // Pass current filters to maintain them
      await refreshNotifications(search: search, type: type);

      debugPrint(
        'Marked all notifications as read. Count: ${_notifications.length}',
      );
    } catch (e) {
      _setError(e.toString());
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      // Call the API to delete the notification from the server
      await _apiService.deleteNotification(int.parse(notificationId));

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
      // Refresh unread count to ensure accuracy
      await refreshUnreadCount();
    } catch (e) {
      _setError(e.toString());
      debugPrint('Error deleting notification $notificationId: $e');
    }
  }

  // Delete all notifications
  Future<void> deleteAllNotifications() async {
    try {
      // Call the API to delete all notifications
      await _apiService.deleteAllNotifications();

      // Clear local state
      _notifications.clear();
      _unreadCount = 0;
      notifyListeners();

      debugPrint('Successfully deleted all notifications');
      // Refresh unread count to ensure accuracy
      await refreshUnreadCount();
    } catch (e) {
      _setError(e.toString());
      debugPrint('Error deleting all notifications: $e');
    }
  }

  // Utility methods
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

  // Update token
  void setToken(String? token) {
    debugPrint(
      'NotificationsProvider: setToken called with token: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    if (token != null && token.isNotEmpty) {
      _apiService.setToken(token);
    }
  }
}
