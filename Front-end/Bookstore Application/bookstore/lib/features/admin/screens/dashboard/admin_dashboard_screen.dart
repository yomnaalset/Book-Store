import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/notifications_provider.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.managerDashboard),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () async {
                  // Only fetch notifications when user clicks the bell
                  final notificationsProvider = context
                      .read<NotificationsProvider>();
                  await notificationsProvider.refreshUnreadCount();

                  if (context.mounted) {
                    Navigator.pushNamed(context, AppRoutes.adminNotifications);
                  }
                },
              ),
              // Show badge only if there are unread notifications
              // The unread count will be fetched when the bell is clicked
              Consumer<NotificationsProvider>(
                builder: (context, notificationsProvider, child) {
                  if (notificationsProvider.unreadCount > 0) {
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${notificationsProvider.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.adminSettings);
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
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      child: Icon(Icons.admin_panel_settings, size: 25),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      localizations.welcomeManager(
                        authProvider.user?.firstName ?? localizations.admin,
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      authProvider.user?.email ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: Text(localizations.dashboard),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.library_books),
              title: Text(localizations.books),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminBooks);
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: Text(localizations.categories),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminCategories);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(localizations.authors),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminAuthors);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: Text(localizations.userLabel),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminUsers);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: Text(localizations.orders),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminOrders);
              },
            ),
            ListTile(
              leading: const Icon(Icons.book_online),
              title: Text(localizations.borrowings),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.libraryBorrowing);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment_return),
              title: Text(localizations.returnRequests),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminReturnRequests);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: Text(localizations.deliveries),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.libraryDelivery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.discount),
              title: Text(localizations.discounts),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminDiscounts);
              },
            ),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: Text(localizations.advertisements),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminAds);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem),
              title: Text(localizations.complaints),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminComplaints);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: Text(localizations.reports),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.adminReports);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: Text(
                localizations.signOut,
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context); // Close drawer first
                _showLogoutDialog(context, authProvider, localizations);
              },
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              localizations.quickActions,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  localizations.borrowings,
                  Icons.book_online,
                  Colors.orange,
                  () =>
                      Navigator.pushNamed(context, AppRoutes.libraryBorrowing),
                ),
                _buildQuickActionCard(
                  context,
                  localizations.orders,
                  Icons.shopping_cart,
                  Colors.purple,
                  () => Navigator.pushNamed(context, AppRoutes.adminOrders),
                ),
                _buildQuickActionCard(
                  context,
                  localizations.returnRequests,
                  Icons.assignment_return,
                  Colors.teal,
                  () => Navigator.pushNamed(
                    context,
                    AppRoutes.adminReturnRequests,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              localizations.systemOverview,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatsCards(localizations),
            const SizedBox(height: 24),
            Text(
              localizations.recentActivity,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecentActivityList(localizations),
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

  Widget _buildStatsCards(AppLocalizations localizations) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          localizations.totalBooks,
          '1,234',
          Icons.book,
          Colors.blue,
        ),
        _buildStatCard(
          localizations.activeUsers,
          '567',
          Icons.people,
          Colors.green,
        ),
        _buildStatCard(
          localizations.pendingOrders,
          '89',
          Icons.shopping_cart,
          Colors.orange,
        ),
        _buildStatCard(
          localizations.revenue,
          '\$12,345',
          Icons.attach_money,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityList(AppLocalizations localizations) {
    return Card(
      elevation: 2,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Colors.primaries[index % Colors.primaries.length],
              child: Icon(
                [
                  Icons.person_add,
                  Icons.shopping_cart,
                  Icons.book,
                  Icons.report_problem,
                  Icons.discount,
                ][index],
                color: Colors.white,
              ),
            ),
            title: Text(
              [
                localizations.newUserRegistered,
                localizations.newOrderPlaced,
                localizations.newBookAdded,
                localizations.newComplaintReceived,
                localizations.newDiscountCodeCreated,
              ][index],
            ),
            subtitle: Text(
              '${DateTime.now().subtract(Duration(hours: index * 2)).hour}:${DateTime.now().subtract(Duration(hours: index * 2)).minute} - ${DateTime.now().subtract(Duration(hours: index * 2)).day}/${DateTime.now().subtract(Duration(hours: index * 2)).month}',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          );
        },
      ),
    );
  }

  static void _showLogoutDialog(
    BuildContext context,
    AuthProvider authProvider,
    AppLocalizations localizations,
  ) {
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
            localizations.signOut,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Text(
            localizations.signOutConfirmation,
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
              child: Text(
                localizations.cancel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await _performLogout(context, authProvider);
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
              child: Text(
                localizations.signOut,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _performLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    try {
      await authProvider.logout();

      if (context.mounted) {
        AuthService.clearProvidersTokens(context);
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.signOutFailed}: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
