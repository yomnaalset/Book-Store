import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/discounts_provider.dart';
import '../../../models/discount.dart';
import '../../../models/book_discount.dart';
import '../../../services/manager_api_service.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../book_selection/book_selection_screen.dart';
import '../../../../../../core/services/api_config.dart';

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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Code Already Exists'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'A discount code with this name already exists. Choose one of these alternatives:',
            ),
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
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveDiscount() async {
    if (!_formKey.currentState!.validate()) return;

    // Additional validation for book discounts
    if (_discountType == 'book' && _selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a book for the discount'),
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
        String errorMessage = 'Error: ${e.toString()}';

        // Parse error message for better user feedback
        if (e.toString().contains(
          'Discount Code with this code already exists',
        )) {
          final alternatives = _generateAlternativeCodes(_codeController.text);
          errorMessage =
              'A discount code with this name already exists. Try: ${alternatives.join(', ')}';
        } else if (e.toString().contains('validation errors')) {
          errorMessage = 'Please check your input and try again.';
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount created successfully')),
        );
      }
    } else {
      await provider.updateDiscount(discountData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Discount updated successfully')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book discount created successfully')),
        );
      }
    } else {
      await apiService.updateBookDiscount(bookDiscountData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Book discount updated successfully')),
        );
      }
    }

    if (mounted) {
      Navigator.pop(context, bookDiscountData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.discount != null || widget.bookDiscount != null
              ? 'Edit Discount'
              : 'Create Discount',
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
                            const Row(
                              children: [
                                Icon(Icons.local_offer, color: Colors.orange),
                                SizedBox(width: 12),
                                Text(
                                  'Discount Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Code Field
                            TextFormField(
                              controller: _codeController,
                              decoration: const InputDecoration(
                                labelText: 'Discount Code *',
                                border: OutlineInputBorder(),
                                hintText: 'Enter discount code (e.g., SAVE20)',
                                prefixIcon: Icon(Icons.code),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Discount code is required';
                                }
                                if (value.trim().length < 3) {
                                  return 'Discount code must be at least 3 characters';
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
                              const Row(
                                children: [
                                  Icon(Icons.category, color: Colors.purple),
                                  SizedBox(width: 12),
                                  Text(
                                    'Discount Type',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              DropdownButtonFormField<String>(
                                initialValue: _discountType,
                                decoration: const InputDecoration(
                                  labelText: 'Select Discount Type *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.local_offer),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'invoice',
                                    child: Text('Invoice Discount'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'book',
                                    child: Text('Book Discount'),
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
                                    return 'Please select a discount type';
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
                              const Row(
                                children: [
                                  Icon(Icons.book, color: Colors.green),
                                  SizedBox(width: 12),
                                  Text(
                                    'Book Selection',
                                    style: TextStyle(
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
                                        ? 'Select Book'
                                        : 'Change Book',
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
                            const Row(
                              children: [
                                Icon(
                                  Icons.monetization_on,
                                  color: Colors.amber,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Discount Value',
                                  style: TextStyle(
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
                                decoration: const InputDecoration(
                                  labelText: 'Discount Percentage *',
                                  border: OutlineInputBorder(),
                                  hintText:
                                      'Enter percentage (e.g., 20 for 20%)',
                                  prefixIcon: Icon(Icons.percent),
                                  suffixText: '%',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Percentage is required';
                                  }
                                  final percentage = double.tryParse(value);
                                  if (percentage == null) {
                                    return 'Please enter a valid number';
                                  }
                                  if (percentage <= 0 || percentage > 100) {
                                    return 'Percentage must be between 1 and 100';
                                  }
                                  return null;
                                },
                              ),
                            ] else if (_discountType == 'book') ...[
                              // Fixed Price Field for Book Discounts
                              TextFormField(
                                controller: _discountedPriceController,
                                decoration: InputDecoration(
                                  labelText: 'Price after Discount *',
                                  border: const OutlineInputBorder(),
                                  hintText: 'Enter final price (e.g., 15.99)',
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
                                                'Original: \$${_selectedBook!.price!.toStringAsFixed(2)}',
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
                                    return 'Discounted price is required';
                                  }
                                  final price = double.tryParse(value);
                                  if (price == null) {
                                    return 'Please enter a valid number';
                                  }
                                  if (price <= 0) {
                                    return 'Price must be greater than 0';
                                  }
                                  if (_selectedBook?.price != null &&
                                      price >= _selectedBook!.price!) {
                                    return 'Discounted price must be less than original price';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Max Uses Field
                            TextFormField(
                              controller: _maxUsesController,
                              decoration: const InputDecoration(
                                labelText: 'Max Uses Per Customer *',
                                border: OutlineInputBorder(),
                                hintText: 'Enter maximum uses per customer',
                                prefixIcon: Icon(Icons.person),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Max uses is required';
                                }
                                final maxUses = int.tryParse(value);
                                if (maxUses == null || maxUses <= 0) {
                                  return 'Please enter a valid positive number';
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
                            const Row(
                              children: [
                                Icon(Icons.schedule, color: Colors.blue),
                                SizedBox(width: 12),
                                Text(
                                  'Validity & Status',
                                  style: TextStyle(
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
                                decoration: const InputDecoration(
                                  labelText: 'Start Date *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
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
                                decoration: const InputDecoration(
                                  labelText: 'End Date *',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.calendar_today),
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
                              title: const Text('Active'),
                              subtitle: const Text('Enable this discount'),
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
                                        'This discount will be created as inactive and can be activated later.',
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
                                      'This discount will be valid from ${_startDate.day}/${_startDate.month}/${_startDate.year} to ${_endDate.day}/${_endDate.month}/${_endDate.year}',
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
                                          ? 'Create Discount'
                                          : 'Create Inactive Discount')
                                    : 'Edit Discount',
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
    final discountCode =
        widget.discount?.code ?? widget.bookDiscount?.code ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Discount'),
        content: Text(
          'Are you sure you want to delete "$discountCode"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
