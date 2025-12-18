import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../core/services/theme_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../routes/app_routes.dart';

class WebSidebar extends StatelessWidget {
  final String userRole;

  const WebSidebar({super.key, required this.userRole});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = themeService.isDarkMode;
    final user = authProvider.user;

    return Container(
      width: 260,
      color: isDark ? AppColors.darkSurface : AppColors.surface,
      child: Column(
        children: [
          // Logo/App Name Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkCard : AppColors.borderLight,
                  width: 1,
                ),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.library_books, color: AppColors.white, size: 32),
                SizedBox(width: 12),
                Text(
                  'ReadGo',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // User Info Section
          if (user != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? AppColors.darkCard : AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      user.initials,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getRoleDisplayName(userRole),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Navigation Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _buildMenuItems(context, userRole, isDark),
            ),
          ),

          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColors.darkCard : AppColors.borderLight,
                  width: 1,
                ),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await authProvider.logout();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(BuildContext context, String role, bool isDark) {
    if (role == 'admin' || role == 'library_admin') {
      return _buildAdminMenuItems(context, role, isDark);
    } else if (role == 'delivery_admin') {
      return _buildDeliveryMenuItems(context, isDark);
    }
    return [];
  }

  List<Widget> _buildAdminMenuItems(
    BuildContext context,
    String role,
    bool isDark,
  ) {
    final menuItems = [
      _MenuItem(
        icon: Icons.dashboard,
        label: 'Dashboard',
        route: role == 'admin'
            ? AppRoutes.adminDashboard
            : AppRoutes.libraryDashboard,
      ),
      _MenuItem(
        icon: Icons.book,
        label: 'Books',
        route: AppRoutes.managerBooks,
      ),
      _MenuItem(
        icon: Icons.category,
        label: 'Categories',
        route: AppRoutes.managerCategories,
      ),
      _MenuItem(
        icon: Icons.person,
        label: 'Authors',
        route: AppRoutes.managerAuthors,
      ),
      _MenuItem(
        icon: Icons.shopping_cart,
        label: 'Orders',
        route: AppRoutes.managerOrders,
      ),
      _MenuItem(
        icon: Icons.book_online,
        label: 'Borrowing',
        route: AppRoutes.managerBorrows,
      ),
      _MenuItem(
        icon: Icons.assignment_return,
        label: 'Return Requests',
        route: AppRoutes.adminReturnRequests,
      ),
      _MenuItem(
        icon: Icons.campaign,
        label: 'Ads',
        route: AppRoutes.managerAds,
      ),
      _MenuItem(
        icon: Icons.report,
        label: 'Reports',
        route: AppRoutes.managerReports,
      ),
      _MenuItem(
        icon: Icons.notifications,
        label: 'Notifications',
        route: AppRoutes.managerNotifications,
      ),
      _MenuItem(
        icon: Icons.settings,
        label: 'Settings',
        route: AppRoutes.managerSettings,
      ),
      _MenuItem(
        icon: Icons.person,
        label: 'Profile',
        route: AppRoutes.managerProfile,
      ),
    ];

    if (role == 'library_admin') {
      menuItems.insert(
        4,
        _MenuItem(
          icon: Icons.local_library,
          label: 'Libraries',
          route: AppRoutes.managerLibrary,
        ),
      );
    }

    return menuItems.map((item) {
      final isSelected = ModalRoute.of(context)?.settings.name == item.route;
      return _buildMenuItem(context, item, isSelected, isDark);
    }).toList();
  }

  List<Widget> _buildDeliveryMenuItems(BuildContext context, bool isDark) {
    final menuItems = [
      _MenuItem(
        icon: Icons.dashboard,
        label: 'Dashboard',
        route: AppRoutes.deliveryDashboard,
      ),
      _MenuItem(
        icon: Icons.local_shipping,
        label: 'Tasks',
        route: AppRoutes.deliveryTasks,
      ),
      _MenuItem(
        icon: Icons.notifications,
        label: 'Notifications',
        route: AppRoutes.deliveryNotifications,
      ),
      _MenuItem(
        icon: Icons.settings,
        label: 'Settings',
        route: AppRoutes.deliverySettings,
      ),
      _MenuItem(
        icon: Icons.person,
        label: 'Profile',
        route: AppRoutes.deliveryProfile,
      ),
    ];

    return menuItems.map((item) {
      final isSelected = ModalRoute.of(context)?.settings.name == item.route;
      return _buildMenuItem(context, item, isSelected, isDark);
    }).toList();
  }

  Widget _buildMenuItem(
    BuildContext context,
    _MenuItem item,
    bool isSelected,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: Theme.of(context).primaryColor, width: 1)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          item.icon,
          color: isSelected
              ? Theme.of(context).primaryColor
              : (isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary),
        ),
        title: Text(
          item.label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).primaryColor
                : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          Navigator.pushNamed(context, item.route);
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'library_admin':
        return 'Library Manager';
      case 'delivery_admin':
        return 'Delivery Manager';
      default:
        return 'User';
    }
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String route;

  _MenuItem({required this.icon, required this.label, required this.route});
}
