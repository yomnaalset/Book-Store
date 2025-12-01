import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final Color? backgroundColor;
  final Color? textColor;

  const StatusChip({
    super.key,
    required this.status,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    // Handle empty or null status
    if (status.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey, width: 1),
        ),
        child: const Text(
          'Unknown',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final statusColors = _getStatusColors();
    final color = statusColors[status.toLowerCase()] ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: textColor ?? color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Map<String, Color> _getStatusColors() {
    return {
      // BorrowRequest statuses
      'pending': Colors.orange,
      'approved': Colors.green,
      'rejected': Colors.red,
      'active': Colors.blue,
      'completed': Colors.green,
      'cancelled': Colors.grey,
      'overdue': Colors.red,
      'assigned_to_delivery': Colors.grey,
      'delivered': Colors.blue,
      'returned': Colors.green,
      // ReturnRequest statuses
      'PENDING': Colors.orange,
      'APPROVED': Colors.green,
      'ASSIGNED': Colors.blue,
      'ACCEPTED': Colors.blue,
      'IN_PROGRESS': Colors.blue,
      'COMPLETED': Colors.green,
    };
  }
}
