import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/orders_provider.dart' as admin_orders_provider;
import '../../../../orders/models/order.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../../../routes/app_routes.dart';
import '../../../../auth/providers/auth_provider.dart';

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

  // Status tabs as per specification
  final List<String> _statusTabs = [
    'All',
    'Pending',
    'Approved',
    'Delivering',
    'Completed',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);

    // Add listener to TabController
    _tabController.addListener(() {
      debugPrint(
        'DEBUG: TabController listener triggered with index: ${_tabController.index}, indexIsChanging: ${_tabController.indexIsChanging}',
      );
      // Always call _onTabChanged when the index changes
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });

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

  void _onTabChanged(int index) {
    final selectedTab = _statusTabs[index];
    String? status;

    debugPrint('DEBUG: Tab changed to: $selectedTab (index: $index)');

    switch (selectedTab) {
      case 'All':
        status = null;
        break;
      case 'Pending':
        status = 'pending';
        break;
      case 'Approved':
        status = 'confirmed';
        break;
      case 'Delivering':
        status = 'in_delivery';
        break;
      case 'Completed':
        status = 'delivered';
        break;
      case 'Cancelled':
        status = 'cancelled';
        break;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Refresh icon
          IconButton(
            onPressed: () => _loadOrders(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _statusTabs.map((status) => Tab(text: status)).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (index) {
            debugPrint('DEBUG: TabBar onTap called with index: $index');
            // Update the selected status and reload orders
            _onTabChanged(index);
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
                  hintText: 'Search orders...',
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
                          'Error: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadOrders,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.orders.isEmpty) {
                  return EmptyState(
                    title: 'No Orders',
                    message: _getEmptyMessage(),
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

  Widget _buildOrderCard(Order order) {
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
                    '#ORD-${order.id.toString().padLeft(4, '0')}',
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
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'view',
                        child: Row(
                          children: [
                            Icon(Icons.visibility, size: 20),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),
                      if (order.status.toLowerCase() != 'cancelled' &&
                          order.status.toLowerCase() != 'delivered')
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Cancel Order',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      if (order.status.toLowerCase() == 'in_delivery' ||
                          order.status.toLowerCase() == 'delivering')
                        const PopupMenuItem(
                          value: 'track',
                          child: Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 20,
                                color: Colors.green,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Track Delivery',
                                style: TextStyle(color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                    ],
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
                      'Customer: ${order.customerName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusChip(status: order.status),
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
                    'Ordered: ${_formatDate(order.createdAt)}',
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
                      '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
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

  String _getEmptyMessage() {
    switch (_selectedStatus) {
      case 'pending':
        return 'No pending orders found';
      case 'confirmed':
        return 'No approved orders found';
      case 'in_delivery':
        return 'No orders in delivery found';
      case 'delivered':
        return 'No completed orders found';
      case 'cancelled':
        return 'No cancelled orders found';
      default:
        return 'No orders found';
    }
  }

  void _showCancelOrderDialog(Order order) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this order:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'Enter reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                _cancelOrder(order, reasonController.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for rejection'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject Order'),
          ),
        ],
      ),
    );
  }

  void _showTrackDeliveryDialog(Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Track Delivery'),
        content: const Text(
          'Delivery tracking feature will be implemented with Google Maps integration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(Order order, String rejectionReason) async {
    try {
      final provider = context.read<admin_orders_provider.OrdersProvider>();
      final success = await provider.rejectOrder(
        int.parse(order.id),
        rejectionReason,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled successfully'),
              backgroundColor: Colors.red,
            ),
          );
          _loadOrders(); // Refresh the orders list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cancelling order: ${e.toString()}')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
