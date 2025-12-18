import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/orders_provider.dart';
import '../../../../orders/models/order.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../../../core/localization/app_localizations.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _isLoading = false;
  Order? _currentOrder;
  List<Map<String, dynamic>> _deliveryManagers = [];
  String? _selectedDeliveryManagerId;

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
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_currentOrder?.id ?? widget.order.id}'),
        actions: [
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Header
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.shopping_cart,
                            size: 64,
                            color: Colors.blue,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Order #${_currentOrder!.id}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          StatusChip(status: _currentOrder!.status),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Customer Information
                  _buildSectionCard(
                    title: 'Customer Information',
                    icon: Icons.person,
                    children: [
                      _buildInfoRow('Name', _currentOrder!.customerName),
                      _buildInfoRow('Email', _currentOrder!.customerEmail),
                      if (_currentOrder!.shippingAddress != null) ...[
                        _buildInfoRow(
                          'Shipping Address',
                          _currentOrder!.shippingAddressText ?? 'No address',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Order Items
                  _buildSectionCard(
                    title: 'Order Items',
                    icon: Icons.inventory,
                    children: [
                      ..._currentOrder!.items.map(
                        (item) => _buildOrderItemCard(item),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Payment Information
                  _buildSectionCard(
                    title: 'Payment Information',
                    icon: Icons.payment,
                    children: [
                      _buildInfoRow(
                        'Payment Method',
                        _currentOrder!.paymentMethod ?? 'Not specified',
                      ),
                      _buildInfoRow(
                        'Payment Status',
                        _currentOrder!.paymentStatus ?? 'Pending',
                      ),
                      _buildInfoRow(
                        'Subtotal',
                        '\$${_currentOrder!.totalAmount.toStringAsFixed(2)}',
                      ),
                      if (_currentOrder!.discountCode != null) ...[
                        _buildInfoRow(
                          'Discount Code',
                          _currentOrder!.discountCode ?? '',
                        ),
                        if (_currentOrder!.discountAmount != null) ...[
                          _buildInfoRow(
                            'Discount Amount',
                            '\$${_currentOrder!.discountAmount}',
                          ),
                        ],
                      ],
                      _buildInfoRow(
                        'Total Amount',
                        '\$${_currentOrder!.totalAmount.toStringAsFixed(2)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Order Timeline
                  _buildSectionCard(
                    title: 'Order Timeline',
                    icon: Icons.timeline,
                    children: [
                      _buildInfoRow(
                        'Order Date',
                        _formatDate(_currentOrder!.createdAt),
                      ),
                      ...[
                        _buildInfoRow(
                          'Last Updated',
                          _formatDate(_currentOrder!.updatedAt),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showStatusUpdateDialog(),
                          icon: const Icon(Icons.edit),
                          label: const Text('Update Status'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItemCard(OrderItem item) {
    // Get book image URL from either book object or snapshot
    final String? imageUrl = item.book.primaryImageUrl ?? item.bookImage;

    // Get book title from either book object or snapshot
    final String bookTitle = item.book.title;

    // Get author name from either book object or snapshot
    final String? authorName = item.book.author?.name ?? item.bookAuthor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            // Book cover image or placeholder
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.book,
                            color: Colors.grey,
                            size: 30,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
                    )
                  : const Icon(Icons.book, color: Colors.grey, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (authorName != null && authorName.isNotEmpty) ...[
                    Text(
                      'by $authorName',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Qty: ${item.quantity}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Price: \$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Total: \$${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  if (item.isBorrowed) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Borrowed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
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
                        _showApprovalDialog();
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
                        _showRejectDialog();
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
        );
      },
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
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _selectedDeliveryManagerId == null
                              ? Text(
                                  'Choose a delivery manager',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
            color: _getStatusColor(manager['status']),
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
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
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
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
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
                              : Theme.of(context).colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        color: selectedId == manager['id']
                            ? Colors.green.withValues(alpha: 0.1)
                            : Theme.of(context).colorScheme.surface,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _getStatusColor(manager['status']),
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
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${manager['status'] ?? 'Unknown'} • ${manager['phone'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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

  Color _getStatusColor(String? status) {
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
        if (success != null && success['success'] == true) {
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
