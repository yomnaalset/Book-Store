import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_message.dart';
import '../services/fine_service.dart';
import '../../auth/providers/auth_provider.dart';

class FinePaymentMethodScreen extends StatefulWidget {
  final int? fineId; // Return request fine ID (new way)
  final int?
  borrowRequestId; // Borrow request ID (old way, for backward compatibility)
  final double fineAmount;
  final int hoursOverdue;

  const FinePaymentMethodScreen({
    super.key,
    this.fineId,
    this.borrowRequestId,
    required this.fineAmount,
    required this.hoursOverdue,
  });

  @override
  State<FinePaymentMethodScreen> createState() =>
      _FinePaymentMethodScreenState();
}

class _FinePaymentMethodScreenState extends State<FinePaymentMethodScreen> {
  String _selectedPaymentMethod = 'cash'; // 'cash' or 'mastercard'
  bool _isLoading = false;
  String? _errorMessage;
  final FineService _fineService = FineService();

  // MasterCard form fields
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  final TextEditingController _cardholderNameController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _cardholderNameController.dispose();
    super.dispose();
  }

  void _initializeService() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      _fineService.setToken(authProvider.token!);
    }
  }

  Future<void> _handlePaymentMethodSelection() async {
    // Validate MasterCard form if selected
    if (_selectedPaymentMethod == 'mastercard') {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_selectedPaymentMethod == 'cash') {
        // Select cash payment method
        Map<String, dynamic> result;

        if (widget.fineId != null) {
          // Use new return request fine endpoint
          result = await _fineService.selectReturnFinePaymentMethod(
            fineId: widget.fineId!,
            paymentMethod: 'cash',
          );
        } else if (widget.borrowRequestId != null) {
          // Use old borrowing fine endpoint (backward compatibility)
          result = await _fineService.selectPaymentMethod(
            borrowRequestId: widget.borrowRequestId!,
            paymentMethod: 'cash',
          );
        } else {
          throw Exception('Either fineId or borrowRequestId must be provided');
        }

        if (result['success'] == true && mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cash payment method selected. Delivery manager will collect cash upon return.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back
          Navigator.of(context).pop(true);
        } else {
          // Payment method selection failed
          throw Exception(
            result['message'] ?? 'Failed to select cash payment method',
          );
        }
      } else if (_selectedPaymentMethod == 'mastercard') {
        // Process MasterCard payment
        final cardData = {
          'card_number': _cardNumberController.text.replaceAll(' ', ''),
          'expiry_date': _expiryDateController.text,
          'cvv': _cvvController.text,
          'cardholder_name': _cardholderNameController.text,
        };

        Map<String, dynamic> result;

        if (widget.fineId != null) {
          // Use new return request fine endpoint
          result = await _fineService.confirmReturnFineCardPayment(
            fineId: widget.fineId!,
            cardData: cardData,
          );
        } else if (widget.borrowRequestId != null) {
          // Use old borrowing fine endpoint (backward compatibility)
          result = await _fineService.processMasterCardPayment(
            borrowRequestId: widget.borrowRequestId!,
            cardData: cardData,
          );
        } else {
          throw Exception('Either fineId or borrowRequestId must be provided');
        }

        if (result['success'] == true && mounted) {
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment processed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back
          Navigator.of(context).pop(true);
        } else {
          throw Exception(result['message'] ?? 'Payment failed');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Try to extract a user-friendly error message based on payment method
          final errorString = e.toString();

          if (_selectedPaymentMethod == 'cash') {
            // Cash-specific error messages
            // Extract the actual error message from nested exceptions
            String extractedMessage = errorString;

            // Try to extract from "Exception: Error selecting payment method: <actual message>"
            final nestedMatch = RegExp(
              r'Error selecting payment method: (.+)',
            ).firstMatch(errorString);
            if (nestedMatch != null) {
              extractedMessage = nestedMatch.group(1) ?? errorString;
            } else {
              // Try to extract from "Exception: <message>"
              final simpleMatch = RegExp(
                r'Exception: (.+)',
              ).firstMatch(errorString);
              if (simpleMatch != null) {
                extractedMessage = simpleMatch.group(1) ?? errorString;
              }
            }

            // Clean up the message
            extractedMessage = extractedMessage.trim();

            // Set appropriate error message
            if (extractedMessage.contains('404') ||
                extractedMessage.contains('not found')) {
              _errorMessage = 'Service not found. Please try again later.';
            } else if (extractedMessage.contains(
                  'Failed to select payment method',
                ) ||
                extractedMessage.contains(
                  'Failed to select cash payment method',
                )) {
              _errorMessage =
                  'Failed to select cash payment method. Please try again.';
            } else if (extractedMessage.contains(
              'Error selecting payment method',
            )) {
              _errorMessage = 'Error selecting cash payment. Please try again.';
            } else if (extractedMessage.isNotEmpty &&
                extractedMessage != errorString) {
              // Use the extracted message if it's different and not empty
              _errorMessage = extractedMessage;
            } else {
              _errorMessage =
                  'Failed to select cash payment method. Please try again.';
            }
          } else {
            // MasterCard-specific error messages
            if (errorString.contains('404') ||
                errorString.contains('Payment failed')) {
              _errorMessage =
                  'Payment failed. Please check your card details and try again.';
            } else if (errorString.contains('Error processing payment')) {
              _errorMessage = 'Error processing payment. Please try again.';
            } else {
              // Extract the actual error message from the exception
              final match = RegExp(r'Exception: (.+)').firstMatch(errorString);
              _errorMessage = match != null
                  ? match.group(1) ??
                        'Payment failed. Please check your card details and try again.'
                  : 'Payment failed. Please check your card details and try again.';
            }
          }
        });
      }
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
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.paymentMethod,
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
            // Fine Summary Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.fineDetails,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSizeL,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    _buildInfoRow('Hours Overdue', '${widget.hoursOverdue}'),
                    const SizedBox(height: AppDimensions.spacingS),
                    _buildInfoRow(
                      localizations.fineAmount,
                      '\$${widget.fineAmount.toStringAsFixed(2)}',
                      isAmount: true,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: AppDimensions.spacingXL),

            // Payment Method Selection
            Text(
              localizations.selectPaymentMethod,
              style: const TextStyle(
                fontSize: AppDimensions.fontSizeL,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),

            // Payment Method Options
            SegmentedButton<String>(
              segments: [
                ButtonSegment<String>(
                  value: 'cash',
                  label: Text(localizations.paymentMethodCash),
                  icon: const Icon(Icons.money),
                ),
                ButtonSegment<String>(
                  value: 'mastercard',
                  label: Text(localizations.paymentMethodCard),
                  icon: const Icon(Icons.credit_card),
                ),
              ],
              selected: {_selectedPaymentMethod},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedPaymentMethod = newSelection.first;
                });
              },
            ),

            const SizedBox(height: AppDimensions.spacingL),

            // Payment Method Description
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: AppColors.infoLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _selectedPaymentMethod == 'cash'
                        ? Icons.info_outline
                        : Icons.credit_card,
                    color: AppColors.info,
                    size: 20,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      _selectedPaymentMethod == 'cash'
                          ? localizations.deliveryManagerWillCollectCash
                          : 'Enter your card details below to complete the payment.',
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // MasterCard Form Fields (only show when MasterCard is selected)
            if (_selectedPaymentMethod == 'mastercard') ...[
              const SizedBox(height: AppDimensions.spacingXL),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Card Number
                    TextFormField(
                      controller: _cardNumberController,
                      decoration: InputDecoration(
                        labelText: 'Card Number',
                        hintText: '1234 5678 9012 3456',
                        prefixIcon: const Icon(Icons.credit_card),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter card number';
                        }
                        final cardNumber = value.replaceAll(' ', '');
                        if (cardNumber.length < 13 || cardNumber.length > 19) {
                          return 'Invalid card number';
                        }
                        return null;
                      },
                      inputFormatters: [
                        // Format card number with spaces
                        CardNumberInputFormatter(),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    // Expiry Date
                    TextFormField(
                      controller: _expiryDateController,
                      decoration: InputDecoration(
                        labelText: 'Expiry Date',
                        hintText: 'MM/YY',
                        prefixIcon: const Icon(Icons.calendar_today),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter expiry date';
                        }
                        if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(value)) {
                          return 'Invalid format (MM/YY)';
                        }
                        return null;
                      },
                      inputFormatters: [
                        // Format expiry date as MM/YY
                        ExpiryDateInputFormatter(),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    // CVV
                    TextFormField(
                      controller: _cvvController,
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        hintText: '123',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter CVV';
                        }
                        if (value.length < 3) {
                          return 'Invalid CVV';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    // Cardholder Name
                    TextFormField(
                      controller: _cardholderNameController,
                      decoration: InputDecoration(
                        labelText: 'Cardholder Name',
                        hintText: 'John Doe',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter cardholder name';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppDimensions.spacingXL),

            // Error Message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.spacingM),
                child: ErrorMessage(message: _errorMessage!),
              ),

            // Continue/Confirm Payment Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handlePaymentMethodSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.paddingM,
                  ),
                ),
                child: _isLoading
                    ? const LoadingIndicator()
                    : Text(
                        _selectedPaymentMethod == 'cash'
                            ? localizations.continueButton
                            : 'Confirm Payment',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isAmount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: AppDimensions.fontSizeM,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isAmount
                ? AppDimensions.fontSizeXL
                : AppDimensions.fontSizeM,
            fontWeight: isAmount ? FontWeight.bold : FontWeight.w600,
            color: isAmount ? AppColors.error : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// Input formatter for card number (adds spaces every 4 digits)
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.isEmpty) {
      return newValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

// Input formatter for expiry date (MM/YY format)
class ExpiryDateInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    if (text.isEmpty) {
      return newValue;
    }

    if (text.length > 4) {
      return oldValue;
    }

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(text[i]);
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}
