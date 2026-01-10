import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../books/models/book.dart';
import '../providers/borrow_provider.dart';
import '../models/book.dart' as borrow_book;
import '../screens/payment_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';

class BorrowRequestScreen extends StatefulWidget {
  final Book book;

  const BorrowRequestScreen({super.key, required this.book});

  @override
  State<BorrowRequestScreen> createState() => _BorrowRequestScreenState();
}

class _BorrowRequestScreenState extends State<BorrowRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  final _deliveryAddressController = TextEditingController();

  int _selectedDays = 7;
  final List<int> _durationOptions = [1, 2, 7, 14]; // Duration options in days
  bool _isLoadingProfile = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserAddress();
    });
  }

  Future<void> _loadUserAddress() async {
    setState(() {
      _isLoadingProfile = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(
        context,
        listen: false,
      );

      if (authProvider.token != null) {
        profileProvider.setToken(authProvider.token);

        // Load profile data to get the latest address
        await profileProvider.loadProfile(
          token: authProvider.token,
          context: context,
        );

        // Get the current user data
        final currentUser = authProvider.user;
        if (currentUser != null &&
            currentUser.address != null &&
            currentUser.address!.isNotEmpty) {
          _deliveryAddressController.text = currentUser.address!;
        } else {
          // Show dialog to add address
          _showAddAddressDialog();
        }
      }
    } catch (e) {
      debugPrint('Error loading user address: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  void _showAddAddressDialog() {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.addressRequired),
          content: Text(localizations.addressRequiredMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/profile').then((_) {
                  // Reload address after returning from profile
                  _loadUserAddress();
                });
              },
              child: Text(localizations.yes),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    _deliveryAddressController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    // Calculate fees
    // Borrowing fee from book's borrow price
    double borrowingFee = widget.book.borrowPriceAsDouble > 0
        ? widget.book.borrowPriceAsDouble
        : 10.0; // Default fallback

    // Delivery fee is 4% of borrowing fee
    final deliveryFee = borrowingFee * 0.04;
    final totalFee = borrowingFee + deliveryFee;

    // Navigate to payment screen WITHOUT creating the request yet
    // Pass all the necessary data to create the request after payment
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentScreen(
          borrowRequest: null, // No request created yet
          book: borrow_book.Book(
            id: int.parse(widget.book.id),
            title: widget.book.title,
            author: widget.book.author?.name,
            coverImageUrl: widget.book.coverImageUrl,
            price: borrowingFee,
          ),
          borrowingFee: borrowingFee,
          deliveryFee: deliveryFee,
          totalFee: totalFee,
          // Pass the request data to be used after payment
          bookId: widget.book.id, // Keep as string since the API expects string
          borrowPeriodDays: _selectedDays,
          deliveryAddress: _deliveryAddressController.text.trim(),
          notes: _notesController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.borrowRequest,
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
      ),
      body: Consumer<BorrowProvider>(
        builder: (context, borrowProvider, child) {
          if (_isLoadingProfile) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppDimensions.spacingM),
                  Text(localizations.loadingYourAddress),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Book Info
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                                  const SizedBox(
                                    height: AppDimensions.spacingS,
                                  ),
                                  if (widget.book.author != null)
                                    Text(
                                      localizations.byAuthor(
                                        widget.book.author?.name ??
                                            localizations.author,
                                      ),
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeM,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  const SizedBox(
                                    height: AppDimensions.spacingS,
                                  ),
                                  Text(
                                    localizations.availableCopies(
                                      widget.book.availableCopies ?? 0,
                                    ),
                                    style: const TextStyle(
                                      fontSize: AppDimensions.fontSizeS,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),

                  // Duration Selection
                  Text(
                    localizations.borrowDuration,
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingM),

                  Wrap(
                    spacing: AppDimensions.spacingM,
                    children: _durationOptions.map((days) {
                      final isSelected = _selectedDays == days;
                      final label = '$days ${localizations.days}';
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedDays = days);
                          }
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? AppColors.white
                              : AppColors.textPrimary,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),

                  // Delivery Address
                  Text(
                    localizations.deliveryAddress,
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingM),

                  CustomTextField(
                    controller: _deliveryAddressController,
                    hintText: localizations.enterDeliveryAddress,
                    maxLines: 2,
                    enabled: false, // Make it read-only
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return localizations.deliveryAddressRequired;
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppDimensions.spacingS),

                  // Edit Address Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(context, '/profile').then((_) {
                          // Reload address after returning from profile
                          _loadUserAddress();
                        });
                      },
                      icon: const Icon(Icons.edit, size: 16),
                      label: Text(localizations.editAddressFromProfile),
                    ),
                  ),

                  const SizedBox(height: AppDimensions.spacingXL),

                  // Notes
                  Text(
                    localizations.additionalNotesOptional,
                    style: const TextStyle(
                      fontSize: AppDimensions.fontSizeL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingM),

                  CustomTextField(
                    controller: _notesController,
                    hintText: localizations.anySpecialRequests,
                    maxLines: 3,
                  ),

                  const SizedBox(height: AppDimensions.spacingXXL),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      text: localizations.submitRequest,
                      onPressed: borrowProvider.isLoading
                          ? null
                          : _submitRequest,
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
