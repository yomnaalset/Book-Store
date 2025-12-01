import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../../../../core/constants/app_colors.dart';
import '../../../../../features/auth/providers/auth_provider.dart';
import '../../../../../features/cart/providers/cart_provider.dart';
import '../../../../../features/favorites/providers/favorites_provider.dart';
import '../../../../../features/notifications/providers/notifications_provider.dart';

class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.primaryGradient,
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
      leading: Builder(
        builder: (context) => GestureDetector(
          onTap: () => _showProfileMenu(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.white, width: 2),
            ),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return CircleAvatar(
                  backgroundColor: AppColors.white,
                  backgroundImage: authProvider.user?.profilePicture != null
                      ? NetworkImage(authProvider.user!.profilePicture!)
                      : null,
                  child: authProvider.user?.profilePicture == null
                      ? const Icon(
                          Icons.person,
                          color: AppColors.uranianBlue,
                          size: 20,
                        )
                      : null,
                );
              },
            ),
          ),
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.library_books, color: AppColors.white, size: 28),
          const SizedBox(width: 8),
          Text(
            'Bookstore',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        // Favorites Icon
        Consumer<FavoritesProvider>(
          builder: (context, favoritesProvider, child) {
            return badges.Badge(
              badgeContent: Text(
                '${favoritesProvider.count}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              showBadge: favoritesProvider.count > 0,
              badgeStyle: const badges.BadgeStyle(
                badgeColor: AppColors.error,
                padding: EdgeInsets.all(4),
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/favorites');
                },
                icon: const Icon(
                  Icons.favorite_outline,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
            );
          },
        ),

        // Notifications Icon with Badge
        Consumer<NotificationsProvider>(
          builder: (context, notificationsProvider, child) {
            return badges.Badge(
              badgeContent: Text(
                '${notificationsProvider.unreadCount}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              showBadge: notificationsProvider.unreadCount > 0,
              badgeStyle: const badges.BadgeStyle(
                badgeColor: AppColors.error,
                padding: EdgeInsets.all(4),
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/notifications');
                },
                icon: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
            );
          },
        ),

        // Cart Icon with Badge
        Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            return badges.Badge(
              badgeContent: Text(
                '${cartProvider.itemCount}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              showBadge: cartProvider.itemCount > 0,
              badgeStyle: const badges.BadgeStyle(
                badgeColor: AppColors.error,
                padding: EdgeInsets.all(4),
              ),
              child: IconButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/cart');
                },
                icon: const Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.white,
                  size: 24,
                ),
              ),
            );
          },
        ),

        const SizedBox(width: 8),
      ],
    );
  }

  void _showProfileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Profile Section
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.uranianBlue,
                        backgroundImage:
                            authProvider.user?.profilePicture != null
                            ? NetworkImage(authProvider.user!.profilePicture!)
                            : null,
                        child: authProvider.user?.profilePicture == null
                            ? const Icon(
                                Icons.person,
                                color: AppColors.white,
                                size: 30,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authProvider.user?.firstName ?? 'Guest User',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              authProvider.user?.email ?? 'guest@bookstore.com',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.uranianBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                authProvider.user?.userType.toUpperCase() ??
                                    'USER',
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu Items
                _buildMenuItem(context, Icons.person_outline, 'My Profile', () {
                  Navigator.pop(context);
                  _showSnackBar(context, 'Profile feature coming soon!');
                }),
                _buildMenuItem(
                  context,
                  Icons.receipt_long_outlined,
                  'My Orders',
                  () {
                    Navigator.pop(context);
                    _showSnackBar(context, 'Orders feature coming soon!');
                  },
                ),

                // Admin/Manager specific items
                if (authProvider.user?.userType == 'library_admin')
                  _buildMenuItem(
                    context,
                    Icons.admin_panel_settings_outlined,
                    'Library Management',
                    () {
                      Navigator.pop(context);
                      _showSnackBar(context, 'Library management coming soon!');
                    },
                  ),

                if (authProvider.user?.userType == 'delivery_admin')
                  _buildMenuItem(
                    context,
                    Icons.local_shipping_outlined,
                    'Delivery Management',
                    () {
                      Navigator.pop(context);
                      _showSnackBar(
                        context,
                        'Delivery management coming soon!',
                      );
                    },
                  ),

                _buildMenuItem(
                  context,
                  Icons.language_outlined,
                  'Language',
                  () {
                    Navigator.pop(context);
                    _showLanguageDialog(context);
                  },
                ),
                _buildMenuItem(
                  context,
                  Icons.settings_outlined,
                  'Settings',
                  () {
                    Navigator.pop(context);
                    _showSnackBar(context, 'Settings feature coming soon!');
                  },
                ),
                _buildMenuItem(context, Icons.logout_outlined, 'Logout', () {
                  Navigator.pop(context);
                  _showLogoutDialog(context);
                }, isDestructive: true),

                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? AppColors.error : AppColors.uranianBlue,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? AppColors.error : AppColors.primaryText,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇺🇸'),
              title: const Text('English'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(context, 'Language changed to English');
              },
            ),
            ListTile(
              leading: const Text('🇸🇦'),
              title: const Text('العربية'),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(context, 'تم تغيير اللغة إلى العربية');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar(context, 'Logout functionality coming soon!');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.uranianBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
