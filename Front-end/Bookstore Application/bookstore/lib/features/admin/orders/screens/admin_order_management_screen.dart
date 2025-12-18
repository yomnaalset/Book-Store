import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../orders/models/order.dart';
import '../widgets/order_approval_card.dart';
import '../providers/orders_provider.dart' as admin_orders_provider;
import '../../../../core/localization/app_localizations.dart';

class AdminOrderManagementScreen extends StatefulWidget {
  const AdminOrderManagementScreen({super.key});

  @override
  State<AdminOrderManagementScreen> createState() =>
      _AdminOrderManagementScreenState();
}

class _AdminOrderManagementScreenState extends State<AdminOrderManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<Order> _pendingOrders = [];
  List<Order> _confirmedOrders = [];
  List<Order> _inDeliveryOrders = [];
  List<Order> _deliveredOrders = [];
  List<Map<String, dynamic>> _deliveryManagers = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadPendingOrders(),
        _loadDeliveryManagers(),
        _loadConfirmedOrders(),
        _loadInDeliveryOrders(),
        _loadDeliveredOrders(),
      ]);
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              '${localizations.failedToLoadOrders}: ${e.toString()}';
        });
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPendingOrders() async {
    try {
      final response = await http.get(
        Uri.parse('YOUR_API_BASE_URL/api/delivery/orders/pending_approval/'),
        headers: {'Authorization': 'Bearer YOUR_AUTH_TOKEN'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _pendingOrders = (data['orders'] as List)
              .map((order) => Order.fromJson(order))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading pending orders: $e');
    }
  }

  Future<void> _loadDeliveryManagers() async {
    try {
      final provider = context.read<admin_orders_provider.OrdersProvider>();
      final managers = await provider.apiService.getAvailableDeliveryAgents();

      setState(() {
        _deliveryManagers = managers
            .map(
              (agent) => {
                'id': agent.id.toString(),
                'name': agent.name,
                'phone': agent.phone,
                'status': agent.status,
                'is_available':
                    agent.status == 'online' || agent.status == 'available',
              },
            )
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading delivery managers: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.errorLoadingDeliveryManagers(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadConfirmedOrders() async {
    // Load confirmed orders
    setState(() {
      _confirmedOrders = [];
    });
  }

  Future<void> _loadInDeliveryOrders() async {
    // Load in-delivery orders
    setState(() {
      _inDeliveryOrders = [];
    });
  }

  Future<void> _loadDeliveredOrders() async {
    // Load delivered orders
    setState(() {
      _deliveredOrders = [];
    });
  }

  Future<void> _approveOrder(String orderId, String deliveryManagerId) async {
    try {
      final response = await http.patch(
        Uri.parse('YOUR_API_BASE_URL/api/delivery/orders/$orderId/approve/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_AUTH_TOKEN',
        },
        body: jsonEncode({'delivery_manager_id': deliveryManagerId}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.orderApprovedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadPendingOrders();
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['error'] ?? localizations.failedToApproveOrder,
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorApprovingOrder(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectOrder(String orderId) async {
    final localizations = AppLocalizations.of(context);
    final TextEditingController reasonController = TextEditingController();

    final bool? confirmed = await showDialog<bool>(
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
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(localizations.rejectOrder),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.isNotEmpty) {
      try {
        final response = await http.patch(
          Uri.parse('YOUR_API_BASE_URL/api/delivery/orders/$orderId/reject/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer YOUR_AUTH_TOKEN',
          },
          body: jsonEncode({'rejection_reason': reasonController.text}),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${localizations.orderRejectedSuccessfully}. ${localizations.rejectionReason}: ${reasonController.text}',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          _loadPendingOrders();
        } else {
          final errorData = jsonDecode(response.body);
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  errorData['error'] ?? localizations.failedToRejectOrder,
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.errorRejectingOrder(e.toString())),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.orderManagement),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: localizations.statusPending,
              icon: const Icon(Icons.schedule),
            ),
            Tab(
              text: localizations.confirmed,
              icon: const Icon(Icons.check_circle),
            ),
            Tab(
              text: localizations.inDelivery,
              icon: const Icon(Icons.local_shipping),
            ),
            Tab(text: localizations.delivered, icon: const Icon(Icons.home)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: localizations.refreshOrders,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: Text(localizations.retry),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPendingOrdersTab(),
                _buildConfirmedOrdersTab(),
                _buildInDeliveryOrdersTab(),
                _buildDeliveredOrdersTab(),
              ],
            ),
    );
  }

  Widget _buildPendingOrdersTab() {
    final localizations = AppLocalizations.of(context);
    if (_pendingOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              localizations.noPendingOrders,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.allOrdersProcessed,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingOrders.length,
        itemBuilder: (context, index) {
          final order = _pendingOrders[index];
          return OrderApprovalCard(
            order: order,
            deliveryManagers: _deliveryManagers,
            onApprove: (deliveryManagerId) =>
                _approveOrder(order.id, deliveryManagerId),
            onReject: () => _rejectOrder(order.id),
          );
        },
      ),
    );
  }

  Widget _buildConfirmedOrdersTab() {
    final localizations = AppLocalizations.of(context);
    return _buildOrdersList(_confirmedOrders, localizations.noConfirmedOrders);
  }

  Widget _buildInDeliveryOrdersTab() {
    final localizations = AppLocalizations.of(context);
    return _buildOrdersList(
      _inDeliveryOrders,
      localizations.noOrdersInDelivery,
    );
  }

  Widget _buildDeliveredOrdersTab() {
    final localizations = AppLocalizations.of(context);
    return _buildOrdersList(_deliveredOrders, localizations.noDeliveredOrders);
  }

  Widget _buildOrdersList(List<Order> orders, String emptyMessage) {
    final localizations = AppLocalizations.of(context);
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                order.orderNumber.substring(order.orderNumber.length - 2),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text('${localizations.orders} #${order.orderNumber}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${localizations.customerLabel}: ${order.userId}',
                ), // This would be customer name
                Text(
                  '${localizations.total}: \$${order.totalAmount.toStringAsFixed(2)}',
                ),
                Text('${localizations.dates}: ${_formatDate(order.createdAt)}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(order.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _getStatusColor(order.status)),
              ),
              child: Text(
                _getStatusText(order.status, localizations),
                style: TextStyle(
                  color: _getStatusColor(order.status),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            onTap: () {
              // Navigate to order details
            },
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'in_delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status, AppLocalizations localizations) {
    // Use the translation method to handle all order statuses
    return localizations.getOrderStatusLabel(status);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
