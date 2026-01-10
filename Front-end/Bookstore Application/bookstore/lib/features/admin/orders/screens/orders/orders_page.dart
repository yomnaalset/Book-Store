import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/orders_provider.dart' as admin_orders_provider;
import '../../../../orders/models/order.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../../../routes/app_routes.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/localization/app_localizations.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with TickerProviderStateMixin {
  String _searchQuery = '';
  String? _selectedStatus;
  Timer? _searchDebounceTimer;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  // Status tabs - will be localized in build method
  List<String> _getStatusTabs(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return [
      localizations.all,
      localizations.statusPending,
      localizations.statusApproved,
      localizations.delivering,
      localizations.statusCompleted,
      localizations.cancelled,
    ];
  }

  @override
  void initState() {
    super.initState();
    // Initialize with default length, will be updated in build
    _tabController = TabController(length: 6, vsync: this);

    // Add listener to TabController - will be set up in build method

    // Defer loading until after the initial build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index, BuildContext context) {
    final statusTabs = _getStatusTabs(context);
    final localizations = AppLocalizations.of(context);
    final selectedTab = statusTabs[index];
    String? status;

    debugPrint('DEBUG: Tab changed to: $selectedTab (index: $index)');

    if (selectedTab == localizations.all) {
      status = null;
    } else if (selectedTab == localizations.statusPending) {
      status = 'pending';
    } else if (selectedTab == localizations.statusApproved) {
      status = 'confirmed';
    } else if (selectedTab == localizations.delivering) {
      status = 'in_delivery';
    } else if (selectedTab == localizations.statusCompleted) {
      status = 'delivered';
    } else if (selectedTab == localizations.cancelled) {
      status = 'cancelled';
    }

    debugPrint('DEBUG: Selected status: $status');

    if (mounted) {
      setState(() {
        _selectedStatus = status;
      });
      // Load orders with the new status filter
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    final provider = context.read<admin_orders_provider.OrdersProvider>();
    final authProvider = context.read<AuthProvider>();

    debugPrint(
      'DEBUG: Loading orders with status: $_selectedStatus, search: $_searchQuery',
    );

    // Ensure provider has the current token
    if (authProvider.token != null) {
      provider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Orders page - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
      );
    } else {
      debugPrint('DEBUG: Orders page - No token available from AuthProvider');
    }

    debugPrint('DEBUG: Calling provider.getOrders with parameters:');
    debugPrint('  - search: ${_searchQuery.isEmpty ? null : _searchQuery}');
    debugPrint('  - status: $_selectedStatus');

    await provider.getOrders(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      status: _selectedStatus,
    );
  }

  void _onSearch(String query) {
    debugPrint('DEBUG: Search called with query: "$query"');
    if (mounted) {
      setState(() {
        _searchQuery = query;
      });
      _loadOrders();
    }
  }

  void _onSearchChanged(String query) {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // Set new timer for debounced search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
        _loadOrders();
      }
    });
  }

  void _navigateToOrderDetails(Order order) {
    Navigator.pushNamed(
      context,
      AppRoutes.managerOrderDetails,
      arguments: order,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final statusTabs = _getStatusTabs(context);

    // Update TabController length if needed
    if (_tabController.length != statusTabs.length) {
      _tabController.dispose();
      _tabController = TabController(length: statusTabs.length, vsync: this);
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          _onTabChanged(_tabController.index, context);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.orders),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Refresh icon
          IconButton(
            onPressed: () => _loadOrders(),
            icon: const Icon(Icons.refresh),
            tooltip: localizations.refreshOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: statusTabs.map((status) => Tab(text: status)).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (index) {
            debugPrint('DEBUG: TabBar onTap called with index: $index');
            // Update the selected status and reload orders
            _onTabChanged(index, context);
          },
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: localizations.searchOrders,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
                onChanged: _onSearchChanged,
                onSubmitted: _onSearch,
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: Consumer<admin_orders_provider.OrdersProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.orders.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${localizations.error}: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadOrders,
                          child: Text(localizations.retry),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.orders.isEmpty) {
                  return EmptyState(
                    title: localizations.noOrders,
                    message: _getEmptyMessage(context),
                    icon: Icons.shopping_cart,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 16.0,
                  ),
                  itemCount: provider.orders.length,
                  itemBuilder: (context, index) {
                    final order = provider.orders[index];
                    return _buildOrderCard(order);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Get the effective status for display, checking delivery assignment if available
  String _getEffectiveStatus(Order order) {
    // If delivery assignment status is 'in_delivery', show that instead of order status
    if (order.deliveryAssignment != null &&
        order.deliveryAssignment!.status.toLowerCase() == 'in_delivery') {
      return 'in_delivery';
    }
    return order.status;
  }

  Widget _buildOrderCard(Order order) {
    final localizations = AppLocalizations.of(context);
    final effectiveStatus = _getEffectiveStatus(order);
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToOrderDetails(order),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with order number and more options
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    order.orderNumber.isNotEmpty
                        ? '#${order.orderNumber}'
                        : '#ORD-${order.id.toString().padLeft(4, '0')}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'view':
                          _navigateToOrderDetails(order);
                          break;
                        case 'cancel':
                          _showCancelOrderDialog(order);
                          break;
                        case 'track':
                          _showTrackDeliveryDialog(order);
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return [
                        PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              const Icon(Icons.visibility, size: 20),
                              const SizedBox(width: 8),
                              Text(localizations.viewDetails),
                            ],
                          ),
                        ),
                        if (effectiveStatus.toLowerCase() != 'cancelled' &&
                            effectiveStatus.toLowerCase() != 'delivered')
                          PopupMenuItem(
                            value: 'cancel',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.cancel,
                                  size: 20,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  localizations.cancelOrder,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        if (effectiveStatus.toLowerCase() == 'in_delivery' ||
                            effectiveStatus.toLowerCase() == 'delivering')
                          PopupMenuItem(
                            value: 'track',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 20,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  localizations.trackDelivery,
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                      ];
                    },
                    child: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Customer name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${localizations.customerLabel}: ${order.customerName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusChip(status: effectiveStatus),
                ],
              ),
              const SizedBox(height: 12),

              // Total price with money icon
              Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.green, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '\$${order.totalAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Order date
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${localizations.orderedLabel}: ${_formatDate(order.createdAt)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.inventory, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${order.items.length} ${order.items.length == 1 ? localizations.itemsLabel : localizations.itemsLabelPlural}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getEmptyMessage(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    switch (_selectedStatus) {
      case 'pending':
        return localizations.noPendingOrders;
      case 'confirmed':
        return localizations.noConfirmedOrders;
      case 'in_delivery':
        return localizations.noOrdersInDelivery;
      case 'delivered':
        return localizations.noDeliveredOrders;
      case 'cancelled':
        return localizations.noCancelledOrders;
      default:
        return localizations.noOrdersFound;
    }
  }

  void _showCancelOrderDialog(Order order) {
    final localizations = AppLocalizations.of(context);
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.rejectOrder),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizations.pleaseProvideReasonForRejecting),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                labelText: localizations.rejectionReason,
                hintText: localizations.enterReasonForRejection,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _cancelOrder(order, reasonController.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.pleaseProvideRejectionReason),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(localizations.rejectOrder),
          ),
        ],
      ),
    );
  }

  void _showTrackDeliveryDialog(Order order) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.trackDelivery),
        content: Text(localizations.deliveryTrackingFeatureComingSoon),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.ok),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(Order order, String rejectionReason) async {
    final localizations = AppLocalizations.of(context);
    try {
      final provider = context.read<admin_orders_provider.OrdersProvider>();
      final success = await provider.rejectOrder(
        int.parse(order.id),
        rejectionReason,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.orderCancelledSuccessfully),
              backgroundColor: Colors.red,
            ),
          );
          _loadOrders(); // Refresh the orders list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.failedToCancelOrder),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorCancellingOrder(e.toString())),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
