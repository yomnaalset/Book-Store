import 'package:flutter/material.dart';
import '../models/delivery_task.dart';

class EnhancedDeliveryCard extends StatelessWidget {
  final DeliveryTask task;
  final VoidCallback onStartDelivery;
  final VoidCallback onCompleteDelivery;
  final bool isTrackingEnabled;

  const EnhancedDeliveryCard({
    super.key,
    required this.task,
    required this.onStartDelivery,
    required this.onCompleteDelivery,
    this.isTrackingEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with task number and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Task #${task.taskNumber}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),

            const SizedBox(height: 16),

            // Task Information
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  // Customer Information
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Customer: ${task.customerName}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Delivery Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Address: ${task.deliveryAddress}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Task Type
                  Row(
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Type: ${_getTaskTypeDisplay(task.taskType)}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  if (task.notes != null && task.notes!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.note_outlined,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notes: ${task.notes}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color textColor;
    String statusText;

    switch (task.status.toLowerCase()) {
      case 'pending':
        textColor = Colors.orange;
        statusText = 'Pending';
        break;
      case 'assigned':
        textColor = Colors.blue;
        statusText = 'Assigned';
        break;
      case 'accepted':
        textColor = Colors.cyan;
        statusText = 'Accepted';
        break;
      case 'in_progress':
        textColor = Colors.purple;
        statusText = 'In Progress';
        break;
      case 'delivered':
        textColor = Colors.green;
        statusText = 'Delivered';
        break;
      case 'completed':
        textColor = Colors.green;
        statusText = 'Completed';
        break;
      case 'failed':
        textColor = Colors.red;
        statusText = 'Failed';
        break;
      default:
        textColor = Colors.grey;
        statusText = task.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    switch (task.status.toLowerCase()) {
      case 'assigned':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onStartDelivery,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start Delivery'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28A745),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'in_progress':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onCompleteDelivery,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Mark Delivered'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '✓ Delivery Completed',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
          ),
        );
      case 'completed':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '✓ Task Completed',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
          ),
        );
      case 'failed':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '✗ Delivery Failed',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
          ),
        );
      default:
        final theme = Theme.of(context);
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Status: ${task.status}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF383D41),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
    }
  }

  String _getTaskTypeDisplay(String taskType) {
    switch (taskType.toLowerCase()) {
      case 'pickup':
        return 'Pickup';
      case 'delivery':
        return 'Delivery';
      case 'return':
        return 'Return';
      default:
        return taskType;
    }
  }
}
