import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/translations.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Defer loading notifications until after the first frame is built
    // This prevents setState() being called during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    final provider = Provider.of<DeliveryNotificationsProvider>(
      context,
      listen: false,
    );
    await provider.loadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppTranslations.t(context, 'notifications')),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          Consumer<DeliveryNotificationsProvider>(
            builder: (context, provider, child) {
              if (provider.notifications.isEmpty) {
                return IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadNotifications,
                );
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'delete_all') {
                    _deleteAllNotifications();
                  } else if (value == 'refresh') {
                    _loadNotifications();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh, size: 20),
                        SizedBox(width: 8),
                        Text('Refresh'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete All', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<DeliveryNotificationsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    provider.error!,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadNotifications,
                    child: Text(AppTranslations.t(context, 'retry')),
                  ),
                ],
              ),
            );
          }

          final urgentNotifications = provider.urgentNotifications;
          final recentNotifications = provider.recentNotifications;
          final unreadCount = provider.unreadCount;

          if (urgentNotifications.isEmpty && recentNotifications.isEmpty) {
            // Check if there's a mismatch between unread count and empty list
            if (unreadCount > 0) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_outlined,
                      size: 64,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No delivery notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'You have $unreadCount unread notification${unreadCount > 1 ? 's' : ''} that are not linked to delivery-related activities.',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadNotifications,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            }
            
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You are all caught up!',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadNotifications,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (urgentNotifications.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Urgent Notifications',
                      AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    ...urgentNotifications.map(
                      (notification) => _buildNotificationCard(
                        notification: notification,
                        title: notification['title'] ?? 'Urgent Notification',
                        subtitle: notification['message'] ?? 'No message',
                        time:
                            DateTime.tryParse(
                              notification['created_at'] ?? '',
                            ) ??
                            DateTime.now(),
                        type: NotificationType.urgent,
                        isRead: notification['is_read'] ?? false,
                        onTap: () => _showNotificationDetails(notification),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (recentNotifications.isNotEmpty) ...[
                    _buildSectionHeader(
                      'Recent Notifications',
                      AppColors.primary,
                    ),
                    const SizedBox(height: 12),
                    ...recentNotifications
                        .take(10)
                        .map(
                          (notification) => _buildNotificationCard(
                            notification: notification,
                            title: notification['title'] ?? 'Notification',
                            subtitle: notification['message'] ?? 'No message',
                            time:
                                DateTime.tryParse(
                                  notification['created_at'] ?? '',
                                ) ??
                                DateTime.now(),
                            type: NotificationType.info,
                            isRead: notification['is_read'] ?? false,
                            onTap: () => _showNotificationDetails(notification),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard({
    required Map<String, dynamic> notification,
    required String title,
    required String subtitle,
    required DateTime time,
    required NotificationType type,
    required VoidCallback onTap,
    bool isRead = false,
  }) {
    final theme = Theme.of(context);
    IconData icon;
    Color color;

    switch (type) {
      case NotificationType.urgent:
        icon = Icons.warning;
        color = AppColors.error;
        break;
      case NotificationType.info:
        icon = Icons.info_outline;
        color = AppColors.info;
        break;
      case NotificationType.success:
        icon = Icons.check_circle_outline;
        color = AppColors.success;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
            fontSize: 14,
            color: isRead
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isRead
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(time),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        onTap: onTap,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: theme.colorScheme.error,
              onPressed: () => _deleteNotification(notification),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification['title'] ?? 'Notification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification['message'] ?? 'No message'),
            const SizedBox(height: 8),
            Text('Type: ${notification['type'] ?? 'info'}'),
            Text(
              'Created: ${_formatTime(DateTime.tryParse(notification['created_at'] ?? '') ?? DateTime.now())}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (!(notification['is_read'] ?? false))
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Mark as read
                final provider = Provider.of<DeliveryNotificationsProvider>(
                  context,
                  listen: false,
                );
                provider.markAsRead(notification['id'].toString());
              },
              child: const Text('Mark as Read'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text(
          'Are you sure you want to delete this notification?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final provider = Provider.of<DeliveryNotificationsProvider>(
        context,
        listen: false,
      );
      final success = await provider.deleteNotification(
        notification['id'].toString(),
      );

      if (mounted) {
        if (success) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Notification deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Unable to delete notification. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAllNotifications() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Notifications'),
        content: const Text(
          'Are you sure you want to delete all notifications? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      final provider = Provider.of<DeliveryNotificationsProvider>(
        context,
        listen: false,
      );
      final success = await provider.deleteAllNotifications();

      if (mounted) {
        if (success) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('All notifications deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to delete notifications. Please try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

enum NotificationType { urgent, info, success }
