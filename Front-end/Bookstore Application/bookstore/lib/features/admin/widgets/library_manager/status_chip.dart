import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';

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
    final localizations = AppLocalizations.of(context);

    // Handle empty or null status
    if (status.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey, width: 1),
        ),
        child: Text(
          localizations.unknown,
          style: const TextStyle(
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
        _formatStatus(status, localizations),
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
      // Complaint statuses
      'open': Colors.orange,
      'pending': Colors.orange,
      'in_progress': Colors.blue, // Represents "Replied" for complaints
      'replied': Colors.blue,
      'resolved': Colors.green,
      'closed': Colors.grey,
      // BorrowRequest statuses
      'approved': Colors.green,
      'rejected': Colors.red,
      'active': Colors.blue,
      'completed': Colors.green,
      'cancelled': Colors.grey,
      'overdue': Colors.red,
      'assigned_to_delivery': Colors.grey,
      'delivered': Colors.blue,
      'returned': Colors.green,
      // Order statuses
      'pending_review': Colors.orange,
      'rejected_by_admin': Colors.red,
      'waiting_for_delivery_manager': Colors.orange,
      'rejected_by_delivery_manager': Colors.red,
      'confirmed': Colors.blue,
      'shipped': Colors.blue,
      'in_delivery': Colors.blue,
      // ReturnRequest statuses
      'PENDING': Colors.orange,
      'APPROVED': Colors.green,
      'ASSIGNED': Colors.blue,
      'ACCEPTED': Colors.blue,
      'IN_PROGRESS': Colors.blue,
      'COMPLETED': Colors.green,
    };
  }

  String _formatStatus(String status, AppLocalizations localizations) {
    final lowerStatus = status.toLowerCase();

    // Format complaint statuses for better display
    switch (lowerStatus) {
      case 'open':
      case 'pending':
        return localizations.statusPending.toUpperCase();
      case 'in_progress':
      case 'replied':
        return localizations.replied.toUpperCase();
      case 'resolved':
        return localizations.resolved.toUpperCase();
      case 'closed':
        return localizations.closed.toUpperCase();
      // Borrow request statuses
      case 'approved':
        return localizations.statusApproved.toUpperCase();
      case 'rejected':
        return localizations.statusRejected.toUpperCase();
      case 'active':
        return localizations.statusActive.toUpperCase();
      case 'delivered':
        return localizations.statusDelivered.toUpperCase();
      case 'returned':
        return localizations.statusReturned.toUpperCase();
      case 'overdue':
        return localizations.statusOverdue.toUpperCase();
      case 'completed':
        return localizations.statusCompleted.toUpperCase();
      case 'cancelled':
        return localizations.statusCancelled.toUpperCase();
      case 'assigned_to_delivery':
        return localizations.assigned.toUpperCase();
      default:
        // Try to use getOrderStatusLabel first for order statuses
        // This handles order-specific statuses like 'rejected_by_admin', 'pending_review', etc.
        final orderStatusLabel = localizations.getOrderStatusLabel(status);
        // If getOrderStatusLabel returns a formatted version (not the original), use it
        if (orderStatusLabel.toLowerCase() != status.toLowerCase()) {
          return orderStatusLabel.toUpperCase();
        }
        // Try to use getBorrowStatusLabel as fallback for borrow request statuses
        try {
          final borrowStatusLabel = localizations.getBorrowStatusLabel(status);
          if (borrowStatusLabel.toLowerCase() != status.toLowerCase()) {
            return borrowStatusLabel.toUpperCase();
          }
        } catch (e) {
          // getBorrowStatusLabel might throw for non-borrow statuses, which is fine
        }
        // Final fallback: capitalize first letter of each word
        return status
            .split('_')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ')
            .toUpperCase();
    }
  }
}
