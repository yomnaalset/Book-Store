import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../orders/models/order.dart';
import '../../../orders/models/order_note.dart';
import 'clean_order_item_card.dart';
import 'order_details_shared.dart';
import '../providers/orders_provider.dart';
import '../../models/delivery_agent.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../delivery_manager/providers/delivery_status_provider.dart';

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
    final localizations = AppLocalizations.of(context);
    if (widget.order.deliveryAssignment == null) {
      return Center(
        child: Text(
          localizations.noDeliveryManagerInformationAvailable,
          style: const TextStyle(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.shared.buildCustomerDetailRow(
          localizations.fullName,
          widget.order.deliveryAgentName.isNotEmpty
              ? widget.order.deliveryAgentName
              : localizations.notProvided,
          Icons.person_outline,
        ),
        widget.shared.buildCustomerDetailRow(
          localizations.phoneNumber,
          (widget.order.deliveryAssignment!.deliveryManager?.phone != null &&
                  widget
                      .order
                      .deliveryAssignment!
                      .deliveryManager!
                      .phone
                      .isNotEmpty)
              ? widget.order.deliveryAssignment!.deliveryManager!.phone
              : localizations.unavailable,
          Icons.phone,
        ),
        widget.shared.buildCustomerDetailRow(
          localizations.email,
          widget.order.deliveryAssignment!.deliveryManager?.email ??
              localizations.notProvided,
          Icons.email,
        ),
        if (widget.order.deliveryNotes != null &&
            widget.order.deliveryNotes!.isNotEmpty) ...[
          widget.shared.buildCustomerDetailRow(
            localizations.notes,
            widget.order.deliveryNotes!,
            Icons.note,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1 - Order Details
          widget.shared.buildSectionCard(
            context: context,
            title: localizations.orderDetails,
            icon: Icons.shopping_cart,
            children: [
              widget.shared.buildInfoRow(
                localizations.orderNumber,
                '#ORD-${widget.order.id.toString().padLeft(4, '0')}',
              ),
              widget.shared.buildInfoRow(
                localizations.creationDate,
                widget.shared.formatDate(widget.order.createdAt),
              ),
              widget.shared.buildInfoRow(
                localizations.currentStatus,
                localizations.getOrderStatusLabel(widget.order.status),
              ),
              widget.shared.buildInfoRow(
                localizations.numberOfBooks,
                '${widget.order.items.fold(0, (sum, item) => sum + item.quantity)}',
              ),
              widget.shared.buildInfoRow(
                localizations.subtotal,
                '\$${widget.order.subtotal.toStringAsFixed(2)}',
              ),
              if (widget.shared.hasEffectiveDiscount(widget.order)) ...[
                widget.shared.buildInfoRow(
                  localizations.discount,
                  '-\$${(widget.order.subtotal - widget.order.totalAmount).toStringAsFixed(2)}',
                  isHighlighted: true,
                  textColor: Colors.red,
                ),
              ],
              if (widget.order.deliveryCost > 0) ...[
                widget.shared.buildInfoRow(
                  localizations.deliveryCost,
                  '\$${widget.order.deliveryCost.toStringAsFixed(2)}',
                ),
              ],
              // Always show tax if it exists (even if 0, as it might be calculated)
              widget.shared.buildInfoRow(
                localizations.tax,
                '\$${widget.order.taxAmount.toStringAsFixed(2)}',
              ),
              widget.shared.buildInfoRow(
                localizations.totalAmount,
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
            title: localizations.customerInformation,
            icon: Icons.person,
            children: [
              widget.shared.buildCustomerDetailRow(
                localizations.fullName,
                widget.order.customerName,
                Icons.person_outline,
              ),
              widget.shared.buildCustomerDetailRow(
                localizations.phoneNumber,
                widget.order.customerPhone.isNotEmpty
                    ? widget.order.customerPhone
                    : localizations.notProvided,
                Icons.phone,
              ),
              widget.shared.buildCustomerDetailRow(
                localizations.email,
                widget.order.customerEmail,
                Icons.email,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 3 - Payment Information
          widget.shared.buildSectionCard(
            context: context,
            title: localizations.paymentInformation,
            icon: Icons.payment,
            children: [
              widget.shared.buildInfoRow(
                localizations.paymentMethod,
                widget.shared.getPaymentMethodDisplay(
                  widget.order.paymentMethod,
                  context,
                ),
              ),
              widget.shared.buildInfoRow(
                localizations.paymentStatus,
                widget.shared.getPaymentStatusDisplay(
                  widget.order.paymentStatus,
                  context,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 4 - Delivery Manager (Admin can assign)
          if (!widget.order.isCancelled) ...[
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return widget.shared.buildSectionCard(
                  context: context,
                  title: localizations.assignedDeliveryManager,
                  icon: Icons.local_shipping,
                  children: [
                    if (_shouldShowDeliveryManagerInfo()) ...[
                      _buildDeliveryManagerInfo(),
                    ] else if (!_shouldShowAssignButton()) ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            localizations.deliveryManagerWillBeAssignedSoon,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Column(
                        children: [
                          Center(
                            child: Text(
                              localizations.noDeliveryManagerAssignedYet,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              _showApproveDialog();
                            },
                            icon: const Icon(Icons.person_add),
                            label: Text(localizations.assignDeliveryManager),
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
                );
              },
            ),
          ],
          if (!widget.order.isCancelled) const SizedBox(height: 16),

          // Order Items Section
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return widget.shared.buildSectionCard(
                context: context,
                title: localizations.orderItems,
                icon: Icons.inventory,
                children: [
                  ...widget.order.items.map(
                    (item) => CleanOrderItemCard(item: item),
                  ),
                ],
              );
            },
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
    final localizations = AppLocalizations.of(context);
    return widget.shared.buildSectionCard(
      context: context,
      title: localizations.adminActions,
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
                  label: Text(localizations.approveOrder),
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
                  label: Text(localizations.rejectOrder),
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
    final localizations = AppLocalizations.of(context);
    return widget.shared.buildSectionCard(
      context: context,
      title: localizations.deliveryTracking,
      icon: Icons.location_on,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _viewDeliveryLocation,
            icon: const Icon(Icons.map, color: Colors.white),
            label: Text(localizations.viewDeliveryLocation),
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
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.noDeliveryManagersAvailable),
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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.errorLoadingDeliveryManagers(e.toString()),
            ),
          ),
        );
      }
    }
  }

  void _showDeliveryManagerSelectionDialog(List<DeliveryAgent> managers) {
    String? selectedManagerId;

    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return StatefulBuilder(
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
                      Expanded(
                        child: Text(
                          localizations.selectDeliveryManager,
                          style: const TextStyle(
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
                  Text(
                    localizations.selectADeliveryManagerForThisRequest,
                    style: const TextStyle(
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
                        final rawStatusText = manager.statusDisplay;
                        final statusText = _getLocalizedStatus(
                          rawStatusText,
                          localizations,
                        );
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
                          child: Text(localizations.cancel),
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
                          child: Text(localizations.approve),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getLocalizedStatus(
    String statusText,
    AppLocalizations localizations,
  ) {
    switch (statusText.toLowerCase()) {
      case 'online':
        return localizations.online;
      case 'busy':
        return localizations.busy;
      case 'offline':
        return localizations.offline;
      default:
        return statusText;
    }
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
        final localizations = AppLocalizations.of(context);
        if (success != null && success['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.orderApprovedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );

          // CRITICAL: Update order immediately from response data
          // The response contains the updated order with assignment status
          if (success['order'] != null) {
            try {
              final orderData = success['order'] as Map<String, dynamic>;
              final updatedOrder = Order.fromJson(orderData);
              widget.onOrderUpdated(updatedOrder);
              debugPrint(
                'AdminOrderDetailsWidget: Updated order from approval response',
              );
            } catch (e) {
              debugPrint(
                'AdminOrderDetailsWidget: Error parsing order from response: $e',
              );
              // Fallback: Fetch from server
              final updatedOrder = await provider.getOrderById(
                int.parse(widget.order.id),
              );
              if (updatedOrder != null) {
                widget.onOrderUpdated(updatedOrder);
              }
            }
          } else {
            // Fallback: Fetch from server if order not in response
            final updatedOrder = await provider.getOrderById(
              int.parse(widget.order.id),
            );
            if (updatedOrder != null) {
              widget.onOrderUpdated(updatedOrder);
            }
          }

          // CRITICAL: Refresh delivery manager status from server
          // This ensures the UI reflects the actual server state
          if (mounted) {
            try {
              final statusProvider = context.read<DeliveryStatusProvider>();
              await statusProvider.loadCurrentStatus();
              debugPrint(
                'AdminOrderDetailsWidget: Refreshed delivery manager status after approval',
              );
            } catch (e) {
              debugPrint(
                'AdminOrderDetailsWidget: Error refreshing delivery status: $e',
              );
              // Non-critical error - don't show to user
            }
          }

          // Force a rebuild to update button visibility
          if (mounted) {
            setState(() {});
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.error ?? localizations.failedToApproveOrder,
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

  void _showRejectDialog() {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
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
                  _rejectOrder(reasonController.text.trim());
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
        );
      },
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
        final localizations = AppLocalizations.of(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.orderRejectedReason(reason)),
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
              content: Text(
                provider.error ?? localizations.failedToRejectOrder,
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
          final location = locationData['location'] as Map<String, dynamic>?;
          final latitude = location?['latitude'] as double?;
          final longitude = location?['longitude'] as double?;

          if (latitude != null && longitude != null) {
            await _launchGoogleMaps(latitude, longitude);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Delivery manager location is not available at the moment.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.error ?? localizations.failedToGetDeliveryLocation,
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
          SnackBar(content: Text('${localizations.error}: ${e.toString()}')),
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

  /// Launch Google Maps with the given coordinates
  Future<void> _launchGoogleMaps(double latitude, double longitude) async {
    try {
      // Try multiple URL schemes in order of preference
      final urls = [
        // Google Maps app (Android) - navigation mode
        Uri.parse('google.navigation:q=$latitude,$longitude'),
        // Google Maps app (Android/iOS) - search mode
        Uri.parse('comgooglemaps://?q=$latitude,$longitude'),
        // Geo scheme (Android) - opens default maps app
        Uri.parse('geo:$latitude,$longitude'),
        // Google Maps web URL (always works as fallback)
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        ),
      ];

      bool launched = false;
      for (final url in urls) {
        try {
          // Try to launch directly - canLaunchUrl can be unreliable
          await launchUrl(url, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        } catch (e) {
          // Try next URL if this one fails
          debugPrint('Failed to launch URL $url: $e');
          continue;
        }
      }

      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open maps application.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildNotesSection() {
    final localizations = AppLocalizations.of(context);
    return widget.shared.buildSectionCard(
      context: context,
      title: localizations.additionalNotes,
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
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Text(
              localizations.noNotesYet,
              style: const TextStyle(
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
              label: Text(localizations.addNote),
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

  String _getLocalizedAuthorType(
    String? authorType,
    AppLocalizations localizations,
  ) {
    switch (authorType?.toLowerCase()) {
      case 'customer':
        return localizations.customer;
      case 'library_admin':
        return localizations.admin;
      case 'delivery_admin':
        return localizations.deliveryManager;
      default:
        return authorType ?? localizations.unknown;
    }
  }

  Widget _buildNoteCard(OrderNote note) {
    final dateFormat =
        '${note.createdAt.day}/${note.createdAt.month}/${note.createdAt.year} ${note.createdAt.hour}:${note.createdAt.minute.toString().padLeft(2, '0')}';

    return Builder(
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        final localizedAuthorType = _getLocalizedAuthorType(
          note.authorType,
          localizations,
        );

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
                          '${note.authorDisplayName} ($localizedAuthorType)',
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
                Builder(
                  builder: (editContext) {
                    final editLocalizations = AppLocalizations.of(editContext);
                    return Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () => _editNote(note),
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: Text(editLocalizations.edit),
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
                            label: Text(editLocalizations.delete),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.paddingS,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _addNotes() {
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.addNotes),
          content: TextField(
            decoration: InputDecoration(
              hintText: localizations.enterNotesAboutThisOrder,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            controller: notesController,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () async {
                final notes = notesController.text.trim();
                if (notes.isEmpty) {
                  // Use dialog context for validation message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.pleaseEnterSomeNotes),
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
                _showSnackBarSafely(
                  localizations.addingNotes,
                  AppColors.primary,
                );

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
                    localizations.noteAddedSuccessfully,
                    AppColors.success,
                  );
                } else {
                  _showSnackBarSafely(
                    provider.error ?? localizations.failedToAddNotes,
                    AppColors.error,
                  );
                }
              },
              child: Text(localizations.save),
            ),
          ],
        );
      },
    );
  }

  void _editNote(OrderNote note) {
    final TextEditingController notesController = TextEditingController(
      text: note.content,
    );

    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.editNote),
          content: TextField(
            decoration: InputDecoration(
              hintText: localizations.enterNoteContent,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
            controller: notesController,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () async {
                final notes = notesController.text.trim();
                if (notes.isEmpty) {
                  // Use dialog context for validation message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.pleaseEnterSomeNotes),
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
                _showSnackBarSafely(
                  localizations.updatingNote,
                  AppColors.primary,
                );

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
                    localizations.noteUpdatedSuccessfully,
                    AppColors.success,
                  );
                } else {
                  _showSnackBarSafely(
                    provider.error ?? localizations.failedToUpdateNote,
                    AppColors.error,
                  );
                }
              },
              child: Text(localizations.save),
            ),
          ],
        );
      },
    );
  }

  void _deleteNote(OrderNote note) {
    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.deleteNote),
          content: Text(localizations.confirmDeleteNote),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(localizations.cancel),
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
                final localizations = AppLocalizations.of(context);
                _showSnackBarSafely(
                  localizations.deletingNote,
                  AppColors.primary,
                );

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
                    localizations.noteDeletedSuccessfully,
                    AppColors.success,
                  );
                } else {
                  _showSnackBarSafely(
                    provider.error ?? localizations.failedToDeleteNote,
                    AppColors.error,
                  );
                }
              },
              child: Text(
                localizations.delete,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }
}
