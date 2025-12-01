import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../../core/localization/app_localizations.dart';
import '../../../core/translations.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/delivery_tasks_provider.dart';
import '../providers/notifications_provider.dart';
import '../../../features/delivery_manager/providers/delivery_status_provider.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../widgets/dashboard_stats_card.dart';
import '../widgets/quick_action_button.dart';
import '../widgets/task_list_tile.dart';
import '../widgets/availability_toggle.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'purchase_orders_screen.dart';
import 'borrow_requests_screen.dart';
import 'return_requests_screen.dart';
import 'all_orders_screen.dart';

class DeliveryManagerDashboardScreen extends StatefulWidget {
  const DeliveryManagerDashboardScreen({super.key});

  @override
  State<DeliveryManagerDashboardScreen> createState() =>
      _DeliveryManagerDashboardScreenState();
}

class _DeliveryManagerDashboardScreenState
    extends State<DeliveryManagerDashboardScreen>
    with WidgetsBindingObserver {
  Timer? _statusRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeProviders();
    _startPeriodicStatusRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh status when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  /// Start periodic status refresh (every 1 minute)
  void _startPeriodicStatusRefresh() {
    _statusRefreshTimer?.cancel();
    _statusRefreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _refreshStatus();
      } else {
        timer.cancel();
      }
    });
  }

  /// Refresh delivery manager status from server
  Future<void> _refreshStatus() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.userRole != 'delivery_admin') return;

    final statusProvider = Provider.of<DeliveryStatusProvider>(
      context,
      listen: false,
    );

    try {
      await statusProvider.loadCurrentStatus();
      debugPrint('DeliveryManagerDashboard: Status refreshed periodically');
    } catch (e) {
      debugPrint('DeliveryManagerDashboard: Error refreshing status: $e');
    }
  }

  Future<void> _initializeProviders() async {
    // Check if user has delivery manager role before initializing
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.userRole != 'delivery_admin') {
      debugPrint(
        'DeliveryManagerDashboard: User role is ${authProvider.userRole}, not delivery_admin. Skipping initialization.',
      );
      return;
    }

    final statusProvider = Provider.of<DeliveryStatusProvider>(
      context,
      listen: false,
    );
    final tasksProvider = Provider.of<DeliveryTasksProvider>(
      context,
      listen: false,
    );
    final notificationsProvider = Provider.of<DeliveryNotificationsProvider>(
      context,
      listen: false,
    );

    // Set authentication token for status provider
    // Try multiple methods to get the token
    String? token = authProvider.token ?? authProvider.getCurrentToken();

    // If still no token, wait a bit for token to load from storage
    if (token == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      token = authProvider.token ?? authProvider.getCurrentToken();
    }

    if (token != null && token.isNotEmpty) {
      statusProvider.setToken(token);
      // Clear any existing errors now that we have a token
      statusProvider.clearError();
      debugPrint('DeliveryManagerDashboard: Token set for status provider');
    } else {
      debugPrint(
        'DeliveryManagerDashboard: Warning - No token available. User may need to login again.',
      );
      // Don't proceed with loading status if no token
      return;
    }

    // Load status, tasks, and notifications for dashboard statistics
    await Future.wait([
      statusProvider.loadCurrentStatus(),
      tasksProvider.loadTasks(),
      notificationsProvider.refreshUnreadCount(), // Load unread count for badge
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).deliveryManager),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          // Notifications with Badge
          Consumer<DeliveryNotificationsProvider>(
            builder: (context, notificationsProvider, child) {
              return badges.Badge(
                badgeContent: Text(
                  '${notificationsProvider.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                showBadge: notificationsProvider.unreadCount > 0,
                badgeStyle: const badges.BadgeStyle(
                  badgeColor: Colors.red,
                  padding: EdgeInsets.all(4),
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final tasksProvider = Provider.of<DeliveryTasksProvider>(
            context,
            listen: false,
          );
          final statusProvider = Provider.of<DeliveryStatusProvider>(
            context,
            listen: false,
          );
          final notificationsProvider =
              Provider.of<DeliveryNotificationsProvider>(
                context,
                listen: false,
              );
          await Future.wait([
            tasksProvider.loadTasks(),
            statusProvider.loadCurrentStatus(),
            notificationsProvider.refreshUnreadCount(),
          ]);
          debugPrint('Dashboard: Refreshed tasks - Assigned: ${tasksProvider.assignedTasksCount}, Completed: ${tasksProvider.completedTasksCount}, In Progress: ${tasksProvider.inTransitTasksCount}');
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeSection(),
              const SizedBox(height: 24),

              // Availability Toggle
              _buildAvailabilitySection(),
              const SizedBox(height: 24),

              // Dashboard Stats
              _buildDashboardStats(),
              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions(),
              const SizedBox(height: 24),

              // Urgent Tasks
              _buildUrgentTasks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Consumer<DeliveryTasksProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).welcome,
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${provider.assignedTasksCount} ${AppTranslations.t(context, 'assigned_tasks')}',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 16,
                        // opacity: 0.9,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.local_shipping_outlined,
                color: theme.colorScheme.onPrimary,
                size: 48,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailabilitySection() {
    return Consumer<DeliveryStatusProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTranslations.t(context, 'availability'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                AvailabilityToggle(
                  currentStatus: provider.currentStatus,
                  canChangeManually: provider.canChangeManually,
                  onStatusChanged: (status) async {
                    // Show loading indicator
                    final scaffoldMessenger = ScaffoldMessenger.of(context);

                    // Use the new unified status provider
                    final success = await provider.updateStatus(status);

                    if (!mounted) return;

                    if (success) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Status updated to ${status == 'online' ? 'Online' : 'Offline'}',
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    } else if (provider.errorMessage != null) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(
                          content: Text(provider.errorMessage!),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardStats() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTranslations.t(context, 'today_stats'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Consumer<DeliveryTasksProvider>(
          builder: (context, provider, child) {
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                DashboardStatsCard(
                  title: AppTranslations.t(context, 'assigned_tasks'),
                  value: provider.assignedTasksCount.toString(),
                  icon: Icons.assignment_outlined,
                  color: AppColors.warning,
                ),
                DashboardStatsCard(
                  title: AppTranslations.t(context, 'completed_tasks'),
                  value: provider.completedTasksCount.toString(),
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                ),
                DashboardStatsCard(
                  title: AppTranslations.t(context, 'in_progress_tasks'),
                  value: provider.inTransitTasksCount.toString(),
                  icon: Icons.local_shipping_outlined,
                  color: AppColors.info,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppTranslations.t(context, 'quick_actions'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                title: AppLocalizations.of(context).purchaseOrders,
                icon: Icons.shopping_cart_outlined,
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PurchaseOrdersScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                title: AppLocalizations.of(context).borrowRequests,
                icon: Icons.library_books_outlined,
                color: AppColors.success,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BorrowRequestsScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: QuickActionButton(
                title: AppLocalizations.of(context).returnRequests,
                icon: Icons.undo_outlined,
                color: AppColors.warning,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReturnRequestsScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QuickActionButton(
                title: AppTranslations.t(context, 'all_requests'),
                icon: Icons.list_outlined,
                color: AppColors.info,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AllOrdersScreen(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUrgentTasks() {
    return Consumer<DeliveryTasksProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        final urgentTasks = provider.getUrgentTasks();

        if (urgentTasks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.t(context, 'urgent_tasks'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            ...urgentTasks.take(3).map((task) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TaskListTile(
                      task: task,
                      isUrgent: true,
                      onTap: () {
                        // Navigate to task details
                        // Navigator.push(context, MaterialPageRoute(...));
                      },
                    ),
                  );
                }).toList()
                as List<Widget>,
          ],
        );
      },
    );
  }
}
