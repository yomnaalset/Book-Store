import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notification.dart';

class NotificationsApiService {
  final String baseUrl;
  final Map<String, String> Function() getHeaders;

  NotificationsApiService({required this.baseUrl, required this.getHeaders});

  // Get notifications
  Future<List<Notification>> getNotifications({
    int page = 1,
    int limit = 20,
    String? search,
    String? type,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        if (search != null && search.isNotEmpty) 'search': search,
        if (type != null && type.isNotEmpty) 'type': type,
      };

      final uri = Uri.parse(
        '$baseUrl/notifications/',
      ).replace(queryParameters: queryParams);

      final response = await http.get(uri, headers: getHeaders());

      if (response.statusCode == 200) {
        final List<dynamic> notificationsJson = jsonDecode(response.body);
        return notificationsJson
            .map((json) => Notification.fromJson(json))
            .toList();
      } else {
        debugPrint('Failed to get notifications: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception('Failed to get notifications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting notifications: $e');
      rethrow;
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/notifications/$notificationId/mark_as_read/'),
        headers: getHeaders(),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Failed to mark notification as read: ${response.statusCode}',
        );
        debugPrint('Response body: ${response.body}');
        throw Exception(
          'Failed to mark notification as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/notifications/mark_all_as_read/'),
        headers: getHeaders(),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Failed to mark all notifications as read: ${response.statusCode}',
        );
        debugPrint('Response body: ${response.body}');
        throw Exception(
          'Failed to mark all notifications as read: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/notifications/$notificationId/'),
        headers: getHeaders(),
      );

      if (response.statusCode != 204) {
        debugPrint('Failed to delete notification: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception(
          'Failed to delete notification: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
      rethrow;
    }
  }

  // Get unread count
  Future<int> getUnreadCount() async {
    try {
      final headers = getHeaders();
      final authHeader = headers['Authorization'] ?? '';
      
      // Only make API call if we have a valid Bearer token
      if (authHeader.isEmpty || !authHeader.startsWith('Bearer ') || authHeader.length < 20) {
        debugPrint('NotificationsApiService: Skipping unread count - no valid token');
        return 0;
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/notifications/unread_count/'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unread_count'] ?? 0;
      } else if (response.statusCode == 401) {
        // Unauthorized - user is not authenticated
        debugPrint('NotificationsApiService: Unauthorized - user not authenticated');
        return 0;
      } else {
        debugPrint('Failed to get unread count: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        throw Exception('Failed to get unread count: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      // Return 0 instead of rethrowing to avoid breaking the UI
      return 0;
    }
  }
}
