import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/services/api_config.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _discountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Defer loading to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCartFromServer();
    });
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _loadCartFromServer() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    if (authProvider.token != null) {
      debugPrint('CartScreen: Loading cart from server...');
      try {
        await cartProvider.loadCartFromServer(authProvider.token!);
      } catch (e) {
        debugPrint(
          'CartScreen: Failed to load from server, using local cart: $e',
        );
        // Don't clear local cart if server load fails
      }
    } else {
      debugPrint('CartScreen: No auth token available, using local cart only');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (cartProvider.items.isNotEmpty) {
                return TextButton(
                  onPressed: () => _showClearCartDialog(),
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (cartProvider.isEmpty) {
            return _buildEmptyCart();
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  itemCount: cartProvider.items.length,
                  itemBuilder: (context, index) {
                    final item = cartProvider.items[index];
                    return _buildCartItem(item, cartProvider);
                  },
                ),
              ),
              _buildCartSummary(cartProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 100,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 128),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeXL,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'Add some books to your cart to get started',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeM,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXL),
            CustomButton(
              text: 'Continue Shopping',
              onPressed: () => Navigator.pop(context),
              type: ButtonType.primary,
              size: ButtonSize.large,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItem(CartItem item, CartProvider cartProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Book Image
              Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  child: item.book.primaryImageUrl != null
                      ? Image.network(
                          item.book.primaryImageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Theme.of(context).colorScheme.surface,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              _buildDefaultBookCover(),
                        )
                      : _buildDefaultBookCover(),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingM),

              // Book Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.book.title,
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeM,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    Text(
                      'by ${item.book.author?.name ?? 'Unknown Author'}',
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingS),

                    // Price
                    Row(
                      children: [
                        if (item.hasDiscount) ...[
                          Text(
                            '\$${item.price.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeS,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingS),
                        ],
                        Text(
                          '\$${(item.discountPrice ?? item.price).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: AppDimensions.fontSizeM,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingM),

                    // Quantity Controls and Remove Button
                    Row(
                      children: [
                        _buildQuantityControls(item, cartProvider),
                        const Spacer(),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${item.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeM,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingS),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radiusS,
                                ),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: IconButton(
                                onPressed: () =>
                                    _removeItem(item, cartProvider),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                tooltip: 'Remove item from cart',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBookCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.uranianBlue.withValues(alpha: 0.1),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.book_outlined, size: 40, color: AppColors.primary),
      ),
    );
  }

  Widget _buildQuantityControls(CartItem item, CartProvider cartProvider) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: item.quantity > 1
                ? () => cartProvider.updateQuantity(item.id, item.quantity - 1)
                : null,
            icon: const Icon(Icons.remove, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 40),
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: AppDimensions.fontSizeM,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed:
                (item.book.stock == null || item.quantity < item.book.stock!)
                ? () => cartProvider.updateQuantity(item.id, item.quantity + 1)
                : null,
            icon: const Icon(Icons.add, size: 18),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary(CartProvider cartProvider) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black26
                : Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Discount Code Section
            _buildDiscountSection(cartProvider),

            const Divider(height: AppDimensions.spacingL),

            // Price Breakdown
            _buildPriceBreakdown(cartProvider),

            const SizedBox(height: AppDimensions.spacingL),

            // Checkout Button
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return CustomButton(
                  text: 'Proceed to Checkout',
                  onPressed: authProvider.isAuthenticated
                      ? () => _proceedToCheckout(cartProvider)
                      : () => _showLoginRequired(),
                  type: ButtonType.primary,
                  size: ButtonSize.large,
                  isFullWidth: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountSection(CartProvider cartProvider) {
    if (cartProvider.discountCode != null) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textHint.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingS),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  ),
                  child: const Icon(
                    Icons.local_offer,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discount Applied',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeS,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXS),
                      Text(
                        cartProvider.discountCode!,
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _editDiscountCode(cartProvider),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      tooltip: 'Edit discount code',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusS,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                    IconButton(
                      onPressed: () =>
                          cartProvider.removeDiscountCode(context: context),
                      icon: const Icon(
                        Icons.close,
                        color: AppColors.error,
                        size: 20,
                      ),
                      tooltip: 'Remove discount code',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.error.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusS,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.savings_outlined,
                    color: AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Text(
                    'You saved \$${cartProvider.discountAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeM,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _discountController,
            decoration: const InputDecoration(
              hintText: 'Enter discount code',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingM),
        CustomButton(
          text: 'Apply',
          onPressed: () => _applyDiscountCode(cartProvider),
          type: ButtonType.secondary,
        ),
      ],
    );
  }

  Widget _buildPriceBreakdown(CartProvider cartProvider) {
    return Column(
      children: [
        _buildPriceRow(
          'Subtotal',
          '\$${cartProvider.subtotal.toStringAsFixed(2)}',
        ),
        if (cartProvider.totalSavings > 0)
          _buildPriceRow(
            'Savings',
            '-\$${cartProvider.totalSavings.toStringAsFixed(2)}',
            color: AppColors.success,
          ),
        if (cartProvider.taxAmount > 0)
          _buildPriceRow(
            'Tax',
            '\$${cartProvider.taxAmount.toStringAsFixed(2)}',
          ),
        if (cartProvider.deliveryCost > 0)
          _buildPriceRow(
            'Delivery',
            '\$${cartProvider.deliveryCost.toStringAsFixed(2)}',
          ),
        const Divider(),
        _buildPriceRow(
          'Total',
          '\$${cartProvider.total.toStringAsFixed(2)}',
          isTotal: true,
        ),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    String amount, {
    Color? color,
    bool isTotal = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal
                  ? AppDimensions.fontSizeL
                  : AppDimensions.fontSizeM,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal
                  ? AppDimensions.fontSizeL
                  : AppDimensions.fontSizeM,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: color ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  void _removeItem(CartItem item, CartProvider cartProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove "${item.book.title}" from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              cartProvider.removeFromCart(item.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.book.title} removed from cart'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text(
          'Are you sure you want to remove all items from your cart?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<CartProvider>(context, listen: false).clearCart();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Cart cleared'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editDiscountCode(CartProvider cartProvider) async {
    final TextEditingController editController = TextEditingController(
      text: cartProvider.discountCode ?? '',
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Discount Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a new discount code:'),
            const SizedBox(height: AppDimensions.spacingM),
            TextField(
              controller: editController,
              decoration: const InputDecoration(
                hintText: 'Enter discount code',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM,
                  vertical: AppDimensions.paddingS,
                ),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newCode = editController.text.trim();
              if (newCode.isNotEmpty) {
                Navigator.pop(context, newCode);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      // Remove current discount first
      if (mounted) {
        cartProvider.removeDiscountCode(context: context);
      }

      // Apply new discount code
      if (!mounted) return;
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      final success = await cartProvider.applyDiscountCode(result, token);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Discount code updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                cartProvider.errorMessage ??
                    'Failed to apply new discount code',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _applyDiscountCode(CartProvider cartProvider) async {
    if (!mounted) return;
    
    final discountCode = _discountController.text.trim();
    if (discountCode.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a discount code'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    debugPrint('🔍 CartScreen: Testing API connectivity...');
    debugPrint('🔍 CartScreen: Base URL: ${ApiConfig.getBaseUrl()}');
    debugPrint('🔍 CartScreen: Discount code: $discountCode');
    debugPrint('🔍 CartScreen: Subtotal: ${cartProvider.subtotal}');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    debugPrint('🔍 CartScreen: Token available: ${authProvider.token != null}');

    final success = await cartProvider.applyDiscountCode(
      discountCode,
      authProvider.token,
    );

    if (!mounted) return;
    
    if (success) {
      _discountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discount code applied successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cartProvider.errorMessage ?? 'Failed to apply discount code',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _proceedToCheckout(CartProvider cartProvider) {
    final errors = cartProvider.validateCart();
    if (errors.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cart Issues'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: errors
                .map(
                  (error) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $error'),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.pushNamed(context, '/checkout');
  }

  void _showLoginRequired() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Please login to proceed with checkout'),
        backgroundColor: AppColors.warning,
        action: SnackBarAction(
          label: 'Login',
          textColor: Colors.white,
          onPressed: () {
            Navigator.pushNamed(context, '/login');
          },
        ),
      ),
    );
    Navigator.pushNamed(context, '/login');
  }
}
