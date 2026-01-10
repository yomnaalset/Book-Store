import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/localization/app_localizations.dart';
import '../providers/orders_provider.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    final ordersProvider = Provider.of<OrdersProvider>(context, listen: false);
    // Only load purchase orders, not borrow orders
    // Borrow orders should be viewed in the Borrow Status screen
    await ordersProvider.loadOrdersByType('purchase');
  }

  /// Get the effective status for display, checking delivery assignment if available
  String _getEffectiveStatus(dynamic order) {
    // If delivery assignment status is 'in_delivery', show that instead of order status
    if (order.deliveryAssignment != null &&
        order.deliveryAssignment!.status.toLowerCase() == 'in_delivery') {
      return 'in_delivery';
    }
    return order.status ?? 'pending';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.myOrders,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: localizations.refresh,
              onPressed: _loadOrders,
            ),
          ),
        ],
      ),
      body: Consumer<OrdersProvider>(
        builder: (context, ordersProvider, child) {
          if (ordersProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (ordersProvider.hasError) {
            return _buildErrorState(ordersProvider.errorMessage!);
          }

          // Filter to only show purchase orders (exclude borrow orders)
          final purchaseOrders = ordersProvider.orders
              .where((order) => order.isPurchaseOrder)
              .toList();

          if (purchaseOrders.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: EdgeInsets.only(
              left: AppDimensions.paddingM,
              right: AppDimensions.paddingM,
              top: AppDimensions.paddingM,
              bottom:
                  AppDimensions.paddingM +
                  MediaQuery.of(context).padding.bottom,
            ),
            itemCount: purchaseOrders.length,
            itemBuilder: (context, index) {
              final order = purchaseOrders[index];
              return _buildOrderCard(order);
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              '/order-detail',
              arguments: {'orderId': order.id ?? order.orderNumber},
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          final effectiveStatus = _getEffectiveStatus(order);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizations.orderNumberPrefix(
                                  '${order.orderNumber ?? order.id}',
                                ),
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeM,
                                  fontWeight: FontWeight.w600,
                                  color: context.textColor,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingS),
                              Text(
                                localizations.totalPrefix(
                                  '\$${order.totalAmount?.toStringAsFixed(2) ?? '0.00'}',
                                ),
                                style: const TextStyle(
                                  fontSize: AppDimensions.fontSizeM,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingS),
                              Text(
                                localizations.statusPrefix(
                                  localizations.getOrderStatusLabel(
                                    effectiveStatus,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeS,
                                  color: context.secondaryTextColor,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                    Flexible(
                      child: _buildStatusChip(
                        _getEffectiveStatus(order),
                        context,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: context.secondaryTextColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = AppColors.warning.withValues(alpha: 0.2);
        textColor = AppColors.warning;
        break;
      case 'processing':
        backgroundColor = AppColors.primary.withValues(alpha: 0.2);
        textColor = AppColors.primary;
        break;
      case 'delivered':
        backgroundColor = AppColors.success.withValues(alpha: 0.2);
        textColor = AppColors.success;
        break;
      case 'cancelled':
        backgroundColor = AppColors.error.withValues(alpha: 0.2);
        textColor = AppColors.error;
        break;
      default:
        backgroundColor = AppColors.textSecondary.withValues(alpha: 0.2);
        textColor = AppColors.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingM,
        vertical: AppDimensions.spacingS,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
      ),
      child: Text(
        localizations.getOrderStatusLabel(status).toUpperCase(),
        style: TextStyle(
          fontSize: AppDimensions.fontSizeXS,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildEmptyState() {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: context.secondaryTextColor.withValues(alpha: 128),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              localizations.noOrdersFoundOrders,
              style: TextStyle(
                fontSize: AppDimensions.fontSizeL,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              localizations.ordersWillAppearHere,
              style: TextStyle(
                fontSize: AppDimensions.fontSizeM,
                color: context.secondaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXL),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: Text(localizations.browseBooks),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: AppColors.error),
            const SizedBox(height: AppDimensions.spacingL),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  children: [
                    Text(
                      localizations.failedToLoadOrders,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeL,
                        fontWeight: FontWeight.w600,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    Text(
                      error,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeM,
                        color: context.secondaryTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppDimensions.spacingXL),
                    ElevatedButton(
                      onPressed: _loadOrders,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(localizations.tryAgain),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
