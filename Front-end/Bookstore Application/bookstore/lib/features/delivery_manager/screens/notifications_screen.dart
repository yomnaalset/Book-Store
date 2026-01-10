import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../../notifications/utils/notification_translator.dart';
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
        title: Text(
          AppLocalizations.of(context).notifications,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Consumer<DeliveryNotificationsProvider>(
            builder: (context, provider, child) {
              final localizations = AppLocalizations.of(context);
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
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        const Icon(Icons.refresh, size: 20),
                        const SizedBox(width: 8),
                        Text(localizations.refresh),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete_all',
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          localizations.deleteAll,
                          style: const TextStyle(color: Colors.red),
                        ),
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
                    child: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            );
          }

          final urgentNotifications = provider.urgentNotifications;
          final allNotifications = provider.notifications;
          final unreadCount = provider.unreadCount;

          // Show all notifications if available, otherwise check urgent/recent
          if (allNotifications.isEmpty) {
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
                      AppLocalizations.of(context).noDeliveryNotifications,
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
                        AppLocalizations.of(
                          context,
                        ).unreadNotificationsCount(unreadCount),
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
                      label: Text(AppLocalizations.of(context).refresh),
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
                    AppLocalizations.of(context).noNotifications,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).youAreAllCaughtUp,
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
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return _buildSectionHeader(
                          localizations.urgentNotifications,
                          AppColors.error,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ...urgentNotifications.map((notification) {
                      final localizations = AppLocalizations.of(context);
                      final originalTitle = notification['title'] ?? '';
                      final originalMessage = notification['message'] ?? '';
                      return _buildNotificationCard(
                        notification: notification,
                        title: NotificationTranslator.translateTitle(
                          originalTitle,
                          localizations,
                        ),
                        subtitle: NotificationTranslator.translateMessage(
                          originalMessage,
                          localizations,
                        ),
                        time:
                            DateTime.tryParse(
                              notification['created_at'] ?? '',
                            ) ??
                            DateTime.now(),
                        type: NotificationType.urgent,
                        isRead: notification['is_read'] ?? false,
                        onTap: () => _showNotificationDetails(notification),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                  // Show all notifications (not just recent ones)
                  if (allNotifications.isNotEmpty) ...[
                    if (urgentNotifications.isNotEmpty)
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildSectionHeader(
                            localizations.recentNotifications,
                            AppColors.primary,
                          );
                        },
                      )
                    else
                      const SizedBox.shrink(),
                    if (urgentNotifications.isNotEmpty)
                      const SizedBox(height: 12),
                    // Show all notifications, excluding urgent ones that were already shown
                    ...allNotifications
                        .where((notification) {
                          // Exclude urgent notifications that were already shown
                          return !urgentNotifications.contains(notification);
                        })
                        .map((notification) {
                          final localizations = AppLocalizations.of(context);
                          final originalTitle = notification['title'] ?? '';
                          final originalMessage = notification['message'] ?? '';
                          // Determine notification type based on priority
                          final priority = notification['priority'] ?? '';
                          final isUrgent =
                              priority == 'high' || priority == 'urgent';
                          return _buildNotificationCard(
                            notification: notification,
                            title: NotificationTranslator.translateTitle(
                              originalTitle,
                              localizations,
                            ),
                            subtitle: NotificationTranslator.translateMessage(
                              originalMessage,
                              localizations,
                            ),
                            time:
                                DateTime.tryParse(
                                  notification['created_at'] ?? '',
                                ) ??
                                DateTime.now(),
                            type: isUrgent
                                ? NotificationType.urgent
                                : NotificationType.info,
                            isRead: notification['is_read'] ?? false,
                            onTap: () => _showNotificationDetails(notification),
                          );
                        }),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
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
                _formatTime(time, context),
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
      ),
    );
  }

  String _formatTime(DateTime time, BuildContext context) {
    final now = DateTime.now();
    final difference = now.difference(time);
    final localizations = AppLocalizations.of(context);

    if (difference.inDays > 0) {
      return localizations.dAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return localizations.hAgo(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return localizations.mAgo(difference.inMinutes);
    } else {
      return localizations.justNow;
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    final localizations = AppLocalizations.of(context);
    final originalTitle = notification['title'] ?? '';
    final originalMessage = notification['message'] ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          NotificationTranslator.translateTitle(originalTitle, localizations),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              NotificationTranslator.translateMessage(
                originalMessage,
                localizations,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${localizations.typeLabel} ${notification['type'] ?? 'info'}',
            ),
            Text(
              '${localizations.createdLabel} ${_formatTime(DateTime.tryParse(notification['created_at'] ?? '') ?? DateTime.now(), context)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.close),
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
              child: Text(localizations.markAsRead),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteNotification),
        content: Text(localizations.confirmDeleteNotification),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.delete),
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
        final localizations = AppLocalizations.of(context);
        if (success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(localizations.notificationDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(localizations.unableToDeleteNotification),
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

    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteAllNotifications),
        content: Text(localizations.areYouSureDeleteAllNotifications),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.deleteAll),
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
        final localizations = AppLocalizations.of(context);
        if (success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(localizations.allNotificationsDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(localizations.unableToDeleteNotifications),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

enum NotificationType { urgent, info, success }
