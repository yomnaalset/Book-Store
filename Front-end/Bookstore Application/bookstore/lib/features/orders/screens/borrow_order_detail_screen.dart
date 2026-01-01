import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/services/api_service.dart';
import '../models/order.dart';
import '../../delivery_manager/providers/borrowing_delivery_provider.dart';
import '../../borrow/models/borrow_request.dart';
import '../../borrow/services/borrow_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../delivery_manager/services/delivery_status_service.dart';
import 'order_detail_screen.dart';

/// Separate screen for displaying borrow order details
/// This screen does NOT show the "Order Summary" section
class BorrowOrderDetailScreen extends StatefulWidget {
  final Order order;

  const BorrowOrderDetailScreen({super.key, required this.order});

  @override
  State<BorrowOrderDetailScreen> createState() =>
      _BorrowOrderDetailScreenState();
}

class _BorrowOrderDetailScreenState extends State<BorrowOrderDetailScreen>
    with WidgetsBindingObserver {
  Order? _order;
  bool _isLoading = true;
  String? _errorMessage;
  BorrowRequest? _borrowRequest;
  bool _isLoadingBorrowRequest = false;
  String? _deliveryManagerStatus; // Current status from current_status endpoint
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start with the provided order, but try to fetch full details from server
    // This ensures we get customer_email and other details that might be missing
    _order = widget.order;
    _isLoading = false;
    // Fetch full order details, borrow request, and delivery manager status in the background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrderDetails();
      _loadBorrowRequest();
      _loadDeliveryManagerStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh order details when app comes back to foreground
    // This ensures the status is updated if delivery manager completed delivery
    if (state == AppLifecycleState.resumed && mounted) {
      debugPrint(
        'BorrowOrderDetailScreen: App resumed, refreshing order details',
      );
      _loadOrderDetails();
      _loadBorrowRequest();
    }
  }

  /// Load delivery manager status from current_status endpoint (single source of truth)
  Future<void> _loadDeliveryManagerStatus() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        DeliveryStatusService.setToken(authProvider.token!);
      }

      final statusData = await DeliveryStatusService.getCurrentStatus();

      if (mounted) {
        setState(() {
          _deliveryManagerStatus = statusData?['delivery_status'];
        });
      }
    } catch (e) {
      debugPrint('Error loading delivery manager status: $e');
    }
  }

  /// Extract borrow request ID from order number (e.g., BR000022 -> 22)
  int? _extractBorrowRequestId(String orderNumber) {
    try {
      // Order number format: BR000022
      if (orderNumber.toUpperCase().startsWith('BR')) {
        final idString = orderNumber
            .substring(2)
            .replaceAll(RegExp(r'^0+'), '');
        if (idString.isNotEmpty) {
          return int.parse(idString);
        }
      }
    } catch (e) {
      debugPrint('Error extracting borrow request ID: $e');
    }
    return null;
  }

  /// Load borrow request to get payment information
  Future<void> _loadBorrowRequest() async {
    if (!mounted) return;

    final borrowRequestId = _extractBorrowRequestId(widget.order.orderNumber);
    if (borrowRequestId == null) {
      debugPrint(
        'BorrowOrderDetailScreen: Cannot extract borrow request ID from order number: ${widget.order.orderNumber}',
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoadingBorrowRequest = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        debugPrint('BorrowOrderDetailScreen: No auth token available');
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          setState(() {
            _isLoadingBorrowRequest = false;
            _errorMessage = localizations.authenticationRequired;
          });
        }
        return;
      }

      final borrowService = BorrowService();
      borrowService.setToken(token);

      debugPrint(
        'BorrowOrderDetailScreen: Fetching borrow request $borrowRequestId from server...',
      );
      final borrowRequest = await borrowService.getBorrowRequest(
        borrowRequestId.toString(),
      );

      if (!mounted) return;

      setState(() {
        _borrowRequest = borrowRequest;
        _isLoadingBorrowRequest = false;
        _errorMessage = null;

        // Update order status based on borrow request status
        // This ensures the UI reflects the latest status from the backend
        if (_order != null && borrowRequest != null) {
          final borrowStatus = borrowRequest.status.toLowerCase();

          // Map borrow request status to order status for display
          String newOrderStatus = _order!.status;
          if (borrowStatus == 'active') {
            // When borrow request is "active", delivery is completed
            // Order status should reflect this (could be "delivered" or "active")
            newOrderStatus = 'active';
          } else if (borrowStatus == 'out_for_delivery') {
            newOrderStatus = 'out_for_delivery';
          } else if (borrowStatus == 'delivered') {
            newOrderStatus = 'delivered';
          } else if (borrowStatus == 'in_delivery') {
            newOrderStatus = 'in_delivery';
          }

          // Only update if status actually changed
          if (newOrderStatus != _order!.status) {
            debugPrint(
              'BorrowOrderDetailScreen: Updating order status from "${_order!.status}" to "$newOrderStatus" based on borrow request status "$borrowStatus"',
            );
            _order = _order!.copyWith(status: newOrderStatus);
          }
        }
      });

      debugPrint(
        'BorrowOrderDetailScreen: Successfully loaded borrow request. Status: ${borrowRequest?.status}',
      );
    } catch (e) {
      debugPrint('BorrowOrderDetailScreen: Error loading borrow request: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _isLoadingBorrowRequest = false;
          _errorMessage = '${localizations.error}: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _loadOrderDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check if user is a delivery manager - if so, try BorrowingDeliveryProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userType = authProvider.user?.userType;
      final isDeliveryManager = userType == 'delivery_admin';

      if (isDeliveryManager) {
        // For delivery managers, try to get refreshed order from BorrowingDeliveryProvider
        try {
          final borrowingProvider = Provider.of<BorrowingDeliveryProvider>(
            context,
            listen: false,
          );

          // Force refresh the provider to get latest data
          await borrowingProvider.loadBorrowRequests();

          if (!mounted) return;
          final refreshedOrder = borrowingProvider.getOrderById(
            widget.order.id,
          );

          if (refreshedOrder != null) {
            debugPrint(
              'BorrowOrderDetailScreen: Found order in BorrowingDeliveryProvider. Email: ${refreshedOrder.customerEmail.isEmpty ? "EMPTY" : refreshedOrder.customerEmail}',
            );
            if (mounted) {
              setState(() {
                _order = refreshedOrder;
                _isLoading = false;
              });
              return;
            }
          } else {
            debugPrint(
              'BorrowOrderDetailScreen: Order not found in BorrowingDeliveryProvider after refresh',
            );
          }
        } catch (e) {
          debugPrint(
            'BorrowOrderDetailScreen: Error getting order from BorrowingDeliveryProvider: $e',
          );
        }
      }

      // For customers or if provider refresh failed, keep the existing order
      // The order status will be updated by _loadBorrowRequest() which fetches from the server
      debugPrint(
        'BorrowOrderDetailScreen: Using existing order. Email: ${widget.order.customerEmail.isEmpty ? "EMPTY" : widget.order.customerEmail}',
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // Final fallback
      debugPrint('BorrowOrderDetailScreen: Error in _loadOrderDetails: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Get the effective status to display
  /// For borrow orders, prioritize borrow request status as it's the source of truth
  String _getEffectiveStatus() {
    if (_borrowRequest != null) {
      // Use borrow request status as the source of truth for borrow orders
      return _borrowRequest!.status;
    }
    // Fall back to order status if borrow request is not loaded yet
    return _order?.status ?? 'unknown';
  }

  /// Check if order delivery is complete (order cannot be modified after delivery)
  bool _isDeliveryComplete() {
    if (_order == null) return false;
    // Check if order status is delivered
    if (_order!.isDelivered) return true;
    // For borrow orders, also check if borrow request status is active (delivery complete)
    if (_borrowRequest != null) {
      return _borrowRequest!.status.toLowerCase() == 'active';
    }
    return false;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
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

  Widget _buildStatusChip(String status, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    Color statusColor;
    switch (status.toLowerCase()) {
      case 'pending':
        statusColor = AppColors.warning;
        break;
      case 'assigned':
      case 'confirmed':
        statusColor = AppColors.info;
        break;
      case 'in_delivery':
        statusColor = AppColors.primary;
        break;
      case 'delivered':
        statusColor = AppColors.success;
        break;
      case 'cancelled':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        localizations.getBorrowStatusLabel(status).toUpperCase(),
        style: TextStyle(
          fontSize: AppDimensions.fontSizeXS,
          fontWeight: FontWeight.bold,
          color: statusColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.borrowOrderDetails),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: const Center(child: LoadingIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.borrowOrderDetails),
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
                child: Text(localizations.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localizations.borrowOrderDetails),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: Center(
          child: Text(
            localizations.noOrdersFound,
            style: const TextStyle(fontSize: AppDimensions.fontSizeL),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            return Text(
              '${localizations.orderNumberLabel.split(':')[0]} #${_order!.orderNumber}',
            );
          },
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return IconButton(
                onPressed: () async {
                  // Refresh both order details and borrow request
                  await _loadOrderDetails();
                  await _loadBorrowRequest();
                },
                icon: const Icon(Icons.refresh),
                tooltip: localizations.refresh,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadOrderDetails();
          await _loadBorrowRequest();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Status Section
              _buildSectionCard(
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
                      _buildStatusChip(_getEffectiveStatus(), context),
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
                ],
              ),

              // NOTE: Order Summary section is intentionally NOT included here
              // NOTE: Order Items section is intentionally NOT included here for borrow orders
              // This is the key difference from the purchase order detail screen

              // Additional Notes Section
              _buildSectionCard(
                title: localizations.additionalNotes,
                icon: Icons.note,
                children: [
                  if (_order!.hasNotes) ...[
                    ..._order!.notesList.map(
                      (note) => Container(
                        margin: const EdgeInsets.only(
                          bottom: AppDimensions.spacingM,
                        ),
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              note.content,
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeM,
                              ),
                            ),
                            if (note.authorName != null) ...[
                              const SizedBox(height: AppDimensions.spacingS),
                              Text(
                                '${localizations.byAuthor('')}: ${note.authorName}',
                                style: const TextStyle(
                                  fontSize: AppDimensions.fontSizeS,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                  ] else if (_order!.notes != null &&
                      _order!.notes!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(
                        bottom: AppDimensions.spacingM,
                      ),
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _order!.notes!,
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                  ],
                  if (!_order!.hasNotes &&
                      (_order!.notes == null || _order!.notes!.isEmpty))
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
                  if (!_isDeliveryComplete() && (_order!.canEditNotes ?? true))
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Use the same add notes functionality from OrderDetailScreen
                          // For now, navigate to order detail screen for notes management
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => OrderDetailScreen(
                                orderId: _order!.id,
                                order: _order,
                              ),
                            ),
                          );
                        },
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
              ),

              // Payment Information Section
              _buildSectionCard(
                title: localizations.paymentInformation,
                icon: Icons.payment,
                children: [
                  if (_isLoadingBorrowRequest)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.paddingM),
                        child: LoadingIndicator(),
                      ),
                    )
                  else if (_order!.paymentInfo != null) ...[
                    _buildInfoRow(
                      localizations.paymentMethod,
                      _getPaymentMethodDisplay(
                        _order!.paymentInfo!.paymentMethod,
                        context,
                      ),
                    ),
                    _buildInfoRow(
                      localizations.paymentStatus,
                      _getPaymentStatusDisplay(
                        _order!.paymentInfo!.status,
                        context,
                      ),
                    ),
                    if (_order!.paymentInfo!.transactionId != null)
                      _buildInfoRow(
                        localizations.transactionId,
                        _order!.paymentInfo!.transactionId!,
                      ),
                    if (_order!.totalAmount > 0)
                      _buildInfoRow(
                        localizations.amount,
                        '\$${_order!.totalAmount.toStringAsFixed(2)}',
                      ),
                  ] else if (_order!.paymentMethod != null &&
                      _order!.paymentMethod!.isNotEmpty) ...[
                    // Payment method from order (now includes payment_method from borrow request via serializer)
                    _buildInfoRow(
                      localizations.paymentMethod,
                      _getPaymentMethodDisplay(_order!.paymentMethod!, context),
                    ),
                    _buildInfoRow(
                      localizations.paymentStatus,
                      _borrowRequest != null
                          ? _getBorrowRequestPaymentStatus(
                              _borrowRequest!,
                              context,
                            )
                          : _getPaymentStatusDisplay(_order!.status, context),
                    ),
                    if (_order!.totalAmount > 0)
                      _buildInfoRow(
                        localizations.amount,
                        '\$${_order!.totalAmount.toStringAsFixed(2)}',
                      ),
                  ] else if (_borrowRequest != null) ...[
                    // Get payment status from borrow request when payment method not available
                    _buildInfoRow(
                      localizations.paymentStatus,
                      _getBorrowRequestPaymentStatus(_borrowRequest!, context),
                    ),
                    if (_order!.totalAmount > 0)
                      _buildInfoRow(
                        localizations.amount,
                        '\$${_order!.totalAmount.toStringAsFixed(2)}',
                      ),
                    _buildInfoRow(
                      localizations.paymentMethod,
                      localizations.notAvailable,
                    ),
                  ] else ...[
                    _buildInfoRow(
                      localizations.paymentMethod,
                      localizations.notProvided,
                    ),
                    _buildInfoRow(
                      localizations.paymentStatus,
                      localizations.notProvided,
                    ),
                  ],
                ],
              ),

              // Customer Information Section
              _buildSectionCard(
                title: localizations.customerInformation,
                icon: Icons.person,
                children: [
                  _buildInfoRow(localizations.nameLabel, _order!.customerName),
                  _buildInfoRow(
                    localizations.emailLabel,
                    _order!.customerEmail.isNotEmpty
                        ? _order!.customerEmail
                        : localizations.notProvided,
                  ),
                  if (_order!.deliveryAddress != null) ...[
                    _buildInfoRow(
                      localizations.addressLabel,
                      _order!.deliveryAddress!.fullAddress,
                    ),
                    if (_order!.deliveryAddress!.phone != null)
                      _buildInfoRow(
                        localizations.phoneLabel,
                        _order!.deliveryAddress!.phone!,
                      ),
                  ],
                ],
              ),

              // Action Buttons Section (for pending/assigned orders)
              if (_shouldShowActionButtons()) _buildActionButtonsSection(),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if action buttons should be shown
  /// IMPORTANT: Only show action buttons to delivery managers, not customers
  bool _shouldShowActionButtons() {
    // First check if user is a delivery manager
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userType = authProvider.user?.userType;
    final isDeliveryManager = userType == 'delivery_admin';

    // Don't show action buttons to customers
    if (!isDeliveryManager) {
      debugPrint(
        '_shouldShowActionButtons: User is not a delivery manager (userType: $userType), hiding action buttons',
      );
      return false;
    }

    final status = _order!.status.toLowerCase();
    final borrowRequestStatus = _borrowRequest?.status.toLowerCase();

    // Don't show buttons if delivery is completed
    // Delivery is completed when borrow_request status is 'active' or 'delivered'
    // OR when order status is 'delivered' AND borrow_request status is 'delivered'
    if (borrowRequestStatus == 'active' ||
        borrowRequestStatus == 'delivered' ||
        (status == 'delivered' && borrowRequestStatus == 'delivered')) {
      debugPrint(
        '_shouldShowActionButtons: Delivery completed - hiding Actions section. Order Status: $status, Borrow Request Status: $borrowRequestStatus',
      );
      return false;
    }

    // Show buttons for orders that require action from delivery manager
    // This includes all statuses where the delivery manager can take action
    // Include 'delivered' status only when it's not fully completed (e.g., after Start Delivery, before final confirmation)
    final shouldShow =
        status == 'pending' ||
        status == 'confirmed' ||
        status == 'assigned' ||
        status == 'assigned_to_delivery' ||
        status == 'pending_delivery' ||
        status == 'preparing' ||
        status == 'out_for_delivery' ||
        status == 'in_delivery' ||
        (status == 'delivered' &&
            borrowRequestStatus !=
                'delivered') || // Show buttons when status is 'delivered' but borrow request is not 'delivered' (awaiting confirmation)
        (status == 'pending_assignment' && _borrowRequest != null);

    debugPrint(
      '_shouldShowActionButtons: $shouldShow for status: $status (borrowRequest: ${_borrowRequest?.status}), userType: $userType',
    );

    return shouldShow;
  }

  /// Build action buttons section based on order status
  Widget _buildActionButtonsSection() {
    final status = _order!.status.toLowerCase();
    final borrowRequestStatus = _borrowRequest?.status.toLowerCase();

    // Debug logging to help identify why buttons aren't showing
    debugPrint('=== Action Buttons Debug ===');
    debugPrint('Order Status: $status');
    debugPrint('Borrow Request Status: $borrowRequestStatus');
    debugPrint('Has Borrow Request: ${_borrowRequest != null}');

    return Card(
      margin: const EdgeInsets.only(top: AppDimensions.spacingM),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Row(
                  children: [
                    const Icon(
                      Icons.touch_app,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                    Text(
                      localizations.actions,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSizeL,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingM),
            // Determine which buttons to show based on order status
            // Priority: Check borrow request status first (source of truth), then order status as fallback
            Builder(
              builder: (context) {
                // Determine the actual status to check (borrow request status is source of truth)
                final actualStatus =
                    (_borrowRequest != null && borrowRequestStatus != null)
                    ? borrowRequestStatus
                    : status;

                // Check if delivery has started (but not yet completed)
                // After "Start Delivery" is clicked, status changes to "delivered" (awaiting final confirmation)
                // Also check for in_delivery status for backward compatibility
                // Don't show buttons if borrow_request status is 'active' (delivery is completed)
                // Priority: Check order status first (more reliable after start delivery)
                final isDeliveryCompleted =
                    borrowRequestStatus == 'active' ||
                    borrowRequestStatus == 'delivered' ||
                    (status == 'delivered' &&
                        borrowRequestStatus == 'delivered');
                final deliveryStarted =
                    !isDeliveryCompleted &&
                    (status == 'in_delivery' ||
                        (borrowRequestStatus != null &&
                            (borrowRequestStatus == 'in_delivery' ||
                                borrowRequestStatus == 'out_for_delivery')));

                // Check if order needs Accept/Reject buttons
                // Only show Accept/Reject when order is assigned but not yet accepted
                final needsAcceptReject =
                    _borrowRequest != null &&
                    (borrowRequestStatus == 'assigned_to_delivery' ||
                        borrowRequestStatus == 'pending_delivery') &&
                    borrowRequestStatus != 'preparing' &&
                    borrowRequestStatus != 'out_for_delivery' &&
                    borrowRequestStatus != 'in_delivery' &&
                    borrowRequestStatus != 'confirmed';

                // Explicitly define statuses that should show "Start Delivery" button
                // out_for_delivery means "ready to start" - show Start Delivery button
                // Priority: Check order status first, then borrow request status
                final orderCanStartDelivery =
                    status == 'confirmed' ||
                    status == 'preparing' ||
                    status == 'pending_delivery' ||
                    status == 'assigned_to_delivery' ||
                    status == 'assigned' ||
                    status == 'approved' ||
                    status == 'accepted' ||
                    status ==
                        'out_for_delivery'; // out_for_delivery = ready to start delivery

                final borrowRequestCanStartDelivery =
                    borrowRequestStatus == null ||
                    borrowRequestStatus == 'confirmed' ||
                    borrowRequestStatus == 'preparing' ||
                    borrowRequestStatus == 'pending_delivery' ||
                    borrowRequestStatus == 'assigned_to_delivery' ||
                    borrowRequestStatus == 'assigned' ||
                    borrowRequestStatus == 'approved' ||
                    borrowRequestStatus == 'accepted' ||
                    borrowRequestStatus ==
                        'out_for_delivery'; // out_for_delivery = ready to start delivery

                // Don't show "Start Delivery" if status is already "delivered" (delivery has been started)
                // or if delivery is completed (borrow_request status is 'active' or 'delivered')
                // IMPORTANT: Only show Start Delivery button if manager is Online
                final isManagerOnline =
                    _deliveryManagerStatus?.toLowerCase() == 'online';
                final canStartDelivery =
                    !isDeliveryCompleted &&
                    !deliveryStarted &&
                    status != 'delivered' &&
                    borrowRequestStatus != 'delivered' &&
                    !needsAcceptReject &&
                    isManagerOnline && // Manager must be Online to start delivery
                    (orderCanStartDelivery || borrowRequestCanStartDelivery);

                debugPrint('=== Button Logic Debug ===');
                debugPrint('Order Status: $status');
                debugPrint('Borrow Request Status: $borrowRequestStatus');
                debugPrint('Actual Status (used for logic): $actualStatus');
                debugPrint('Delivery Started: $deliveryStarted');
                debugPrint('Needs Accept/Reject: $needsAcceptReject');
                debugPrint('Manager Status: $_deliveryManagerStatus');
                debugPrint('Is Manager Online: $isManagerOnline');
                debugPrint('Can Start Delivery: $canStartDelivery');

                if (needsAcceptReject) {
                  // Show Accept/Reject buttons for orders that haven't been accepted yet
                  final localizations = AppLocalizations.of(context);
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleAcceptRequest,
                          icon: const Icon(Icons.check, size: 20),
                          label: Text(localizations.acceptRequest),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimensions.paddingM,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : _handleRejectRequest,
                          icon: const Icon(Icons.close, size: 20),
                          label: Text(localizations.reject),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimensions.paddingM,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else if (deliveryStarted && !isDeliveryCompleted) {
                  // Show Delivered and Update Current Location buttons after delivery has started
                  // But hide them when delivery is completed (status is 'delivered' or borrow request is 'delivered'/'active')
                  // This appears when status is "in_delivery" or "out_for_delivery" (delivery in progress)
                  // Hide buttons if order status is 'delivered' (delivery completed)
                  final localizations = AppLocalizations.of(context);
                  final statusLabel =
                      _deliveryManagerStatus?.toUpperCase() ??
                      localizations.busy.toUpperCase();
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : _handleCompleteDelivery,
                          icon: const Icon(Icons.done_all, size: 20),
                          label: Text(localizations.completeDelivery),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimensions.paddingM,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingM),
                      // Update Current Location button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading || _isUpdatingLocation
                              ? null
                              : _handleUpdateLocation,
                          icon: _isUpdatingLocation
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.location_on, size: 20),
                          label: Text(
                            _isUpdatingLocation
                                ? localizations.updatingLocation
                                : localizations.updateCurrentLocation,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimensions.paddingM,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingM),
                      // Show status banner based on actual delivery manager status from current_status endpoint
                      if (_deliveryManagerStatus == 'busy')
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusS,
                            ),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: AppDimensions.spacingS),
                              Expanded(
                                child: Text(
                                  localizations.deliveryInProgressStatus(
                                    statusLabel,
                                  ),
                                  style: const TextStyle(
                                    fontSize: AppDimensions.fontSizeS,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                } else if (canStartDelivery) {
                  // Show Start Delivery button when delivery can be started
                  // This button appears for orders that have been accepted but delivery hasn't started
                  // Statuses: confirmed, preparing, pending_delivery, assigned_to_delivery, assigned, approved, accepted
                  // IMPORTANT: Only shown when manager is Online
                  final localizations = AppLocalizations.of(context);
                  debugPrint(
                    'Showing Start Delivery button - Order Status: $status, Borrow Request Status: $borrowRequestStatus, Actual Status: $actualStatus, Manager Status: $_deliveryManagerStatus',
                  );

                  // Show warning if manager is not Online (shouldn't happen due to canStartDelivery check, but safety check)
                  return Column(
                    children: [
                      if (!isManagerOnline && _deliveryManagerStatus != null)
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          margin: const EdgeInsets.only(
                            bottom: AppDimensions.spacingM,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusS,
                            ),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: AppDimensions.spacingS),
                              Expanded(
                                child: Text(
                                  localizations.youMustBeOnlineToStartDelivery,
                                  style: const TextStyle(
                                    fontSize: AppDimensions.fontSizeS,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_isLoading || !isManagerOnline)
                              ? null
                              : _handleStartDelivery,
                          icon: const Icon(Icons.local_shipping, size: 20),
                          label: Text(localizations.startDelivery),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimensions.paddingM,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Fallback: If none of the above conditions match, check if delivery is completed
                  // If delivery is completed, don't show any buttons
                  if (isDeliveryCompleted || status == 'delivered') {
                    debugPrint(
                      'Delivery completed - hiding all action buttons. Order Status: $status, Borrow Request Status: $borrowRequestStatus',
                    );
                    return const SizedBox.shrink();
                  }

                  // Only show Start Delivery button if delivery hasn't started and isn't completed
                  // IMPORTANT: Also check if manager is Online
                  final localizations = AppLocalizations.of(context);
                  final isManagerOnlineFallback =
                      _deliveryManagerStatus?.toLowerCase() == 'online';
                  debugPrint(
                    'Fallback: Showing Start Delivery button - Order Status: $status, Borrow Request Status: $borrowRequestStatus, Actual Status: $actualStatus, Manager Status: $_deliveryManagerStatus',
                  );

                  // Show warning if manager is not Online
                  return Column(
                    children: [
                      if (!isManagerOnlineFallback &&
                          _deliveryManagerStatus != null)
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          margin: const EdgeInsets.only(
                            bottom: AppDimensions.spacingM,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radiusS,
                            ),
                            border: Border.all(color: AppColors.warning),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                size: 16,
                                color: AppColors.warning,
                              ),
                              const SizedBox(width: AppDimensions.spacingS),
                              Expanded(
                                child: Text(
                                  localizations.youMustBeOnlineToStartDelivery,
                                  style: const TextStyle(
                                    fontSize: AppDimensions.fontSizeS,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_isLoading || !isManagerOnlineFallback)
                              ? null
                              : _handleStartDelivery,
                          icon: const Icon(Icons.local_shipping, size: 20),
                          label: Text(localizations.startDelivery),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
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
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Handle accept request
  Future<void> _handleAcceptRequest() async {
    if (!mounted) return;

    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.acceptDeliveryRequest),
        content: Text(localizations.acceptDeliveryRequestMessage),
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
            child: Text(localizations.acceptRequest),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      final provider = Provider.of<BorrowingDeliveryProvider>(
        context,
        listen: false,
      );

      final success = await provider.acceptRequest(_order!.id);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        if (!mounted) return;
        // Refresh delivery manager status from current_status endpoint
        await _loadDeliveryManagerStatus();
        try {
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            final statusLabel =
                _deliveryManagerStatus?.toUpperCase() ??
                localizations.busy.toUpperCase();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.requestAcceptedStatus(statusLabel)),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } catch (_) {
          // Widget disposed, ignore
        }
        // Reload order details
        try {
          if (!mounted) return;
          await _loadOrderDetails();
          if (!mounted) return;
          await _loadBorrowRequest();
        } catch (e) {
          debugPrint('Error reloading order details after accept: $e');
          // Don't show error to user, the accept was successful
        }
      } else {
        if (!mounted) return;
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage ?? 'Failed to accept request',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        } catch (_) {
          // Widget disposed, ignore
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      } catch (_) {
        // Widget disposed, ignore
      }
    }
  }

  /// Handle reject request
  Future<void> _handleRejectRequest() async {
    if (!mounted) return;

    final localizations = AppLocalizations.of(context);
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.rejectDeliveryRequest),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.rejectDeliveryRequestMessage),
            const SizedBox(height: AppDimensions.spacingM),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: localizations.enterRejectionReason,
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
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.pleaseProvideRejectionReason),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: Text(localizations.reject),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      final provider = Provider.of<BorrowingDeliveryProvider>(
        context,
        listen: false,
      );

      final success = await provider.rejectRequest(
        _order!.id,
        reasonController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        if (!mounted) return;
        try {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.requestRejectedSuccessfully),
              backgroundColor: AppColors.success,
            ),
          );
        } catch (_) {
          // Widget disposed, ignore
        }
        // Navigate back since the order is no longer assigned to this delivery manager
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        if (!mounted) return;
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage ?? 'Failed to reject request',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        } catch (_) {
          // Widget disposed, ignore
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      } catch (_) {
        // Widget disposed, ignore
      }
    }
  }

  /// Handle start delivery
  Future<void> _handleStartDelivery() async {
    if (!mounted) return;

    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.startDelivery),
        content: Text(localizations.startDeliveryConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.info,
              foregroundColor: AppColors.white,
            ),
            child: Text(localizations.startDelivery),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      final provider = Provider.of<BorrowingDeliveryProvider>(
        context,
        listen: false,
      );

      // Get delivery manager ID from auth provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final deliveryManagerId = authProvider.user?.id;

      if (deliveryManagerId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to get delivery manager ID. Please login again.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final success = await provider.startDelivery(
        _order!.id,
        deliveryManagerId,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        if (!mounted) return;
        // Refresh delivery manager status from current_status endpoint
        await _loadDeliveryManagerStatus();
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          final statusLabel =
              _deliveryManagerStatus?.toUpperCase() ??
              localizations.busy.toUpperCase();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.deliveryStartedStatus(statusLabel)),
              backgroundColor: AppColors.info,
            ),
          );
        }
        // Reload order details and borrow request to get updated status
        // This is critical to show "Mark as Delivered" button after delivery starts
        try {
          if (!mounted) return;
          // Force refresh from provider first to get updated order status
          final borrowingProvider = Provider.of<BorrowingDeliveryProvider>(
            context,
            listen: false,
          );
          await borrowingProvider.loadBorrowRequests();

          if (!mounted) return;
          // Get the updated order from provider (should have status 'in_delivery')
          final updatedOrder = borrowingProvider.getOrderById(_order!.id);
          if (updatedOrder != null) {
            debugPrint(
              'BorrowOrderDetailScreen: Updated order status after start delivery: ${updatedOrder.status}',
            );
            debugPrint(
              'BorrowOrderDetailScreen: Previous order status: ${_order!.status}',
            );
            setState(() {
              _order = updatedOrder;
            });
            debugPrint(
              'BorrowOrderDetailScreen: Order status after setState: ${_order!.status}',
            );
          } else {
            debugPrint(
              'BorrowOrderDetailScreen: Updated order not found in provider after start delivery',
            );
          }

          if (!mounted) return;
          // Then reload order details from server
          await _loadOrderDetails();

          if (!mounted) return;
          // Reload borrow request to get updated status
          await _loadBorrowRequest();

          // Force a rebuild to show updated buttons
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          debugPrint('Error reloading order details after start delivery: $e');
        }
      } else {
        if (!mounted) return;
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage ?? 'Failed to start delivery',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        } catch (_) {
          // Widget disposed, ignore
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      } catch (_) {
        // Widget disposed, ignore
      }
    }
  }

  /// Handle complete delivery
  Future<void> _handleCompleteDelivery() async {
    if (!mounted) return;

    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.completeDelivery),
        content: Text(localizations.completeDeliveryMessage),
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
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (!mounted) return;
      final provider = Provider.of<BorrowingDeliveryProvider>(
        context,
        listen: false,
      );

      final success = await provider.completeDelivery(_order!.id);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (success) {
        if (!mounted) return;
        // Refresh delivery manager status from current_status endpoint
        await _loadDeliveryManagerStatus();
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          final statusLabel =
              _deliveryManagerStatus?.toUpperCase() ??
              localizations.online.toUpperCase();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.deliveryCompletedStatus(statusLabel)),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        // Reload order details
        try {
          if (!mounted) return;
          await _loadOrderDetails();
          if (!mounted) return;
          await _loadBorrowRequest();
        } catch (e) {
          debugPrint(
            'Error reloading order details after complete delivery: $e',
          );
        }
      } else {
        if (!mounted) return;
        // Check if error is 403 Forbidden
        final errorMessage = provider.errorMessage ?? '';
        final isForbidden =
            errorMessage.toLowerCase().contains('403') ||
            errorMessage.toLowerCase().contains('forbidden') ||
            errorMessage.toLowerCase().contains('permission');

        if (isForbidden) {
          // Hide delivery buttons and show error - don't retry
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.youDoNotHavePermissionDeliveryManagersOnly,
              ),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
          // Reload data to ensure UI reflects backend state
          await _loadOrderDetails();
          await _loadBorrowRequest();
        } else {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.error,
              ),
            );
          } catch (_) {
            // Widget disposed, ignore
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      // Check if error is 403 Forbidden
      final errorString = e.toString().toLowerCase();
      final isForbidden =
          errorString.contains('403') || errorString.contains('forbidden');

      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isForbidden
                  ? AppLocalizations.of(
                      context,
                    ).youDoNotHavePermissionDeliveryManagersOnly
                  : 'Error: ${e.toString()}',
            ),
            backgroundColor: AppColors.error,
            duration: isForbidden ? const Duration(seconds: 5) : Duration.zero,
          ),
        );
        // Reload data if forbidden to ensure UI reflects backend state
        if (isForbidden) {
          await _loadOrderDetails();
          await _loadBorrowRequest();
        }
      } catch (_) {
        // Widget disposed, ignore
      }
    }
  }

  /// Handle update current location
  Future<void> _handleUpdateLocation() async {
    if (!mounted) return;

    setState(() {
      _isUpdatingLocation = true;
    });

    try {
      // Check location service enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.locationServicesDisabled),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.locationPermissionsDenied),
                backgroundColor: AppColors.error,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.locationPermissionsPermanentlyDenied),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Get current GPS position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      // Get auth token
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizations.authenticationRequiredPleaseLoginAgain,
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Send location update to backend
      final url = '${ApiService.baseUrl}/delivery/location/';
      debugPrint('Update Location - Full URL: $url');
      debugPrint('Update Location - Base URL: ${ApiService.baseUrl}');
      debugPrint(
        'Update Location - Coordinates: ${position.latitude}, ${position.longitude}',
      );

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': position.latitude,
          'longitude': position.longitude,
        }),
      );

      debugPrint('Update Location - Response Status: ${response.statusCode}');
      debugPrint(
        'Update Location - Response Body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}',
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Location updated successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    data['error'] ??
                        data['message'] ??
                        'Failed to update location',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        } catch (e) {
          debugPrint('Error parsing response: $e');
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.locationUpdatedSuccessfully),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      } else {
        // Handle error response - try to parse JSON, fallback to generic message
        final localizations = AppLocalizations.of(context);
        String errorMessage = localizations.failedToUpdateLocation;
        try {
          final data = jsonDecode(response.body);
          errorMessage = data['error'] ?? data['message'] ?? errorMessage;
        } catch (e) {
          // Response is not JSON (likely HTML 404 page)
          debugPrint(
            'Error response is not JSON: ${response.body.substring(0, response.body.length > 100 ? 100 : response.body.length)}',
          );
          if (response.statusCode == 404) {
            errorMessage = localizations.endpointNotFound;
          } else {
            errorMessage = localizations.failedToUpdateLocationWithStatus(
              response.statusCode.toString(),
            );
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error updating location: $e');
      final localizations = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.errorUpdatingLocation(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingLocation = false;
        });
      }
    }
  }

  String _getPaymentMethodDisplay(String method, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    switch (method.toLowerCase()) {
      case 'card':
      case 'mastercard':
        return localizations.paymentMethodCard;
      case 'cash_on_delivery':
      case 'cod':
      case 'cash':
        return localizations.paymentMethodCashOnDelivery;
      default:
        return method;
    }
  }

  String _getPaymentStatusDisplay(String status, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    switch (status.toLowerCase()) {
      case 'paid':
        return localizations.paymentStatusPaid;
      case 'unpaid':
        return localizations.paymentStatusUnpaid;
      case 'pending':
        return localizations.paymentStatusPending;
      case 'delivered':
        // For payment status, "delivered" means payment was completed upon delivery
        // Use statusDelivered which is already translated
        return localizations.statusDelivered;
      case 'completed':
        return localizations.paymentStatusPaid;
      default:
        // Try to get localized status from borrow status labels
        try {
          final borrowStatusLabel = localizations.getBorrowStatusLabel(status);
          // If getBorrowStatusLabel returns a different value, it means it was translated
          if (borrowStatusLabel.toLowerCase() != status.toLowerCase()) {
            return borrowStatusLabel;
          }
        } catch (e) {
          // getBorrowStatusLabel might throw for invalid statuses, continue to fallback
        }
        // Final fallback: return the status as-is
        return status;
    }
  }

  /// Get payment status from borrow request based on its status
  String _getBorrowRequestPaymentStatus(
    BorrowRequest borrowRequest,
    BuildContext context,
  ) {
    final localizations = AppLocalizations.of(context);
    // Check borrow request status to determine payment status
    final status = borrowRequest.status.toLowerCase();
    if (status == 'payment_pending' || status == 'pending') {
      return localizations.paymentStatusPending;
    } else if (status == 'approved' ||
        status == 'assigned_to_delivery' ||
        status == 'preparing' ||
        status == 'out_for_delivery' ||
        status == 'active') {
      return localizations.paymentStatusPaid;
    } else {
      return localizations.notAvailable;
    }
  }
}
