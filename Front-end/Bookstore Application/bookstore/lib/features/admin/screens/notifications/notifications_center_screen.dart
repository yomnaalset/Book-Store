import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../../admin/providers/notifications_provider.dart'
    as admin_notifications_provider;
import '../../../admin/models/notification_model.dart';
import '../../../admin/widgets/library_manager/admin_search_bar.dart';
import '../../../admin/widgets/empty_state.dart';
import 'package:readgo/features/auth/providers/auth_provider.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../notifications/utils/notification_translator.dart';
import '../../../../../core/utils/formatters.dart';

class NotificationsCenterScreen extends StatefulWidget {
  const NotificationsCenterScreen({super.key});

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  String? _selectedType;
  String _searchQuery = '';
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    // Load notifications when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNotifications();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    try {
      final provider = context
          .read<admin_notifications_provider.NotificationsProvider>();
      final authProvider = context.read<AuthProvider>();

      // Check if user is authenticated
      if (authProvider.token == null || authProvider.token!.isEmpty) {
        debugPrint('NotificationsCenter: No authentication token available');
        return;
      }

      debugPrint(
        'NotificationsCenter: Loading notifications with token: ${authProvider.token!.substring(0, 20)}...',
      );

      await provider.getNotifications(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        type: _selectedType,
      );

