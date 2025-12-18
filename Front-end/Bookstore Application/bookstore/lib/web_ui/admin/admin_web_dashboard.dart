import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../routes/app_routes.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/admin/providers/notifications_provider.dart';
import '../widgets/web_scaffold.dart';
import '../widgets/language_selector.dart';

class AdminWebDashboard extends StatelessWidget {
  const AdminWebDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return WebScaffold(
      title: localizations.managerDashboard,
      actions: [
        // Language selector - quick access to switch between Arabic (RTL) and English (LTR)
        const LanguageSelector(),
        const SizedBox(width: 8),
        // Notification button with badge
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () async {
                final notificationsProvider = context
                    .read<NotificationsProvider>();
                await notificationsProvider.refreshUnreadCount();

                if (context.mounted) {
                  Navigator.pushNamed(context, AppRoutes.adminNotifications);
                }
              },
            ),
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
        // Settings button
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.pushNamed(context, AppRoutes.adminSettings);
          },
        ),
      ],
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
}
