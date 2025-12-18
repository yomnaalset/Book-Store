import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import '../../orders/models/order.dart';
import '../../orders/screens/order_detail_screen.dart';
import '../screens/borrow_requests_screen.dart';

/// Card widget for displaying borrowing orders in different states
class BorrowOrderCard extends StatelessWidget {
  final Order order;
  final BorrowOrderCardType cardType;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onStartDelivery;
  final VoidCallback? onComplete;

  const BorrowOrderCard({
    super.key,
    required this.order,
    required this.cardType,
    this.onAccept,
    this.onReject,
    this.onStartDelivery,
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _getCardBorderColor(), width: 2),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to order details screen
          // For borrowing orders, we can pass the order directly to avoid fetch issues
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OrderDetailScreenWithOrder(order: order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getCardColor(),
                    radius: 24,
                    child: Icon(_getCardIcon(), color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.orderNumber}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context).borrowingRequest,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _getCardColor(),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(order.status),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations
                              .getBorrowStatusLabel(order.status)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Customer Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Column(
                          children: [
                            _buildDetailRow(
                              icon: Icons.person,
                              label: localizations.customer,
                              value: order.customerName,
                            ),
                            const Divider(height: 16),
                            _buildDetailRow(
                              icon: Icons.location_on,
                              label: localizations.addressLabel,
                              value:
                                  order.shippingAddress?.fullAddress ??
                                  localizations.noAddress,
                            ),
                            const Divider(height: 16),
                            _buildDetailRow(
                              icon: Icons.library_books,
                              label: localizations.bookTitle,
                              value:
                                  order.bookTitle ??
                                  (order.items.isNotEmpty
                                      ? order.items.first.book.title
                                      : localizations.noBookTitleAvailable),
                            ),
                            if (order.bookAuthor != null ||
                                (order.items.isNotEmpty &&
                                    order.items.first.book.author?.name !=
                                        null)) ...[
                              const Divider(height: 16),
                              _buildDetailRow(
                                icon: Icons.person_outline,
                                label: localizations.author,
                                value:
                                    order.bookAuthor ??
                                    (order.items.isNotEmpty
                                        ? order.items.first.book.author?.name ??
                                              localizations.unknownAuthor
                                        : localizations.unknownAuthor),
                              ),
                            ],
                            const Divider(height: 16),
                            _buildDetailRow(
                              icon: Icons.schedule,
                              label: localizations.created,
                              value: _formatDate(order.createdAt),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Book Items
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).booksToDeliver,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ...order.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.book, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.book.title,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getCardColor() {
    switch (cardType) {
      case BorrowOrderCardType.pending:
        return Colors.orange;
      case BorrowOrderCardType.inProgress:
        return Colors.blue;
      case BorrowOrderCardType.completed:
        return Colors.green;
    }
  }

  Color _getCardBorderColor() {
    return _getCardColor().withValues(alpha: 0.3);
  }

  IconData _getCardIcon() {
    switch (cardType) {
      case BorrowOrderCardType.pending:
        return Icons.pending_actions;
      case BorrowOrderCardType.inProgress:
        return Icons.local_shipping;
      case BorrowOrderCardType.completed:
        return Icons.done_all;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'pending_assignment':
        return Colors.orange;
      case 'confirmed':
      case 'assigned':
      case 'assigned_to_delivery':
        return Colors.blue;
      case 'pending_delivery':
      case 'preparing':
      case 'out_for_delivery':
      case 'in_delivery':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'returned':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
