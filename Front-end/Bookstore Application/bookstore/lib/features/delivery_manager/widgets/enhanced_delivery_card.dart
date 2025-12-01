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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with task number and status
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Task #${task.taskNumber}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),

            const SizedBox(height: 16),

            // Task Information
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
              ),
              child: Column(
                children: [
                  // Customer Information
                  Row(
                    children: [
                      const Icon(
                        Icons.person,
                        size: 20,
                        color: Color(0xFF6C757D),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Customer: ${task.customerName}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF495057),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Delivery Address
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 20,
                        color: Color(0xFF6C757D),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Address: ${task.deliveryAddress}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF495057),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Task Type
                  Row(
                    children: [
                      const Icon(
                        Icons.category,
                        size: 20,
                        color: Color(0xFF6C757D),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Type: ${_getTaskTypeDisplay(task.taskType)}',
                        style: const TextStyle(
                          color: Color(0xFF6C757D),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  if (task.notes != null && task.notes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.note,
                          size: 20,
                          color: Color(0xFF6C757D),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notes: ${task.notes}',
                            style: const TextStyle(
                              color: Color(0xFF6C757D),
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
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color backgroundColor;
    Color textColor;
    String statusText;

    switch (task.status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        statusText = 'Pending';
        break;
      case 'assigned':
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        statusText = 'Assigned';
        break;
      case 'accepted':
        backgroundColor = Colors.cyan.withValues(alpha: 0.1);
        textColor = Colors.cyan;
        statusText = 'Accepted';
        break;
      case 'in_progress':
        backgroundColor = Colors.purple.withValues(alpha: 0.1);
        textColor = Colors.purple;
        statusText = 'In Progress';
        break;
      case 'delivered':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        statusText = 'Delivered';
        break;
      case 'completed':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        statusText = 'Completed';
        break;
      case 'failed':
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        statusText = 'Failed';
        break;
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        statusText = task.status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'delivered':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD4EDDA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC3E6CB)),
          ),
          child: const Text(
            '✓ Delivery Completed',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF155724),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      case 'completed':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFD4EDDA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFC3E6CB)),
          ),
          child: const Text(
            '✓ Task Completed',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF155724),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      case 'failed':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8D7DA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF5C6CB)),
          ),
          child: const Text(
            '✗ Delivery Failed',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF721C24),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE2E3E5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD6D8DB)),
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
