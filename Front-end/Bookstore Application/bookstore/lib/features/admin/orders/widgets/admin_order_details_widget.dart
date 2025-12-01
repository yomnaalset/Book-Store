import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../orders/models/order.dart';
import '../../../orders/models/order_note.dart';
import 'clean_order_item_card.dart';
import 'order_details_shared.dart';
import '../providers/orders_provider.dart';
import 'delivery_location_map_widget.dart';
import '../../models/delivery_agent.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';

class AdminOrderDetailsWidget extends StatefulWidget {
  final Order order;
  final OrderDetailsShared shared;
  final Function(Order) onOrderUpdated;

  const AdminOrderDetailsWidget({
    super.key,
    required this.order,
    required this.shared,
    required this.onOrderUpdated,
  });

  @override
  State<AdminOrderDetailsWidget> createState() =>
      _AdminOrderDetailsWidgetState();
}

class _AdminOrderDetailsWidgetState extends State<AdminOrderDetailsWidget> {
  bool _isLoading = false;

  bool _shouldShowAssignButton() {
    if (widget.order.isCancelled) return false;
    return widget.order.isConfirmed &&
        !widget.order.hasDeliveryAssignment &&
        !widget.order.isInDelivery &&
        !widget.order.isDelivered &&
        !widget.order.isAssignedToDelivery;
  }

  bool _shouldShowApproveRejectButtons() {
    // Show approve/reject buttons when order status is "pending" (Pending Review)
    return widget.order.isPending && !widget.order.isCancelled;
  }

  bool _shouldShowDeliveryManagerInfo() {
    return widget.order.deliveryAgentName.isNotEmpty ||
        (widget.order.deliveryAssignment != null &&
            widget.order.deliveryAssignment!.deliveryManagerName.isNotEmpty);
  }

