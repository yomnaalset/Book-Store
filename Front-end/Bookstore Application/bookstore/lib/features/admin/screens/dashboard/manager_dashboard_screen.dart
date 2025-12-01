import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/notifications_provider.dart'
    as admin_notifications_provider;

class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
      // Removed automatic timer - notifications will only refresh when user clicks the bell
    });
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final notificationsProvider = context
          .read<admin_notifications_provider.NotificationsProvider>();

      if (authProvider.token != null && mounted) {
        await notificationsProvider.refreshUnreadCount();
      }
    } catch (e) {
      debugPrint('Error refreshing unread count: $e');
    }
  }

  Future<void> _initializeNotifications() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final notificationsProvider = context
          .read<admin_notifications_provider.NotificationsProvider>();

      if (authProvider.token != null) {
        notificationsProvider.setToken(authProvider.token);
        // Only refresh unread count, don't load full notifications
        await notificationsProvider.refreshUnreadCount();
      }
    } catch (e) {
      debugPrint('Error initializing notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          Consumer<admin_notifications_provider.NotificationsProvider>(
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
                  icon: const Icon(Icons.notifications),
                  onPressed: () async {
                    // Refresh notifications before navigating
                    await _refreshUnreadCount();
                    if (context.mounted) {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.managerNotifications,
                      );
                    }
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.managerSettings);
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, AppRoutes.managerProfile);
                },
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        child: Icon(Icons.person, size: 30),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Welcome, ${authProvider.user?.firstName ?? 'Manager'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        authProvider.user?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Tap to view profile',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Dashboard'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Personal Profile'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerProfile);
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_books),
              title: const Text('Library Management'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerLibrary);
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Categories'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerCategories);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Authors'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerAuthors);
              },
            ),
            ListTile(
              leading: const Icon(Icons.book),
              title: const Text('Books'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerBooks);
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_online),
              title: const Text('Borrowing'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerBorrows);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_return),
              title: const Text('Return Requests'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminReturnRequests);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Orders'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerOrders);
              },
            ),
            ListTile(
              leading: const Icon(Icons.discount),
              title: const Text('Discounts'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminDiscounts);
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: const Text('Announcements'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerAds);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem),
              title: const Text('Complaints'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerComplaints);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text('Reports'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerReports);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog(authProvider);
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildQuickActionCard(
                  context,
                  'Library Management',
                  Icons.library_books,
                  Colors.blue,
                  () => Navigator.pushNamed(context, AppRoutes.managerLibrary),
                ),
                _buildQuickActionCard(
                  context,
                  'Books',
                  Icons.book,
                  Colors.green,
                  () => Navigator.pushNamed(context, AppRoutes.managerBooks),
                ),
                _buildQuickActionCard(
                  context,
                  'Borrowing',
                  Icons.book_online,
                  Colors.orange,
                  () => Navigator.pushNamed(context, AppRoutes.managerBorrows),
                ),
                _buildQuickActionCard(
                  context,
                  'Orders',
                  Icons.shopping_cart,
                  Colors.purple,
                  () => Navigator.pushNamed(context, AppRoutes.managerOrders),
                ),
                _buildQuickActionCard(
                  context,
                  'Return Requests',
                  Icons.assignment_return,
                  Colors.teal,
                  () => Navigator.pushNamed(
                    context,
                    AppRoutes.adminReturnRequests,
                  ),
                ),
              ],
            ),
            // Recent Activity section removed - will be implemented with real data later
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(AuthProvider authProvider) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Sign Out',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _performLogout(authProvider);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Sign Out',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout(AuthProvider authProvider) async {
    try {
      await authProvider.logout();

      if (mounted) {
        AuthService.clearProvidersTokens(context);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
