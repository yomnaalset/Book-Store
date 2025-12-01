import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../orders/providers/orders_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/order_card.dart';
import '../widgets/advanced_search_filter_bar.dart';

class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen({super.key});

  @override
  State<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends State<AllOrdersScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedOrderType;

  @override
  void initState() {
    super.initState();
    // Load all orders when the screen initializes (no filters initially)
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
      'AllOrdersScreen: Loading orders from server with filters - status: $_selectedStatus, orderType: $_selectedOrderType, search: "$_searchQuery"',
    );

    try {
      await ordersProvider.loadOrders(
        status: _selectedStatus,
        orderType: _selectedOrderType,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      debugPrint(
        'AllOrdersScreen: Orders loaded successfully. Count: ${ordersProvider.orders.length}',
      );
    } catch (error) {
      debugPrint('AllOrdersScreen: Error loading orders: $error');
    }
  }

  void _onSearchChanged(String query) {
    debugPrint('AllOrdersScreen: Search query changed to: "$query"');
    setState(() {
      _searchQuery = query;
    });
    // Reload orders from server with new search query
    _loadOrdersFromServer();
  }

  void _onStatusFilterChanged(String? status) {
    debugPrint('AllOrdersScreen: Status filter changed to: $status');
    setState(() {
      _selectedStatus = status;
    });
    // Reload orders from server with new status filter
    _loadOrdersFromServer();
  }

  void _onOrderTypeFilterChanged(String? orderType) {
    debugPrint('AllOrdersScreen: Order type filter changed to: $orderType');
    setState(() {
      _selectedOrderType = orderType;
    });
    // Reload orders from server with new order type filter
    _loadOrdersFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).all),
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
              // Advanced Search and Filter Bar
              AdvancedSearchFilterBar(
                searchHint: 'Search all requests...',
                statusFilterOptions: statusFilterOptions,
                orderTypeFilterOptions: ordersProvider.orderTypeFilterOptions,
                onSearchChanged: _onSearchChanged,
                onStatusFilterChanged: _onStatusFilterChanged,
                onOrderTypeFilterChanged: _onOrderTypeFilterChanged,
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
                                Icons.list_outlined,
                                size: 64,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedStatus != null ||
                                        _selectedOrderType != null
                                    ? 'No matching requests found'
                                    : 'No Orders Found',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedStatus != null ||
                                        _selectedOrderType != null
                                    ? 'Try adjusting your search or filter criteria'
                                    : 'No orders are currently available.',
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
