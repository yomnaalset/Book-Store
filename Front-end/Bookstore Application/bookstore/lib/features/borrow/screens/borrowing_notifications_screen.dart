import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../notifications/models/notification.dart' as notification_model;
import '../../notifications/providers/notifications_provider.dart';
import '../../auth/providers/auth_provider.dart';

class BorrowingNotificationsScreen extends StatefulWidget {
  const BorrowingNotificationsScreen({super.key});

  @override
  State<BorrowingNotificationsScreen> createState() =>
      _BorrowingNotificationsScreenState();
}

class _BorrowingNotificationsScreenState
    extends State<BorrowingNotificationsScreen> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  void _loadNotifications() {
    final provider = Provider.of<NotificationsProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token != null) {
      provider.setToken(authProvider.token!);
      provider.loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Borrowing Notifications',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: PopupMenuButton<String>(
              onSelected: (value) {
                setState(() {
                  _selectedFilter = value;
                });
                _filterNotifications();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'all',
                  child: Text('All Notifications'),
                ),
                const PopupMenuItem(
                  value: 'borrow_request',
                  child: Text('Borrow Requests'),
                ),
                const PopupMenuItem(
                  value: 'borrow_approved',
                  child: Text('Approvals'),
                ),
                const PopupMenuItem(
                  value: 'delivery_task_created',
                  child: Text('Delivery Tasks'),
                ),
                const PopupMenuItem(
                  value: 'return_reminder',
                  child: Text('Return Reminders'),
                ),
                const PopupMenuItem(
                  value: 'return_confirmed',
                  child: Text('Return Confirmations'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const LoadingIndicator();
          }

          final filteredNotifications = _getFilteredNotifications(
            provider.notifications,
          );

          if (filteredNotifications.isEmpty) {
            return EmptyState(
              message: _getEmptyMessage(),
              icon: Icons.notifications_none,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            itemCount: filteredNotifications.length,
            itemBuilder: (context, index) {
              final notification = filteredNotifications[index];
              return _buildNotificationCard(notification, provider);
            },
          );
        },
      ),
    );
  }

  List<notification_model.Notification> _getFilteredNotifications(
    List<notification_model.Notification> notifications,
  ) {
    if (_selectedFilter == 'all') {
      return notifications.where((n) => _isBorrowingRelated(n)).toList();
    }

    return notifications
        .where((n) => _isBorrowingRelated(n) && n.type == _selectedFilter)
        .toList();
  }

  bool _isBorrowingRelated(notification_model.Notification notification) {
    final borrowingTypes = [
      'borrow_request',
      'borrow_approved',
      'borrow_rejected',
      'delivery_task_created',
      'delivery_started',
      'delivery_completed',
      'return_reminder',
      'return_task_created',
      'return_confirmed',
      'book_returned',
      'overdue_fine',
    ];

    return borrowingTypes.contains(notification.type);
  }

  String _getEmptyMessage() {
    switch (_selectedFilter) {
      case 'borrow_request':
        return 'No borrow request notifications';
      case 'borrow_approved':
        return 'No approval notifications';
      case 'delivery_task_created':
        return 'No delivery task notifications';
      case 'return_reminder':
        return 'No return reminder notifications';
      case 'return_confirmed':
        return 'No return confirmation notifications';
      default:
        return 'No borrowing notifications';
    }
  }

  void _filterNotifications() {
    // Trigger rebuild with filtered notifications
    setState(() {});
  }

  Widget _buildNotificationCard(
    notification_model.Notification notification,
    NotificationsProvider provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: InkWell(
        onTap: () => _markAsRead(notification, provider),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: AppDimensions.fontSizeL,
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                            color: notification.isRead
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingS),
                        Text(
                          notification.message,
                          style: TextStyle(
                            fontSize: AppDimensions.fontSizeM,
                            color: notification.isRead
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
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
              const SizedBox(height: AppDimensions.spacingS),
              Row(
                children: [
                  Icon(
                    _getNotificationIcon(notification.type),
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    _getNotificationTypeText(notification.type),
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeS,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(notification.createdAt),
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeS,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'borrow_request':
        return Icons.book;
      case 'borrow_approved':
        return Icons.check_circle;
      case 'borrow_rejected':
        return Icons.cancel;
      case 'delivery_task_created':
        return Icons.local_shipping;
      case 'delivery_started':
        return Icons.directions_car;
      case 'delivery_completed':
        return Icons.done_all;
      case 'return_reminder':
        return Icons.schedule;
      case 'return_task_created':
        return Icons.keyboard_return;
      case 'return_confirmed':
        return Icons.check_circle_outline;
      case 'book_returned':
        return Icons.library_books;
      case 'overdue_fine':
        return Icons.warning;
      default:
        return Icons.notifications;
    }
  }

  String _getNotificationTypeText(String type) {
    switch (type) {
      case 'borrow_request':
        return 'New Request';
      case 'borrow_approved':
        return 'Request Approved';
      case 'borrow_rejected':
        return 'Request Rejected';
      case 'delivery_task_created':
        return 'Delivery Task';
      case 'delivery_started':
        return 'Delivery Started';
      case 'delivery_completed':
        return 'Delivery Completed';
      case 'return_reminder':
        return 'Return Reminder';
      case 'return_task_created':
        return 'Return Task';
      case 'return_confirmed':
        return 'Return Confirmed';
      case 'book_returned':
        return 'Book Returned';
      case 'overdue_fine':
        return 'Overdue Fine';
      default:
        return 'Notification';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

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

  void _markAsRead(
    notification_model.Notification notification,
    NotificationsProvider provider,
  ) async {
    if (!notification.isRead) {
      await provider.markAsRead(notification.id);
    }
  }
}
