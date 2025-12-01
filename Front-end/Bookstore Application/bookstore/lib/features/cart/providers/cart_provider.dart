import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/cart_item.dart';
import '../../books/models/book.dart';
import '../services/cart_service.dart';
import '../../auth/providers/auth_provider.dart';

// Helper function to safely parse double values from JSON
double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? 0.0;
  }
  return 0.0;
}

class CartProvider extends ChangeNotifier {
  final CartService _cartService;
  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  final double _taxRate = 0.08; // 8% tax rate
  final double _deliveryRate = 0.04; // 4% delivery cost rate
  String? _discountCode;
  double _discountAmount = 0.0;

  CartProvider(this._cartService) {
    _loadCartFromLocal();
  }

  // Getters
  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  String? get discountCode => _discountCode;
  double get discountAmount => _discountAmount;

  // Calculate totals
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get originalSubtotal =>
      _items.fold(0.0, (sum, item) => sum + item.originalTotalPrice);
  double get totalSavings => originalSubtotal - subtotal + _discountAmount;
  double get taxAmount => subtotal * _taxRate;
  // Delivery cost is 4% of final invoice value (subtotal + tax - discount)
  double get deliveryCost {
    final finalInvoiceValue = subtotal + taxAmount - _discountAmount;
    return finalInvoiceValue * _deliveryRate;
  }

  double get total => subtotal + taxAmount + deliveryCost - _discountAmount;

  // Check if a specific discount code is already applied
  bool isDiscountCodeApplied(String code) {
    return _discountCode == code;
  }

  // Check if any discount code is applied
  bool get hasDiscountCodeApplied =>
      _discountCode != null && _discountCode!.isNotEmpty;

  // Add item to cart
  Future<void> addToCart(
    Book book,
    int quantity, {
    BuildContext? context,
  }) async {
    debugPrint(
      'CartProvider: Adding ${book.title} to cart with quantity $quantity',
    );

    final existingIndex = _items.indexWhere((item) => item.book.id == book.id);

    if (existingIndex >= 0) {
      // Update existing item quantity
      final existingItem = _items[existingIndex];
      final newQuantity = existingItem.quantity + quantity;

      // Check stock availability
      if (book.stock != null && newQuantity > book.stock!) {
        _setError(
          'Cannot add more items. Only ${book.stock} items available in stock.',
        );
        return;
      }

      _items[existingIndex] = existingItem.copyWith(quantity: newQuantity);
      debugPrint(
        'CartProvider: Updated existing item quantity to $newQuantity',
      );
    } else {
      // Add new item
      if (book.stock != null && quantity > book.stock!) {
        _setError(
          'Cannot add items. Only ${book.stock} items available in stock.',
        );
        return;
      }

      final cartItem = CartItem(
        id: '${book.id}_${DateTime.now().millisecondsSinceEpoch}',
        book: book,
        quantity: quantity,
        price: book.priceAsDouble,
        discountPrice: book.discountPrice,
        addedAt: DateTime.now(),
      );
      _items.add(cartItem);
      debugPrint(
        'CartProvider: Added new item to cart. Total items: ${_items.length}',
      );
    }

    await _saveCartToLocal();
    debugPrint('CartProvider: Saved cart to local storage');
    notifyListeners();
    debugPrint('CartProvider: Notified listeners');

    // Sync with server if user is authenticated
    if (context != null && context.mounted) {
      await _syncWithServer(context);
    }
  }

  // Remove item from cart
  Future<void> removeFromCart(String itemId, {BuildContext? context}) async {
    _items.removeWhere((item) => item.id == itemId);
    await _saveCartToLocal();
    notifyListeners();

    // Sync with server if user is authenticated
    if (context != null && context.mounted) {
      await _syncWithServer(context);
    }
  }

  // Update item quantity
  Future<void> updateQuantity(
    String itemId,
    int quantity, {
    BuildContext? context,
  }) async {
    if (quantity <= 0) {
      await removeFromCart(itemId, context: context);
      return;
    }

    final index = _items.indexWhere((item) => item.id == itemId);
    if (index >= 0) {
      final item = _items[index];

      // Check stock availability
      if (item.book.stock != null && quantity > item.book.stock!) {
        _setError(
          'Cannot update quantity. Only ${item.book.stock} items available in stock.',
        );
        return;
      }

      _items[index] = item.copyWith(quantity: quantity);
      await _saveCartToLocal();
      notifyListeners();

      // Sync with server if user is authenticated
      if (context != null && context.mounted) {
        await _syncWithServer(context);
      }
    }
  }

