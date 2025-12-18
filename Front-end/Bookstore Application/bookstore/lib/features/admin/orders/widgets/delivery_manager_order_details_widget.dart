import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../orders/models/order.dart';
import 'clean_order_item_card.dart';
import 'order_details_shared.dart';
import '../providers/orders_provider.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../delivery_manager/providers/delivery_status_provider.dart';
import 'package:readgo/features/auth/providers/auth_provider.dart';

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
      final authProvider = context.read<AuthProvider>();

      // Get current delivery manager ID
      final deliveryManagerId = authProvider.user?.id;
      if (deliveryManagerId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User ID not found. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Call PATCH /api/delivery/orders/{id}/approve/
      final result = await provider.approveOrder(
        int.parse(widget.order.id),
        deliveryManagerId,
      );

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        if (result != null && result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.orderApprovedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );

          // CRITICAL: Always call GET /orders/{id}/ immediately after success
          // This ensures we have the latest orderStatus from the server
          try {
            final freshOrder = await provider.getOrderById(widget.order.id);
            if (freshOrder != null) {
              widget.onOrderUpdated(freshOrder);
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Fetched fresh order after approve - Status: ${freshOrder.status}',
              );
            }
          } catch (e) {
            debugPrint(
              'DeliveryManagerOrderDetailsWidget: Error fetching order after approve: $e',
            );
            // Try to use order from response as fallback
            if (result['order'] != null) {
              try {
                final orderData = result['order'] as Map<String, dynamic>;
                final updatedOrder = Order.fromJson(orderData);
                widget.onOrderUpdated(updatedOrder);
              } catch (parseError) {
                debugPrint(
                  'DeliveryManagerOrderDetailsWidget: Error parsing order from response: $parseError',
                );
              }
            }
          }

          // CRITICAL: Call GET /delivery-profiles/current_status/ to update deliveryStatus
          if (mounted) {
            try {
              final statusProvider = context.read<DeliveryStatusProvider>();
              await statusProvider.loadCurrentStatus();
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Refreshed delivery status after approving order - Status: ${statusProvider.currentStatus}',
              );
            } catch (e) {
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Error refreshing delivery status: $e',
              );
              // Non-critical error - don't show to user
            }
          }

          // Force a rebuild to update button visibility
          // Buttons will be re-evaluated based on fresh data from server
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
            content: Text(
              '${localizations.errorApprovingOrder}: ${e.toString()}',
            ),
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

    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.rejectAssignment),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizations.rejectAssignmentConfirmation),
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
            child: Text(localizations.cancel),
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
            child: Text(localizations.rejectAssignmentButton),
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
      final authProvider = context.read<AuthProvider>();
      final localizations = AppLocalizations.of(context);

      // Check that the user is a delivery manager
      if (authProvider.user?.userType != 'delivery_admin') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Only delivery managers can reject assignments',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get assignment ID from order
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
            SnackBar(
              content: Text(localizations.assignmentNotFound),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Check that the current assignment status allows rejection
      // Only waiting_for_delivery_manager status allows rejection
      final orderStatus = widget.order.status.toLowerCase().trim();
      final isWaitingStatus =
          widget.order.isWaitingForDeliveryManager ||
          orderStatus == 'waiting_for_delivery_manager';

      if (!isWaitingStatus) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Assignment cannot be rejected. Current order status: ${widget.order.status}',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        debugPrint(
          'DeliveryManagerOrderDetailsWidget: Cannot reject assignment - order status is ${widget.order.status}, expected waiting_for_delivery_manager',
        );
        return;
      }

      // Send PATCH to /api/delivery/assignments/{id}/update-status/ with status: "rejected"
      try {
        await provider.apiService.updateDeliveryStatus(
          int.parse(assignmentId),
          'rejected',
          failureReason: reason.isNotEmpty ? reason : null,
        );

        // After successful server response (200 OK)
        if (mounted) {
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

          // Update the order status on the frontend
          final freshOrder = await provider.getOrderById(widget.order.id);
          if (freshOrder != null) {
            widget.onOrderUpdated(freshOrder);
            debugPrint(
              'DeliveryManagerOrderDetailsWidget: Updated order after rejection - Status: ${freshOrder.status}',
            );
          }

          // Refresh delivery manager status from /api/delivery-profiles/current_status/
          if (mounted) {
            try {
              final statusProvider = context.read<DeliveryStatusProvider>();
              await statusProvider.loadCurrentStatus();
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Refreshed delivery status after rejection - Status: ${statusProvider.currentStatus}',
              );
            } catch (e) {
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Error refreshing delivery status: $e',
              );
              // Non-critical error - don't show to user
            }
          }

          // Hide Approve/Reject buttons and show/hide Start Delivery based on new status
          // Buttons will be re-evaluated automatically based on fresh order status
          if (mounted) {
            setState(() {});
          }
        }
      } catch (e) {
        // Handle 400 error and other errors
        String errorMessage = localizations.errorRejectingAssignment;
        final errorString = e.toString();

        // Check for 400 Bad Request
        if (errorString.contains('400')) {
          // 400 Bad Request - extract error message from exception
          // Format: "Failed to update delivery status: 400 - {error message}"
          final statusCodeMatch = RegExp(
            r':\s*400\s*-\s*(.+)$',
          ).firstMatch(errorString);
          if (statusCodeMatch != null) {
            final extractedError = statusCodeMatch.group(1)?.trim() ?? '';
            errorMessage =
                '${localizations.errorRejectingAssignment}: $extractedError';
          } else {
            // Try alternative format
            final errorMatch = RegExp(
              r'error[^:]*:\s*(.+?)(?:\s*-\s*\d+|$)',
            ).firstMatch(errorString);
            if (errorMatch != null) {
              errorMessage =
                  '${localizations.errorRejectingAssignment}: ${errorMatch.group(1)?.trim() ?? ''}';
            } else {
              errorMessage =
                  '${localizations.errorRejectingAssignment}: Invalid request. The assignment status may not allow rejection.';
            }
          }

          debugPrint(
            'DeliveryManagerOrderDetailsWidget: 400 error rejecting assignment: $e',
          );
        } else {
          // Other errors (403, 404, 500, etc.)
          // Extract error message if available
          final errorMatch = RegExp(
            r':\s*\d+\s*-\s*(.+)$',
          ).firstMatch(errorString);
          if (errorMatch != null) {
            errorMessage =
                '${localizations.errorRejectingAssignment}: ${errorMatch.group(1)?.trim() ?? ''}';
          } else {
            errorMessage =
                '${localizations.errorRejectingAssignment}: $errorString';
          }

          debugPrint(
            'DeliveryManagerOrderDetailsWidget: Error rejecting assignment: $e',
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        debugPrint(
          'DeliveryManagerOrderDetailsWidget: Unexpected error rejecting assignment: $e',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${localizations.errorRejectingAssignment}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
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
      final result = await provider.startDelivery(int.parse(widget.order.id));

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        if (result != null && result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.deliveryStartedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );

          // CRITICAL: Always fetch fresh order data from server after starting delivery
          // orderStatus should be 'in_delivery' after starting delivery
          try {
            final freshOrder = await provider.getOrderById(widget.order.id);
            if (freshOrder != null) {
              widget.onOrderUpdated(freshOrder);
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Fetched fresh order after start delivery - Status: ${freshOrder.status}',
              );
            }
          } catch (e) {
            debugPrint(
              'DeliveryManagerOrderDetailsWidget: Error fetching order after start delivery: $e',
            );
            // Try to use order from response as fallback
            if (result['order'] != null) {
              try {
                final orderData = result['order'] as Map<String, dynamic>;
                final updatedOrder = Order.fromJson(orderData);
                widget.onOrderUpdated(updatedOrder);
              } catch (parseError) {
                debugPrint(
                  'DeliveryManagerOrderDetailsWidget: Error parsing order from response: $parseError',
                );
              }
            }
          }

          // CRITICAL: Refresh delivery manager status from server
          // Backend sets status to 'busy' when delivery starts
          // deliveryStatus should be 'busy' after starting delivery
          if (mounted) {
            try {
              final statusProvider = context.read<DeliveryStatusProvider>();
              await statusProvider.loadCurrentStatus();
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Refreshed delivery manager status after starting delivery - Status: ${statusProvider.currentStatus}',
              );
            } catch (e) {
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Error refreshing delivery status: $e',
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
                provider.error ?? localizations.failedToStartDelivery,
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
            content: Text(
              '${localizations.errorStartingDelivery}: ${e.toString()}',
            ),
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

  Future<void> _completeDelivery() async {
    // Get provider before async gap
    final provider = context.read<OrdersProvider>();

    // Show confirmation dialog
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.completeDelivery),
        content: Text(localizations.completeDeliveryConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(localizations.markAsDelivered),
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
        final localizations = AppLocalizations.of(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.orderMarkedDelivered),
              backgroundColor: Colors.green,
            ),
          );

          // CRITICAL: Refresh order details from server
          final freshOrder = await provider.getOrderById(widget.order.id);
          if (freshOrder != null) {
            widget.onOrderUpdated(freshOrder);
          }

          // CRITICAL: Refresh delivery manager status from server
          // Backend may have changed status to online if no other active deliveries
          if (mounted) {
            try {
              final statusProvider = context.read<DeliveryStatusProvider>();
              await statusProvider.loadCurrentStatus();
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Refreshed delivery manager status after completing delivery',
              );
            } catch (e) {
              debugPrint(
                'DeliveryManagerOrderDetailsWidget: Error refreshing delivery status: $e',
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
              content: Text(localizations.failedToCompleteDelivery),
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
            content: Text(
              '${localizations.errorCompletingDelivery}: ${e.toString()}',
            ),
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

  void _showLocationMap() {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deliveryTracking),
        content: Text(localizations.deliveryTrackingInfo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.ok),
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

    // Get manager status from provider (single source of truth)
    final statusProvider = context.watch<DeliveryStatusProvider>();
    final managerStatus = statusProvider.currentStatus.toLowerCase();
    final isManagerOnline = managerStatus == 'online';
    final isManagerBusy = managerStatus == 'busy';

    // Button visibility logic based on order status and delivery manager status
    // Following the exact table provided:

    final isWaitingStatus =
        widget.order.isWaitingForDeliveryManager ||
        orderStatus == 'waiting_for_delivery_manager' ||
        rawStatus == 'waiting_for_delivery_manager';

    final isApprovedStatus = orderStatus == 'approved';
    final isInDeliveryStatus =
        orderStatus == 'in_delivery' ||
        orderStatus == 'delivery_in_progress' ||
        orderStatus == 'in_progress';
    final isCompletedStatus =
        orderStatus == 'completed' ||
        orderStatus == 'delivered' ||
        orderStatus == 'rejected';

    // Show Approve/Reject buttons:
    // Table Row 1: waiting_for_delivery_manager + online → Show Approve/Reject
    // - Order status is waiting_for_delivery_manager (NOT approved)
    // - Delivery manager status is online
    // - Order is NOT completed or rejected
    final shouldShowAcceptReject =
        isWaitingStatus &&
        !isApprovedStatus &&
        isManagerOnline &&
        !isCompletedStatus;

    // Show Start Delivery button:
    // Table Row 3: approved + online → Show Start Delivery
    // - Order status is approved (NOT waiting_for_delivery_manager)
    // - Delivery manager status is online
    // - Order is NOT in delivery or completed
    final shouldShowStartDelivery =
        isApprovedStatus &&
        !isWaitingStatus &&
        isManagerOnline &&
        !isInDeliveryStatus &&
        !isCompletedStatus;

    // Show Complete Delivery and Update Location buttons:
    // Table Row 5 & 6: in_delivery + (busy OR online) → Show Complete Delivery + Update Location
    // - Order status is in_delivery
    // - Delivery manager status can be busy or online (handle gracefully)
    final shouldShowCompleteDelivery = isInDeliveryStatus && !isCompletedStatus;
    final shouldShowUpdateLocation = isInDeliveryStatus && !isCompletedStatus;

    // Table Row 7 & 8: completed/rejected → Hide all buttons (handled by conditions above)

    debugPrint('DeliveryManagerActions: isWaitingStatus = $isWaitingStatus');
    debugPrint('DeliveryManagerActions: managerStatus = $managerStatus');
    debugPrint('DeliveryManagerActions: isManagerOnline = $isManagerOnline');
    debugPrint('DeliveryManagerActions: isManagerBusy = $isManagerBusy');
    debugPrint(
      'DeliveryManagerActions: shouldShowAcceptReject = $shouldShowAcceptReject',
    );
    debugPrint(
      'DeliveryManagerActions: shouldShowStartDelivery = $shouldShowStartDelivery',
    );
    debugPrint(
      'DeliveryManagerActions: shouldShowCompleteDelivery = $shouldShowCompleteDelivery',
    );
    debugPrint(
      'DeliveryManagerActions: shouldShowUpdateLocation = $shouldShowUpdateLocation',
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
            // Table: waiting_for_delivery_manager + online → Show Accept/Reject
            else if (shouldShowAcceptReject) ...[
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
            // Show Start Delivery button
            // Table: approved/waiting_for_delivery_manager + online → Show Start Delivery
            else if (shouldShowStartDelivery) ...[
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);

                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startDelivery,
                      icon: const Icon(
                        Icons.local_shipping,
                        color: Colors.white,
                      ),
                      label: Text(localizations.startDelivery),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  );
                },
              ),
            ]
            // Show Complete Delivery and Update Location buttons
            // Table: in_delivery + (busy OR online) → Show Complete Delivery + Update Location
            else if (shouldShowCompleteDelivery) ...[
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _completeDelivery,
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: Text(localizations.markAsDelivered),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  );
                },
              ),
              if (shouldShowUpdateLocation) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showLocationMap,
                        icon: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                        ),
                        label: Text(localizations.trackDelivery),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    );
                  },
                ),
              ],
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
      physics: const AlwaysScrollableScrollPhysics(),
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
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations
                              .getOrderStatusLabel(widget.order.status)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        );
                      },
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
                '${widget.order.items.fold(0, (sum, item) => sum + item.quantity)}',
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
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return widget.shared.buildSectionCard(
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
                  if (widget.order.shippingAddress != null) ...[
                    widget.shared.buildCustomerDetailRow(
                      localizations.addressLabel,
                      widget.order.shippingAddressText ??
                          localizations.notProvided,
                      Icons.location_on,
                    ),
                  ],
                ],
              );
            },
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
                  context,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Delivery Manager Action Buttons (handles all statuses)
          if (!widget.order.isCancelled) _buildDeliveryManagerActions(),
        ],
      ),
    );
  }
}
