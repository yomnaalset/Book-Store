import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/discounts_provider.dart';
import '../../../models/discount.dart';
import '../../../models/book_discount.dart';
import '../../../services/manager_api_service.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../book_selection/book_selection_screen.dart';
import '../../../../../../core/services/api_config.dart';
import '../../../../../core/localization/app_localizations.dart';

class DiscountFormScreen extends StatefulWidget {
  final Discount? discount;
  final BookDiscount? bookDiscount;

  const DiscountFormScreen({super.key, this.discount, this.bookDiscount});

  @override
  State<DiscountFormScreen> createState() => _DiscountFormScreenState();
}

class _DiscountFormScreenState extends State<DiscountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _percentageController = TextEditingController();
  final _maxUsesController = TextEditingController();
  final _discountedPriceController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _isActive = true;
  bool _isLoading = false;

  // Discount type and book selection
  String _discountType = 'invoice'; // 'invoice' or 'book'
  AvailableBook? _selectedBook;

  @override
  void initState() {
    super.initState();
    debugPrint(
      'DEBUG: DiscountFormScreen initState - discount: ${widget.discount}, bookDiscount: ${widget.bookDiscount}',
    );
    if (widget.discount != null) {
      _discountType = 'invoice';
      _populateDiscountForm();
    } else if (widget.bookDiscount != null) {
      _discountType = 'book';
      _populateBookDiscountForm();
    } else {
      // For new discounts, default to invoice type
      _discountType = 'invoice';
      debugPrint(
        'DEBUG: New discount form initialized with type: $_discountType',
      );
    }
  }

  void _populateDiscountForm() {
    final discount = widget.discount!;
    _codeController.text = discount.code;
    _percentageController.text = discount.value.toString();
    _maxUsesController.text = discount.usageLimit?.toString() ?? '1';
    _endDate = discount.endDate ?? DateTime.now().add(const Duration(days: 30));
    _startDate = discount.startDate ?? DateTime.now();
    _isActive = discount.isActive;
  }

  void _populateBookDiscountForm() {
    final bookDiscount = widget.bookDiscount!;
    _codeController.text = bookDiscount.code;
    _maxUsesController.text = bookDiscount.usageLimitPerCustomer.toString();
    _endDate = bookDiscount.endDate;
    _startDate = bookDiscount.startDate;
    _isActive = bookDiscount.isActive;

    // Book discounts only support fixed price
    _discountedPriceController.text = bookDiscount.discountedPrice.toString();

    // Create AvailableBook from BookDiscount data
    _selectedBook = AvailableBook(
      id: bookDiscount.bookId,
      name: bookDiscount.bookName,
      authorName: '', // Not available in BookDiscount
      categoryName: '', // Not available in BookDiscount
      price: bookDiscount.bookPrice,
      thumbnail: bookDiscount.bookThumbnail,
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _percentageController.dispose();
    _maxUsesController.dispose();
    _discountedPriceController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 1));
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _endDate) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _selectBook() async {
    final result = await Navigator.push<AvailableBook>(
      context,
      MaterialPageRoute(
        builder: (context) => BookSelectionScreen(
          onBookSelected: (book) {
            setState(() {
              _selectedBook = book;
            });
          },
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _selectedBook = result;
      });
    }
  }

  List<String> _generateAlternativeCodes(String baseCode) {
    final alternatives = <String>[];
    final cleanCode = baseCode.toUpperCase().trim();

    // Add numbers
    for (int i = 1; i <= 5; i++) {
      alternatives.add('$cleanCode$i');
    }

    // Add year suffix
    final currentYear = DateTime.now().year;
    alternatives.add('$cleanCode$currentYear');

    // Add month suffix
    final currentMonth = DateTime.now().month;
    alternatives.add('$cleanCode${currentMonth.toString().padLeft(2, '0')}');

    // Add variations with underscores
    alternatives.add('${cleanCode}_NEW');
    alternatives.add('${cleanCode}_V2');

    return alternatives.take(5).toList();
  }

  void _showAlternativeCodesDialog(List<String> alternatives) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.codeAlreadyExists),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(localizations.discountCodeAlreadyExistsMessage),
            const SizedBox(height: 16),
            ...alternatives.map(
              (code) => ListTile(
                title: Text(code),
                onTap: () {
                  _codeController.text = code;
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(localizations.cancel),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDiscount() async {
    if (!_formKey.currentState!.validate()) return;

    final localizations = AppLocalizations.of(context);
    // Additional validation for book discounts
    if (_discountType == 'book' && _selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseSelectBookForDiscount),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_discountType == 'invoice') {
        await _saveInvoiceDiscount();
      } else {
        await _saveBookDiscount();
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        String errorMessage = '${localizations.error}: ${e.toString()}';

        // Parse error message for better user feedback
        if (e.toString().contains(
          'Discount Code with this code already exists',
        )) {
          final alternatives = _generateAlternativeCodes(_codeController.text);
          errorMessage = localizations.discountCodeAlreadyExistsTry(
            alternatives.join(', '),
          );
        } else if (e.toString().contains('validation errors')) {
          errorMessage = localizations.pleaseCheckInputAndTryAgain;
        }

        // Show error with alternative codes if available
        if (e.toString().contains(
          'Discount Code with this code already exists',
        )) {
          final alternatives = _generateAlternativeCodes(_codeController.text);
          _showAlternativeCodesDialog(alternatives);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveInvoiceDiscount() async {
    final provider = context.read<DiscountsProvider>();
    final authProvider = context.read<AuthProvider>();

    // Ensure provider has the current token
    if (authProvider.token != null) {
      provider.setToken(authProvider.token);
    }

    final discountData = Discount(
      id: widget.discount?.id ?? '',
      code: _codeController.text.trim().toUpperCase(),
      title: _codeController.text.trim().toUpperCase(),
      type: Discount.typePercentage,
      value: double.parse(_percentageController.text.trim()),
      usageLimit: int.parse(_maxUsesController.text.trim()),
      isActive: _isActive,
      startDate: _startDate,
      endDate: _endDate,
      createdAt: widget.discount?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (widget.discount == null) {
      await provider.createDiscount(discountData);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.discountCreatedSuccessfully)),
        );
      }
    } else {
      await provider.updateDiscount(discountData);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.discountUpdatedSuccessfully)),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context, discountData);
    }
  }

  Future<void> _saveBookDiscount() async {
    final authProvider = context.read<AuthProvider>();
    final apiService = ManagerApiService(
      baseUrl: ApiConfig.getAndroidEmulatorUrl(),
      headers: {},
      getAuthToken: () => authProvider.token ?? '',
    );

    if (authProvider.token != null) {
      apiService.setToken(authProvider.token);
    }

    // Book discounts only support fixed price
    final discountedPrice = double.parse(
      _discountedPriceController.text.trim(),
    );

    final bookDiscountData = BookDiscount(
      id: widget.bookDiscount?.id ?? '',
      code: _codeController.text.trim().toUpperCase(),
      discountType: BookDiscount.typeFixedPrice,
      bookId: _selectedBook!.id,
      bookName: _selectedBook!.name,
      bookPrice: _selectedBook!.price,
      bookThumbnail: _selectedBook!.thumbnail,
      discountedPrice: discountedPrice,
      usageLimitPerCustomer: int.parse(_maxUsesController.text.trim()),
      startDate: _startDate,
      endDate: _endDate,
      isActive: _isActive,
      createdAt: widget.bookDiscount?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      createdById: authProvider.user?.id,
    );

    if (widget.bookDiscount == null) {
      await apiService.createBookDiscount(bookDiscountData);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.bookDiscountCreatedSuccessfully),
          ),
        );
      }
    } else {
      await apiService.updateBookDiscount(bookDiscountData);
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.bookDiscountUpdatedSuccessfully),
          ),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context, bookDiscountData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.discount != null || widget.bookDiscount != null
              ? localizations.editDiscount
              : localizations.createDiscount,
        ),
        actions: [
          if (widget.discount != null || widget.bookDiscount != null)
            IconButton(
              onPressed: _isLoading ? null : () => _deleteDiscount(),
              icon: const Icon(Icons.delete),
              color: Colors.red,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Row(
                                  children: [
                                    const Icon(
                                      Icons.local_offer,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      localizations.discountInformation,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Code Field
                            TextFormField(
                              controller: _codeController,
                              decoration: InputDecoration(
                                labelText: '${localizations.discountCode} *',
                                border: const OutlineInputBorder(),
                                hintText: localizations.enterDiscountCode,
                                prefixIcon: const Icon(Icons.code),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return localizations.discountCodeRequired;
                                }
                                if (value.trim().length < 3) {
                                  return localizations.discountCodeMinLength;
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Discount Type Selection (only for new discounts)
                    if (widget.discount == null && widget.bookDiscount == null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.category,
                                    color: Colors.purple,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    localizations.discountType,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              DropdownButtonFormField<String>(
                                initialValue: _discountType,
                                decoration: InputDecoration(
                                  labelText:
                                      '${localizations.selectDiscountType} *',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.local_offer),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'invoice',
                                    child: Text(localizations.invoiceDiscount),
                                  ),
                                  DropdownMenuItem(
                                    value: 'book',
                                    child: Text(localizations.bookDiscount),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _discountType = value!;
                                    // Clear book selection when switching types
                                    if (_discountType == 'invoice') {
                                      _selectedBook = null;
                                    }
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return localizations
                                        .pleaseSelectDiscountType;
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (widget.discount == null && widget.bookDiscount == null)
                      const SizedBox(height: 16),

                    // Book Selection (only for book discounts)
                    if (_discountType == 'book')
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.book, color: Colors.green),
                                  const SizedBox(width: 12),
                                  Text(
                                    localizations.bookSelection,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Selected Book Display
                              if (_selectedBook != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.green.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      if (_selectedBook!.thumbnail != null)
                                        Container(
                                          width: 50,
                                          height: 60,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: Image.network(
                                              _selectedBook!.thumbnail!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => const Icon(
                                                    Icons.book,
                                                    size: 30,
                                                  ),
                                            ),
                                          ),
                                        )
                                      else
                                        const Icon(Icons.book, size: 30),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedBook!.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            if (_selectedBook!.price != null)
                                              Text(
                                                '\$${_selectedBook!.price!.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          setState(() {
                                            _selectedBook = null;
                                          });
                                        },
                                        icon: const Icon(Icons.close),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 16),

                              // Select Book Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _selectBook,
                                  icon: const Icon(Icons.search),
                                  label: Text(
                                    _selectedBook == null
                                        ? localizations.selectBook
                                        : localizations.changeBook,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_discountType == 'book') const SizedBox(height: 16),

                    // Discount Value Fields (conditional based on type)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.monetization_on,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  localizations.discountValue,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            if (_discountType == 'invoice') ...[
                              // Percentage Field for Invoice Discounts
                              TextFormField(
                                controller: _percentageController,
                                decoration: InputDecoration(
                                  labelText:
                                      '${localizations.discountPercentage} *',
                                  border: const OutlineInputBorder(),
                                  hintText: localizations.enterPercentage,
                                  prefixIcon: const Icon(Icons.percent),
                                  suffixText: '%',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return localizations.percentageRequired;
                                  }
                                  final percentage = double.tryParse(value);
                                  if (percentage == null) {
                                    return localizations.pleaseEnterValidNumber;
                                  }
                                  if (percentage <= 0 || percentage > 100) {
                                    return localizations.percentageRange;
                                  }
                                  return null;
                                },
                              ),
                            ] else if (_discountType == 'book') ...[
                              // Fixed Price Field for Book Discounts
                              TextFormField(
                                controller: _discountedPriceController,
                                decoration: InputDecoration(
                                  labelText:
                                      '${localizations.priceAfterDiscount} *',
                                  border: const OutlineInputBorder(),
                                  hintText: localizations.enterFinalPrice,
                                  prefixIcon: const Icon(Icons.attach_money),
                                  suffix: _selectedBook?.price != null
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                            right: 12.0,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                '${localizations.original}: \$${_selectedBook!.price!.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  decoration: TextDecoration
                                                      .lineThrough,
                                                  color: Colors.grey,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : null,
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return localizations
                                        .discountedPriceRequired;
                                  }
                                  final price = double.tryParse(value);
                                  if (price == null) {
                                    return localizations.pleaseEnterValidNumber;
                                  }
                                  if (price <= 0) {
                                    return localizations
                                        .priceMustBeGreaterThanZero;
                                  }
                                  if (_selectedBook?.price != null &&
                                      price >= _selectedBook!.price!) {
                                    return localizations
                                        .discountedPriceMustBeLess;
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Max Uses Field
                            TextFormField(
                              controller: _maxUsesController,
                              decoration: InputDecoration(
                                labelText:
                                    '${localizations.maxUsesPerCustomer} *',
                                border: const OutlineInputBorder(),
                                hintText: localizations.enterMaxUses,
                                prefixIcon: const Icon(Icons.person),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return localizations.maxUsesRequired;
                                }
                                final maxUses = int.tryParse(value);
                                if (maxUses == null || maxUses <= 0) {
                                  return localizations.validPositiveNumber;
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Validity Period and Status
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.schedule, color: Colors.blue),
                                const SizedBox(width: 12),
                                Text(
                                  localizations.validityAndStatus,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Start Date Field
                            InkWell(
                              onTap: _selectStartDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '${localizations.startDate} *',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // End Date Field
                            InkWell(
                              onTap: _selectEndDate,
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: '${localizations.endDate} *',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.calendar_today),
                                ),
                                child: Text(
                                  '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Active Status Switch
                            SwitchListTile(
                              title: Text(localizations.active),
                              subtitle: Text(localizations.enableThisDiscount),
                              value: _isActive,
                              onChanged: (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                            ),

                            // Status indicator
                            if (!_isActive)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.orange[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        localizations.discountCreatedInactive,
                                        style: TextStyle(
                                          color: Colors.orange[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Info about expiration
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      localizations.discountValidFromTo(
                                        '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                                        '${_endDate.day}/${_endDate.month}/${_endDate.year}',
                                      ),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveDiscount,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                widget.discount == null &&
                                        widget.bookDiscount == null
                                    ? (_isActive
                                          ? localizations.createDiscount
                                          : localizations
                                                .createInactiveDiscount)
                                    : localizations.editDiscount,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _deleteDiscount() async {
    final localizations = AppLocalizations.of(context);
    final discountCode =
        widget.discount?.code ?? widget.bookDiscount?.code ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteDiscount),
        content: Text(localizations.deleteDiscountConfirmation(discountCode)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (!mounted) return;
        final authProvider = context.read<AuthProvider>();

        if (widget.discount != null) {
          // Delete invoice discount
          final provider = context.read<DiscountsProvider>();
          if (authProvider.token != null) {
            provider.setToken(authProvider.token);
          }
          await provider.deleteDiscount(int.parse(widget.discount!.id));
        } else if (widget.bookDiscount != null) {
          // Delete book discount
          final apiService = ManagerApiService(
            baseUrl: ApiConfig.getAndroidEmulatorUrl(),
            headers: {},
            getAuthToken: () => authProvider.token ?? '',
          );
          if (authProvider.token != null) {
            apiService.setToken(authProvider.token);
          }
          await apiService.deleteBookDiscount(
            int.parse(widget.bookDiscount!.id),
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Discount deleted successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
