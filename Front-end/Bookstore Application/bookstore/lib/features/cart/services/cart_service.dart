import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../../../features/cart/models/cart_item.dart';
import '../../../../features/books/models/book.dart' as book;

class CartService {
  final String baseUrl;
  String? _errorMessage;

  CartService({required this.baseUrl});

  String? get errorMessage => _errorMessage;

  // Get cart items from server
  Future<List<CartItem>> getCart(String token) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cart/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> itemsJson = data['data']['items'] ?? [];
        return itemsJson.map((json) => CartItem.fromJson(json)).toList();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load cart');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error getting cart: $e');
      return [];
    }
  }

  // Add item to cart on server
  Future<bool> addToCart({
    required String token,
    required String bookId,
    required int quantity,
  }) async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cart/add/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'book_id': bookId, 'quantity': quantity}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('CartService: Item added to cart successfully');
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to add item to cart');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error adding to cart: $e');
      return false;
    }
  }

  // Update cart item quantity
  Future<bool> updateCartItem({
    required String token,
    required String itemId,
    required int quantity,
  }) async {
    _clearError();

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/cart/items/$itemId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'quantity': quantity}),
      );

      if (response.statusCode == 200) {
        debugPrint('CartService: Cart item updated successfully');
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to update cart item');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error updating cart item: $e');
      return false;
    }
  }

  // Remove item from cart
  Future<bool> removeFromCart({
    required String token,
    required String itemId,
  }) async {
    _clearError();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/cart/items/$itemId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('CartService: Item removed from cart successfully');
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to remove item from cart');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error removing from cart: $e');
      return false;
    }
  }

  // Clear entire cart
  Future<bool> clearCart(String token) async {
    _clearError();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/cart/clear/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        debugPrint('CartService: Cart cleared successfully');
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to clear cart');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error clearing cart: $e');
      return false;
    }
  }

  // Apply discount code
  Future<double> applyDiscountCode(
    String discountCode,
    double subtotal,
    String? token,
  ) async {
    _clearError();

    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final url = '$baseUrl/discounts/apply/';
      final body = json.encode({
        'code': discountCode,
        'order_amount': subtotal,
      });

      debugPrint('🔍 CartService: Applying discount code');
      debugPrint('🔍 CartService: URL: $url');
      debugPrint('🔍 CartService: Headers: $headers');
      debugPrint('🔍 CartService: Body: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      debugPrint('🔍 CartService: Response status: ${response.statusCode}');
      debugPrint('🔍 CartService: Response body: ${response.body}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final discount = (data['discount_amount'] ?? 0.0).toDouble();
        debugPrint(
          'CartService: Discount code applied successfully, discount: $discount',
        );
        return discount;
      } else {
        final data = json.decode(response.body);
        final errorMessage = data['message'];
        // Error translation is handled in the UI layer
        _setError(errorMessage ?? 'Invalid discount code');
        return 0.0;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error applying discount code: $e');
      return 0.0;
    }
  }

  // Remove applied discount code
  Future<bool> removeDiscountCode({required String token}) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};

      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final url = '$baseUrl/discounts/remove/';

      debugPrint('🔍 CartService: Removing discount code');
      debugPrint('🔍 CartService: URL: $url');
      debugPrint('🔍 CartService: Headers: $headers');

      final response = await http.post(Uri.parse(url), headers: headers);

      debugPrint(
        '🔍 CartService: Remove response status: ${response.statusCode}',
      );
      debugPrint('🔍 CartService: Remove response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint(
          'CartService: Discount code removed successfully: ${data['message']}',
        );
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to remove discount code');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error removing discount code: $e');
      return false;
    }
  }

  // Calculate delivery cost
  Future<double> calculateDelivery({
    required String token,
    required Map<String, dynamic> deliveryAddress,
    required List<CartItem> items,
    required List<book.Book> books,
  }) async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delivery/calculate/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'delivery_address': deliveryAddress,
          'items': items
              .map(
                (item) => {
                  'book_id': item.book.id,
                  'quantity': item.quantity,
                  'weight': item.book.weight ?? 0.5, // Default weight
                },
              )
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final deliveryCost = (data['delivery_cost'] ?? 0.0).toDouble();
        debugPrint(
          'CartService: Delivery calculated successfully: $deliveryCost',
        );
        return deliveryCost;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to calculate delivery');
        return 0.0;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error calculating delivery: $e');
      return 0.0;
    }
  }

  // Sync local cart with server
  Future<bool> syncCart({
    required String token,
    required List<CartItem> localItems,
  }) async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cart/sync/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'items': localItems
              .map(
                (item) => {'book_id': item.book.id, 'quantity': item.quantity},
              )
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('CartService: Cart synced successfully');
        return true;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to sync cart');
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error syncing cart: $e');
      return false;
    }
  }

  // Get available payment methods
  Future<List<Map<String, dynamic>>> getPaymentMethods(String token) async {
    _clearError();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/payment/methods/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> methods = data['payment_methods'] ?? [];
        return methods.cast<Map<String, dynamic>>();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load payment methods');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error getting payment methods: $e');
      return [];
    }
  }

  // Process checkout
  Future<Map<String, dynamic>?> processCheckout({
    required String token,
    required Map<String, dynamic> checkoutData,
  }) async {
    _clearError();

    try {
      debugPrint('CartService: Processing checkout with data: $checkoutData');

      final response = await http.post(
        Uri.parse('$baseUrl/delivery/orders/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(checkoutData),
      );

      debugPrint(
        'CartService: Checkout response status: ${response.statusCode}',
      );
      debugPrint('CartService: Checkout response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        debugPrint('CartService: Checkout processed successfully');
        debugPrint('CartService: Order created with ID: ${data['id']}');
        return data;
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to process checkout');
        debugPrint('CartService: Checkout failed: ${data['message']}');
        return null;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error processing checkout: $e');
      return null;
    }
  }

  // Get delivery options
  Future<List<Map<String, dynamic>>> getDeliveryOptions({
    required String token,
    required Map<String, dynamic> address,
  }) async {
    _clearError();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/delivery/options/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'address': address}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> options = data['delivery_options'] ?? [];
        return options.cast<Map<String, dynamic>>();
      } else {
        final data = json.decode(response.body);
        _setError(data['message'] ?? 'Failed to load delivery options');
        return [];
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      debugPrint('CartService: Error getting delivery options: $e');
      return [];
    }
  }

  // Private helper methods
  void _setError(String error) {
    _errorMessage = error;
  }

  void _clearError() {
    _errorMessage = null;
  }
}
