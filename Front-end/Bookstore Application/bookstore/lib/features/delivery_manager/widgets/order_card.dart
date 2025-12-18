import 'package:flutter/material.dart';
import '../../orders/models/order.dart';
import '../../../core/localization/app_localizations.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;

  const OrderCard({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Order Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _getOrderTypeColor(order.orderType),
                    radius: 20,
                    child: Icon(
                      _getOrderTypeIcon(order.orderType),
                      color: Colors.white,
                      size: 20,
                    ),
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
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              _getLocalizedOrderType(
                                order.orderType,
                                localizations,
                              ),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _getOrderTypeColor(order.orderType),
                                fontWeight: FontWeight.w500,
                              ),
                            );
                          },
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
                          localizations.getOrderStatusLabel(order.status),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Order Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        _buildDetailRow(
                          context: context,
                          icon: Icons.person_outline,
                          label: localizations.orderCustomerLabel,
                          value: order.customerName,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          context: context,
                          icon: Icons.location_on_outlined,
                          label: localizations.orderAddressLabel,
                          value:
                              order.shippingAddress?.fullAddress ??
                              localizations.notAvailable,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          context: context,
                          icon: Icons.shopping_bag_outlined,
                          label: localizations.orderItemsLabel,
                          value:
                              '${order.items.length} ${localizations.orderItemsLabel.toLowerCase()}',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          context: context,
                          icon: Icons.attach_money_outlined,
                          label: localizations.orderTotalLabel,
                          value: '\$${order.totalAmount.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          context: context,
                          icon: Icons.schedule_outlined,
                          label: localizations.orderCreatedLabel,
                          value: _formatDate(order.createdAt),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // Order Items Preview
              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      '${localizations.orderItemsLabel}:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                ...order.items
                    .take(3)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• ${item.book.title} (x${item.quantity})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                if (order.items.length > 3)
                  Text(
                    '... and ${order.items.length - 3} more',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
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
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  IconData _getOrderTypeIcon(String orderType) {
    switch (orderType.toLowerCase()) {
      case 'purchase':
        return Icons.shopping_cart_outlined;
      case 'borrowing':
        return Icons.library_books_outlined;
      case 'return_collection':
        return Icons.undo_outlined;
      default:
        return Icons.receipt_outlined;
    }
  }

  Color _getOrderTypeColor(String orderType) {
    switch (orderType.toLowerCase()) {
      case 'purchase':
        return Colors.blue;
      case 'borrowing':
        return Colors.green;
      case 'return_collection':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'pending_assignment':
        return Colors.amber;
      case 'confirmed':
        return Colors.blue;
      case 'in_delivery':
        return Colors.purple;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'returned':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getLocalizedOrderType(
    String orderType,
    AppLocalizations localizations,
  ) {
    switch (orderType.toLowerCase()) {
      case 'purchase':
        return localizations.purchaseOrder;
      case 'borrowing':
        return localizations.borrowingRequest;
      case 'return_collection':
        return localizations.returnRequest;
      default:
        return orderType;
    }
  }
}