  Widget _buildDeliveryManagerInfo() {
    if (widget.order.deliveryAssignment == null) {
      return const Center(
        child: Text(
          'No delivery manager information available',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.shared.buildCustomerDetailRow(
          'Full Name',
          widget.order.deliveryAgentName.isNotEmpty
              ? widget.order.deliveryAgentName
              : 'Not provided',
          Icons.person_outline,
        ),
        widget.shared.buildCustomerDetailRow(
          'Phone Number',
          widget.order.deliveryAssignment!.deliveryManager?.phone ??
              'Not provided',
          Icons.phone,
        ),
        widget.shared.buildCustomerDetailRow(
          'Email',
          widget.order.deliveryAssignment!.deliveryManager?.email ??
              'Not provided',
          Icons.email,
        ),
        if (widget.order.deliveryNotes != null &&
            widget.order.deliveryNotes!.isNotEmpty) ...[
          widget.shared.buildCustomerDetailRow(
            'Delivery Notes',
            widget.order.deliveryNotes!,
            Icons.note,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1 - Order Details
          widget.shared.buildSectionCard(
            context: context,
            title: 'Order Details',
            icon: Icons.shopping_cart,
            children: [
              widget.shared.buildInfoRow(
                'Order Number',
                '#ORD-${widget.order.id.toString().padLeft(4, '0')}',
              ),
              widget.shared.buildInfoRow(
                'Creation Date',
                widget.shared.formatDate(widget.order.createdAt),
              ),
              widget.shared.buildInfoRow(
                'Current Status',
                widget.order.statusDisplay,
              ),
              widget.shared.buildInfoRow(
                'Number of Books',
                '${widget.order.items.length}',
              ),
              widget.shared.buildInfoRow(
                'Subtotal',
                '\$${widget.order.subtotal.toStringAsFixed(2)}',
              ),
              if (widget.shared.hasEffectiveDiscount(widget.order)) ...[
                widget.shared.buildInfoRow(
                  'Discount',
                  '-\$${(widget.order.subtotal - widget.order.totalAmount).toStringAsFixed(2)}',
                  isHighlighted: true,
                  textColor: Colors.red,
                ),
              ],
              if (widget.order.shippingCost > 0) ...[
                widget.shared.buildInfoRow(
                  'Delivery Cost',
                  '\$${widget.order.shippingCost.toStringAsFixed(2)}',
                ),
              ],
              // Always show tax if it exists (even if 0, as it might be calculated)
              widget.shared.buildInfoRow(
                'Tax',
                '\$${widget.order.taxAmount.toStringAsFixed(2)}',
              ),
              widget.shared.buildInfoRow(
                'Total Amount',
                '\$${widget.order.totalAmount.toStringAsFixed(2)}',
                isHighlighted: true,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2 - Customer Information
          widget.shared.buildSectionCard(
            context: context,
            title: 'Customer Information',
            icon: Icons.person,
            children: [
              widget.shared.buildCustomerDetailRow(
                'Full Name',
                widget.order.customerName,
                Icons.person_outline,
              ),
              widget.shared.buildCustomerDetailRow(
                'Phone Number',
                widget.order.customerPhone.isNotEmpty
                    ? widget.order.customerPhone
                    : 'Not provided',
                Icons.phone,
              ),
              widget.shared.buildCustomerDetailRow(
                'Email',
                widget.order.customerEmail,
                Icons.email,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 3 - Payment Information
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
              widget.shared.buildInfoRow(
                'Payment Status',
                widget.shared.getPaymentStatusDisplay(
                  widget.order.paymentStatus,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 4 - Delivery Manager (Admin can assign)
          if (!widget.order.isCancelled) ...[
            widget.shared.buildSectionCard(
              context: context,
              title: 'Assigned Delivery Manager',
              icon: Icons.local_shipping,
              children: [
                if (_shouldShowDeliveryManagerInfo()) ...[
                  _buildDeliveryManagerInfo(),
                ] else if (!_shouldShowAssignButton()) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Delivery manager will be assigned soon',
                        style: TextStyle(
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Column(
                    children: [
                      const Center(
                        child: Text(
                          'No delivery manager assigned yet',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Assign delivery manager functionality',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.person_add),
                        label: const Text('Assign Delivery Manager'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
          if (!widget.order.isCancelled) const SizedBox(height: 16),

          // Order Items Section
          widget.shared.buildSectionCard(
            context: context,
            title: 'Order Items',
            icon: Icons.inventory,
            children: [
              ...widget.order.items.map(
                (item) => CleanOrderItemCard(item: item),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Additional Notes Section
          _buildNotesSection(),

          // Admin Actions Section
          if (_shouldShowApproveRejectButtons()) _buildAdminActions(),

          // View Delivery Location Button (when status is "in_delivery")
          if (widget.order.isInDelivery && !widget.order.isCancelled)
            _buildViewDeliveryLocationButton(),
        ],
      ),
    );
  }

  Widget _buildAdminActions() {
    return widget.shared.buildSectionCard(
      context: context,
      title: 'Admin Actions',
      icon: Icons.admin_panel_settings,
      children: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showApproveDialog,
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Approve Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showRejectDialog,
                  icon: const Icon(Icons.cancel, color: Colors.white),
                  label: const Text('Reject Order'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildViewDeliveryLocationButton() {
    return widget.shared.buildSectionCard(
      context: context,
      title: 'Delivery Tracking',
      icon: Icons.location_on,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _viewDeliveryLocation,
            icon: const Icon(Icons.map, color: Colors.white),
            label: const Text('View Delivery Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showApproveDialog() async {
    // Load available delivery managers
    try {
      final provider = context.read<OrdersProvider>();
      final managers = await provider.apiService.getAvailableDeliveryAgents();

      if (managers.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No delivery managers available'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Show delivery manager selection dialog
      if (mounted) {
        _showDeliveryManagerSelectionDialog(managers);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading delivery managers: ${e.toString()}'),
          ),
        );
      }
    }
  }

  void _showDeliveryManagerSelectionDialog(List<DeliveryAgent> managers) {
    String? selectedManagerId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF28A745).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF28A745),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select Delivery Manager',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Delivery Manager Selection
                const Text(
                  'Select a delivery manager for this request:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF495057),
                  ),
                ),
                const SizedBox(height: 16),

                // Delivery Manager List
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: managers.length,
                    itemBuilder: (context, index) {
                      final manager = managers[index];
                      final managerId = manager.id.toString();
                      final isAvailable =
                          manager.isOnlineStatus && manager.isAvailable;
                      final statusColor = manager.statusColor;
                      final statusText = manager.statusDisplay;
                      final isSelected = selectedManagerId == managerId;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isAvailable
                                ? () {
                                    setState(() {
                                      selectedManagerId = managerId;
                                    });
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFF28A745,
                                      ).withValues(alpha: 0.1)
                                    : isAvailable
                                    ? Colors.white
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF28A745)
                                      : isAvailable
                                      ? const Color(0xFFE9ECEF)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Status Indicator
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Manager Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          manager.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isAvailable
                                                ? Colors.black
                                                : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              _getStatusIcon(statusText),
                                              size: 14,
                                              color: statusColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: statusColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Selection Indicator
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF28A745),
                                      size: 20,
                                    )
                                  else if (!isAvailable)
                                    const Icon(
                                      Icons.block,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedManagerId != null
                            ? () {
                                Navigator.of(context).pop();
                                _approveOrder(int.parse(selectedManagerId!));
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getStatusIcon(String statusText) {
    switch (statusText.toLowerCase()) {
      case 'online':
        return Icons.wifi;
      case 'busy':
        return Icons.local_shipping;
      case 'offline':
        return Icons.wifi_off;
      default:
        return Icons.help_outline;
    }
  }

  Future<void> _approveOrder(int deliveryManagerId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OrdersProvider>();
      final success = await provider.approveOrder(
        int.parse(widget.order.id),
        deliveryManagerId,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order approved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh order details
          final updatedOrder = await provider.getOrderById(
            int.parse(widget.order.id),
          );
          if (updatedOrder != null) {
            widget.onOrderUpdated(updatedOrder);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Failed to approve order'),
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
        int.parse(widget.order.id),
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
          final updatedOrder = await provider.getOrderById(
            int.parse(widget.order.id),
          );
          if (updatedOrder != null) {
            widget.onOrderUpdated(updatedOrder);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Failed to reject order'),
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

  Future<void> _viewDeliveryLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OrdersProvider>();
      final locationData = await provider.getOrderDeliveryLocation(
        int.parse(widget.order.id),
      );

      if (mounted) {
        if (locationData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryLocationMapWidget(
                order: widget.order,
                locationData: locationData,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.error ?? 'Failed to get delivery location',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildNotesSection() {
    return widget.shared.buildSectionCard(
      context: context,
      title: 'Additional Notes',
      icon: Icons.note,
      children: [
        // Display notes if available
        if (widget.order.hasNotes) ...[
          // Display list of notes with author information
          ...widget.order.notesList.map((note) => _buildNoteCard(note)),
          const SizedBox(height: AppDimensions.spacingM),
        ] else if (widget.order.notes != null &&
            widget.order.notes!.isNotEmpty) ...[
          // Fallback: Show legacy notes if new notes list is empty but legacy field has content
          _buildNoteCard(
            OrderNote(
              id: 0,
              content: widget.order.notes!,
              createdAt: widget.order.updatedAt,
              updatedAt: widget.order.updatedAt,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
        ],
        // Show message if no notes and user can add notes
        if (!widget.order.hasNotes &&
            (widget.order.notes == null || widget.order.notes!.isEmpty))
          const Padding(
            padding: EdgeInsets.all(AppDimensions.paddingM),
            child: Text(
              'No notes yet. Add a note to track important information about this order.',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeS,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        // Show Add Note button only if order is not delivered
        if (!_isDeliveryComplete() && (widget.order.canEditNotes ?? true))
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addNotes,
              icon: const Icon(Icons.add),
              label: const Text('Add Note'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.paddingM,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Check if order delivery is complete (order cannot be modified after delivery)
  bool _isDeliveryComplete() {
    return widget.order.isDelivered;
  }

  /// Safely show a SnackBar, checking if the widget is still mounted
  void _showSnackBarSafely(String message, Color backgroundColor) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
    } catch (e) {
      // Widget was disposed, ignore
      debugPrint('Error showing SnackBar: $e');
    }
  }

  Widget _buildNoteCard(OrderNote note) {
    final dateFormat =
        '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year} ${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note content
          Text(
            note.content,
            style: const TextStyle(fontSize: AppDimensions.fontSizeM),
            overflow: TextOverflow.visible,
            softWrap: true,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          // Author and timestamp info - stacked vertically for better spacing
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author info
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${note.authorDisplayName} (${note.authorTypeDisplay})',
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Timestamp info
              Row(
                children: [
                  const Icon(
                    Icons.access_time,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateFormat,
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeS,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Edit/Delete buttons if user is the author of this note and order is not delivered
          if ((note.canEdit ?? false) && !_isDeliveryComplete()) ...[
            const SizedBox(height: AppDimensions.spacingS),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _editNote(note),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.paddingS,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _deleteNote(note),
                    icon: const Icon(Icons.delete_outlined, size: 16),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.paddingS,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _addNotes() {
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Notes'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter notes about this order...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          controller: notesController,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isEmpty) {
                // Use dialog context for validation message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter some notes'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // Get providers before async operations using widget's context
              if (!mounted) return;
              final provider = Provider.of<OrdersProvider>(
                context,
                listen: false,
              );

              // Show loading indicator using widget's context
              _showSnackBarSafely('Adding notes...', AppColors.primary);

              final success = await provider.addOrderNotes(
                widget.order.id,
                notes,
              );

              if (!mounted) return;

              if (success) {
                // Reload order to get updated notes with author info
                final updatedOrder = await provider.getOrderById(
                  int.parse(widget.order.id),
                );
                if (updatedOrder != null) {
                  widget.onOrderUpdated(updatedOrder);
                }

                _showSnackBarSafely(
                  'Note added successfully',
                  AppColors.success,
                );
              } else {
                _showSnackBarSafely(
                  provider.error ?? 'Failed to add notes',
                  AppColors.error,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editNote(OrderNote note) {
    final TextEditingController notesController = TextEditingController(
      text: note.content,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter note content...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          controller: notesController,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isEmpty) {
                // Use dialog context for validation message
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter some note content'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // Get providers before async operations using widget's context
              if (!mounted) return;
              final provider = Provider.of<OrdersProvider>(
                context,
                listen: false,
              );

              // Show loading indicator using widget's context
              _showSnackBarSafely('Updating note...', AppColors.primary);

              // Use editOrderNotes with note_id
              final success = await provider.editOrderNotes(
                widget.order.id,
                notes,
                noteId: note.id,
              );

              if (!mounted) return;

              if (success) {
                // Reload order to get updated notes
                final updatedOrder = await provider.getOrderById(
                  int.parse(widget.order.id),
                );
                if (updatedOrder != null) {
                  widget.onOrderUpdated(updatedOrder);
                }
                _showSnackBarSafely(
                  'Note updated successfully',
                  AppColors.success,
                );
              } else {
                _showSnackBarSafely(
                  provider.error ?? 'Failed to update note',
                  AppColors.error,
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteNote(OrderNote note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Get providers before async operations using widget's context
              if (!mounted) return;
              final provider = Provider.of<OrdersProvider>(
                context,
                listen: false,
              );

              // Show loading indicator using widget's context
              _showSnackBarSafely('Deleting note...', AppColors.primary);

              // Use deleteOrderNotes with note_id
              final success = await provider.deleteOrderNotes(
                widget.order.id,
                noteId: note.id,
              );

              if (!mounted) return;

              if (success) {
                // Reload order to get updated notes
                final updatedOrder = await provider.getOrderById(
                  int.parse(widget.order.id),
                );
                if (updatedOrder != null) {
                  widget.onOrderUpdated(updatedOrder);
                }
                _showSnackBarSafely(
                  'Note deleted successfully',
                  AppColors.success,
                );
              } else {
                _showSnackBarSafely(
                  provider.error ?? 'Failed to delete note',
                  AppColors.error,
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
