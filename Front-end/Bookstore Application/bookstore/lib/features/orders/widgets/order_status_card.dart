import 'package:flutter/material.dart';
import '../../orders/models/order.dart';

class OrderStatusCard extends StatelessWidget {
  final Order order;

  const OrderStatusCard({super.key, required this.order});

  /// Get the effective status for display, checking delivery assignment if available
  String _getEffectiveStatus() {
    // If delivery assignment status is 'in_delivery', show that instead of order status
    if (order.deliveryAssignment != null &&
        order.deliveryAssignment!.status.toLowerCase() == 'in_delivery') {
      return 'in_delivery';
    }
    return order.status;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = _getEffectiveStatus();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getStatusIcon(effectiveStatus),
                  color: _getStatusColor(effectiveStatus),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Order Status',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      effectiveStatus,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(effectiveStatus),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStatusText(effectiveStatus),
                    style: TextStyle(
                      color: _getStatusColor(effectiveStatus),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status Progress
            _buildStatusProgress(context, effectiveStatus),

            const SizedBox(height: 16),

            // Estimated Delivery
            if (effectiveStatus != 'delivered' &&
                effectiveStatus != 'cancelled') ...[
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    'Estimated delivery: ${_getEstimatedDelivery(effectiveStatus)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusProgress(BuildContext context, String effectiveStatus) {
    final statuses = ['pending', 'confirmed', 'in_delivery', 'delivered'];
    final currentIndex = statuses.indexOf(effectiveStatus);

    return Row(
      children: statuses.asMap().entries.map((entry) {
        final index = entry.key;
        final isCompleted = index <= currentIndex;
        final isCurrent = index == currentIndex;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : isCurrent
                    ? Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              if (index < statuses.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted
                        ? Theme.of(context).primaryColor
                        : Colors.grey[300],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule;
      case 'confirmed':
        return Icons.check_circle_outline;
      case 'in_delivery':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.home;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'in_delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Approval';
      case 'confirmed':
        return 'Confirmed';
      case 'in_delivery':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status.toUpperCase();
    }
  }

  String _getEstimatedDelivery(String status) {
    switch (status) {
      case 'pending':
        return 'Within 24 hours';
      case 'confirmed':
        return 'Within 2-4 hours';
      case 'in_delivery':
        return 'Within 1 hour';
      default:
        return 'N/A';
    }
  }
}
