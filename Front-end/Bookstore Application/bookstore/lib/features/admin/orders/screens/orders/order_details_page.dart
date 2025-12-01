import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/orders_provider.dart';
import '../../../../orders/models/order.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../widgets/customer_order_details_widget.dart';
import '../../widgets/admin_order_details_widget.dart';
import '../../widgets/delivery_manager_order_details_widget.dart';
import '../../widgets/order_details_shared.dart';

class OrderDetailsPage extends StatefulWidget {
  final Order order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool _isLoading = false;
  Order? _currentOrder;
  List<Map<String, dynamic>> _deliveryManagers = [];
  String? _selectedDeliveryManagerId;
  bool _isEditMode = false; // Track edit mode for delivery managers

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    // Defer the API call to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrderDetails();
      _loadDeliveryManagers();
    });
  }

  Future<void> _fetchOrderDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OrdersProvider>();
      final freshOrder = await provider.getOrderById(widget.order.id);

      // Debug discount information
      debugPrint('DEBUG: Order loaded - ID: ${freshOrder?.id}');
      debugPrint('DEBUG: Order status: ${freshOrder?.status}');
      debugPrint('DEBUG: Order isConfirmed: ${freshOrder?.isConfirmed}');
      debugPrint('DEBUG: Order discount code: ${freshOrder?.discountCode}');
      debugPrint('DEBUG: Order discount amount: ${freshOrder?.discountAmount}');
      debugPrint('DEBUG: Order coupon code: ${freshOrder?.couponCode}');
      debugPrint('DEBUG: Order hasDiscount: ${freshOrder?.hasDiscount}');
      debugPrint('DEBUG: Order subtotal: ${freshOrder?.subtotal}');
      debugPrint(
        'DEBUG: Order hasDeliveryAssignment: ${freshOrder?.hasDeliveryAssignment}',
      );
      debugPrint(
        'DEBUG: Order deliveryAssignment: ${freshOrder?.deliveryAssignment}',
      );
      debugPrint(
        'DEBUG: Order deliveryAgentName: ${freshOrder?.deliveryAgentName}',
      );

      if (mounted && freshOrder != null) {
        setState(() {
          _currentOrder = freshOrder;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load order details: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _loadDeliveryManagers() async {
    try {
      final provider = context.read<OrdersProvider>();
      final managers = await provider.apiService.getAvailableDeliveryAgents();

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load delivery managers: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userType = authProvider.user?.userType ?? 'customer';
    final shared = OrderDetailsShared();

    // Use the same logic as _buildOrderDetailsContent to determine user type
    final isDeliveryAdmin =
        userType == 'delivery_admin' || authProvider.isDeliveryAdmin;
    final isLibraryAdmin =
        userType == 'library_admin' || authProvider.isLibraryAdmin;

    // Debug logging to help diagnose user type issues
    debugPrint('OrderDetailsPage: Current userType: $userType');
    debugPrint('OrderDetailsPage: authProvider.user: ${authProvider.user}');
    debugPrint(
      'OrderDetailsPage: authProvider.isDeliveryAdmin: ${authProvider.isDeliveryAdmin}',
    );
    debugPrint(
      'OrderDetailsPage: isDeliveryAdmin (calculated): $isDeliveryAdmin',
    );
    debugPrint(
      'OrderDetailsPage: authProvider.isLibraryAdmin: ${authProvider.isLibraryAdmin}',
    );
    debugPrint(
      'OrderDetailsPage: authProvider.isCustomer: ${authProvider.isCustomer}',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_currentOrder?.id ?? widget.order.id}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Show edit icon for delivery managers to toggle Accept/Reject buttons
          if (isDeliveryAdmin)
            IconButton(
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                });
              },
              icon: Icon(_isEditMode ? Icons.close : Icons.edit),
              tooltip: _isEditMode ? 'Close Actions' : 'Show Actions',
            ),
          // Only show update status button for library admins, not delivery managers
          if (isLibraryAdmin)
            IconButton(
              onPressed: () => _showStatusUpdateDialog(),
              icon: const Icon(Icons.edit),
              tooltip: 'Update Status',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentOrder == null
          ? const Center(child: Text('Order not found'))
          : _buildOrderDetailsContent(authProvider, userType, shared),
    );
  }

  Widget _buildOrderDetailsContent(
    AuthProvider authProvider,
    String userType,
    OrderDetailsShared shared,
  ) {
    // Use multiple checks to ensure correct widget is shown
    // Check both userType string and helper methods for robustness
    final isDeliveryAdmin =
        userType == 'delivery_admin' || authProvider.isDeliveryAdmin;
    final isLibraryAdmin =
        userType == 'library_admin' || authProvider.isLibraryAdmin;
    final isCustomer = userType == 'customer' || authProvider.isCustomer;

    // VERY EXPLICIT DEBUG LOGGING
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('OrderDetailsPage: _buildOrderDetailsContent called');
    debugPrint('OrderDetailsPage: userType from authProvider = "$userType"');
    debugPrint(
      'OrderDetailsPage: authProvider.user?.userType = "${authProvider.user?.userType}"',
    );
    debugPrint(
      'OrderDetailsPage: authProvider.isDeliveryAdmin = ${authProvider.isDeliveryAdmin}',
    );
    debugPrint(
      'OrderDetailsPage: authProvider.isLibraryAdmin = ${authProvider.isLibraryAdmin}',
    );
    debugPrint(
      'OrderDetailsPage: authProvider.isCustomer = ${authProvider.isCustomer}',
    );
    debugPrint(
      'OrderDetailsPage: isDeliveryAdmin (calculated) = $isDeliveryAdmin',
    );
    debugPrint(
      'OrderDetailsPage: isLibraryAdmin (calculated) = $isLibraryAdmin',
    );
    debugPrint('OrderDetailsPage: isCustomer (calculated) = $isCustomer');
    debugPrint('═══════════════════════════════════════════════════════');

    // Route to completely separate widgets based on user type
    // Priority: delivery_admin > library_admin > customer
    if (isDeliveryAdmin) {
      debugPrint(
        '✅ OrderDetailsPage: SELECTED DeliveryManagerOrderDetailsWidget',
      );
      return DeliveryManagerOrderDetailsWidget(
        order: _currentOrder!,
        shared: shared,
        isEditMode: _isEditMode,
        onOrderUpdated: (Order updatedOrder) {
          setState(() {
            _currentOrder = updatedOrder;
          });
        },
      );
    } else if (isLibraryAdmin) {
      debugPrint('✅ OrderDetailsPage: SELECTED AdminOrderDetailsWidget');
      return AdminOrderDetailsWidget(
        order: _currentOrder!,
        shared: shared,
        onOrderUpdated: (Order updatedOrder) {
          setState(() {
            _currentOrder = updatedOrder;
          });
        },
      );
    } else {
      // Customer view (default fallback)
      debugPrint(
        '✅ OrderDetailsPage: SELECTED CustomerOrderDetailsWidget (FALLBACK)',
      );
      return CustomerOrderDetailsWidget(order: _currentOrder!, shared: shared);
    }
  }

  // All unused UI building methods removed - functionality moved to separate widgets

  void _showStatusUpdateDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isDeliveryManager = authProvider.isDeliveryAdmin;
    final isLibraryAdmin = authProvider.isLibraryAdmin;

    // Only show approve/reject dialog for library admins
    if (!isLibraryAdmin && isDeliveryManager) {
      // For delivery managers, show delivery actions instead
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Use the control actions below to manage delivery'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Order Action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What action would you like to take for this order?'),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showApprovalDialog();
                    },
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    label: const Text('Approve'),
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
                      _showRejectDialog();
                    },
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    label: const Text('Reject'),
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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showApprovalDialog() {
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
              const Text(
                'Assign Delivery Manager',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Text(
                'Select a delivery manager to assign this order',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Delivery Manager Selection
              if (_deliveryManagers
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
                          'No delivery managers available',
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
                    _deliveryManagers,
                    _selectedDeliveryManagerId,
                    (value) {
                      setState(() {
                        _selectedDeliveryManagerId = value;
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
                          child: _selectedDeliveryManagerId == null
                              ? Text(
                                  'Choose a delivery manager',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                )
                              : _buildSelectedManagerDisplay(
                                  _deliveryManagers.firstWhere(
                                    (manager) =>
                                        manager['id'] ==
                                        _selectedDeliveryManagerId,
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
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _deliveryManagers
                                  .where(
                                    (manager) =>
                                        manager['is_available'] == true,
                                  )
                                  .isEmpty ||
                              _selectedDeliveryManagerId == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              _approveOrder();
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
                      child: const Text(
                        'Approve Order',
                        style: TextStyle(
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
                manager['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Text(
                '${manager['status'] ?? 'Unknown'} • ${manager['phone'] ?? 'N/A'}',
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

            const Text(
              'Select Delivery Manager',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                  manager['name'] ?? 'Unknown',
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
                                  '${manager['status'] ?? 'Unknown'} • ${manager['phone'] ?? 'N/A'}',
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

  Color _getDeliveryManagerStatusColor(String? status) {
    if (status == null) return Colors.grey;

    switch (status) {
      case 'online':
        return Colors.green;
      case 'available':
        return Colors.green;
      case 'busy':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _approveOrder() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OrdersProvider>();
      final success = await provider.approveOrder(
        int.parse(_currentOrder!.id),
        int.parse(_selectedDeliveryManagerId!),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Order approved successfully! Order sent to delivery.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh order details
          await _fetchOrderDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to approve order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving order: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showRejectDialog() {
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
                _rejectOrder(reasonController.text.trim());
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

  Future<void> _rejectOrder(String reason) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OrdersProvider>();
      final success = await provider.rejectOrder(
        int.parse(_currentOrder!.id),
        reason,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order rejected. Reason: $reason'),
              backgroundColor: Colors.red,
            ),
          );
          // Refresh order details
          await _fetchOrderDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to reject order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting order: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