      // Also fetch the unread count when loading notifications
      await provider.refreshUnreadCount();
    } catch (e) {
      debugPrint('NotificationsCenter: Error loading notifications: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.errorLoadingNotificationsAdmin(e.toString()),
            ),
          ),
        );
      }
    }
  }

  void _onSearch(String query) {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // Set new timer for debounced search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = query;
      });
      _loadNotifications();
    });
  }

  void _onTypeFilterChanged(String? type) {
    setState(() {
      _selectedType = type;
    });
    _loadNotifications();
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) {
      debugPrint(
        'NotificationsCenter: Notification ${notification.id} is already read, skipping',
      );
      return;
    }

    try {
      debugPrint(
        'NotificationsCenter: Marking notification ${notification.id} as read',
      );
      final provider = context
          .read<admin_notifications_provider.NotificationsProvider>();

      // Pass current filters to maintain them when refreshing
      // The provider will handle optimistic UI update and server sync
      await provider.markAsRead(
        notification.id!,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        type: _selectedType,
      );

      debugPrint(
        'NotificationsCenter: Successfully marked notification ${notification.id} as read',
      );

      // Don't call _loadNotifications() here - the provider already handles refresh
      // and optimistic updates. This prevents overwriting the optimistic update.

      if (mounted) {
        try {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.notificationMarkedAsRead)),
          );
        } catch (e) {
          // Widget disposed, ignore
          debugPrint(
            'NotificationsCenter: Error showing snackbar (success): $e',
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationsCenter: Error marking notification as read: $e');
      if (mounted) {
        try {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        } catch (snackbarError) {
          // Widget disposed, ignore
          debugPrint(
            'NotificationsCenter: Error showing snackbar (error): $snackbarError',
          );
        }
      }
    }
  }

  Future<void> _markAllAsRead() async {
    debugPrint('NotificationsCenter: _markAllAsRead called');
    try {
      final provider = context
          .read<admin_notifications_provider.NotificationsProvider>();
      debugPrint(
        'NotificationsCenter: Provider unreadCount before: ${provider.unreadCount}',
      );
      // Pass current filters to maintain them when refreshing
      await provider.markAllAsRead(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        type: _selectedType,
      );
      debugPrint(
        'NotificationsCenter: Provider unreadCount after: ${provider.unreadCount}',
      );

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.allNotificationsMarkedAsRead)),
        );
      }
    } catch (e) {
      debugPrint('NotificationsCenter: Error in _markAllAsRead: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _deleteNotification(NotificationModel notification) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteNotification),
        content: Text(localizations.areYouSureDeleteNotification),
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
      try {
        if (!mounted) return;
        final provider = context
            .read<admin_notifications_provider.NotificationsProvider>();
        await provider.deleteNotification(notification.id!);

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.notificationDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
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
      try {
        if (!mounted) return;
        final provider = context
            .read<admin_notifications_provider.NotificationsProvider>();
        await provider.deleteAllNotifications();

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.allNotificationsDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.unableToDeleteNotifications),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.notifications),
        actions: [
          Consumer<admin_notifications_provider.NotificationsProvider>(
            builder: (context, provider, child) {
              if (provider.notifications.isEmpty) {
                return IconButton(
                  onPressed: () => _loadNotifications(),
                  icon: const Icon(Icons.refresh),
                );
              }
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'mark_all_read') {
                    _markAllAsRead();
                  } else if (value == 'delete_all') {
                    _deleteAllNotifications();
                  } else if (value == 'refresh') {
                    _loadNotifications();
                  }
                },
                itemBuilder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return [
                    if (provider.unreadCount > 0)
                      PopupMenuItem(
                        value: 'mark_all_read',
                        child: Row(
                          children: [
                            const Icon(Icons.done_all, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              localizations.markAllReadWithCount(
                                provider.unreadCount,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  ];
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return AdminSearchBar(
                      hintText: localizations.searchNotificationsPlaceholder,
                      onChanged: _onSearch,
                    );
                  },
                ),
                const SizedBox(height: 16),
                // Type Filter
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          '${localizations.type}:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        FilterChip(
                          label: Text(localizations.all),
                          selected: _selectedType == null,
                          onSelected: (_) => _onTypeFilterChanged(null),
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          checkmarkColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: _selectedType == null
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        FilterChip(
                          label: Text(localizations.order),
                          selected: _selectedType == 'new_order',
                          onSelected: (_) => _onTypeFilterChanged('new_order'),
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          checkmarkColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: _selectedType == 'new_order'
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        FilterChip(
                          label: Text(localizations.borrowing),
                          selected: _selectedType == 'borrow_request',
                          onSelected: (_) =>
                              _onTypeFilterChanged('borrow_request'),
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          checkmarkColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: _selectedType == 'borrow_request'
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        FilterChip(
                          label: Text(localizations.delivery),
                          selected: _selectedType == 'delivery_task_created',
                          onSelected: (_) =>
                              _onTypeFilterChanged('delivery_task_created'),
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          checkmarkColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: _selectedType == 'delivery_task_created'
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        FilterChip(
                          label: Text(localizations.complaint),
                          selected: _selectedType == 'new_complaint',
                          onSelected: (_) =>
                              _onTypeFilterChanged('new_complaint'),
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          checkmarkColor: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: _selectedType == 'new_complaint'
                                ? Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Notifications List
          Expanded(
            child:
                Consumer2<
                  AuthProvider,
                  admin_notifications_provider.NotificationsProvider
                >(
                  builder: (context, authProvider, provider, child) {
                    if (provider.isLoading && provider.notifications.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (provider.error != null &&
                        provider.notifications.isEmpty) {
                      return Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${localizations.error}: ${provider.error}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadNotifications,
                                  child: Text(localizations.retry),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }

                    if (provider.notifications.isEmpty) {
                      return Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return EmptyState(
                            title: localizations.noNotifications,
                            message: localizations.noNotificationsFound,
                            icon: Icons.notifications_none,
                            action: ElevatedButton(
                              onPressed: _loadNotifications,
                              child: Text(localizations.refresh),
                            ),
                          );
                        },
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: provider.notifications.length,
                      itemBuilder: (context, index) {
                        final notification = provider.notifications[index];
                        return _buildNotificationCard(notification);
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    // Use stable key based only on ID to prevent widget recreation
    // This ensures only the color changes, not the shape or structure
    return Card(
      key: ValueKey('notification_${notification.id}'),
      margin: const EdgeInsets.only(bottom: 8.0),
      // Only change the color, keep all other properties the same
      color: notification.isRead
          ? Theme.of(context).colorScheme.surface
          : Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: 0.3),
      // Ensure consistent shape and elevation
      elevation: 1.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getNotificationColor(notification.type),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              NotificationTranslator.translateTitle(
                notification.title,
                localizations,
              ),
              style: TextStyle(
                fontWeight: notification.isRead
                    ? FontWeight.normal
                    : FontWeight.bold,
              ),
            );
          },
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  NotificationTranslator.translateMessage(
                    notification.message,
                    localizations,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                );
              },
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Row(
                  children: [
                    Flexible(
                      child: Text(
                        _formatDate(notification.createdAt, localizations),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getNotificationColor(
                            notification.type,
                          ).withValues(alpha: 26),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          notification.type,
                          style: TextStyle(
                            fontSize: 10,
                            color: _getNotificationColor(notification.type),
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.isRead)
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Flexible(
                    child: TextButton(
                      onPressed: () => _markAsRead(notification),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        localizations.markAsRead,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                },
              ),
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    _deleteNotification(notification);
                    break;
                }
              },
              itemBuilder: (context) {
                final localizations = AppLocalizations.of(context);
                return [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(localizations.delete),
                  ),
                ];
              },
            ),
          ],
        ),
        onTap: () {
          if (!notification.isRead) {
            _markAsRead(notification);
          }
          // Handle notification tap based on type
          _handleNotificationTap(notification);
        },
      ),
    );
  }

  Color _getNotificationColor(String type) {
    switch (type.toLowerCase()) {
      case 'system_alert':
        return Colors.blue;
      case 'new_order':
        return Colors.orange;
      case 'borrow_request':
      case 'borrow_approved':
      case 'borrow_rejected':
        return Colors.green;
      case 'delivery_task_created':
      case 'delivery_started':
      case 'delivery_completed':
        return Colors.purple;
      case 'new_complaint':
      case 'complaint_resolved':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(String type) {
    switch (type.toLowerCase()) {
      case 'system_alert':
        return Icons.settings;
      case 'new_order':
        return Icons.shopping_cart;
      case 'borrow_request':
      case 'borrow_approved':
      case 'borrow_rejected':
        return Icons.book;
      case 'delivery_task_created':
      case 'delivery_started':
      case 'delivery_completed':
        return Icons.local_shipping;
      case 'new_complaint':
      case 'complaint_resolved':
        return Icons.report_problem;
      default:
        return Icons.notifications;
    }
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Handle navigation based on notification type and data
    // This would typically navigate to the relevant screen
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Notification: ${notification.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      // Widget disposed, ignore
      debugPrint(
        'NotificationsCenter: Error showing snackbar in _handleNotificationTap: $e',
      );
    }
  }

  String _formatDate(DateTime date, AppLocalizations localizations) {
    return Formatters.formatDateTime(date);
  }
}
