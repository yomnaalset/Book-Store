import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/localization/app_localizations.dart';
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
    final localizations = AppLocalizations.of(context);
    return AppBar(
      backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.primaryGradient,
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
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
            localizations.bookstore,
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
            final localizations = AppLocalizations.of(context);
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
                              authProvider.user?.firstName ??
                                  localizations.guestUser,
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
                                    localizations.userLabel,
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
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        _buildMenuItem(
                          context,
                          Icons.person_outline,
                          localizations.myProfile,
                          () {
                            Navigator.pop(context);
                            _showSnackBar(
                              context,
                              localizations.profileFeatureComingSoon,
                            );
                          },
                        ),
                        _buildMenuItem(
                          context,
                          Icons.receipt_long_outlined,
                          localizations.myOrdersMenu,
                          () {
                            Navigator.pop(context);
                            _showSnackBar(
                              context,
                              localizations.ordersFeatureComingSoon,
                            );
                          },
                        ),

                        // Admin/Manager specific items
                        if (authProvider.user?.userType == 'library_admin')
                          _buildMenuItem(
                            context,
                            Icons.admin_panel_settings_outlined,
                            localizations.libraryManagement,
                            () {
                              Navigator.pop(context);
                              _showSnackBar(
                                context,
                                localizations.libraryManagementComingSoon,
                              );
                            },
                          ),

                        if (authProvider.user?.userType == 'delivery_admin')
                          _buildMenuItem(
                            context,
                            Icons.local_shipping_outlined,
                            localizations.deliveryManagement,
                            () {
                              Navigator.pop(context);
                              _showSnackBar(
                                context,
                                localizations.deliveryManagementComingSoon,
                              );
                            },
                          ),

                        _buildMenuItem(
                          context,
                          Icons.language_outlined,
                          localizations.languageMenu,
                          () {
                            Navigator.pop(context);
                            _showLanguageDialog(context);
                          },
                        ),
                        _buildMenuItem(
                          context,
                          Icons.settings_outlined,
                          localizations.settings,
                          () {
                            Navigator.pop(context);
                            _showSnackBar(
                              context,
                              localizations.settingsFeatureComingSoon,
                            );
                          },
                        ),
                        _buildMenuItem(
                          context,
                          Icons.logout_outlined,
                          localizations.logout,
                          () {
                            Navigator.pop(context);
                            _showLogoutDialog(context);
                          },
                          isDestructive: true,
                        ),
                      ],
                    );
                  },
                ),

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
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.selectLanguage),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇺🇸'),
              title: Text(localizations.englishLanguage),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(context, localizations.languageChangedToEnglish);
              },
            ),
            ListTile(
              leading: SvgPicture.asset(
                'assets/images/Flag_of_Syria.svg',
                width: 24,
                height: 18,
                fit: BoxFit.contain,
              ),
              title: Text(localizations.arabicLanguage),
              onTap: () {
                Navigator.pop(context);
                _showSnackBar(context, localizations.languageChangedToArabic);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.logout),
        content: Text(localizations.logoutConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSnackBar(
                context,
                localizations.logoutFunctionalityComingSoon,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(localizations.logout),
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
