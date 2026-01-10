import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/orders_provider.dart' as admin_orders_provider;
import '../../../../orders/models/order.dart';
import '../../../widgets/library_manager/admin_search_bar.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../../../routes/app_routes.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/localization/app_localizations.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    // Defer loading until after the initial build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    final provider = context.read<admin_orders_provider.OrdersProvider>();
    final authProvider = context.read<AuthProvider>();

    // Ensure provider has the current token
    if (authProvider.token != null) {
      provider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Orders list - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
      );
    } else {
      debugPrint('DEBUG: Orders list - No token available from AuthProvider');
    }

    await provider.getOrders(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      status: _selectedStatus,
    );
  }

  void _onSearch(String query) {
    if (mounted) {
      setState(() {
        _searchQuery = query;
      });
      _loadOrders();
    }
  }

  void _onFilterChanged(String? status) {
    if (mounted) {
      setState(() {
        _selectedStatus = status;
      });
      _loadOrders();
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.orders),
        actions: [
          IconButton(
            onPressed: () => _loadOrders(),
            icon: const Icon(Icons.refresh),
            tooltip: localizations.refreshOrders,
          ),
        ],
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AdminSearchBar(
              hintText: localizations.searchOrders,
              onChanged: (query) {
                // Cancel previous timer
                _searchDebounceTimer?.cancel();

                // Set new timer for debounced search
                _searchDebounceTimer = Timer(
                  const Duration(milliseconds: 500),
                  () {
                    if (mounted) {
                      setState(() {
                        _searchQuery = query;
                      });
                      _loadOrders();
                    }
                  },
                );
              },
              onSubmitted: _onSearch,
            ),
          ),

          // Status Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: InputDecoration(
                labelText: localizations.status,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(localizations.allStatuses),
                ),
                DropdownMenuItem(
                  value: 'pending',
                  child: Text(localizations.statusPending),
                ),
                DropdownMenuItem(
                  value: 'pending_assignment',
                  child: Text(localizations.pendingAssignment),
                ),
                DropdownMenuItem(
                  value: 'confirmed',
                  child: Text(localizations.confirmed),
                ),
                DropdownMenuItem(
                  value: 'in_delivery',
                  child: Text(localizations.inDelivery),
                ),
                DropdownMenuItem(
                  value: 'delivered',
                  child: Text(localizations.delivered),
                ),
                DropdownMenuItem(
                  value: 'returned',
                  child: Text(localizations.statusReturned),
                ),
              ],
              onChanged: _onFilterChanged,
            ),
          ),

          const SizedBox(height: 16),

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
                    message: localizations.noOrdersFound,
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
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(
            effectiveStatus,
          ).withValues(alpha: 0.1),
          child: Icon(
            Icons.shopping_cart,
            color: _getStatusColor(effectiveStatus),
          ),
        ),
        title: Text(
          order.orderNumber.isNotEmpty
              ? '${localizations.orders} #${order.orderNumber}'
              : '${localizations.orders} #${order.id}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            Text(
              '${localizations.customerLabel}: ${order.customerName}',
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '\$${order.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(status: effectiveStatus),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${localizations.orderedLabel}: ${_formatDate(order.createdAt)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.inventory, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${order.items.length} ${order.items.length == 1 ? localizations.itemsLabel : localizations.itemsLabelPlural}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'view':
                _navigateToOrderDetails(order);
                break;
              case 'update_status':
                _showStatusUpdateDialog(order);
                break;
            }
          },
          itemBuilder: (context) {
            final localizations = AppLocalizations.of(context);
            return [
              PopupMenuItem(
                value: 'view',
                child: Text(localizations.viewDetails),
              ),
              PopupMenuItem(
                value: 'update_status',
                child: Text(localizations.updateStatus),
              ),
            ];
          },
        ),
        onTap: () => _navigateToOrderDetails(order),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'pending_assignment':
        return Colors.amber;
      case 'confirmed':
        return Colors.blue;
      case 'in_delivery':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'returned':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  void _showStatusUpdateDialog(Order order) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.orderAction),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizations.whatActionForOrder),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showApprovalDialog(order);
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: Text(localizations.approve),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showRejectDialog(order);
                    },
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: Text(localizations.reject),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog(Order order) async {
    // Load delivery managers first
    final provider = context.read<admin_orders_provider.OrdersProvider>();
    List<Map<String, dynamic>> deliveryManagers = [];
    String? selectedDeliveryManagerId;

    try {
      final managers = await provider.apiService.getAvailableDeliveryAgents();
      deliveryManagers = managers
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
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.errorLoadingDeliveryManagers(e.toString()),
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    final localizations = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                localizations.assignDeliveryManager,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                localizations.selectDeliveryManagerToAssignOrder(
                  int.parse(order.id),
                ),
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Delivery Manager Selection
              if (deliveryManagers
                  .where((manager) => manager['is_available'] == true)
                  .isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_rounded, color: Colors.red[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          localizations.noDeliveryManagersAvailable,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                GestureDetector(
                  onTap: () => _showDeliveryManagerSelection(
                    context,
                    deliveryManagers,
                    selectedDeliveryManagerId,
                    (value) {
                      setState(() {
                        selectedDeliveryManagerId = value;
                      });
                    },
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[50],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: selectedDeliveryManagerId == null
                              ? Text(
                                  localizations.chooseDeliveryManager,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                )
                              : _buildSelectedManagerDisplay(
                                  deliveryManagers.firstWhere(
                                    (manager) =>
                                        manager['id'] ==
                                        selectedDeliveryManagerId,
                                  ),
                                ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        localizations.cancel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          deliveryManagers
                                  .where(
                                    (manager) =>
                                        manager['is_available'] == true,
                                  )
                                  .isEmpty ||
                              selectedDeliveryManagerId == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              _approveOrder(
                                order,
                                int.parse(selectedDeliveryManagerId!),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        localizations.approveOrderButton,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedManagerDisplay(Map<String, dynamic> manager) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: _getDeliveryManagerStatusColor(manager['status']),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                manager['name'],
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                '${manager['status']} • ${manager['phone']}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeliveryManagerSelection(
    BuildContext context,
    List<Map<String, dynamic>> deliveryManagers,
    String? selectedId,
    Function(String?) onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              AppLocalizations.of(context).selectDeliveryManager,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Delivery managers list
            ...deliveryManagers
                .where((manager) => manager['is_available'] == true)
                .map(
                  (manager) => GestureDetector(
                    onTap: () {
                      onSelected(manager['id']);
                      Navigator.pop(context);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selectedId == manager['id']
                              ? Colors.green
                              : Colors.grey[300]!,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: selectedId == manager['id']
                            ? Colors.green[50]
                            : Colors.white,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getDeliveryManagerStatusColor(
                                manager['status'],
                              ),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  manager['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: selectedId == manager['id']
                                        ? Colors.green[700]
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${manager['status']} • ${manager['phone']}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selectedId == manager['id'])
                            Icon(
                              Icons.check_circle,
                              color: Colors.green[700],
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(Order order) {
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
                _rejectOrder(order, reasonController.text.trim());
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

  Future<void> _approveOrder(Order order, int deliveryManagerId) async {
    final localizations = AppLocalizations.of(context);
    try {
      final provider = context.read<admin_orders_provider.OrdersProvider>();
      final success = await provider.approveOrder(
        int.parse(order.id),
        deliveryManagerId,
      );

      if (mounted) {
        if (success != null && success['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.orderApprovedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
          _loadOrders(); // Refresh the orders list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.failedToApproveOrder),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorApprovingOrder(e.toString())),
          ),
        );
      }
    }
  }

  Future<void> _rejectOrder(Order order, String reason) async {
    final localizations = AppLocalizations.of(context);
    try {
      final provider = context.read<admin_orders_provider.OrdersProvider>();
      final success = await provider.rejectOrder(int.parse(order.id), reason);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localizations.orderRejectedSuccessfully}. ${localizations.rejectionReason}: $reason',
              ),
              backgroundColor: Colors.red,
            ),
          );
          _loadOrders(); // Refresh the orders list
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.failedToRejectOrder),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorRejectingOrder(e.toString())),
          ),
        );
      }
    }
  }

  Color _getDeliveryManagerStatusColor(String status) {
    // Handle legacy 'busy' status by treating it as 'online' (green)
    final normalizedStatus = status.toLowerCase() == 'busy'
        ? 'online'
        : status.toLowerCase();

    switch (normalizedStatus) {
      case 'online':
      case 'available':
        return Colors.green;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
