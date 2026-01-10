import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/orders_provider.dart';
import '../../../../orders/models/order.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../widgets/customer_order_details_widget.dart';
import '../../widgets/admin_order_details_widget.dart';
import '../../widgets/delivery_manager_order_details_widget.dart';
import '../../widgets/order_details_shared.dart';
import '../../../../../core/localization/app_localizations.dart';

class OrderDetailsPage extends StatefulWidget {
  final Order order;

  const OrderDetailsPage({super.key, required this.order});

  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  bool _isLoading = false;
  Order? _currentOrder;
  bool _isEditMode = false; // Track edit mode for delivery managers

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    // Defer the API call to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchOrderDetails();
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userType = authProvider.user?.userType ?? 'customer';
    final shared = OrderDetailsShared();

    // Use the same logic as _buildOrderDetailsContent to determine user type
    final isDeliveryAdmin =
        userType == 'delivery_admin' || authProvider.isDeliveryAdmin;

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
        title: Builder(
          builder: (context) {
            final localizations = AppLocalizations.of(context);
            final order = _currentOrder ?? widget.order;
            final orderNumber = order.orderNumber.isNotEmpty
                ? order.orderNumber
                : 'ORD-${order.id.toString().padLeft(4, '0')}';
            return Text(localizations.orderNumberPrefix(orderNumber));
          },
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
}
