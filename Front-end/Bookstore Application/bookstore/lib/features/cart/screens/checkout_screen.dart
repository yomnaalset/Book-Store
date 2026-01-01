import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/localization/app_localizations.dart';
import '../providers/cart_provider.dart';
import '../../auth/providers/auth_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paymentFormKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Address controllers
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipController = TextEditingController();
  final _countryController = TextEditingController();

  // Payment controllers
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _cardHolderController = TextEditingController();

  String _selectedPaymentMethod = 'mastercard';
  bool _showPaymentValidation = false;

  @override
  void initState() {
    super.initState();
    // Initialize form fields with user data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFormWithUserData();
    });

    // Add listeners to reset validation state when user starts typing
    _cardNumberController.addListener(_resetValidationState);
    _cardHolderController.addListener(_resetValidationState);
    _expiryController.addListener(_resetValidationState);
    _cvvController.addListener(_resetValidationState);
  }

  void _initializeFormWithUserData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null) {
      // Pre-fill address fields with user's existing data
      if (user.address != null && user.address!.isNotEmpty) {
        _addressController.text = user.address!;
      }
      if (user.city != null && user.city!.isNotEmpty) {
        _cityController.text = user.city!;
      }
      if (user.zipCode != null && user.zipCode!.isNotEmpty) {
        _zipController.text = user.zipCode!;
      }
      if (user.country != null && user.country!.isNotEmpty) {
        _countryController.text = user.country!;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _zipController.dispose();
    _countryController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.checkout,
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Container(
            color: AppColors.primary,
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: _buildCustomStepper(context),
          ),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          return Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) =>
                      setState(() => _currentStep = index),
                  children: [
                    _buildDeliveryStep(),
                    _buildPaymentStep(),
                    _buildReviewStep(cartProvider),
                  ],
                ),
              ),
              _buildBottomNavigation(cartProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCustomStepper(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Row(
      children: [
        _buildStep(
          stepNumber: 1,
          title: localizations.delivering,
          isActive: _currentStep == 0,
          isCompleted: _currentStep > 0,
        ),
        _buildStepConnector(),
        _buildStep(
          stepNumber: 2,
          title: localizations.paymentMethod,
          isActive: _currentStep == 1,
          isCompleted: _currentStep > 1,
        ),
        _buildStepConnector(),
        _buildStep(
          stepNumber: 3,
          title: localizations.invoice,
          isActive: _currentStep == 2,
          isCompleted: _currentStep > 2,
        ),
      ],
    );
  }

  Widget _buildStep({
    required int stepNumber,
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted || isActive
                  ? AppColors.white
                  : AppColors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check, color: AppColors.primary, size: 20)
                  : Text(
                      '$stepNumber',
                      style: TextStyle(
                        color: isActive || isCompleted
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepConnector() {
    return Container(
      height: 2,
      width: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  Widget _buildDeliveryStep() {
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizations.deliveryInformation,
                  style: TextStyle(
                    fontSize: AppDimensions.fontSizeL,
                    fontWeight: FontWeight.bold,
                    color: context.textColor,
                  ),
                ),
                TextButton.icon(
                  onPressed: _navigateToProfile,
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(localizations.editProfile),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingL),

            // Show message when all fields are empty
            if (_areAllFieldsEmpty())
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Text(
                        localizations.noDeliveryInfoFound,
                        style: const TextStyle(
                          color: AppColors.warning,
                          fontSize: AppDimensions.fontSizeS,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Show message when fields have data but are read-only
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppDimensions.spacingS),
                    Expanded(
                      child: Text(
                        localizations.deliveryInfoReadonly,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: AppDimensions.fontSizeS,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // All fields are always disabled/read-only
            CustomTextField(
              label: localizations.addressLabel,
              controller: _addressController,
              enabled: false,
              validator: (value) => value?.isEmpty == true
                  ? localizations.pleaseEnterAddress
                  : null,
              maxLines: 2,
            ),
            const SizedBox(height: AppDimensions.spacingM),

            CustomTextField(
              label: localizations.cityLabel,
              controller: _cityController,
              enabled: false,
              validator: (value) =>
                  value?.isEmpty == true ? localizations.pleaseEnterCity : null,
            ),
            const SizedBox(height: AppDimensions.spacingM),

            Row(
              children: [
                Expanded(
                  child: CustomTextField(
                    label: localizations.zipCodeLabel,
                    controller: _zipController,
                    enabled: false,
                    validator: (value) => value?.isEmpty == true
                        ? localizations.pleaseEnterZip
                        : null,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: CustomTextField(
                    label: localizations.countryLabel,
                    controller: _countryController,
                    enabled: false,
                    validator: (value) => value?.isEmpty == true
                        ? localizations.pleaseEnterCountry
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentStep() {
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.paymentMethod,
            style: TextStyle(
              fontSize: AppDimensions.fontSizeL,
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),

          _buildPaymentMethods(),

          const SizedBox(height: AppDimensions.spacingL),

          if (_selectedPaymentMethod == 'mastercard') _buildCardDetails(),

          // Show validation error message for all fields
          if (_showPaymentValidation &&
              _selectedPaymentMethod == 'mastercard' &&
              _hasEmptyCardFields())
            Container(
              margin: const EdgeInsets.only(top: AppDimensions.spacingM),
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      localizations.fillAllCardDetails,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: AppDimensions.fontSizeS,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final localizations = AppLocalizations.of(context);
    final methods = [
      {
        'id': 'mastercard',
        'name': localizations.mastercard,
        'icon': Icons.credit_card,
      },
      {'id': 'cash', 'name': localizations.cashPayment, 'icon': Icons.money},
    ];

    return RadioGroup<String>(
      groupValue: _selectedPaymentMethod,
      onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
      child: Column(
        children: methods
            .map(
              (method) => Card(
                child: RadioListTile<String>(
                  value: method['id'] as String,
                  title: Text(method['name'] as String),
                  secondary: Icon(method['icon'] as IconData),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCardDetails() {
    final localizations = AppLocalizations.of(context);
    return Form(
      key: _paymentFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.cardDetails,
            style: TextStyle(
              fontSize: AppDimensions.fontSizeM,
              fontWeight: FontWeight.w600,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),

          CustomTextField(
            label: localizations.cardNumber,
            controller: _cardNumberController,
            validator: (value) {
              if (_showPaymentValidation && (value?.isEmpty == true)) {
                return localizations.required;
              }
              return null;
            },
            keyboardType: TextInputType.number,
            borderColor:
                _showPaymentValidation && _cardNumberController.text.isEmpty
                ? Colors.red
                : null,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          CustomTextField(
            label: localizations.cardholderName,
            controller: _cardHolderController,
            validator: (value) {
              if (_showPaymentValidation && (value?.isEmpty == true)) {
                return localizations.required;
              }
              return null;
            },
            borderColor:
                _showPaymentValidation && _cardHolderController.text.isEmpty
                ? Colors.red
                : null,
          ),
          const SizedBox(height: AppDimensions.spacingM),

          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: localizations.expiryDate,
                  controller: _expiryController,
                  validator: (value) {
                    if (_showPaymentValidation && (value?.isEmpty == true)) {
                      return localizations.required;
                    }
                    return null;
                  },
                  keyboardType: TextInputType.number,
                  borderColor:
                      _showPaymentValidation && _expiryController.text.isEmpty
                      ? Colors.red
                      : null,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: CustomTextField(
                  label: localizations.cvv,
                  controller: _cvvController,
                  validator: (value) {
                    if (_showPaymentValidation && (value?.isEmpty == true)) {
                      return localizations.required;
                    }
                    return null;
                  },
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  borderColor:
                      _showPaymentValidation && _cvvController.text.isEmpty
                      ? Colors.red
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(CartProvider cartProvider) {
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.orderSummary,
            style: TextStyle(
              fontSize: AppDimensions.fontSizeL,
              fontWeight: FontWeight.bold,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),

          // Order items
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                children: cartProvider.items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppDimensions.spacingS,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.book.title} x ${item.quantity}',
                                style: TextStyle(color: context.textColor),
                              ),
                            ),
                            Text(
                              '\$${item.totalPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: context.textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),

          const SizedBox(height: AppDimensions.spacingM),

          // Price breakdown
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                children: [
                  _buildSummaryRow(
                    localizations.subtotal,
                    '\$${cartProvider.subtotal.toStringAsFixed(2)}',
                  ),
                  _buildSummaryRow(
                    localizations.tax,
                    '\$${cartProvider.taxAmount.toStringAsFixed(2)}',
                  ),
                  _buildSummaryRow(
                    localizations.delivery,
                    '\$${cartProvider.deliveryCost.toStringAsFixed(2)}',
                  ),
                  if (cartProvider.discountAmount > 0) ...[
                    const Divider(),
                    _buildSummaryRow(
                      localizations.discount,
                      '-\$${cartProvider.discountAmount.toStringAsFixed(2)}',
                      color: AppColors.success,
                    ),
                  ],
                  _buildSummaryRow(
                    localizations.total,
                    '\$${cartProvider.total.toStringAsFixed(2)}',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
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
              color: color ?? context.textColor,
            ),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: isTotal
                  ? AppDimensions.fontSizeL
                  : AppDimensions.fontSizeM,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: color ?? context.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation(CartProvider cartProvider) {
    final localizations = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode ? Colors.black26 : Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_currentStep > 0)
              Expanded(
                child: CustomButton(
                  text: localizations.back,
                  onPressed: () => _previousStep(),
                  type: ButtonType.secondary,
                ),
              ),
            if (_currentStep > 0) const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              flex: 2,
              child: CustomButton(
                text: _currentStep < 2
                    ? localizations.continueButton
                    : localizations.placeOrder,
                onPressed: () =>
                    _currentStep < 2 ? _nextStep() : _placeOrder(cartProvider),
                type: ButtonType.primary,
                isLoading: cartProvider.isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _nextStep() {
    if (_currentStep == 0 && !_formKey.currentState!.validate()) {
      return;
    }

    // Validate payment step when Mastercard is selected
    if (_currentStep == 1 && _selectedPaymentMethod == 'mastercard') {
      setState(() {
        _showPaymentValidation = true;
      });

      if (!_paymentFormKey.currentState!.validate() || _hasEmptyCardFields()) {
        return;
      }
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToProfile() async {
    // Navigate to profile screen to edit user information
    await Navigator.pushNamed(context, '/profile');

    // Refresh user data from server to get the latest information
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshUserData();

      // Always refresh the form data when returning from profile screen
      // This ensures we get the latest data
      _initializeFormWithUserData();

      // Force a rebuild to update the UI with new data
      setState(() {});
    }
  }

  bool _areAllFieldsEmpty() {
    return _addressController.text.isEmpty &&
        _cityController.text.isEmpty &&
        _zipController.text.isEmpty &&
        _countryController.text.isEmpty;
  }

  bool _hasEmptyCardFields() {
    return _cardNumberController.text.trim().isEmpty ||
        _cardHolderController.text.trim().isEmpty ||
        _expiryController.text.trim().isEmpty ||
        _cvvController.text.trim().isEmpty;
  }

  void _resetValidationState() {
    if (_showPaymentValidation) {
      setState(() {
        _showPaymentValidation = false;
      });
    }
  }

  Future<void> _saveAddressToProfile(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;

    if (user != null) {
      // Update user profile with the address information from the form
      final profileData = {
        'address': _addressController.text.isNotEmpty
            ? _addressController.text
            : user.address,
        'city': _cityController.text.isNotEmpty
            ? _cityController.text
            : user.city,
        'zip_code': _zipController.text.isNotEmpty
            ? _zipController.text
            : user.zipCode,
        'country': _countryController.text.isNotEmpty
            ? _countryController.text
            : user.country,
      };

      // Update the local user profile
      authProvider.updateUserProfile(profileData);

      // Note: In a real app, you might want to also save this to the backend
      // via an API call to persist the changes
    }
  }

  Future<void> _placeOrder(CartProvider cartProvider) async {
    try {
      // Validate card details one more time before placing order
      if (_selectedPaymentMethod == 'mastercard') {
        setState(() {
          _showPaymentValidation = true;
        });

        if (!_paymentFormKey.currentState!.validate() ||
            _hasEmptyCardFields()) {
          return;
        }
      }

      // Save address information to user profile for future orders
      await _saveAddressToProfile(context);

      if (!mounted) return;

      // Prepare checkout data with address and payment method
      final checkoutData = cartProvider.getCheckoutData();
      checkoutData['address'] = _addressController.text;
      checkoutData['city'] = _cityController.text;
      checkoutData['payment_method'] = _selectedPaymentMethod;

      // Add card details if Mastercard is selected
      if (_selectedPaymentMethod == 'mastercard') {
        checkoutData['card_details'] = {
          'card_number': _cardNumberController.text.trim(),
          'cardholder_name': _cardHolderController.text.trim(),
          'expiry_date': _expiryController.text.trim(),
          'cvv': _cvvController.text.trim(),
        };
      }

      // Process the actual checkout
      final result = await cartProvider.processCheckoutWithData(
        context,
        checkoutData,
      );

      if (result != null) {
        // Clear the cart
        cartProvider.clearCart();

        // Show success dialog
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(localizations.orderPlaced),
              content: Text(localizations.orderPlacedSuccessfully),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/orders',
                      (route) => route.isFirst,
                    );
                  },
                  child: Text(localizations.viewOrders),
                ),
              ],
            ),
          );
        }
      } else {
        // Show error dialog
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(localizations.orderFailed),
              content: Text(
                cartProvider.errorMessage ?? localizations.failedToPlaceOrder,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations.ok),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // Show error dialog
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(localizations.orderFailed),
            content: Text('${localizations.error}: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(localizations.ok),
              ),
            ],
          ),
        );
      }
    }
  }
}
