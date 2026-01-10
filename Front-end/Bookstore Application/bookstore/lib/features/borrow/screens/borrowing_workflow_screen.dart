import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../models/borrow_request.dart';

class BorrowingWorkflowScreen extends StatefulWidget {
  final BorrowRequest borrowRequest;

  const BorrowingWorkflowScreen({super.key, required this.borrowRequest});

  @override
  State<BorrowingWorkflowScreen> createState() =>
      _BorrowingWorkflowScreenState();
}

class _BorrowingWorkflowScreenState extends State<BorrowingWorkflowScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Request #${widget.borrowRequest.id}',
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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: AppDimensions.spacingXL),
            _buildWorkflowTimeline(),
            const SizedBox(height: AppDimensions.spacingXL),
            _buildRequestDetailsCard(),
            const SizedBox(height: AppDimensions.spacingXL),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Request #${widget.borrowRequest.id}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                const Icon(Icons.book, color: Color(0xFF6C757D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.borrowRequest.bookTitle ?? 'Unknown Book',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF495057),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF6C757D)),
                const SizedBox(width: 8),
                Text(
                  widget.borrowRequest.customerName ?? 'Unknown Customer',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
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

  Widget _buildStatusChip() {
    Color backgroundColor;
    Color textColor;
    String statusText;

    switch (widget.borrowRequest.status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange.withValues(alpha: 0.1);
        textColor = Colors.orange;
        statusText = 'Under Review';
        break;
      case 'approved':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        statusText = 'Approved';
        break;
      case 'rejected':
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        statusText = 'Rejected';
        break;
      case 'active':
        backgroundColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        statusText = 'Active';
        break;
      case 'delivered':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        statusText = 'Delivered';
        break;
      case 'returned':
        backgroundColor = Colors.purple.withValues(alpha: 0.1);
        textColor = Colors.purple;
        statusText = 'Returned';
        break;
      case 'late':
        backgroundColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        statusText = 'Overdue';
        break;
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        statusText = widget.borrowRequest.status;
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

  Widget _buildWorkflowTimeline() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            _buildTimelineItem(
              'Request Submitted',
              widget.borrowRequest.requestDate,
              Icons.add_circle,
              Colors.blue,
              true,
            ),
            if (widget.borrowRequest.approvalDate != null)
              _buildTimelineItem(
                'Request Approved',
                widget.borrowRequest.approvalDate!,
                Icons.check_circle,
                Colors.green,
                true,
              ),
            if (widget.borrowRequest.deliveryDate != null)
              _buildTimelineItem(
                'Book Delivered',
                widget.borrowRequest.deliveryDate!,
                Icons.local_shipping,
                Colors.green,
                true,
              ),
            if (widget.borrowRequest.returnDate != null)
              _buildTimelineItem(
                'Book Returned',
                widget.borrowRequest.returnDate!,
                Icons.assignment_return,
                Colors.purple,
                true,
              ),
            // Show upcoming events
            if (widget.borrowRequest.status.toLowerCase() == 'pending')
              _buildTimelineItem(
                'Awaiting Admin Approval',
                null,
                Icons.hourglass_empty,
                Colors.orange,
                false,
              ),
            if (widget.borrowRequest.status.toLowerCase() == 'approved')
              _buildTimelineItem(
                'Awaiting Delivery',
                null,
                Icons.local_shipping,
                Colors.blue,
                false,
              ),
            if (widget.borrowRequest.status.toLowerCase() == 'active')
              _buildTimelineItem(
                'Due Date: ${_formatDate(widget.borrowRequest.dueDate ?? DateTime.now())}',
                null,
                Icons.schedule,
                Colors.orange,
                false,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    String title,
    DateTime? date,
    IconData icon,
    Color color,
    bool isCompleted,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? color : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isCompleted ? Colors.white : Colors.grey,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isCompleted ? Colors.black : Colors.grey,
                  ),
                ),
                if (date != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(date),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            _buildDetailRow(
              'Duration',
              '${widget.borrowRequest.durationDays} days',
              Icons.access_time,
            ),
            if (widget.borrowRequest.deliveryAddress != null)
              _buildDetailRow(
                'Delivery Address',
                widget.borrowRequest.deliveryAddress!,
                Icons.location_on,
              ),
            if (widget.borrowRequest.additionalNotes != null &&
                widget.borrowRequest.additionalNotes!.isNotEmpty)
              _buildDetailRow(
                'Notes',
                widget.borrowRequest.additionalNotes!,
                Icons.note,
              ),
            if (widget.borrowRequest.rejectionReason != null)
              _buildDetailRow(
                'Rejection Reason',
                widget.borrowRequest.rejectionReason!,
                Icons.cancel,
                textColor: Colors.red,
              ),
            if (widget.borrowRequest.fineAmount != null &&
                widget.borrowRequest.fineAmount! > 0)
              _buildDetailRow(
                'Fine Amount',
                '\$${widget.borrowRequest.fineAmount!.toStringAsFixed(2)}',
                Icons.monetization_on,
                textColor: Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
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

  Widget _buildActionButtons() {
    final status = widget.borrowRequest.status.toLowerCase();

    if (status == 'active') {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _requestEarlyReturn,
              icon: const Icon(Icons.assignment_return),
              label: const Text('Request Early Return'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _requestExtension,
              icon: const Icon(Icons.schedule),
              label: const Text('Request Extension'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (status == 'pending') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _cancelRequest,
          icon: const Icon(Icons.cancel),
          label: const Text('Cancel Request'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  void _requestEarlyReturn() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Early Return'),
        content: const Text(
          'Are you sure you want to request an early return for this book?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Early return request submitted'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _requestExtension() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Extension'),
        content: const Text(
          'Are you sure you want to request an extension for this book?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Extension request submitted'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _cancelRequest() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text(
          'Are you sure you want to cancel this borrowing request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request cancelled'),
                  backgroundColor: AppColors.warning,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
