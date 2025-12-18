import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/services/api_service.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/error_message.dart';
import '../providers/cart_provider.dart';
import '../../orders/screens/order_tracking_screen.dart';
import '../../auth/providers/auth_provider.dart';

class CartCheckoutScreen extends StatefulWidget {
  const CartCheckoutScreen({super.key});

  @override
  State<CartCheckoutScreen> createState() => _CartCheckoutScreenState();
}

class _CartCheckoutScreenState extends State<CartCheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedPaymentMethod = 'cash';
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, String>> _savedAddresses = [];
  Map<String, String>? _selectedAddress;

  // Card details controllers for credit card payment
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedAddresses() async {
    try {
      // Load saved addresses from user profile
      setState(() {
        _savedAddresses = [
          {
            'id': '1',
            'title': 'Home',
            'address': '123 Main Street, Apt 4B',
            'city': 'New York',
            'state': 'NY',
            'postalCode': '10001',
            'phone': '+1234567890',
            'isDefault': 'true',
          },
          {
            'id': '2',
            'title': 'Work',
            'address': '456 Business Ave, Floor 10',
            'city': 'New York',
            'state': 'NY',
            'postalCode': '10002',
            'phone': '+1234567891',
            'isDefault': 'false',
          },
        ];
        if (_savedAddresses.isNotEmpty) {
          _selectedAddress = _savedAddresses.firstWhere(
            (addr) => addr['isDefault'] == 'true',
            orElse: () => _savedAddresses.first,
          );
          _addressController.text =
              '${_selectedAddress!['address']}, ${_selectedAddress!['city']}, ${_selectedAddress!['state']} ${_selectedAddress!['postalCode']}';
          _phoneController.text = _selectedAddress!['phone']!;
        }
      });
    } catch (e) {
      debugPrint('Error loading saved addresses: $e');
    }
  }

  Future<void> _completePurchase() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate card details if mastercard is selected
    if (_selectedPaymentMethod == 'mastercard' && !_validateCardDetails()) {
      return;
    }

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.items.isEmpty) {
      setState(() {
        _errorMessage = 'Your cart is empty';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the auth token from AuthProvider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        setState(() {
          _errorMessage = 'Please log in to complete your order';
        });
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/delivery/orders/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'cart_items': cartProvider.items.map((item) => item.id).toList(),
          'total_price': cartProvider.items.fold(
            0.0,
            (sum, item) => sum + item.totalPrice,
          ),
          'address': _addressController.text,
          'payment_method': _selectedPaymentMethod,
          'delivery_notes': _notesController.text,
          'card_details': _selectedPaymentMethod == 'mastercard'
              ? {
                  'card_number': _cardNumberController.text.trim(),
                  'cardholder_name': _cardHolderController.text.trim(),
                  'expiry_date': _expiryController.text.trim(),
                  'cvv': _cvvController.text.trim(),
                }
              : null,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // Clear cart after successful order
          cartProvider.clearCart();

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Order delivered successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            // Navigate to order tracking screen
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => OrderTrackingScreen(
                  orderId: data['order']['id'],
                  orderNumber: data['order']['order_number'],
                ),
              ),
            );
          }
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to deliver order';
          });
        }
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _errorMessage = errorData['error'] ?? 'Failed to deliver order';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()} while delivering order';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your cart is empty',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add some books to your cart first',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Order Summary
                  _buildOrderSummary(cartProvider),

                  const SizedBox(height: 24),

                  // Delivery Address Section
                  _buildAddressSection(),

                  const SizedBox(height: 24),

                  // Payment Method Section
                  _buildPaymentMethodSection(),

                  const SizedBox(height: 24),

                  // Additional Notes
                  _buildNotesSection(),

                  const SizedBox(height: 24),

                  // Error Message
                  if (_errorMessage != null) ...[
                    ErrorMessage(message: _errorMessage!),
                    const SizedBox(height: 16),
                  ],

                  // Complete Purchase Button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Complete Purchase',
                      onPressed: _isLoading ? null : _completePurchase,
                      isLoading: _isLoading,
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderSummary(CartProvider cartProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Summary',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Order Items
            ...cartProvider.items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        item.book.coverImageUrl ?? '',
                        width: 50,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 50,
                          height: 70,
                          color: Colors.grey[300],
                          child: const Icon(Icons.book),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.book.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'by ${item.book.author}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Qty: ${item.quantity}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                '\$${item.totalPrice.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
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

            const Divider(),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '\$${cartProvider.items.fold(0.0, (sum, item) => sum + item.totalPrice).toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Address',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Saved Addresses Dropdown
            if (_savedAddresses.isNotEmpty) ...[
              DropdownButtonFormField<Map<String, String>>(
                initialValue: _selectedAddress,
                decoration: const InputDecoration(
                  labelText: 'Select Address',
                  border: OutlineInputBorder(),
                ),
                items: _savedAddresses.map((address) {
                  return DropdownMenuItem<Map<String, String>>(
                    value: address,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          address['title']!,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${address['address']}, ${address['city']}, ${address['state']} ${address['postalCode']}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (address) {
                  setState(() {
                    _selectedAddress = address;
                    _addressController.text =
                        '${address!['address']}, ${address['city']}, ${address['state']} ${address['postalCode']}';
                    _phoneController.text = address['phone']!;
                  });
                },
              ),
              const SizedBox(height: 16),
            ],

            // Address Field
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Delivery Address',
                hintText: 'Enter your delivery address',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a delivery address';
                }
                return null;
              },
              maxLines: 3,
            ),

            const SizedBox(height: 16),

            // Phone Field
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'Enter your phone number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Method',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Payment Method Options
            RadioGroup<String>(
              groupValue: _selectedPaymentMethod,
              onChanged: (value) {
                setState(() {
                  _selectedPaymentMethod = value!;
                });
              },
              child: Column(
                children: [
                  RadioListTile<String>(
                    title: const Text('Cash on Delivery'),
                    subtitle: const Text('Pay when your order arrives'),
                    value: 'cash',
                    activeColor: Theme.of(context).primaryColor,
                  ),
                  RadioListTile<String>(
                    title: const Text('Mastercard'),
                    subtitle: const Text('Pay securely with your card'),
                    value: 'mastercard',
                    activeColor: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),

            // Card Details Section (only shown when mastercard payment is selected)
            if (_selectedPaymentMethod == 'mastercard') ...[
              const SizedBox(height: 16),
              const Text(
                'Card Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Card Number
              TextFormField(
                controller: _cardNumberController,
                decoration: const InputDecoration(
                  labelText: 'Card Number',
                  hintText: '1234 5678 9012 3456',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your card number';
                  }
                  final cardNumber = value
                      .replaceAll(' ', '')
                      .replaceAll('-', '');
                  if (cardNumber.length < 13 || cardNumber.length > 19) {
                    return 'Please enter a valid card number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Cardholder Name
              TextFormField(
                controller: _cardHolderController,
                decoration: const InputDecoration(
                  labelText: 'Cardholder Name',
                  hintText: 'John Doe',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the cardholder name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Expiry and CVV in a row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _expiryController,
                      decoration: const InputDecoration(
                        labelText: 'Expiry (MM/YY)',
                        hintText: '12/25',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter expiry date';
                        }
                        // ignore: deprecated_member_use
                        final expiryPattern = RegExp(
                          r'^(0[1-9]|1[0-2])\/\d{2}$',
                        );
                        if (!expiryPattern.hasMatch(value.trim())) {
                          return 'Please enter expiry date in MM/YY format';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _cvvController,
                      decoration: const InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter CVV';
                        }
                        // ignore: deprecated_member_use
                        final cvvPattern = RegExp(r'^\d{3,4}$');
                        if (!cvvPattern.hasMatch(value.trim())) {
                          return 'Please enter a valid CVV (3-4 digits)';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _validateCardDetails() {
    if (_selectedPaymentMethod != 'mastercard') {
      return true; // No validation needed for cash payment
    }

    // Check if all card fields are filled
    if (_cardNumberController.text.trim().isEmpty) {
      _showValidationError('Please enter your card number');
      return false;
    }

    if (_cardHolderController.text.trim().isEmpty) {
      _showValidationError('Please enter the cardholder name');
      return false;
    }

    if (_expiryController.text.trim().isEmpty) {
      _showValidationError('Please enter the expiry date');
      return false;
    }

    if (_cvvController.text.trim().isEmpty) {
      _showValidationError('Please enter the CVV');
      return false;
    }

    return true;
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Notes',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Delivery Instructions',
                hintText: 'Any special instructions for delivery...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
