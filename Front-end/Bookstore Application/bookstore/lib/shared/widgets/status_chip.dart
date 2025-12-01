import 'package:flutter/material.dart';
import '../../constants/colors.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final Color? color;
  final bool isOutlined;
  final double? fontSize;
  final EdgeInsets? padding;

  const StatusChip({
    super.key,
    required this.status,
    this.color,
    this.isOutlined = false,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = color ?? _getStatusColor(status);
    final textColor = isOutlined ? statusColor : Colors.white;

    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : statusColor,
        border: Border.all(color: statusColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getStatusText(status),
        style: TextStyle(
          color: textColor,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.pending;
      case 'assigned':
        return AppColors.assigned;
      case 'in_progress':
      case 'in progress':
        return AppColors.inProgress;
      case 'delivered':
        return AppColors.delivered;
      case 'cancelled':
        return AppColors.cancelled;
      case 'confirmed':
        return AppColors.orderConfirmed;
      case 'shipped':
        return AppColors.orderShipped;
      case 'active':
        return AppColors.success;
      case 'inactive':
        return AppColors.grey500;
      case 'approved':
        return AppColors.borrowApproved;
      case 'requested':
        return AppColors.borrowRequested;
      case 'overdue':
        return AppColors.borrowOverdue;
      case 'returned':
        return AppColors.borrowReturned;
      default:
        return AppColors.grey500;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'in_progress':
        return 'In Progress';
      case 'in progress':
        return 'In Progress';
      default:
        return status.toUpperCase();
    }
  }
}
