import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/localization/app_localizations.dart';
import '../providers/notifications_provider.dart';
import '../models/notification.dart' as notification_model;
import '../utils/notification_translator.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Defer loading until after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;
    final provider = context.read<NotificationsProvider>();
    await provider.loadNotifications();
    // Also refresh unread count to ensure badge is updated
    await provider.refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.notifications),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          Consumer<NotificationsProvider>(
            builder: (context, provider, child) {
              if (provider.notifications.isNotEmpty) {
                return TextButton(
                  onPressed: () => _markAllAsRead(),
                  child: Text(
                    localizations.markAllRead,
                    style: const TextStyle(color: AppColors.white),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.notifications.isEmpty) {
            return const Center(child: LoadingIndicator());
          }

          if (provider.errorMessage != null && provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.errorLoadingNotifications,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadNotifications,
                    child: Text(localizations.retry),
                  ),
                ],
              ),
            );
          }

          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.noNotifications,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.noNotificationsYet,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadNotifications,
                    child: Text(localizations.refreshButton),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notification = provider.notifications[index];
                return _buildNotificationCard(notification);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(notification_model.Notification notification) {
    final localizations = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _markAsRead(notification.id),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: notification.isRead
                ? AppColors.white
                : AppColors.primary.withValues(alpha: 0.05),
            border: notification.isRead
                ? null
                : Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getNotificationColor(
                    notification.type,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            NotificationTranslator.translateTitle(
                              notification.title,
                              localizations,
                            ),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NotificationTranslator.translateMessage(
                        notification.message,
                        localizations,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _formatDateTime(notification.createdAt, context),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const Spacer(),
                        // Delete button
                        IconButton(
                          onPressed: () => _deleteNotification(notification.id),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.textHint,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (notification.type != 'info')
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getNotificationColor(
                                  notification.type,
                                ).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _getNotificationTypeLabel(
                                  notification.type,
                                  context,
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: _getNotificationColor(
                                    notification.type,
                                  ),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      case 'info':
      default:
        return AppColors.primary;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'success':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning;
      case 'error':
        return Icons.error;
      case 'order':
        return Icons.shopping_bag;
      case 'borrow':
        return Icons.book;
      case 'delivery':
        return Icons.local_shipping;
      case 'info':
      default:
        return Icons.info;
    }
  }

  String _getNotificationTypeLabel(String type, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    switch (type.toLowerCase()) {
      case 'success':
        return localizations.notificationTypeSuccess;
      case 'warning':
        return localizations.notificationTypeWarning;
      case 'error':
        return localizations.notificationTypeError;
      case 'order':
        return localizations.notificationTypeOrder;
      case 'borrow':
        return localizations.notificationTypeBorrow;
      case 'delivery':
        return localizations.notificationTypeDelivery;
      case 'info':
      default:
        return localizations.notificationTypeInfo;
    }
  }

  String _formatDateTime(DateTime dateTime, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${localizations.daysAgo}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${localizations.hoursAgo}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${localizations.minutesAgo}';
    } else {
      return localizations.justNow;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    final provider = context.read<NotificationsProvider>();
    await provider.markAsRead(notificationId);
  }

  Future<void> _markAllAsRead() async {
    final provider = context.read<NotificationsProvider>();
    await provider.markAllAsRead();

    if (mounted) {
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.allNotificationsMarkedRead),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  Future<void> _deleteNotification(String notificationId) async {
    // Capture provider and context before async operation
    if (!mounted) return;
    final provider = context.read<NotificationsProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Show confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.deleteNotification),
          content: Text(localizations.confirmDeleteNotification),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(localizations.deleteButton),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      if (!mounted) return;
      await provider.deleteNotification(notificationId);

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(localizations.notificationDeletedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
