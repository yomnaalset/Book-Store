import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../orders/models/order.dart';
import '../../../providers/delivery_provider.dart';
import '../../../widgets/library_manager/status_chip.dart';

class DeliveryMonitoringDetailsScreen extends StatefulWidget {
  final Order order;

  const DeliveryMonitoringDetailsScreen({super.key, required this.order});

  @override
  State<DeliveryMonitoringDetailsScreen> createState() =>
      _DeliveryMonitoringDetailsScreenState();
}

class _DeliveryMonitoringDetailsScreenState
    extends State<DeliveryMonitoringDetailsScreen> {
  Timer? _refreshTimer;
  Order? _currentOrder;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    // Refresh every 30 seconds to get real-time updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _refreshDeliveryData();
    });
  }

  Future<void> _refreshDeliveryData() async {
    try {
      final provider = context.read<DeliveryProvider>();
      await provider.loadDeliveryOrders();

      // Find the updated order
      final updatedOrder =
          provider.orders
                  .where(
                    (order) =>
                        order.id.toString() == widget.order.id.toString(),
                  )
                  .firstOrNull
              as Order?;

      if (updatedOrder != null && mounted) {
        setState(() {
          _currentOrder = updatedOrder;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing delivery data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _currentOrder ?? widget.order;

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery #${order.id}'),
        backgroundColor: const Color(0xFFB5E7FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _refreshDeliveryData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(order),
            const SizedBox(height: 16),
            _buildDeliveryInfoCard(order),
            const SizedBox(height: 16),
            _buildAgentInfoCard(order),
            const SizedBox(height: 16),
            _buildLocationTrackingCard(order),
            const SizedBox(height: 16),
            _buildTimelineCard(order),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Order order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Delivery #${order.id}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF6C757D)),
                const SizedBox(width: 8),
                Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF495057),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfoCard(Order order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Order ID', order.id.toString(), Icons.inventory),
            _buildInfoRow(
              'Delivery Address',
              order.deliveryAddress?.toString() ??
                  order.deliveryAddressText ??
                  'No address',
              Icons.location_on,
            ),
            _buildInfoRow(
              'Request Date',
              _formatDate(order.createdAt),
              Icons.calendar_today,
            ),
            if (order.deliveredAt != null)
              _buildInfoRow(
                'Delivered Date',
                _formatDate(order.deliveredAt!),
                Icons.check_circle,
                textColor: Colors.green,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentInfoCard(Order order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Agent Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            if (order.hasDeliveryAssignment &&
                order.deliveryAgentId != null &&
                order.deliveryAgentId!.isNotEmpty) ...[
              _buildInfoRow(
                'Agent ID',
                order.deliveryAgentId.toString(),
                Icons.delivery_dining,
                textColor: Colors.blue,
              ),
              _buildInfoRow(
                'Agent Name',
                order.deliveryAgentName,
                Icons.person,
                textColor: Colors.blue,
              ),
              _buildInfoRow(
                'Phone Number',
                'Contact Admin', // This would come from the API
                Icons.phone,
                textColor: Colors.blue,
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'No delivery agent assigned yet',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTrackingCard(Order order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Real-time Location Tracking',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            if (order.deliveryAgentId != null &&
                order.deliveryAgentId!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_searching,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Live Location Map',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Agent Location: ${_getMockLocation()}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Updated: ${_formatTime(DateTime.now())}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                'Current Status',
                _getCurrentStatus(order.status),
                Icons.info,
                textColor: _getStatusColor(order.status),
              ),
              _buildInfoRow(
                'Estimated Arrival',
                _getEstimatedArrival(order),
                Icons.schedule,
                textColor: Colors.green,
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_off, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location tracking will be available once agent assigned',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(Order order) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              'Request Created',
              order.createdAt,
              true,
              Icons.add_circle,
            ),
            if (order.deliveryAssignment?.scheduledDate != null)
              _buildTimelineItem(
                'Scheduled for Delivery',
                order.deliveryAssignment!.scheduledDate,
                true,
                Icons.schedule,
              ),
            if (order.deliveryAgentId != null &&
                order.deliveryAgentId!.isNotEmpty)
              _buildTimelineItem(
                'Agent Assigned',
                order.createdAt, // This would be the actual assignment date
                true,
                Icons.person_add,
              ),
            if (order.status == 'in_delivery')
              _buildTimelineItem(
                'Out for Delivery',
                DateTime.now(), // This would be the actual pickup time
                true,
                Icons.local_shipping,
              ),
            if (order.deliveredAt != null)
              _buildTimelineItem(
                'Delivered',
                order.deliveredAt!,
                true,
                Icons.check_circle,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C757D)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6C757D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor ?? const Color(0xFF495057),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    DateTime date,
    bool isCompleted,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isCompleted ? Colors.green : Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.black87 : Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C757D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _getMockLocation() {
    // This would be replaced with real location data from the API
    final locations = [
      '123 Main Street, Downtown',
      '456 Oak Avenue, Midtown',
      '789 Pine Road, Uptown',
      '321 Elm Street, Downtown',
    ];
    return locations[DateTime.now().second % locations.length];
  }

  String _getCurrentStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending_assignment':
        return 'Waiting for Assignment';
      case 'assigned':
        return 'Agent Assigned - Preparing for Pickup';
      case 'in_progress':
        return 'Out for Delivery';
      case 'delivered':
        return 'Successfully Delivered';
      case 'cancelled':
        return 'Delivery Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending_assignment':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'in_progress':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getEstimatedArrival(Order order) {
    if (order.status == 'delivered') {
      return 'Delivered';
    } else if (order.status == 'in_delivery') {
      // Mock estimated arrival time
      final now = DateTime.now();
      final estimated = now.add(const Duration(minutes: 30));
      return '${estimated.hour.toString().padLeft(2, '0')}:${estimated.minute.toString().padLeft(2, '0')}';
    } else {
      return 'TBD';
    }
  }
}
