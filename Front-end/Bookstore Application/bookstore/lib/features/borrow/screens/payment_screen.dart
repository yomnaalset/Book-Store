import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../models/borrow_request.dart';
import '../models/book.dart';
import '../providers/borrow_provider.dart';
import 'request_submitted_success_screen.dart';

class PaymentScreen extends StatefulWidget {
  final BorrowRequest borrowRequest;
  final Book book;
  final double borrowingFee;
  final double deliveryFee;
  final double totalFee;

  const PaymentScreen({
    super.key,
    required this.borrowRequest,
    required this.book,
    required this.borrowingFee,
    required this.deliveryFee,
    required this.totalFee,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  String _selectedPaymentMethod = 'cash'; // 'cash' or 'mastercard'

  // Card input controllers
  final _cardNumberController = TextEditingController();
  final _cardholderNameController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cvvController = TextEditingController();

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardholderNameController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  String _formatCardNumber(String value) {
    // Remove all non-digits
    final digitsOnly = value.replaceAll(RegExp(r'\D'), '');

    // Add spaces every 4 digits
    final buffer = StringBuffer();
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(digitsOnly[i]);
    }
    return buffer.toString();
  }

  Future<void> _confirmPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final borrowProvider = Provider.of<BorrowProvider>(context, listen: false);

    String? cardNumber;
    String? cardholderName;
    int? expiryMonth;
    int? expiryYear;
    String? cvv;

    if (_selectedPaymentMethod == 'mastercard') {
      cardNumber = _cardNumberController.text.replaceAll(' ', '');
      cardholderName = _cardholderNameController.text.trim();
      expiryMonth = int.tryParse(_expiryMonthController.text);
      expiryYear = int.tryParse(_expiryYearController.text);
      cvv = _cvvController.text.trim();
    }

    final success = await borrowProvider.confirmPayment(
      requestId: widget.borrowRequest.id,
      paymentMethod: _selectedPaymentMethod,
      cardNumber: cardNumber,
      cardholderName: cardholderName,
      expiryMonth: expiryMonth,
      expiryYear: expiryYear,
      cvv: cvv,
    );

    if (mounted) {
      if (success) {
        // Navigate to success screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RequestSubmittedSuccessScreen(
              borrowRequest: widget.borrowRequest,
              book: widget.book,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              borrowProvider.errorMessage ?? 'Failed to confirm payment',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Consumer<BorrowProvider>(
        builder: (context, borrowProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Info Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              widget.book.coverImageUrl ?? '',
                              width: 80,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 80,
                                  height: 120,
                                  color: AppColors.surface,
                                  child: const Icon(Icons.book),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.book.title,
                                  style: const TextStyle(
                                    fontSize: AppDimensions.fontSizeL,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spacingS),
                                if (widget.book.author != null)
                                  Text(
                                    'by ${widget.book.author}',
                                    style: const TextStyle(
                                      fontSize: AppDimensions.fontSizeM,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),

                  // Total Fee Section
                  const Text(
                    'Total Fee',
                    style: TextStyle(
                      fontSize: AppDimensions.fontSizeL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Borrowing Fee:',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeM,
                                ),
                              ),
                              Text(
                                '\$${widget.borrowingFee.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: AppDimensions.fontSizeM,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacingS),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Delivery Fee:',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeM,
                                ),
                              ),
                              Text(
                                '\$${widget.deliveryFee.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: AppDimensions.fontSizeM,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeL,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '\$${widget.totalFee.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: AppDimensions.fontSizeL,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),

                  // Payment Method Selection
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: AppDimensions.fontSizeL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingM),

                  // Payment Method Selection using SegmentedButton
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value: 'cash',
                        label: Text('Cash on Delivery'),
                        icon: Icon(Icons.money),
                      ),
                      ButtonSegment<String>(
                        value: 'mastercard',
                        label: Text('Mastercard'),
                        icon: Icon(Icons.credit_card),
                      ),
                    ],
                    selected: {_selectedPaymentMethod},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _selectedPaymentMethod = newSelection.first;
                      });
                    },
                  ),

                  const SizedBox(height: AppDimensions.spacingM),

                  // Payment method description
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.greyLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedPaymentMethod == 'cash'
                              ? Icons.info_outline
                              : Icons.credit_card_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        Expanded(
                          child: Text(
                            _selectedPaymentMethod == 'cash'
                                ? 'Pay when the book is delivered'
                                : 'Pay with credit/debit card',
                            style: const TextStyle(
                              fontSize: AppDimensions.fontSizeS,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Card Input Fields (shown only when Mastercard is selected)
                  if (_selectedPaymentMethod == 'mastercard') ...[
                    const SizedBox(height: AppDimensions.spacingXL),
                    const Text(
                      'Card Details',
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeL,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),

                    // Card Number
                    CustomTextField(
                      controller: _cardNumberController,
                      hintText: 'Card Number',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(19),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          final formatted = _formatCardNumber(newValue.text);
                          return TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                          );
                        }),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Card number is required';
                        }
                        final digitsOnly = value.replaceAll(' ', '');
                        if (digitsOnly.length < 13 || digitsOnly.length > 19) {
                          return 'Invalid card number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppDimensions.spacingM),

                    // Cardholder Name
                    CustomTextField(
                      controller: _cardholderNameController,
                      hintText: 'Cardholder Name',
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Cardholder name is required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppDimensions.spacingM),

                    // Expiry Date Row
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            controller: _expiryMonthController,
                            hintText: 'MM',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Month required';
                              }
                              final month = int.tryParse(value);
                              if (month == null || month < 1 || month > 12) {
                                return 'Invalid month';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        const Text(
                          '/',
                          style: TextStyle(
                            fontSize: AppDimensions.fontSizeXL,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        Expanded(
                          child: CustomTextField(
                            controller: _expiryYearController,
                            hintText: 'YYYY',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Year required';
                              }
                              final year = int.tryParse(value);
                              if (year == null || year < 2024) {
                                return 'Invalid year';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppDimensions.spacingM),

                    // CVV
                    CustomTextField(
                      controller: _cvvController,
                      hintText: 'CVV',
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'CVV is required';
                        }
                        if (value.length < 3 || value.length > 4) {
                          return 'CVV must be 3 or 4 digits';
                        }
                        return null;
                      },
                    ),
                  ],

                  const SizedBox(height: AppDimensions.spacingXXL),

                  // Confirm Request Button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: 'Confirm Request',
                      onPressed: borrowProvider.isLoading
                          ? null
                          : _confirmPayment,
                      isLoading: borrowProvider.isLoading,
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
}
