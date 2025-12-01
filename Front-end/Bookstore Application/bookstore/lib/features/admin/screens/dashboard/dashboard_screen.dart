import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/providers/auth_provider.dart';

class ManagerDashboardScreen extends StatelessWidget {
  const ManagerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manager Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.managerNotifications);
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.managerDashboard);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.person, size: 30),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Welcome, ${authProvider.user?.fullName ?? 'Manager'}',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    authProvider.user?.email ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
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
              leading: const Icon(Icons.library_books),
              title: const Text('Library'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppRoutes.managerDashboard);
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
                Navigator.pushNamed(context, AppRoutes.managerDashboard);
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
                Navigator.pushNamed(context, AppRoutes.managerDashboard);
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
                _showLogoutDialog(context, authProvider);
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
                  'Library',
                  Icons.library_books,
                  Colors.blue,
                  () =>
                      Navigator.pushNamed(context, AppRoutes.managerDashboard),
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
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildRecentActivityList(),
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

  Widget _buildRecentActivityList() {
    // This would typically be populated from a provider
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
                  Icons.book_online,
                  Icons.shopping_cart,
                  Icons.person_add,
                  Icons.book,
                  Icons.discount,
                ][index],
                color: Colors.white,
              ),
            ),
            title: Text(
              [
                'New borrowing request',
                'New order placed',
                'New author added',
                'Book inventory updated',
                'New discount code created',
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
