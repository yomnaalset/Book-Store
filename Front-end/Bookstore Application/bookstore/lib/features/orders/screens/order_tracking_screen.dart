import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

import '../../../core/services/api_service.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../orders/models/order.dart';
import '../widgets/order_status_card.dart';
import '../widgets/delivery_tracking_map.dart';
import '../widgets/delivery_manager_info.dart';
import '../widgets/order_items_list.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;

  const OrderTrackingScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  Order? _order;
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _refreshTimer;
  Map<String, dynamic>? _deliveryManagerLocation;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
    _startPeriodicRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    // Refresh order details every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _fetchOrderDetails();
      }
    });
  }

  Future<void> _fetchOrderDetails() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/api/delivery/orders/${widget.orderId}/',
        ),
        headers: {
          'Authorization': 'Bearer YOUR_AUTH_TOKEN',
        }, // This should come from auth service
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _order = Order.fromJson(data);
          _isLoading = false;
          _errorMessage = null;
        });

        // If order is in delivery, fetch delivery manager location
        if (_order?.status == 'in_delivery') {
          _fetchDeliveryManagerLocation();
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load order details';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchDeliveryManagerLocation() async {
    try {
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/api/delivery/orders/${widget.orderId}/delivery-location/',
        ),
        headers: {
          'Authorization': 'Bearer YOUR_AUTH_TOKEN',
        }, // This should come from auth service
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _deliveryManagerLocation = data;
        });
      }
    } catch (e) {
      // Error fetching delivery manager location - silently handle
    }
  }

  Future<void> _refreshOrder() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchOrderDetails();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order #${widget.orderNumber}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 204),
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
              icon: const Icon(Icons.refresh),
              onPressed: _refreshOrder,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ErrorMessage(message: _errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshOrder,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _order == null
          ? const Center(child: Text('Order not found'))
          : RefreshIndicator(
              onRefresh: _refreshOrder,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Status Card
                    OrderStatusCard(order: _order!),

                    const SizedBox(height: 16),

                    // Delivery Tracking (if in delivery)
                    if (_order!.status == 'in_delivery') ...[
                      DeliveryTrackingMap(
                        order: _order!,
                        deliveryManagerLocation: _deliveryManagerLocation,
                      ),
                      const SizedBox(height: 16),
                      DeliveryManagerInfo(
                        order: _order!,
                        deliveryManagerLocation: _deliveryManagerLocation,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Order Items
                    OrderItemsList(items: _order!.items),

                    const SizedBox(height: 16),

                    // Order Details
                    _buildOrderDetails(),

                    const SizedBox(height: 16),

                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Details',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            _buildDetailRow('Order Number', _order!.orderNumber),
            _buildDetailRow('Order Date', _formatDate(_order!.createdAt)),
            _buildDetailRow(
              'Total Amount',
              '\$${_order!.totalAmount.toStringAsFixed(2)}',
            ),
            _buildDetailRow(
              'Payment Method',
              _order!.paymentInfo?.paymentMethod ?? 'Cash on Delivery',
            ),

            if (_order!.deliveryAddress != null) ...[
              const SizedBox(height: 8),
              Text(
                'Delivery Address',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(_order!.deliveryAddress!.fullAddress),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Contact Support Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _contactSupport,
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Support'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Cancel Order Button (if pending)
        if (_order!.status == 'pending') ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _cancelOrder,
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Order'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Call Support'),
              subtitle: const Text('+1 (555) 123-4567'),
              onTap: () {
                Navigator.pop(context);
                // Implement phone call functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Email Support'),
              subtitle: const Text('support@bookstore.com'),
              onTap: () {
                Navigator.pop(context);
                // Implement email functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Live Chat'),
              subtitle: const Text('Available 24/7'),
              onTap: () {
                Navigator.pop(context);
                // Implement live chat functionality
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _cancelOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Are you sure you want to cancel this order? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Order'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _performCancelOrder();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancelOrder() async {
    try {
      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/api/delivery/orders/${widget.orderId}/cancel/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({'reason': 'Customer requested cancellation'}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Order cancelled successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          _refreshOrder();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel order'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling order: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
