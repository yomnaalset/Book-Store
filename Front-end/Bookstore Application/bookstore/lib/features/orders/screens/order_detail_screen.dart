import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/services/location_management_service.dart';
import '../../../core/services/api_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/order.dart';
import '../models/order_note.dart';
import '../providers/orders_provider.dart';
import '../../borrow/providers/return_request_provider.dart';
import '../../borrow/models/return_request.dart';
import '../../borrow/services/borrow_service.dart';
import '../../borrow/models/borrow_request.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../delivery_manager/providers/delivery_status_provider.dart';
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
        final bookId = _order!.items.first.bookId.toString();
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
            'DEBUG: Order loaded - DeliveryCost: ${order.deliveryCost}',
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

  Widget _buildStatusChip(String status, BuildContext context) {
    final localizations = AppLocalizations.of(context);
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
      child: Builder(
        builder: (context) {
          // Use getBorrowStatusLabel for borrow orders, getOrderStatusLabel for purchase orders
          final statusLabel = (_order != null && _order!.isBorrowingOrder)
              ? localizations.getBorrowStatusLabel(status)
              : localizations.getOrderStatusLabel(status);
          return Text(
            statusLabel.toUpperCase(),
            style: TextStyle(
              fontSize: AppDimensions.fontSizeXS,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(status),
            ),
          );
        },
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

  Widget _buildBookImage(OrderItem item) {
    final imageUrl = item.bookImage;
    final fullImageUrl = imageUrl != null && imageUrl.isNotEmpty
        ? ApiConfig.buildImageUrl(imageUrl) ?? imageUrl
        : null;

    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(color: AppColors.border),
      ),
      child: fullImageUrl != null && fullImageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              child: Image.network(
                fullImageUrl,
                width: 60,
                height: 80,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  debugPrint(
                    'OrderDetailScreen: Error loading book image: $error',
                  );
                  return const Icon(
                    Icons.book,
                    color: AppColors.textSecondary,
                    size: 30,
                  );
                },
              ),
            )
          : const Icon(Icons.book, color: AppColors.textSecondary, size: 30),
    );
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
                    '${note.authorDisplayName} ($localizedAuthorType)',
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
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.addNote),
          content: TextField(
            decoration: InputDecoration(
              hintText: localizations.enterNotesPlaceholder,
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.pleaseEnterSomeNotes),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                // Show loading indicator
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.addingNotes),
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
                    SnackBar(
                      content: Text(localizations.noteAddedSuccessfully),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.errorMessage ?? localizations.failedToAddNotes,
                      ),
                      backgroundColor: AppColors.error,
                    ),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.pleaseEnterNoteContent),
                      backgroundColor: AppColors.warning,
                    ),
                  );
                  return;
                }

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.updatingNote),
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
                    SnackBar(
                      content: Text(localizations.noteUpdatedSuccessfully),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.errorMessage ??
                            localizations.failedToUpdateNote,
                      ),
                      backgroundColor: AppColors.error,
                    ),
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

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.deletingNote),
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
                    SnackBar(
                      content: Text(localizations.noteDeletedSuccessfully),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        provider.errorMessage ??
                            localizations.failedToDeleteNote,
                      ),
                      backgroundColor: AppColors.error,
                    ),
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
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context).orderDetails),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: const Center(child: LoadingIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context).orderDetails,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 204),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
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
          title: Text(
            AppLocalizations.of(context).orderDetails,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withValues(alpha: 204),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
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
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              localizations.orderNumberPrefix(_order!.orderNumber),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            );
          },
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _loadOrderDetails,
              icon: const Icon(Icons.refresh),
              tooltip: AppLocalizations.of(context).refresh,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOrderDetails,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: AppDimensions.paddingM,
              right: AppDimensions.paddingM,
              top: AppDimensions.paddingM,
              bottom: AppDimensions.paddingM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Order Status Section
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    // Get effective status - check delivery assignment if available
                    final effectiveStatus =
                        _order!.deliveryAssignment != null &&
                            _order!.deliveryAssignment!.status.toLowerCase() ==
                                'in_delivery'
                        ? 'in_delivery'
                        : _order!.status;
                    return _buildSectionCard(
                      title: localizations.orderStatusLabel,
                      icon: Icons.info_outline,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              localizations.currentStatus,
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeM,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            _buildStatusChip(effectiveStatus, context),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingM),
                        _buildInfoRow(
                          localizations.orderNumberLabel,
                          _order!.orderNumber,
                        ),
                        _buildInfoRow(
                          localizations.orderDateLabel,
                          _formatDate(_order!.createdAt),
                        ),
                        _buildInfoRow(
                          localizations.lastUpdated,
                          _formatDate(_order!.updatedAt),
                        ),
                        // Show cancellation reason if order is cancelled
                        if (_order!.status.toLowerCase() == 'cancelled') ...[
                          const SizedBox(height: AppDimensions.spacingM),
                          const Divider(),
                          const SizedBox(height: AppDimensions.spacingS),
                          Text(
                            localizations.cancellationReason,
                            style: const TextStyle(
                              fontSize: AppDimensions.fontSizeM,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingS),
                          Container(
                            padding: const EdgeInsets.all(
                              AppDimensions.paddingM,
                            ),
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
                                  : localizations.noCancellationReasonProvided,
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
                    );
                  },
                ),

                // Order Summary Section (only for purchase orders)
                // Hide for borrowing orders (check both orderType and orderNumber prefix)
                if (!isBorrowOrder)
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return _buildSectionCard(
                        title: localizations.orderSummary,
                        icon: Icons.shopping_cart,
                        children: [
                          _buildInfoRow(
                            localizations.numberOfBooks,
                            '${_getTotalBookCount()}',
                          ),
                        ],
                      );
                    },
                  ),

                // Order Items Section
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return _buildSectionCard(
                      title: localizations.orderItems,
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
                                    // Book image
                                    _buildBookImage(item),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
                                    // Book details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.bookTitle,
                                            style: const TextStyle(
                                              fontSize: AppDimensions.fontSizeM,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (item.bookAuthor != null &&
                                              item.bookAuthor!.isNotEmpty) ...[
                                            const SizedBox(
                                              height: AppDimensions.spacingXS,
                                            ),
                                            Text(
                                              '${localizations.by} ${item.bookAuthor}',
                                              style: const TextStyle(
                                                fontSize:
                                                    AppDimensions.fontSizeS,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(
                                            height: AppDimensions.spacingXS,
                                          ),
                                          Text(
                                            '${localizations.quantityLabel} ${item.quantity}',
                                            style: const TextStyle(
                                              fontSize: AppDimensions.fontSizeS,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: AppDimensions.spacingXS,
                                          ),
                                          Text(
                                            '${localizations.priceLabel}: \$${item.unitPrice.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: AppDimensions.fontSizeS,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(
                                            height: AppDimensions.spacingXS,
                                          ),
                                          Text(
                                            '${localizations.totalLabel}: \$${item.totalPrice.toStringAsFixed(2)}',
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
                                  const SizedBox(
                                    height: AppDimensions.spacingM,
                                  ),
                                  const Divider(),
                                  const SizedBox(
                                    height: AppDimensions.spacingM,
                                  ),
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
                    );
                  },
                ),

                // Additional Notes Section - ALWAYS SHOW THIS SECTION
                // This section should always be visible for all users
                // Positioned right after Order Items section
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return _buildSectionCard(
                      title: localizations.additionalNotes,
                      icon: Icons.note,
                      children: [
                        // Display notes if available
                        if (_order!.hasNotes) ...[
                          // Display list of notes with author information
                          ..._order!.notesList.map(
                            (note) => _buildNoteCard(note),
                          ),
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
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(
                                context,
                              );
                              return Padding(
                                padding: const EdgeInsets.all(
                                  AppDimensions.paddingM,
                                ),
                                child: Text(
                                  localizations.noNotesYet,
                                  style: const TextStyle(
                                    fontSize: AppDimensions.fontSizeS,
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              );
                            },
                          ),
                        // Show Add Note button only if order is not delivered
                        if (!_isDeliveryComplete() &&
                            (_order!.canEditNotes ?? true))
                          Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(
                                context,
                              );
                              return SizedBox(
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
                              );
                            },
                          ),
                      ],
                    );
                  },
                ),

                // Payment Information Section
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    if (_order!.paymentInfo != null) {
                      return _buildSectionCard(
                        title: localizations.paymentInformation,
                        icon: Icons.payment,
                        children: [
                          _buildInfoRow(
                            localizations.paymentMethod,
                            _getPaymentMethodDisplay(
                              _order!.paymentInfo!.paymentMethod,
                            ),
                          ),
                          _buildInfoRow(
                            localizations.paymentStatus,
                            _getPaymentStatusDisplay(
                              _order!.paymentInfo!.status,
                            ),
                          ),
                          if (_order!.paymentInfo!.transactionId != null)
                            _buildInfoRow(
                              localizations.transactionId,
                              _order!.paymentInfo!.transactionId!,
                            ),
                        ],
                      );
                    } else if (_order!.paymentMethod != null &&
                        _order!.paymentMethod!.isNotEmpty) {
                      return _buildSectionCard(
                        title: localizations.paymentInformation,
                        icon: Icons.payment,
                        children: [
                          _buildInfoRow(
                            localizations.paymentMethod,
                            _getPaymentMethodDisplay(_order!.paymentMethod!),
                          ),
                          _buildInfoRow(
                            localizations.paymentStatus,
                            _getPaymentStatusDisplay(_order!.status),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // Customer Information Section - Show for delivery managers only
                Builder(
                  builder: (context) {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    final userType = authProvider.user?.userType;
                    final isDeliveryManager = userType == 'delivery_admin';

                    if (!isDeliveryManager) {
                      return const SizedBox.shrink();
                    }

                    final localizations = AppLocalizations.of(context);
                    return _buildSectionCard(
                      title: localizations.customerInformation,
                      icon: Icons.person,
                      children: [
                        _buildInfoRow(
                          localizations.fullName,
                          _order!.customerName,
                        ),
                        _buildInfoRow(
                          localizations.phoneNumber,
                          _order!.customerPhone.isNotEmpty
                              ? _order!.customerPhone
                              : localizations.notProvided,
                        ),
                        _buildInfoRow(
                          localizations.email,
                          _order!.customerEmail,
                        ),
                        if (_order!.deliveryAddress != null) ...[
                          _buildInfoRow(
                            localizations.addressLabel,
                            _order!.deliveryAddressText ??
                                localizations.notProvided,
                          ),
                        ],
                      ],
                    );
                  },
                ),

                // Delivery Manager Information Section - Hide for delivery managers
                if (_order!.status.toLowerCase() != 'cancelled')
                  Builder(
                    builder: (context) {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      final userType = authProvider.user?.userType;
                      final isDeliveryManager = userType == 'delivery_admin';

                      // Hide this section for delivery managers
                      if (isDeliveryManager) {
                        return const SizedBox.shrink();
                      }

                      final localizations = AppLocalizations.of(context);
                      return _buildSectionCard(
                        title: localizations.deliveryManager,
                        icon: Icons.local_shipping,
                        children: [
                          if (_order!.deliveryAssignment != null) ...[
                            _buildInfoRow(
                              localizations.managerName,
                              _order!.deliveryAssignment!.deliveryManagerName,
                            ),
                            _buildInfoRow(
                              localizations.assignedAt,
                              _formatDate(
                                _order!.deliveryAssignment!.assignedAt,
                              ),
                            ),
                            if (_order!.deliveryAssignment!.startedAt != null)
                              _buildInfoRow(
                                localizations.startedAt,
                                _formatDate(
                                  _order!.deliveryAssignment!.startedAt!,
                                ),
                              ),
                            if (_order!.deliveryAssignment!.completedAt != null)
                              _buildInfoRow(
                                localizations.completedAt,
                                _formatDate(
                                  _order!.deliveryAssignment!.completedAt!,
                                ),
                              ),
                            if (_order!.deliveryAssignment!.assignedByName !=
                                null)
                              _buildInfoRow(
                                localizations.assignedBy,
                                _order!.deliveryAssignment!.assignedByName!,
                              ),
                          ] else ...[
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  AppDimensions.paddingL,
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.local_shipping_outlined,
                                      size: 48,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.spacingM,
                                    ),
                                    Text(
                                      localizations.noDeliveryManagerAssigned,
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeM,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.spacingS,
                                    ),
                                    Text(
                                      localizations.orderNotAcceptedYetMessage,
                                      style: const TextStyle(
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
                      );
                    },
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

                    // Check both order status and delivery assignment status
                    final orderStatus = _order!.status.toLowerCase().trim();
                    String? deliveryStatus;
                    if (_order!.deliveryAssignment != null) {
                      deliveryStatus = _order!.deliveryAssignment!.status
                          .toLowerCase()
                          .trim();
                    }
                    final isInDelivery =
                        _order!.isInDelivery ||
                        orderStatus == 'in_delivery' ||
                        (deliveryStatus != null &&
                            (deliveryStatus == 'in_delivery' ||
                                deliveryStatus == 'in-delivery' ||
                                deliveryStatus == 'in delivery'));

                    // Debug: Print button visibility condition
                    debugPrint(
                      'OrderDetailScreen: Button visibility check - '
                      'isCustomer=$isCustomer, '
                      'order.status=$orderStatus, '
                      'order.isInDelivery=${_order!.isInDelivery}, '
                      'deliveryAssignment!=null=${_order!.deliveryAssignment != null}, '
                      'deliveryAssignment.status=$deliveryStatus, '
                      'isInDelivery=$isInDelivery, '
                      'isCancelled=${_order!.isCancelled}',
                    );

                    if (isCustomer && isInDelivery && !_order!.isCancelled) {
                      final localizations = AppLocalizations.of(context);
                      return _buildSectionCard(
                        title: localizations.deliveryTracking,
                        icon: Icons.location_on,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _viewDeliveryLocation,
                              icon: const Icon(Icons.map),
                              label: Text(localizations.viewDeliveryLocation),
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
                      return Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildSectionCard(
                            title: localizations.deliveryActions,
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
                                        child: Text(
                                          localizations.approveDelivery,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingM,
                                    ),
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
                                        child: Text(
                                          localizations.rejectDelivery,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          );
                        },
                      );
                    }

                    // Show Complete Delivery button when status is in_delivery
                    final isInDelivery =
                        _order!.isInDelivery || orderStatus == 'in_delivery';

                    if (isDeliveryManager &&
                        isInDelivery &&
                        !_order!.isCancelled) {
                      return Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return _buildSectionCard(
                            title: localizations.deliveryActions,
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
                                        label: Text(
                                          localizations.updateCurrentLocation,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor: AppColors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: AppDimensions.paddingM,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.spacingM,
                                    ),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _completeDelivery,
                                        icon: const Icon(Icons.check_circle),
                                        label: Text(
                                          localizations.completeDelivery,
                                        ),
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
                        },
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPaymentMethodDisplay(String method) {
    final localizations = AppLocalizations.of(context);
    final methodLower = method.toLowerCase().trim();
    switch (methodLower) {
      case 'card':
      case 'credit_card':
      case 'debit_card':
      case 'credit/debit card':
        return localizations.paymentMethodCard;
      case 'cash':
        return localizations.paymentMethodCash;
      case 'cash_on_delivery':
      case 'cod':
      case 'cash on delivery':
        return localizations.paymentMethodCashOnDelivery;
      default:
        // If method is already localized or doesn't match, return as-is
        return method;
    }
  }

  String _getPaymentStatusDisplay(String status) {
    final localizations = AppLocalizations.of(context);
    final statusLower = status.toLowerCase().trim();

    // Handle standard payment statuses
    switch (statusLower) {
      case 'paid':
        return localizations.paymentStatusPaid;
      case 'unpaid':
        return localizations.paymentStatusUnpaid;
      case 'pending':
        return localizations.paymentStatusPending;
      case 'completed':
        return localizations.paymentStatusPaid;
      case 'delivered':
        // For borrow requests, delivered is a valid status
        // Always use statusDelivered which is already translated
        // Check if it's a borrow order to use getBorrowStatusLabel (which also returns statusDelivered)
        if (_order != null &&
            (_order!.isBorrowingOrder ||
                _order!.orderNumber.toUpperCase().startsWith('BR'))) {
          // getBorrowStatusLabel for "delivered" returns statusDelivered which is translated
          return localizations.getBorrowStatusLabel(status);
        }
        // For non-borrow orders, also use statusDelivered (translated)
        return localizations.statusDelivered;
      case 'returned':
        // For borrow requests, returned is a valid status
        // Always use statusReturned which is already translated
        // Check if it's a borrow order to use getBorrowStatusLabel (which also returns statusReturned)
        if (_order != null &&
            (_order!.isBorrowingOrder ||
                _order!.orderNumber.toUpperCase().startsWith('BR'))) {
          // getBorrowStatusLabel for "returned" returns statusReturned which is translated
          return localizations.getBorrowStatusLabel(status);
        }
        // For non-borrow orders, also use statusReturned (translated)
        return localizations.statusReturned;
      default:
        // If it's not a standard payment status, check if it's an order/borrow status
        // (sometimes payment status field contains order status values)
        // Check both isBorrowingOrder and order number prefix "BR" for borrow orders
        if (_order != null &&
            (_order!.isBorrowingOrder ||
                _order!.orderNumber.toUpperCase().startsWith('BR'))) {
          // Try getBorrowStatusLabel first for borrow orders
          try {
            final borrowStatusLabel = localizations.getBorrowStatusLabel(
              status,
            );
            // If getBorrowStatusLabel returns a translated value (different from input), use it
            // Compare the original status with the returned label to see if it was translated
            final originalStatusFormatted = statusLower
                .split('_')
                .map((word) {
                  if (word.isEmpty) return word;
                  return word[0].toUpperCase() +
                      word.substring(1).toLowerCase();
                })
                .join(' ');
            if (borrowStatusLabel.toLowerCase() != statusLower &&
                borrowStatusLabel.toLowerCase() !=
                    originalStatusFormatted.toLowerCase()) {
              return borrowStatusLabel;
            }
          } catch (e) {
            // Continue to try order status
          }
        }
        try {
          final orderStatusLabel = localizations.getOrderStatusLabel(status);
          // If getOrderStatusLabel returns a different value, it means it's an order status
          if (orderStatusLabel.toLowerCase() != statusLower) {
            return orderStatusLabel;
          }
        } catch (e) {
          // getOrderStatusLabel might throw for invalid statuses, continue to fallback
        }
        // Final fallback: return the status as-is
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
          _buildInfoRow(
            AppLocalizations.of(context).status,
            AppLocalizations.of(
              context,
            ).getReturnRequestStatusLabel(_returnRequest!.status),
          ),
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
      // Get providers before async gap to avoid BuildContext issues
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final statusProvider = authProvider.user?.userType == 'delivery_admin'
          ? Provider.of<DeliveryStatusProvider>(context, listen: false)
          : null;

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
        final localizations = AppLocalizations.of(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.deliveryApprovedSuccessfully),
              backgroundColor: AppColors.success,
            ),
          );
          // Refresh order details
          await _loadOrderDetails();

          // Refresh delivery manager availability status from server
          // This ensures the UI updates to show "Busy" instead of "Online"
          if (statusProvider != null && mounted) {
            try {
              await statusProvider.loadCurrentStatus();
              debugPrint(
                'OrderDetailScreen: Delivery manager status refreshed after accepting assignment',
              );
            } catch (e) {
              debugPrint('OrderDetailScreen: Error refreshing status: $e');
              // Non-critical error, continue
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage ?? localizations.failedToApproveDelivery,
              ),
              backgroundColor: AppColors.error,
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
              '${localizations.errorApprovingDelivery}: ${e.toString()}',
            ),
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
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.rejectDelivery),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizations.pleaseProvideRejectionReason),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: localizations.rejectionReason,
                  hintText: localizations.enterRejectionReason,
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
                Navigator.pop(context);
                _rejectDelivery(reasonController.text.trim());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: AppColors.white,
              ),
              child: Text(localizations.rejectDelivery),
            ),
          ],
        );
      },
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
        final localizations = AppLocalizations.of(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                reason.isNotEmpty
                    ? localizations.deliveryRejectedReason(reason)
                    : localizations.deliveryRejectedSuccessfully,
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
                provider.errorMessage ?? localizations.failedToRejectDelivery,
              ),
              backgroundColor: AppColors.error,
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
              '${localizations.errorRejectingDelivery}: ${e.toString()}',
            ),
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
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.completeDelivery),
          content: Text(localizations.areYouSureMarkDelivered),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.white,
              ),
              child: Text(localizations.completeDelivery),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    if (!mounted) return;

    setState(() {
      _isProcessingAction = true;
    });

    try {
      final success = await provider.completeDelivery(int.parse(_order!.id));

      if (!mounted) return;

      final localizations = AppLocalizations.of(context);
      if (success) {
        _showSnackBarSafely(
          localizations.deliveryCompletedSuccessfully,
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
          provider.errorMessage ?? localizations.failedToCompleteDelivery,
          AppColors.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      _showSnackBarSafely(
        localizations.errorCompletingDeliveryWithError(e.toString()),
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
        // Handle response format: data.location or direct location
        final data = locationData['data'] as Map<String, dynamic>?;
        final location =
            (data?['location'] ?? locationData['location'])
                as Map<String, dynamic>?;
        final latitude = location?['latitude'] as double?;
        final longitude = location?['longitude'] as double?;

        if (latitude != null && longitude != null) {
          await _launchGoogleMaps(latitude, longitude);
        } else {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Delivery manager location is not available at the moment.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
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
            backgroundColor: AppColors.error,
          ),
        );
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
      final localizations = AppLocalizations.of(context);
      _showSnackBarSafely(
        localizations.pleaseLogInToUpdateLocation,
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
        final localizations = AppLocalizations.of(context);
        _showSnackBarSafely(
          localizations.locationPermissionRequiredToUpdate,
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

      final localizations = AppLocalizations.of(context);
      if (result['success'] == true) {
        _showSnackBarSafely(
          localizations.locationUpdatedSuccessfully,
          AppColors.success,
        );
      } else {
        _showSnackBarSafely(
          result['error'] ?? localizations.failedToUpdateLocation,
          AppColors.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      final localizations = AppLocalizations.of(context);
      _showSnackBarSafely(
        localizations.errorUpdatingLocation(e.toString()),
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
