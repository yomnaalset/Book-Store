import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/services/location_management_service.dart';
import '../models/order.dart';
import '../models/order_note.dart';
import '../providers/orders_provider.dart';
import '../../borrow/providers/return_request_provider.dart';
import '../../borrow/models/return_request.dart';
import '../../borrow/services/borrow_service.dart';
import '../../borrow/models/borrow_request.dart';
import '../../auth/providers/auth_provider.dart';
import '../../delivery_manager/providers/delivery_status_provider.dart';
import '../../admin/orders/widgets/delivery_location_map_widget.dart';
import '../services/orders_service.dart';
import 'borrow_order_detail_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final Order?
  order; // Optional: if provided, use it directly instead of fetching

  const OrderDetailScreen({super.key, required this.orderId, this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

/// Wrapper for OrderDetailScreen that accepts Order directly
/// Routes to separate screens for purchase vs borrow orders
class OrderDetailScreenWithOrder extends StatelessWidget {
  final Order order;

  const OrderDetailScreenWithOrder({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    // Route borrow orders to separate screen
    // Check both orderType and orderNumber prefix "BR"
    final isBorrowOrder =
        order.isBorrowingOrder ||
        order.orderNumber.toUpperCase().startsWith('BR');
    if (isBorrowOrder) {
      return BorrowOrderDetailScreen(order: order);
    }
    // Purchase orders use the regular order detail screen
    return OrderDetailScreen(orderId: order.id, order: order);
  }
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = true;
  Order? _order;
  String? _errorMessage;
  BorrowRequest? _borrowRequest;
  ReturnRequest? _returnRequest;
  bool _isLoadingBorrowInfo = false;
  bool _isProcessingAction = false;
  List<Map<String, dynamic>> _activities = [];
  bool _isLoadingActivities = false;

  @override
  void initState() {
    super.initState();
    // If order is provided directly, use it; otherwise fetch
    if (widget.order != null) {
      // If this is a borrowing order, redirect to BorrowOrderDetailScreen
      // Check both orderType and orderNumber prefix "BR"
      final isBorrowOrder =
          widget.order!.isBorrowingOrder ||
          widget.order!.orderNumber.toUpperCase().startsWith('BR');
      if (isBorrowOrder) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) =>
                    BorrowOrderDetailScreen(order: widget.order!),
              ),
            );
          }
        });
        return; // Don't set state, we're redirecting
      }
      _order = widget.order;
      _isLoading = false;
      // Load additional info if needed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final userType = authProvider.user?.userType;
        if (userType == 'library_admin' || userType == 'delivery_admin') {
          _loadActivities();
        }
      });
    } else {
      _loadOrderDetails();
    }
  }

  Future<void> _loadBorrowInfo() async {
    if (!_order!.isBorrowingOrder) return;

    setState(() {
      _isLoadingBorrowInfo = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final returnProvider = Provider.of<ReturnRequestProvider>(
        context,
        listen: false,
      );
      final borrowService = BorrowService();
      if (authProvider.token != null) {
        borrowService.setToken(authProvider.token!);
        returnProvider.setToken(authProvider.token!);
      }

      // Get customer's borrowings
      final borrowings = await borrowService.getAllBorrowingsWithStatus();

      // Find matching borrow request by book ID
      if (_order!.items.isNotEmpty) {
        final bookId = _order!.items.first.book.id;
        try {
          _borrowRequest = borrowings.firstWhere(
            (br) => br.bookId == bookId && br.status == 'active',
          );
        } catch (e) {
          try {
            _borrowRequest = borrowings.firstWhere((br) => br.bookId == bookId);
          } catch (e2) {
            _borrowRequest = borrowings.isNotEmpty ? borrowings.first : null;
          }
        }
      }

      // Load return request if exists
      if (_borrowRequest != null) {
        await returnProvider.loadReturnRequests();

        try {
          _returnRequest = returnProvider.returnRequests.firstWhere(
            (rr) => rr.borrowRequest.id == _borrowRequest!.id,
          );
        } catch (e) {
          _returnRequest = null;
        }
      }
    } catch (e) {
      debugPrint('Error loading borrow info: $e');
    }

    if (mounted) {
      setState(() {
        _isLoadingBorrowInfo = false;
      });
    }
  }

  Future<void> _loadActivities() async {
    if (_order == null) return;

    setState(() {
      _isLoadingActivities = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final ordersService = OrdersService(baseUrl: '');
      if (authProvider.token != null) {
        ordersService.setAuthToken(authProvider.token!);
      }

      final activities = await ordersService.getOrderActivities(
        int.parse(widget.orderId),
      );

      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading activities: $e');
      if (mounted) {
        setState(() {
          _isLoadingActivities = false;
        });
      }
    }
  }

  Future<void> _loadOrderDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<OrdersProvider>(context, listen: false);
      // Force refresh from server to get latest data including order items
      final order = await provider.getOrderById(
        widget.orderId,
        forceRefresh: true,
      );

      if (mounted) {
        if (order != null) {
          // Debug: Print order data to help troubleshoot
          debugPrint(
            'DEBUG: Order loaded - PaymentInfo: ${order.paymentInfo?.toJson()}',
          );
          debugPrint(
            'DEBUG: Order loaded - PaymentMethod: ${order.paymentMethod}',
          );
          debugPrint('DEBUG: Order loaded - CreatedAt: ${order.createdAt}');
          debugPrint('DEBUG: Order loaded - UpdatedAt: ${order.updatedAt}');
          debugPrint(
            'DEBUG: Order loaded - Items count: ${order.items.length}',
          );
          debugPrint(
            'DEBUG: Order loaded - Items: ${order.items.map((item) => item.toJson()).toList()}',
          );
          debugPrint('DEBUG: Order loaded - Subtotal: ${order.subtotal}');
          debugPrint('DEBUG: Order loaded - TotalAmount: ${order.totalAmount}');
          debugPrint('DEBUG: Order loaded - TaxAmount: ${order.taxAmount}');
          debugPrint(
            'DEBUG: Order loaded - ShippingCost: ${order.shippingCost}',
          );
          debugPrint('DEBUG: Order loaded - Status: ${order.status}');
          debugPrint(
            'DEBUG: Order loaded - CancellationReason: ${order.cancellationReason}',
          );
          debugPrint('DEBUG: Order loaded - Notes: ${order.notes}');
          debugPrint(
            'DEBUG: Order loaded - OrderNotes: ${order.orderNotes?.length ?? 0}',
          );
          debugPrint('DEBUG: Order loaded - HasNotes: ${order.hasNotes}');
          debugPrint(
            'DEBUG: Order loaded - CanEditNotes: ${order.canEditNotes}',
          );
          debugPrint(
            'DEBUG: Order loaded - CanDeleteNotes: ${order.canDeleteNotes}',
          );
          if (order.orderNotes != null && order.orderNotes!.isNotEmpty) {
            debugPrint(
              'DEBUG: Order loaded - OrderNotes details: ${order.orderNotes!.map((n) => '${n.id}: ${n.content} by ${n.authorName}').toList()}',
            );
          }
          // If this is a borrowing order, redirect to BorrowOrderDetailScreen
          // Check both orderType and orderNumber prefix "BR"
          final isBorrowOrder =
              order.isBorrowingOrder ||
              order.orderNumber.toUpperCase().startsWith('BR');
          if (isBorrowOrder) {
            if (mounted) {
              // Replace current screen with BorrowOrderDetailScreen
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) =>
                          BorrowOrderDetailScreen(order: order),
                    ),
                  );
                }
              });
            }
            return; // Don't set state, we're redirecting
          }

          setState(() {
            _order = order;
            _isLoading = false;
          });

          // Load activities for admins
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final userType = authProvider.user?.userType;
          if (userType == 'library_admin' || userType == 'delivery_admin') {
            _loadActivities();
          }
        } else {
          setState(() {
            _errorMessage = 'Order not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load order details: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.info;
      case 'shipped':
        return AppColors.primary;
      case 'delivered':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'pending_assignment':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: _getStatusColor(status)),
      ),
      child: Text(
        status.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(
          fontSize: AppDimensions.fontSizeXS,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(status),
        ),
      ),
    );
  }

  /// Check if order delivery is complete (order cannot be modified after delivery)
  bool _isDeliveryComplete() {
    if (_order == null) return false;
    // Check if order status is delivered
    if (_order!.isDelivered) return true;
    // For borrow orders, also check if borrow request status is active (delivery complete)
    if (_order!.isBorrowingOrder && _borrowRequest != null) {
      return _borrowRequest!.status.toLowerCase() == 'active';
    }
    return false;
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
          ),
          const SizedBox(height: AppDimensions.spacingS),
          // Author and timestamp info
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${note.authorDisplayName} (${note.authorTypeDisplay})',
                style: const TextStyle(
                  fontSize: AppDimensions.fontSizeS,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 24),
                const SizedBox(width: AppDimensions.spacingS),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: AppDimensions.fontSizeL,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            ...children,
          ],
        ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter some notes'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Adding notes...'),
                  backgroundColor: AppColors.primary,
                ),
              );

              // Store context before async operations
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Get providers before async operations
              final provider = Provider.of<OrdersProvider>(
                context,
                listen: false,
              );
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final userType = authProvider.user?.userType;
              final isAdmin =
                  userType == 'library_admin' || userType == 'delivery_admin';

              final success = await provider.addOrderNotes(_order!.id, notes);

              if (!mounted) return;

              if (success) {
                // Reload order to get updated notes with author info
                await _loadOrderDetails();
                // Reload activities to show the new activity
                if (isAdmin) {
                  await _loadActivities();
                }

                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Note added successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.errorMessage ?? 'Failed to add notes',
                    ),
                    backgroundColor: AppColors.error,
                  ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter some note content'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Updating note...'),
                  backgroundColor: AppColors.primary,
                ),
              );

              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final provider = Provider.of<OrdersProvider>(
                context,
                listen: false,
              );
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final userType = authProvider.user?.userType;
              final isAdmin =
                  userType == 'library_admin' || userType == 'delivery_admin';

              // Use editOrderNotes with note_id
              final success = await provider.editOrderNotes(
                _order!.id,
                notes,
                noteId: note.id,
              );

              if (!mounted) return;

              if (success) {
                await _loadOrderDetails();
                // Reload activities to show the updated activity
                if (isAdmin) {
                  await _loadActivities();
                }
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Note updated successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.errorMessage ?? 'Failed to update note',
                    ),
                    backgroundColor: AppColors.error,
                  ),
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

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Deleting note...'),
                  backgroundColor: AppColors.primary,
                ),
              );

              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final provider = Provider.of<OrdersProvider>(
                context,
                listen: false,
              );
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final userType = authProvider.user?.userType;
              final isAdmin =
                  userType == 'library_admin' || userType == 'delivery_admin';

              // Use deleteOrderNotes with note_id
              final success = await provider.deleteOrderNotes(
                _order!.id,
                noteId: note.id,
              );

              if (!mounted) return;

              if (success) {
                await _loadOrderDetails();
                // Reload activities to show the deletion activity
                if (isAdmin) {
                  await _loadActivities();
                }
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Note deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      provider.errorMessage ?? 'Failed to delete note',
                    ),
                    backgroundColor: AppColors.error,
                  ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                fontSize: AppDimensions.fontSizeM,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: AppDimensions.fontSizeM,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    final activityType = activity['activity_type'] as String? ?? '';
    final activityTypeDisplay =
        activity['activity_type_display'] as String? ?? activityType;
    final deliveryManagerName =
        activity['delivery_manager_name'] as String? ?? 'Unknown';
    final timestamp = activity['timestamp'] as String? ?? '';
    final activityData =
        activity['activity_data'] as Map<String, dynamic>? ?? {};

    // Get icon and color based on activity type
    IconData icon;
    Color color;
    switch (activityType) {
      case 'add_notes':
        icon = Icons.add_circle;
        color = AppColors.success;
        break;
      case 'edit_notes':
        icon = Icons.edit;
        color = AppColors.info;
        break;
      case 'delete_notes':
        icon = Icons.delete;
        color = AppColors.error;
        break;
      case 'contact_customer':
        icon = Icons.phone;
        color = AppColors.primary;
        break;
      case 'start_delivery':
        icon = Icons.play_circle;
        color = AppColors.success;
        break;
      case 'complete_delivery':
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case 'update_location':
        icon = Icons.location_on;
        color = AppColors.info;
        break;
      case 'view_route':
        icon = Icons.map;
        color = AppColors.primary;
        break;
      case 'update_eta':
        icon = Icons.access_time;
        color = AppColors.warning;
        break;
      default:
        icon = Icons.info;
        color = AppColors.textSecondary;
    }

    // Format timestamp
    String formattedTime = timestamp;
    try {
      if (timestamp.isNotEmpty) {
        final dateTime = DateTime.parse(timestamp);
        formattedTime =
            '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      // Keep original timestamp if parsing fails
    }

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppDimensions.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activityTypeDisplay,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppDimensions.fontSizeM,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'By: $deliveryManagerName',
                  style: const TextStyle(
                    fontSize: AppDimensions.fontSizeS,
                    color: AppColors.textSecondary,
                  ),
                ),
                if (formattedTime.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeS,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (activityData.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    activityData.toString(),
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeS,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: const Center(child: LoadingIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: AppDimensions.spacingM),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: AppDimensions.fontSizeL,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingL),
              ElevatedButton(
                onPressed: _loadOrderDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Order Details'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: const Center(
          child: Text(
            'Order not found',
            style: TextStyle(fontSize: AppDimensions.fontSizeL),
          ),
        ),
      );
    }

    // Check if this is a borrow order (check both orderType and orderNumber prefix)
    final isBorrowOrder =
        _order!.isBorrowingOrder ||
        _order!.orderNumber.toUpperCase().startsWith('BR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_order!.orderNumber}'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            onPressed: _loadOrderDetails,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOrderDetails,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Status Section
              _buildSectionCard(
                title: 'Order Status',
                icon: Icons.info_outline,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Current Status:',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _buildStatusChip(_order!.status),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  _buildInfoRow('Order Number', _order!.orderNumber),
                  _buildInfoRow('Order Date', _formatDate(_order!.createdAt)),
                  _buildInfoRow('Last Updated', _formatDate(_order!.updatedAt)),
                  // Show cancellation reason if order is cancelled
                  if (_order!.status.toLowerCase() == 'cancelled') ...[
                    const SizedBox(height: AppDimensions.spacingM),
                    const Divider(),
                    const SizedBox(height: AppDimensions.spacingS),
                    const Text(
                      'Cancellation Reason:',
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeM,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusM,
                        ),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _order!.cancellationReason != null &&
                                _order!.cancellationReason!.isNotEmpty
                            ? _order!.cancellationReason!
                            : 'No cancellation reason provided',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          color:
                              _order!.cancellationReason != null &&
                                  _order!.cancellationReason!.isNotEmpty
                              ? AppColors.error
                              : AppColors.textSecondary,
                          fontStyle:
                              _order!.cancellationReason == null ||
                                  _order!.cancellationReason!.isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              // Order Summary Section (only for purchase orders)
              // Hide for borrowing orders (check both orderType and orderNumber prefix)
              if (!isBorrowOrder)
                _buildSectionCard(
                  title: 'Order Summary',
                  icon: Icons.shopping_cart,
                  children: [
                    _buildInfoRow('Number of Books', '${_getTotalBookCount()}'),
                  ],
                ),

              // Order Items Section
              _buildSectionCard(
                title: 'Order Items',
                icon: Icons.list_alt,
                children: [
                  if (_order!.items.isNotEmpty)
                    ..._order!.items.map(
                      (item) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Book image placeholder
                              Container(
                                width: 60,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusS,
                                  ),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.book,
                                  color: AppColors.textSecondary,
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacingM),
                              // Book details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.book.title,
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeM,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.spacingXS,
                                    ),
                                    Text(
                                      'Quantity: ${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeS,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.spacingXS,
                                    ),
                                    Text(
                                      'Price: \$${item.unitPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeS,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.spacingXS,
                                    ),
                                    Text(
                                      'Total: \$${item.totalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeM,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (item != _order!.items.last) ...[
                            const SizedBox(height: AppDimensions.spacingM),
                            const Divider(),
                            const SizedBox(height: AppDimensions.spacingM),
                          ],
                        ],
                      ),
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingL),
                        child: Text(
                          'No items available',
                          style: TextStyle(
                            fontSize: AppDimensions.fontSizeM,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Additional Notes Section - ALWAYS SHOW THIS SECTION
              // This section should always be visible for all users
              // Positioned right after Order Items section
              _buildSectionCard(
                title: 'Additional Notes',
                icon: Icons.note,
                children: [
                  // Display notes if available
                  if (_order!.hasNotes) ...[
                    // Display list of notes with author information
                    ..._order!.notesList.map((note) => _buildNoteCard(note)),
                    const SizedBox(height: AppDimensions.spacingM),
                  ] else if (_order!.notes != null &&
                      _order!.notes!.isNotEmpty) ...[
                    // Fallback: Show legacy notes if new notes list is empty but legacy field has content
                    _buildNoteCard(
                      OrderNote(
                        id: 0,
                        content: _order!.notes!,
                        createdAt: _order!.updatedAt,
                        updatedAt: _order!.updatedAt,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                  ],
                  // Show message if no notes and user can add notes
                  if (!_order!.hasNotes &&
                      (_order!.notes == null || _order!.notes!.isEmpty))
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
                  if (!_isDeliveryComplete() && (_order!.canEditNotes ?? true))
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
              ),

              // Customer Information Section
              _buildSectionCard(
                title: 'Customer Information',
                icon: Icons.person,
                children: [
                  _buildInfoRow('Name', _order!.customerName),
                  _buildInfoRow('Email', _order!.customerEmail),
                  if (_order!.shippingAddress != null) ...[
                    _buildInfoRow(
                      'Address',
                      _order!.shippingAddress!.fullAddress,
                    ),
                    if (_order!.shippingAddress!.phone != null)
                      _buildInfoRow('Phone', _order!.shippingAddress!.phone!),
                  ],
                ],
              ),

              // Payment Information Section
              if (_order!.paymentInfo != null)
                _buildSectionCard(
                  title: 'Payment Information',
                  icon: Icons.payment,
                  children: [
                    _buildInfoRow(
                      'Payment Method',
                      _getPaymentMethodDisplay(
                        _order!.paymentInfo!.paymentMethod,
                      ),
                    ),
                    _buildInfoRow(
                      'Payment Status',
                      _getPaymentStatusDisplay(_order!.paymentInfo!.status),
                    ),
                    if (_order!.paymentInfo!.transactionId != null)
                      _buildInfoRow(
                        'Transaction ID',
                        _order!.paymentInfo!.transactionId!,
                      ),
                  ],
                )
              else if (_order!.paymentMethod != null &&
                  _order!.paymentMethod!.isNotEmpty)
                _buildSectionCard(
                  title: 'Payment Information',
                  icon: Icons.payment,
                  children: [
                    _buildInfoRow(
                      'Payment Method',
                      _getPaymentMethodDisplay(_order!.paymentMethod!),
                    ),
                    _buildInfoRow(
                      'Payment Status',
                      _getPaymentStatusDisplay(_order!.status),
                    ),
                  ],
                ),

              // Delivery Manager Information Section
              if (_order!.status.toLowerCase() != 'cancelled')
                _buildSectionCard(
                  title: 'Delivery Manager',
                  icon: Icons.local_shipping,
                  children: [
                    if (_order!.deliveryAssignment != null) ...[
                      _buildInfoRow(
                        'Manager Name',
                        _order!.deliveryAssignment!.deliveryManagerName,
                      ),
                      _buildInfoRow(
                        'Status',
                        _getDeliveryStatusDisplay(
                          _order!.deliveryAssignment!.status,
                        ),
                      ),
                      _buildInfoRow(
                        'Assigned At',
                        _formatDate(_order!.deliveryAssignment!.assignedAt),
                      ),
                      if (_order!.deliveryAssignment!.startedAt != null)
                        _buildInfoRow(
                          'Started At',
                          _formatDate(_order!.deliveryAssignment!.startedAt!),
                        ),
                      if (_order!.deliveryAssignment!.completedAt != null)
                        _buildInfoRow(
                          'Completed At',
                          _formatDate(_order!.deliveryAssignment!.completedAt!),
                        ),
                      if (_order!.deliveryAssignment!.assignedByName != null)
                        _buildInfoRow(
                          'Assigned By',
                          _order!.deliveryAssignment!.assignedByName!,
                        ),
                    ] else ...[
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppDimensions.paddingL),
                          child: Column(
                            children: [
                              Icon(
                                Icons.local_shipping_outlined,
                                size: 48,
                                color: AppColors.textSecondary,
                              ),
                              SizedBox(height: AppDimensions.spacingM),
                              Text(
                                'No delivery manager assigned',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeM,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              SizedBox(height: AppDimensions.spacingS),
                              Text(
                                'The order has not been accepted yet. Delivery manager information will appear once the order is accepted.',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeS,
                                  color: AppColors.textSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

              // Return Book Section (for borrowing orders)
              if (_order!.isBorrowingOrder && _borrowRequest != null)
                _buildReturnBookSection(),

              // Activity Log Section - Show for library admins only (not delivery managers)
              Builder(
                builder: (context) {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final userType = authProvider.user?.userType;
                  // Only show for library_admin, exclude delivery_admin
                  final isLibraryAdmin = userType == 'library_admin';

                  if (!isLibraryAdmin) {
                    return const SizedBox.shrink();
                  }

                  return _buildSectionCard(
                    title: 'Activity Log',
                    icon: Icons.history,
                    children: [
                      if (_isLoadingActivities)
                        const Padding(
                          padding: EdgeInsets.all(AppDimensions.paddingM),
                          child: Center(child: LoadingIndicator()),
                        )
                      else if (_activities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(AppDimensions.paddingM),
                          child: Text(
                            'No activities recorded yet.',
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeS,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        ..._activities.map(
                          (activity) => _buildActivityCard(activity),
                        ),
                    ],
                  );
                },
              ),

              // View Delivery Location Button - Show for customers when status is in_delivery
              Builder(
                builder: (context) {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final userType = authProvider.user?.userType;
                  final isCustomer =
                      userType == null ||
                      (userType != 'library_admin' &&
                          userType != 'delivery_admin');
                  final orderStatus = _order!.status.toLowerCase().trim();
                  final isInDelivery =
                      _order!.isInDelivery || orderStatus == 'in_delivery';

                  if (isCustomer && isInDelivery && !_order!.isCancelled) {
                    return _buildSectionCard(
                      title: 'Delivery Tracking',
                      icon: Icons.location_on,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _viewDeliveryLocation,
                            icon: const Icon(Icons.map),
                            label: const Text('View Delivery Location'),
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

                  return const SizedBox.shrink();
                },
              ),

              // Delivery Manager Action Buttons - Show when status is waiting_for_delivery_manager
              Builder(
                builder: (context) {
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  final isDeliveryManager =
                      authProvider.user?.userType == 'delivery_admin';
                  final orderStatus = _order!.status.toLowerCase().trim();
                  final isWaitingStatus =
                      _order!.isWaitingForDeliveryManager ||
                      orderStatus == 'waiting_for_delivery_manager';

                  if (isDeliveryManager &&
                      isWaitingStatus &&
                      !_order!.isCancelled) {
                    return _buildSectionCard(
                      title: 'Delivery Actions',
                      icon: Icons.local_shipping,
                      children: [
                        if (_isProcessingAction)
                          const Center(child: LoadingIndicator())
                        else
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _acceptDelivery,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.paddingM,
                                    ),
                                  ),
                                  child: const Text('Approve Delivery'),
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacingM),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _showRejectDeliveryDialog,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.paddingM,
                                    ),
                                  ),
                                  child: const Text('Reject Delivery'),
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  }

                  // Show Complete Delivery button when status is in_delivery
                  final isInDelivery =
                      _order!.isInDelivery || orderStatus == 'in_delivery';

                  if (isDeliveryManager &&
                      isInDelivery &&
                      !_order!.isCancelled) {
                    return _buildSectionCard(
                      title: 'Delivery Actions',
                      icon: Icons.local_shipping,
                      children: [
                        if (_isProcessingAction)
                          const Center(child: LoadingIndicator())
                        else
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _updateCurrentLocation,
                                  icon: const Icon(Icons.my_location),
                                  label: const Text('Update Current Location'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.paddingM,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingM),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _completeDelivery,
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Complete Delivery'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    foregroundColor: AppColors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppDimensions.paddingM,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPaymentMethodDisplay(String method) {
    switch (method.toLowerCase()) {
      case 'card':
        return 'Credit/Debit Card';
      case 'cash_on_delivery':
      case 'cod':
        return 'Cash on Delivery';
      default:
        return method;
    }
  }

  String _getPaymentStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'unpaid':
        return 'Unpaid';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }

  String _getDeliveryStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  int _getTotalBookCount() {
    if (_order == null) return 0;

    // Use totalQuantity from backend if available, otherwise calculate from items
    if (_order!.totalQuantity != null) {
      return _order!.totalQuantity!;
    }

    // Fallback: calculate total quantity from items
    return _order!.items.fold(0, (sum, item) => sum + item.quantity);
  }

  String _formatDate(DateTime date) {
    try {
      // Check if the date is valid
      if (date.year < 1900 || date.year > 2100) {
        return 'Invalid Date';
      }
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      debugPrint('DEBUG: Error formatting date: $e');
      return 'Invalid Date';
    }
  }

  Widget _buildReturnBookSection() {
    if (_isLoadingBorrowInfo) {
      return _buildSectionCard(
        title: 'Return Book',
        icon: Icons.assignment_return,
        children: [const Center(child: LoadingIndicator())],
      );
    }

    // If return request exists, show its status
    if (_returnRequest != null) {
      return _buildSectionCard(
        title: 'Return Request',
        icon: Icons.assignment_return,
        children: [
          _buildInfoRow('Status', _returnRequest!.statusDisplay),
          if (_returnRequest!.fineAmount > 0)
            _buildInfoRow(
              'Fine Amount',
              '\$${_returnRequest!.fineAmount.toStringAsFixed(2)}',
            ),
          if (_returnRequest!.fineInvoiceId != null)
            _buildInfoRow('Fine Invoice', _returnRequest!.fineInvoiceId!),
          if (_returnRequest!.deliveryManagerName != null)
            _buildInfoRow(
              'Delivery Manager',
              _returnRequest!.deliveryManagerName!,
            ),
          _buildInfoRow(
            'Requested At',
            _formatDate(_returnRequest!.requestedAt),
          ),
          if (_returnRequest!.hasFine) ...[
            const SizedBox(height: AppDimensions.spacingM),
            ElevatedButton.icon(
              onPressed: () => _showFinePaymentDialog(),
              icon: const Icon(Icons.payment),
              label: const Text('Pay Fine'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.paddingM,
                ),
              ),
            ),
          ],
        ],
      );
    }

    // Show return button if borrowing is active
    if (_borrowRequest != null && _borrowRequest!.status == 'active') {
      return _buildSectionCard(
        title: 'Return Book',
        icon: Icons.assignment_return,
        children: [
          if (_borrowRequest!.dueDate != null) ...[
            _buildInfoRow('Due Date', _formatDate(_borrowRequest!.dueDate!)),
            if (_borrowRequest!.isOverdue) ...[
              const SizedBox(height: AppDimensions.spacingS),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(color: AppColors.error),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: AppColors.error),
                    SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Text(
                        'This book is overdue. A fine will be applied when you return it.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: AppDimensions.spacingM),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showReturnBookDialog(),
              icon: const Icon(Icons.assignment_return),
              label: const Text('Return Book'),
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

    return const SizedBox.shrink();
  }

  void _showReturnBookDialog() {
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Book'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to return this book?'),
            if (_borrowRequest!.isOverdue) ...[
              const SizedBox(height: AppDimensions.spacingM),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusM),
                  border: Border.all(color: AppColors.warning),
                ),
                child: const Text(
                  'This book is overdue. A fine of 5% of the borrowing price will be applied.',
                  style: TextStyle(color: AppColors.warning),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingM),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                hintText: 'Add any notes about the return...',
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
            onPressed: () async {
              Navigator.pop(context);
              await _createReturnRequest(notesController.text.trim());
            },
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );
  }

  Future<void> _createReturnRequest(String notes) async {
    if (_borrowRequest == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Creating return request...'),
        backgroundColor: AppColors.primary,
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final returnProvider = Provider.of<ReturnRequestProvider>(
        context,
        listen: false,
      );
      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      final success = await returnProvider.createReturnRequest(
        _borrowRequest!.id,
        notes: notes.isEmpty ? null : notes,
      );

      if (!mounted) return;

      if (success) {
        await _loadBorrowInfo();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Return request created successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              returnProvider.errorMessage ?? 'Failed to create return request',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _showFinePaymentDialog() {
    if (_returnRequest == null || _borrowRequest == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay Fine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fine Amount: \$${_returnRequest!.fineAmount.toStringAsFixed(2)}',
            ),
            if (_returnRequest!.fineInvoiceId != null)
              Text('Invoice ID: ${_returnRequest!.fineInvoiceId}'),
            const SizedBox(height: AppDimensions.spacingM),
            const Text('Select payment method:'),
            const SizedBox(height: AppDimensions.spacingS),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _payFine('mastercard');
            },
            child: const Text('MasterCard'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _payFine('cash_on_delivery');
            },
            child: const Text('Cash on Delivery'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptDelivery() async {
    setState(() {
      _isProcessingAction = true;
    });

    try {
      final provider = Provider.of<OrdersProvider>(context, listen: false);

      // Get assignment ID from order
      String? assignmentId;
      if (_order!.deliveryAssignment != null) {
        assignmentId = _order!.deliveryAssignment!.id;
      }

      // If still no assignment ID, try to get assignment from order
      if (assignmentId == null || assignmentId.isEmpty) {
        // Refresh order to get assignment
        final freshOrder = await provider.getOrderById(_order!.id);
        if (freshOrder?.deliveryAssignment != null) {
          assignmentId = freshOrder!.deliveryAssignment!.id;
        }
      }

      if (assignmentId == null || assignmentId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment not found. Please refresh the order.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        setState(() {
          _isProcessingAction = false;
        });
        return;
      }

      final success = await provider.acceptAssignment(int.parse(assignmentId));

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery approved successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
          // Refresh order details
          await _loadOrderDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage ?? 'Failed to approve delivery',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving delivery: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  void _showRejectDeliveryDialog() {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Delivery'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejecting this delivery:'),
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
              _rejectDelivery(reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Reject Delivery'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectDelivery(String reason) async {
    setState(() {
      _isProcessingAction = true;
    });

    try {
      final provider = Provider.of<OrdersProvider>(context, listen: false);

      // Get assignment ID from order
      String? assignmentId;
      if (_order!.deliveryAssignment != null) {
        assignmentId = _order!.deliveryAssignment!.id;
      }

      // If still no assignment ID, try to get assignment from order
      if (assignmentId == null || assignmentId.isEmpty) {
        // Refresh order to get assignment
        final freshOrder = await provider.getOrderById(_order!.id);
        if (freshOrder?.deliveryAssignment != null) {
          assignmentId = freshOrder!.deliveryAssignment!.id;
        }
      }

      if (assignmentId == null || assignmentId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assignment not found. Please refresh the order.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        setState(() {
          _isProcessingAction = false;
        });
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
                    ? 'Delivery rejected. Reason: $reason'
                    : 'Delivery rejected successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
          // Refresh order details
          await _loadOrderDetails();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage ?? 'Failed to reject delivery',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting delivery: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _completeDelivery() async {
    // Get providers before async gap
    final provider = Provider.of<OrdersProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final statusProvider = authProvider.user?.userType == 'delivery_admin'
        ? Provider.of<DeliveryStatusProvider>(context, listen: false)
        : null;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: const Text(
          'Are you sure you want to mark this order as delivered? This will complete the delivery process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Complete Delivery'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      final success = await provider.completeDelivery(int.parse(_order!.id));

      if (!mounted) return;

      if (success) {
        _showSnackBarSafely(
          'Delivery completed successfully!',
          AppColors.success,
        );
        // Refresh order details
        await _loadOrderDetails();

        // Refresh delivery manager status after completing delivery
        // This ensures the status updates from "busy" to "online" if no other active deliveries
        if (statusProvider != null && mounted) {
          try {
            // Reload status from server to get the updated status
            await statusProvider.loadCurrentStatus();
            debugPrint(
              'OrderDetailScreen: Delivery manager status refreshed after completing delivery',
            );
          } catch (e) {
            debugPrint('OrderDetailScreen: Error refreshing status: $e');
            // Non-critical error, continue
          }
        }
      } else {
        _showSnackBarSafely(
          provider.errorMessage ?? 'Failed to complete delivery',
          AppColors.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBarSafely(
        'Error completing delivery: ${e.toString()}',
        AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _viewDeliveryLocation() async {
    // Get provider and scaffold messenger before async gap
    final provider = Provider.of<OrdersProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isProcessingAction = true;
    });

    try {
      final locationData = await provider.getOrderDeliveryLocation(
        int.parse(_order!.id),
      );

      if (!mounted) return;

      if (locationData != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeliveryLocationMapWidget(
              order: _order!,
              locationData: locationData,
            ),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Failed to get delivery location',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error loading delivery location: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

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

  Future<void> _updateCurrentLocation() async {
    // Get auth provider before async gap
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token ?? authProvider.getCurrentToken();

    if (token == null || token.isEmpty) {
      _showSnackBarSafely(
        'Please log in to update your location',
        AppColors.error,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isProcessingAction = true;
    });

    try {
      // Request location permission
      final permission = await Permission.location.request();
      if (!mounted) return;

      if (permission != PermissionStatus.granted) {
        _showSnackBarSafely(
          'Location permission is required to update location',
          AppColors.error,
        );
        if (mounted) {
          setState(() {
            _isProcessingAction = false;
          });
        }
        return;
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      // Update location via LocationManagementService
      final result = await LocationManagementService.updateLocation(
        token: token,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        _showSnackBarSafely('Location updated successfully', AppColors.success);
      } else {
        _showSnackBarSafely(
          result['error'] ?? 'Failed to update location',
          AppColors.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBarSafely(
        'Error updating location: ${e.toString()}',
        AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingAction = false;
        });
      }
    }
  }

  Future<void> _payFine(String paymentMethod) async {
    if (_returnRequest == null || _borrowRequest == null) return;

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Processing payment...'),
        backgroundColor: AppColors.primary,
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final returnProvider = Provider.of<ReturnRequestProvider>(
        context,
        listen: false,
      );
      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      // Use return request ID (not borrow request ID)
      final returnRequest = await returnProvider.payFine(
        int.parse(_returnRequest!.id),
        paymentMethod,
      );

      if (!mounted) return;

      if (returnRequest != null) {
        await _loadBorrowInfo();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Fine paid successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(returnProvider.errorMessage ?? 'Failed to pay fine'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
