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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.myOrders),
        actions: [
          IconButton(
            onPressed: _loadOrders,
            icon: const Icon(Icons.refresh),
            tooltip: localizations.refresh,
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
            padding: const EdgeInsets.all(AppDimensions.paddingM),
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
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/order-detail',
            arguments: {'orderId': order.id ?? order.orderNumber},
          );
        },
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
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
                                  order.status ?? 'pending',
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
                    child: _buildStatusChip(order.status ?? 'pending', context),
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
