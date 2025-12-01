import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notification_model.dart';

class NotificationsService {
  final String baseUrl;
  final Map<String, String> headers;
  String? _errorMessage;

  NotificationsService({
    required this.baseUrl,
    this.headers = const {'Content-Type': 'application/json'},
  });

  String? get errorMessage => _errorMessage;

  // Get notifications
  Future<List<NotificationModel>> getNotifications({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    _clearError();

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (unreadOnly) 'unread_only': 'true',
      };

      final uri = Uri.parse(
        '$baseUrl/notifications/',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> notificationsJson = jsonDecode(response.body);
        return notificationsJson
            .map((json) => NotificationModel.fromJson(json))
            .toList();
      }

      _setError('Failed to load notifications');
      return [];
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('NotificationsService: Error getting notifications: $e');
      return [];
    }
  }

  // Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    _clearError();

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/notifications/$notificationId/mark_as_read/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      }

      _setError('Failed to mark notification as read');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint(
        'NotificationsService: Error marking notification as read: $e',
      );
      return false;
    }
  }

  // Mark all notifications as read
  Future<bool> markAllAsRead() async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/mark_all_as_read/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return true;
      }

      _setError('Failed to mark all notifications as read');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint(
        'NotificationsService: Error marking all notifications as read: $e',
      );
      return false;
    }
  }

  // Delete notification
  Future<bool> deleteNotification(String notificationId) async {
    _clearError();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId/'),
        headers: headers,
      );

      if (response.statusCode == 204) {
        return true;
      }

      _setError('Failed to delete notification');
      return false;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('NotificationsService: Error deleting notification: $e');
      return false;
    }
  }

  // Get unread count
  Future<int> getUnreadCount() async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread_count/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread_count'] ?? 0;
      }

      _setError('Failed to get unread count');
      return 0;
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('NotificationsService: Error getting unread count: $e');
      return 0;
    }
  }

  // Private helper methods
  void _setError(String error) {
    _errorMessage = error;
  }

  void _clearError() {
    _errorMessage = null;
  }
}