  // Clear cart
  Future<void> clearCart({BuildContext? context}) async {
    _items.clear();
    _discountCode = null;
    _discountAmount = 0.0;
    await _saveCartToLocal();
    notifyListeners();

    // Sync with server if user is authenticated
    if (context != null && context.mounted) {
      await _syncWithServer(context);
    }
  }

  // Apply discount code
  Future<bool> applyDiscountCode(String code, String? token) async {
    _setLoading(true);
    _clearError();

    try {
      // Check if a discount code is already applied
      if (_discountCode != null && _discountCode!.isNotEmpty) {
        if (_discountCode == code) {
          _setError('This discount code is already applied to your cart.');
          _setLoading(false);
          return false;
        } else {
          _setError(
            'Please remove the current discount code before applying a new one.',
          );
          _setLoading(false);
          return false;
        }
      }

      final discount = await _cartService.applyDiscountCode(
        code,
        subtotal,
        token,
      );
      if (discount > 0) {
        _discountCode = code;
        _discountAmount = discount;
        await _saveCartToLocal();
        notifyListeners();
        _setLoading(false);
        return true;
      } else {
        _setError(_cartService.errorMessage ?? 'Invalid discount code');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Failed to apply discount code: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Remove discount code
  Future<void> removeDiscountCode({BuildContext? context}) async {
    _setLoading(true);
    _clearError();

    try {
      if (context != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        if (authProvider.token != null) {
          // Call backend API to remove discount
          final success = await _cartService.removeDiscountCode(
            token: authProvider.token!,
          );

          if (success) {
            _discountCode = null;
            _discountAmount = 0.0;
            await _saveCartToLocal();
            debugPrint('CartProvider: Discount code removed successfully');
          } else {
            _setError('Failed to remove discount code');
          }
        } else {
          // If no token, just clear locally
          _discountCode = null;
          _discountAmount = 0.0;
          await _saveCartToLocal();
        }
      } else {
        // If no context, just clear locally
        _discountCode = null;
        _discountAmount = 0.0;
        await _saveCartToLocal();
      }
    } catch (e) {
      _setError('Error removing discount code: $e');
      debugPrint('CartProvider: Error removing discount code: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Load cart from server
  Future<void> loadCartFromServer(String token) async {
    _setLoading(true);
    _clearError();

    try {
      final serverItems = await _cartService.getCart(token);
      if (serverItems.isNotEmpty) {
        _items = serverItems;
        await _saveCartToLocal();
      }
      // If server returns empty cart, keep local cart items
      notifyListeners();
      _setLoading(false);
    } catch (e) {
      debugPrint('CartProvider: Failed to load cart from server: $e');
      // Don't clear local cart on server error
      _setLoading(false);
      // Don't set error message for server load failures
    }
  }

  // Sync cart with server
  Future<void> _syncWithServer(BuildContext? context) async {
    try {
      if (context != null) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final token = authProvider.token;

        if (token != null && token.isNotEmpty) {
          debugPrint('CartProvider: Syncing cart with server');

          // For each item in the cart, add it to the server
          for (final item in _items) {
            final success = await _cartService.addToCart(
              token: token,
              bookId: item.book.id,
              quantity: item.quantity,
            );

            if (!success) {
              debugPrint(
                'CartProvider: Failed to sync item ${item.book.title} to server',
              );
              // Don't break the loop, continue with other items
            }
          }

          debugPrint('CartProvider: Cart sync completed');
        } else {
          debugPrint('CartProvider: No auth token available for server sync');
        }
      }
    } catch (e) {
      debugPrint('CartProvider: Error syncing cart with server: $e');
      // Don't throw error, just log it
    }
  }

  // Save cart to local storage
  Future<void> _saveCartToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartData = {
        'items': _items.map((item) => item.toJson()).toList(),
        'discount_code': _discountCode,
        'discount_amount': _discountAmount,
      };
      await prefs.setString('cart_data', json.encode(cartData));
      debugPrint(
        'CartProvider: Successfully saved ${_items.length} items to local storage',
      );
    } catch (e) {
      debugPrint('Failed to save cart to local storage: $e');
    }
  }

  // Load cart from local storage
  Future<void> _loadCartFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartDataString = prefs.getString('cart_data');

      if (cartDataString != null) {
        final cartData = json.decode(cartDataString);
        final List<dynamic> itemsJson = cartData['items'] ?? [];
        _items = itemsJson.map((json) => CartItem.fromJson(json)).toList();
        _discountCode = cartData['discount_code'];
        _discountAmount = _parseDouble(cartData['discount_amount'] ?? 0.0);
        debugPrint(
          'CartProvider: Loaded ${_items.length} items from local storage',
        );
        notifyListeners();
      } else {
        debugPrint('CartProvider: No cart data found in local storage');
      }
    } catch (e) {
      debugPrint('Failed to load cart from local storage: $e');
    }
  }

  // Get item by book ID
  CartItem? getItemByBookId(String bookId) {
    try {
      return _items.firstWhere((item) => item.book.id == bookId);
    } catch (e) {
      return null;
    }
  }

  // Check if book is in cart
  bool isInCart(String bookId) {
    return _items.any((item) => item.book.id == bookId);
  }

  // Get quantity of specific book in cart
  int getBookQuantity(String bookId) {
    final item = getItemByBookId(bookId);
    return item?.quantity ?? 0;
  }

  // Validate cart before checkout
  List<String> validateCart() {
    final errors = <String>[];

    if (_items.isEmpty) {
      errors.add('Cart is empty');
      return errors;
    }

    for (final item in _items) {
      if (item.book.stock != null && item.quantity > item.book.stock!) {
        errors.add(
          '${item.book.title} has only ${item.book.stock} items in stock',
        );
      }

      if (item.book.stock == null || item.book.stock! <= 0) {
        errors.add('${item.book.title} is out of stock');
      }
    }

    return errors;
  }

  // Prepare checkout data
  Map<String, dynamic> getCheckoutData() {
    return {
      'cart_items': _items
          .map(
            (item) => {
              'book_id': item.book.id,
              'quantity': item.quantity,
              'price': item.price,
            },
          )
          .toList(),
      'total_price': total,
      'address': '', // This will be set from the checkout form
      'payment_method': 'cash', // Default payment method
    };
  }

  // Process checkout with custom data
  Future<Map<String, dynamic>?> processCheckoutWithData(
    BuildContext context,
    Map<String, dynamic> checkoutData,
  ) async {
    _setLoading(true);
    _clearError();

    try {
      final token = await _getAuthToken(context);
      final result = await _cartService.processCheckout(
        token: token,
        checkoutData: checkoutData,
      );

      if (result != null) {
        // Clear cart after successful checkout
        clearCart();
        _setLoading(false);
        return result;
      } else {
        _setError(_cartService.errorMessage ?? 'Checkout failed');
        _setLoading(false);
        return null;
      }
    } catch (e) {
      _setError('Checkout error: ${e.toString()}');
      _setLoading(false);
      return null;
    }
  }

  // Process checkout
  Future<Map<String, dynamic>?> processCheckout(BuildContext context) async {
    _setLoading(true);
    _clearError();

    try {
      final checkoutData = getCheckoutData();
      final token = await _getAuthToken(context);
      final result = await _cartService.processCheckout(
        token: token,
        checkoutData: checkoutData,
      );

      if (result != null) {
        // Clear cart after successful checkout
        clearCart();
        _setLoading(false);
        return result;
      } else {
        _setError(_cartService.errorMessage ?? 'Checkout failed');
        _setLoading(false);
        return null;
      }
    } catch (e) {
      _setError('Checkout error: ${e.toString()}');
      _setLoading(false);
      return null;
    }
  }

  // Get auth token from AuthProvider
  Future<String> _getAuthToken(BuildContext context) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      return authProvider.token ?? '';
    } catch (e) {
      debugPrint('CartProvider: Error getting auth token: $e');
      return '';
    }
  }

  // Private helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Clear all data
  void clear() {
    _items.clear();
    _isLoading = false;
    _errorMessage = null;
    _discountCode = null;
    _discountAmount = 0.0;
    notifyListeners();
  }

  // Clear all local storage data
  Future<void> clearLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cart_data');
      await prefs.remove('cart_discount');
      clear();
    } catch (e) {
      debugPrint('Failed to clear local cart data: $e');
    }
  }
}
