import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/localization/app_localizations.dart';
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
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) => Text(localizations.managerDashboard),
        ),
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
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations.welcomeManager(
                              authProvider.user?.firstName ?? 'Manager',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          );
                        },
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
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations.tapToViewProfile,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            softWrap: true,
                            textAlign: TextAlign.start,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: Text(localizations.dashboard),
                  onTap: () {
                    Navigator.pop(context);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(localizations.personalProfile),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerProfile);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.library_books),
                  title: Text(localizations.libraryManagement),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerLibrary);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.category),
                  title: Text(localizations.categories),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerCategories);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(localizations.authors),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerAuthors);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.book),
                  title: Text(localizations.books),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerBooks);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.book_online),
                  title: Text(localizations.newBorrowingRequest),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerBorrows);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.assignment_return),
                  title: Text(localizations.returnRequests),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.adminReturnRequests);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.shopping_cart),
                  title: Text(localizations.orders),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerOrders);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.discount),
                  title: Text(localizations.discounts),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.adminDiscounts);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.campaign),
                  title: Text(localizations.announcements),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerAds);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.report_problem),
                  title: Text(localizations.complaints),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerComplaints);
                  },
                );
              },
            ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: Text(localizations.reports),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.managerReports);
                  },
                );
              },
            ),
            const Divider(),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.error),
                  title: Text(
                    localizations.signOut,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(authProvider);
                  },
                );
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
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.quickActions,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildQuickActionCard(
                      context,
                      localizations.libraryManagement,
                      Icons.library_books,
                      Colors.blue,
                      () => Navigator.pushNamed(
                        context,
                        AppRoutes.managerLibrary,
                      ),
                    ),
                    _buildQuickActionCard(
                      context,
                      localizations.books,
                      Icons.book,
                      Colors.green,
                      () =>
                          Navigator.pushNamed(context, AppRoutes.managerBooks),
                    ),
                    _buildQuickActionCard(
                      context,
                      localizations.newBorrowingRequest,
                      Icons.book_online,
                      Colors.orange,
                      () => Navigator.pushNamed(
                        context,
                        AppRoutes.managerBorrows,
                      ),
                    ),
                    _buildQuickActionCard(
                      context,
                      localizations.orders,
                      Icons.shopping_cart,
                      Colors.purple,
                      () =>
                          Navigator.pushNamed(context, AppRoutes.managerOrders),
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
                );
              },
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
    final localizations = AppLocalizations.of(context);
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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.signOutFailed(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
