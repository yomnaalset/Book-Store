import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../orders/models/order.dart';
import 'clean_order_item_card.dart';
import 'order_details_shared.dart';
import '../providers/orders_provider.dart';

class DeliveryManagerOrderDetailsWidget extends StatefulWidget {
  final Order order;
  final OrderDetailsShared shared;
  final Function(Order) onOrderUpdated;
  final bool isEditMode;

  const DeliveryManagerOrderDetailsWidget({
    super.key,
    required this.order,
    required this.shared,
    required this.onOrderUpdated,
    this.isEditMode = false,
  });

  @override
  State<DeliveryManagerOrderDetailsWidget> createState() =>
      _DeliveryManagerOrderDetailsWidgetState();
}

class _DeliveryManagerOrderDetailsWidgetState
    extends State<DeliveryManagerOrderDetailsWidget> {
  bool _isLoading = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'pending':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _acceptAssignment() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OrdersProvider>();

      // If assignment is not in order object, try to get it from the order
      String? assignmentId;
      if (widget.order.deliveryAssignment != null) {
        assignmentId = widget.order.deliveryAssignment!.id;
      }

      // If still no assignment ID, try to get assignment from order
      if (assignmentId == null || assignmentId.isEmpty) {
        // Refresh order to get assignment
        final freshOrder = await provider.getOrderById(widget.order.id);
        if (freshOrder?.deliveryAssignment != null) {
          assignmentId = freshOrder!.deliveryAssignment!.id;
        }
      }

      if (assignmentId == null || assignmentId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment not found. Please refresh the order.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final success = await provider.acceptAssignment(int.parse(assignmentId));

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment accepted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh order details
          final freshOrder = await provider.getOrderById(widget.order.id);
          if (freshOrder != null) {
            widget.onOrderUpdated(freshOrder);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Failed to accept assignment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting assignment: ${e.toString()}'),
          ),
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

  void _showRejectAssignmentDialog() {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Assignment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for rejecting this delivery assignment:',
            ),
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
              Navigator.pop(context);
              _rejectAssignment(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject Assignment'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectAssignment(String reason) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OrdersProvider>();

      // If assignment is not in order object, try to get it from the order
      String? assignmentId;
      if (widget.order.deliveryAssignment != null) {
        assignmentId = widget.order.deliveryAssignment!.id;
      }

      // If still no assignment ID, try to get assignment from order
      if (assignmentId == null || assignmentId.isEmpty) {
        // Refresh order to get assignment
        final freshOrder = await provider.getOrderById(widget.order.id);
        if (freshOrder?.deliveryAssignment != null) {
          assignmentId = freshOrder!.deliveryAssignment!.id;
        }
      }

      if (assignmentId == null || assignmentId.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment not found. Please refresh the order.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final success = await provider.rejectAssignment(
        int.parse(assignmentId),
        reason: reason.isNotEmpty ? reason : null,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                reason.isNotEmpty
                    ? 'Assignment rejected. Reason: $reason'
                    : 'Assignment rejected successfully',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          // Refresh order details
          final freshOrder = await provider.getOrderById(widget.order.id);
          if (freshOrder != null) {
            widget.onOrderUpdated(freshOrder);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Failed to reject assignment'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting assignment: ${e.toString()}'),
          ),
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

  Future<void> _startDelivery() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OrdersProvider>();
      final success = await provider.startDelivery(int.parse(widget.order.id));

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery started successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh order details
          final freshOrder = await provider.getOrderById(widget.order.id);
          if (freshOrder != null) {
            widget.onOrderUpdated(freshOrder);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start delivery'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting delivery: ${e.toString()}')),
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

  Future<void> _completeDelivery() async {
    // Get provider before async gap
    final provider = context.read<OrdersProvider>();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: const Text(
          'Are you sure you want to mark this order as delivered?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mark as Delivered'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await provider.completeDelivery(
        int.parse(widget.order.id),
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order marked as delivered successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh order details
          final freshOrder = await provider.getOrderById(widget.order.id);
          if (freshOrder != null) {
            widget.onOrderUpdated(freshOrder);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to complete delivery'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing delivery: ${e.toString()}')),
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

  void _showLocationMap() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delivery Tracking'),
        content: const Text(
          'Google Maps integration will be implemented here to show the delivery manager\'s real-time location.',
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

  Widget _buildDeliveryManagerActions() {
    final orderStatus = widget.order.status.toLowerCase().trim();
    final rawStatus = widget.order.status
        .toLowerCase()
        .trim(); // Additional check
    final assignmentStatus =
        widget.order.deliveryAssignment?.status.toLowerCase().trim() ?? '';

    // Check if order has delivery assignment
    final hasAssignment = widget.order.deliveryAssignment != null;

    // Use Order model's helper method for more reliable status checking
    final isAssignedToDelivery = widget.order.isAssignedToDelivery;

    // Debug logging - VERY EXPLICIT
    debugPrint('═══════════════════════════════════════════════════════');
    debugPrint('DeliveryManagerActions: _buildDeliveryManagerActions called');
    debugPrint(
      'DeliveryManagerActions: Raw order.status = "${widget.order.status}"',
    );
    debugPrint(
      'DeliveryManagerActions: orderStatus (lowercase) = "$orderStatus"',
    );
    debugPrint(
      'DeliveryManagerActions: rawStatus (lowercase.trim) = "$rawStatus"',
    );
    debugPrint(
      'DeliveryManagerActions: isWaitingForDeliveryManager = ${widget.order.isWaitingForDeliveryManager}',
    );
    debugPrint(
      'DeliveryManagerActions: isAssignedToDelivery (from model) = $isAssignedToDelivery',
    );
    debugPrint(
      'DeliveryManagerActions: assignmentStatus = "$assignmentStatus"',
    );
    debugPrint('DeliveryManagerActions: hasAssignment = $hasAssignment');
    debugPrint(
      'DeliveryManagerActions: deliveryAssignment = ${widget.order.deliveryAssignment}',
    );

    // Show Accept/Reject buttons if:
    // 1. Order status is "waiting_for_delivery_manager" (as per scenario)
    // 2. OR order status is "assigned_to_delivery" (legacy support)
    // 3. OR order has a delivery assignment AND assignment hasn't been accepted yet
    final assignmentNotAccepted =
        hasAssignment &&
        assignmentStatus != 'accepted' &&
        assignmentStatus != 'in_transit' &&
        assignmentStatus != 'in_progress' &&
        assignmentStatus != 'delivered' &&
        assignmentStatus != 'completed' &&
        assignmentStatus != 'cancelled';

    // Show buttons if:
    // - Order status is "waiting_for_delivery_manager" (primary condition as per scenario)
    // - OR order status is "assigned_to_delivery" (legacy support)
    // - OR has assignment and not accepted yet (fallback for edge cases)
    // - OR assignment status is 'assigned' (initial assignment status from backend)
    // IMPORTANT: Show buttons even if assignment is null, as long as status is waiting_for_delivery_manager
    // Primary condition: Always show buttons if status is waiting_for_delivery_manager
    // This is the main scenario requirement - show buttons regardless of assignment status
    // Check status in multiple ways to ensure we catch it
    final isWaitingStatus =
        widget.order.isWaitingForDeliveryManager ||
        orderStatus == 'waiting_for_delivery_manager' ||
        rawStatus == 'waiting_for_delivery_manager';

    // ALWAYS show buttons if status is waiting_for_delivery_manager (primary scenario requirement)
    // This is the most important condition - it should override everything else
    final shouldShowAcceptReject =
        isWaitingStatus || // PRIMARY: Always show for waiting_for_delivery_manager
        isAssignedToDelivery ||
        assignmentNotAccepted ||
        (hasAssignment &&
            (assignmentStatus == 'assigned' || assignmentStatus == ''));

    debugPrint('DeliveryManagerActions: isWaitingStatus = $isWaitingStatus');
    debugPrint(
      'DeliveryManagerActions: assignmentNotAccepted = $assignmentNotAccepted',
    );
    debugPrint(
      'DeliveryManagerActions: isAssignedToDelivery = $isAssignedToDelivery',
    );
    debugPrint(
      'DeliveryManagerActions: shouldShowAcceptReject = $shouldShowAcceptReject',
    );
    debugPrint('═══════════════════════════════════════════════════════');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            // Show Accept/Reject buttons when order needs acceptance
            // ALWAYS show for orders with status 'waiting_for_delivery_manager' (primary scenario requirement)
            else if (isWaitingStatus || shouldShowAcceptReject) ...[
              // Debug logging
              Builder(
                builder: (context) {
                  debugPrint(
                    'DeliveryManagerActions: Showing Accept/Reject buttons',
                  );
                  debugPrint(
                    '  - shouldShowAcceptReject: $shouldShowAcceptReject',
                  );
                  debugPrint('  - orderStatus: $orderStatus');
                  debugPrint('  - hasAssignment: $hasAssignment');
                  debugPrint(
                    '  - isWaitingForDeliveryManager: ${widget.order.isWaitingForDeliveryManager}',
                  );
                  return const SizedBox.shrink();
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _acceptAssignment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Approve Delivery',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _showRejectAssignmentDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Reject Delivery',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ]
            // Show Start Delivery button when order status is "in_delivery" (after acceptance) or assignment is accepted
            else if (orderStatus == 'in_delivery' ||
                orderStatus == 'delivery_in_progress' ||
                assignmentStatus == 'accepted') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startDelivery,
                  icon: const Icon(Icons.local_shipping, color: Colors.white),
                  label: const Text('Start Delivery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]
            // Show Mark as Delivered button when order status is "in_progress"
            else if (orderStatus == 'in_progress' ||
                orderStatus == 'in_delivery' ||
                assignmentStatus == 'in_transit') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _completeDelivery,
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Mark as Delivered'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showLocationMap,
                  icon: const Icon(Icons.location_on, color: Colors.white),
                  label: const Text('Track Delivery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ] else ...[
              // Show debug info when buttons aren't shown
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'No actions available for this order status',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Status: ${widget.order.status}',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      Text(
                        'isAssignedToDelivery: $isAssignedToDelivery',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                      Text(
                        'hasAssignment: $hasAssignment',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug logging to verify widget is being rendered
    debugPrint('DeliveryManagerOrderDetailsWidget: Building widget');
    debugPrint(
      'DeliveryManagerOrderDetailsWidget: Order ID: ${widget.order.id}',
    );
    debugPrint(
      'DeliveryManagerOrderDetailsWidget: Order Status: ${widget.order.status}',
    );
    debugPrint(
      'DeliveryManagerOrderDetailsWidget: Has Assignment: ${widget.order.hasDeliveryAssignment}',
    );
    debugPrint(
      'DeliveryManagerOrderDetailsWidget: Delivery Assignment: ${widget.order.deliveryAssignment}',
    );

    debugPrint('DeliveryManagerOrderDetailsWidget: Building widget');
    debugPrint(
      'DeliveryManagerOrderDetailsWidget: Order status: ${widget.order.status}',
    );
    debugPrint(
      'DeliveryManagerOrderDetailsWidget: Has delivery assignment: ${widget.order.deliveryAssignment != null}',
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Status Card - Prominent for delivery managers
          widget.shared.buildSectionCard(
            context: context,
            title: 'Order Status',
            icon: Icons.info,
            children: [
              Row(
                children: [
                  const Text(
                    'Current Status: ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(widget.order.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.order.statusDisplay.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              widget.shared.buildInfoRow(
                'Order Number',
                '#ORD-${widget.order.id.toString().padLeft(4, '0')}',
              ),
              widget.shared.buildInfoRow(
                'Order Date',
                widget.shared.formatDate(widget.order.createdAt),
              ),
              widget.shared.buildInfoRow(
                'Last Updated',
                widget.shared.formatDate(widget.order.updatedAt),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Order Summary
          widget.shared.buildSectionCard(
            context: context,
            title: 'Order Summary',
            icon: Icons.shopping_cart,
            children: [
              widget.shared.buildInfoRow(
                'Number of Books',
                '${widget.order.items.length}',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Order Items
          widget.shared.buildSectionCard(
            context: context,
            title: 'Order Items',
            icon: Icons.list,
            children: [
              ...widget.order.items.map(
                (item) => CleanOrderItemCard(item: item),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Customer Information
          widget.shared.buildSectionCard(
            context: context,
            title: 'Customer Information',
            icon: Icons.person,
            children: [
              widget.shared.buildInfoRow('Name', widget.order.customerName),
              widget.shared.buildInfoRow('Email', widget.order.customerEmail),
              if (widget.order.shippingAddress != null) ...[
                widget.shared.buildInfoRow(
                  'Address',
                  widget.order.shippingAddressText ?? 'No address',
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Payment Information
          widget.shared.buildSectionCard(
            context: context,
            title: 'Payment Information',
            icon: Icons.payment,
            children: [
              widget.shared.buildInfoRow(
                'Payment Method',
                widget.shared.getPaymentMethodDisplay(
                  widget.order.paymentMethod,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Approve/Reject Buttons - Show when status is waiting_for_delivery_manager
          Builder(
            builder: (context) {
              final orderStatus = widget.order.status.toLowerCase().trim();
              final isWaiting =
                  widget.order.isWaitingForDeliveryManager ||
                  orderStatus == 'waiting_for_delivery_manager';

              debugPrint(
                '═══════════════════════════════════════════════════════',
              );
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Checking button visibility',
              );
              debugPrint('  - Order status: ${widget.order.status}');
              debugPrint('  - Order status (lowercase): $orderStatus');
              debugPrint(
                '  - isWaitingForDeliveryManager: ${widget.order.isWaitingForDeliveryManager}',
              );
              debugPrint('  - isWaiting: $isWaiting');
              debugPrint('  - isCancelled: ${widget.order.isCancelled}');
              debugPrint(
                '  - Will show buttons: ${!widget.order.isCancelled && isWaiting}',
              );
              debugPrint(
                '═══════════════════════════════════════════════════════',
              );

              if (!widget.order.isCancelled && isWaiting) {
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delivery Actions',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator())
                        else
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _acceptAssignment,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Approve Delivery',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _showRejectAssignmentDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Reject Delivery',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
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
              return const SizedBox.shrink();
            },
          ),

          const SizedBox(height: 24),

          // Delivery Manager Action Buttons (for other statuses)
          if (!widget.order.isCancelled) _buildDeliveryManagerActions(),
        ],
      ),
    );
  }
}
