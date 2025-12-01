import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../orders/providers/orders_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/order_card.dart';
import '../widgets/search_filter_bar.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  String _searchQuery = '';
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    // Load purchase orders when the screen initializes (no filters initially)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrdersFromServer();
    });
  }

  // Load orders from server with current filter parameters
  Future<void> _loadOrdersFromServer() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);

    // Set the auth token before loading orders
    ordersProvider.setToken(authProvider.token);

    debugPrint(
      'PurchaseOrdersScreen: Loading orders from server with filters - status: $_selectedStatus, search: "$_searchQuery"',
    );

    try {
      await ordersProvider.loadOrdersByType(
        'purchase',
        status: _selectedStatus,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      debugPrint(
        'PurchaseOrdersScreen: Orders loaded successfully. Count: ${ordersProvider.orders.length}',
      );
    } catch (error) {
      debugPrint('PurchaseOrdersScreen: Error loading orders: $error');
    }
  }

  void _onSearchChanged(String query) {
    debugPrint('PurchaseOrdersScreen: Search query changed to: "$query"');
    setState(() {
      _searchQuery = query;
    });
    // Reload orders from server with new search query
    _loadOrdersFromServer();
  }

  void _onFilterChanged(String? status) {
    debugPrint('PurchaseOrdersScreen: Status filter changed to: $status');
    setState(() {
      _selectedStatus = status;
    });
    // Reload orders from server with new status filter
    _loadOrdersFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).purchaseOrders),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadOrdersFromServer();
            },
          ),
        ],
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, child) {
          if (ordersProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (ordersProvider.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ErrorMessage(message: ordersProvider.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _loadOrdersFromServer();
                    },
                    child: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            );
          }

          // Get user type to determine which status filters to show
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final userType = authProvider.user?.userType;
          final isDeliveryManager = userType == 'delivery_admin';

          // Use filtered status options for delivery managers
          final statusFilterOptions = isDeliveryManager
              ? ordersProvider.deliveryManagerStatusFilterOptions
              : ordersProvider.statusFilterOptions;

          return Column(
            children: [
              // Search and Filter Bar
              SearchFilterBar(
                searchHint: 'Search purchase requests...',
                filterLabel: 'Status',
                filterOptions: statusFilterOptions,
                onSearchChanged: _onSearchChanged,
                onFilterChanged: _onFilterChanged,
              ),

              // Orders List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadOrdersFromServer();
                  },
                  child: ordersProvider.orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 64,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedStatus != null
                                    ? 'No matching purchase requests found'
                                    : AppLocalizations.of(
                                        context,
                                      ).noPurchaseOrders,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedStatus != null
                                    ? 'Try adjusting your search or filter criteria'
                                    : AppLocalizations.of(
                                        context,
                                      ).noPurchaseOrdersDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: ordersProvider.orders.length,
                          itemBuilder: (context, index) {
                            final order = ordersProvider.orders[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: OrderCard(
                                order: order,
                                onTap: () {
                                  // Navigate to order details
                                  Navigator.pushNamed(
                                    context,
                                    '/order-detail',
                                    arguments: {'orderId': order.id},
                                  );
                                },
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
