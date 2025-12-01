import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/discounts_provider.dart';
import '../../../models/discount.dart';
import '../../../models/book_discount.dart';
import '../../../widgets/library_manager/admin_search_bar.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../../../routes/app_routes.dart';
import '../../../../auth/providers/auth_provider.dart';

class DiscountsListScreen extends StatefulWidget {
  const DiscountsListScreen({super.key});

  @override
  State<DiscountsListScreen> createState() => _DiscountsListScreenState();
}

class _DiscountsListScreenState extends State<DiscountsListScreen> {
  String? _searchQuery;
  String? _selectedStatus = 'all'; // Default to 'all' to show all discounts
  String _discountType = 'invoice'; // 'invoice' or 'book'
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _loadDiscounts();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDiscounts() async {
    final provider = context.read<DiscountsProvider>();
    final authProvider = context.read<AuthProvider>();

    // Only set token if it's different from what the provider already has
    if (authProvider.token != null && !provider.hasValidToken) {
      provider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Discounts list - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
      );
    } else if (authProvider.token == null) {
      debugPrint(
        'DEBUG: Discounts list - No token available from AuthProvider',
      );
      return; // Don't make API call without token
    }

    // Determine the filtering parameters based on selected status
    bool? isActive;
    if (_selectedStatus == 'active') {
      isActive = true;
    } else if (_selectedStatus == 'inactive') {
      isActive = false;
    } else {
      // For 'all' or any other status, get all discounts (isActive = null)
      isActive = null;
    }

    if (_discountType == 'invoice') {
      debugPrint('DEBUG: Loading invoice discounts');
      await provider.getDiscounts(
        search: _searchQuery?.isEmpty ?? true ? null : _searchQuery,
        isActive: isActive,
      );
    } else {
      debugPrint('DEBUG: Loading book discounts');
      await provider.getBookDiscounts(
        search: _searchQuery?.isEmpty ?? true ? null : _searchQuery,
        isActive: isActive,
      );
    }
  }

  void _onSearch(String query) {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    setState(() {
      _searchQuery = query.isEmpty ? null : query;
    });

    // Set new timer for debounced search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadDiscounts();
    });
  }

  void _onFilterChanged(String? status) {
    debugPrint('DEBUG: Filter changed to: $status');
    setState(() {
      _selectedStatus = status;
    });
    _loadDiscounts();
  }

  void _onDiscountTypeChanged(String? type) {
    debugPrint('DEBUG: Discount type changed to: $type');
    setState(() {
      _discountType = type ?? 'invoice';
    });
    debugPrint('DEBUG: Current discount type: $_discountType');
    _loadDiscounts();
  }

  void _navigateToDiscountForm([dynamic discount]) async {
    if (discount != null) {
      // For edit mode, fetch fresh data from server first
      try {
        final provider = context.read<DiscountsProvider>();
        final authProvider = context.read<AuthProvider>();

        // Ensure provider has the current token
        if (authProvider.token != null && !provider.hasValidToken) {
          provider.setToken(authProvider.token);
        }

        if (authProvider.token != null) {
          debugPrint(
            'DEBUG: Edit Discount - Fetching fresh data for discount ID: ${discount.id}',
          );

          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );

          // Fetch fresh discount data based on discount type
          dynamic freshDiscount;
          if (_discountType == 'invoice') {
            freshDiscount = await provider.getDiscountById(
              int.parse(discount.id),
            );
          } else {
            freshDiscount = await provider.getBookDiscountById(
              int.parse(discount.id),
            );
          }
          debugPrint('DEBUG: Edit Discount - Fresh data loaded successfully');

          // Close loading dialog
          if (mounted) {
            Navigator.of(context).pop();
          }

          // Navigate to edit form with fresh data
          if (mounted) {
            Navigator.pushNamed(
              context,
              AppRoutes.managerDiscountForm,
              arguments: _discountType == 'invoice'
                  ? {'discount': freshDiscount}
                  : {'bookDiscount': freshDiscount},
            ).then((_) => _loadDiscounts());
          }
        } else {
          // No token available, navigate with existing data
          Navigator.pushNamed(
            context,
            AppRoutes.managerDiscountForm,
            arguments: _discountType == 'invoice'
                ? {'discount': discount}
                : {'bookDiscount': discount},
          ).then((_) => _loadDiscounts());
        }
      } catch (e) {
        // Close loading dialog if it's open
        if (mounted) {
          Navigator.of(context).pop();
        }

        // Show error and navigate with existing data as fallback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load fresh data: $e'),
              backgroundColor: Colors.orange,
            ),
          );

          Navigator.pushNamed(
            context,
            AppRoutes.managerDiscountForm,
            arguments: _discountType == 'invoice'
                ? {'discount': discount}
                : {'bookDiscount': discount},
          ).then((_) => _loadDiscounts());
        }
      }
    } else {
      // For create mode, navigate directly
      debugPrint('DEBUG: Navigating to create new discount');
      Navigator.pushNamed(context, AppRoutes.managerDiscountForm, arguments: {})
          .then((_) {
            debugPrint('DEBUG: Returned from discount form');
            _loadDiscounts();
          })
          .catchError((error) {
            debugPrint('DEBUG: Error navigating to discount form: $error');
          });
    }
  }

  void _navigateToDiscountDetails(dynamic discount) {
    Navigator.pushNamed(
      context,
      AppRoutes.managerDiscountDetails,
      arguments: {'discount': discount},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discounts'),
        actions: [
          IconButton(
            onPressed: () => _loadDiscounts(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AdminSearchBar(
              hintText: 'Search discounts...',
              onChanged: _onSearch,
              onSubmitted: _onSearch,
            ),
          ),

          // Discount Type Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              initialValue: _discountType,
              decoration: const InputDecoration(
                labelText: 'Discount Type',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'invoice',
                  child: Text('Invoice Discounts'),
                ),
                DropdownMenuItem(value: 'book', child: Text('Book Discounts')),
              ],
              onChanged: _onDiscountTypeChanged,
            ),
          ),

          const SizedBox(height: 16),

          // Status Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
              ],
              onChanged: _onFilterChanged,
            ),
          ),

          const SizedBox(height: 16),

          // Discounts List
          Expanded(
            child: Consumer<DiscountsProvider>(
              builder: (context, provider, child) {
                // Get the appropriate discount list based on type
                final discounts = _discountType == 'invoice'
                    ? provider.discounts
                    : provider.bookDiscounts;

                if (provider.isLoading && discounts.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && discounts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDiscounts,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (discounts.isEmpty) {
                  return const EmptyState(
                    title: 'No Discounts',
                    message: 'No discounts found',
                    icon: Icons.local_offer,
                  );
                }

                // Filter discounts based on selected status
                final filteredDiscounts = _filterDiscountsByStatus(discounts);

                if (filteredDiscounts.isEmpty) {
                  return const EmptyState(
                    title: 'No Discounts',
                    message: 'No discounts found for the selected filter',
                    icon: Icons.local_offer,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: filteredDiscounts.length,
                  itemBuilder: (context, index) {
                    final discount = filteredDiscounts[index];
                    return _buildDiscountCard(discount);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          debugPrint('DEBUG: FAB pressed - attempting to navigate');
          _navigateToDiscountForm();
        },
        tooltip: 'Create Discount',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDiscountCard(dynamic discount) {
    final isExpired =
        discount.endDate != null && discount.endDate!.isBefore(DateTime.now());
    final isActive = discount.isActive && !isExpired;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          child: Icon(
            Icons.local_offer,
            color: isActive ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          discount.code,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(discount.code, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),

            // Show book name for book discounts
            if (_discountType == 'book' && discount.bookName != null) ...[
              Text(
                'Book: ${discount.bookName}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
            ],

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getDisplayValue(discount),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ...[
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Start: ${_formatDate(discount.createdAt)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (discount.endDate != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 16,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'End: ${_formatDate(discount.endDate!)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (_getUsageLimit(discount) != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.shopping_cart, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Max Uses: ${_getUsageLimit(discount)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
            ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  _discountType == 'invoice'
                      ? Text(
                          'Percentage: ${discount.value}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )
                      : _buildBookDiscountPrice(discount),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Show Details Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToDiscountDetails(discount),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('Show details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _navigateToDiscountForm(discount);
                break;
              case 'delete':
                _deleteDiscount(discount);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteDiscount(dynamic discount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Discount'),
        content: Text(
          'Are you sure you want to delete "${discount.code}"? This action cannot be undone.',
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
      try {
        if (!mounted) return;
        final provider = context.read<DiscountsProvider>();

        if (_discountType == 'invoice') {
          await provider.deleteDiscount(int.parse(discount.id));
        } else {
          await provider.deleteBookDiscount(int.parse(discount.id));
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Discount deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int? _getUsageLimit(dynamic discount) {
    // Handle both Discount and BookDiscount objects
    if (discount is Discount) {
      return discount.usageLimit;
    } else if (discount is BookDiscount) {
      return discount.usageLimitPerCustomer;
    }
    return null;
  }

  String _getDisplayValue(dynamic discount) {
    if (discount is Discount) {
      return '${discount.value}% OFF';
    } else if (discount is BookDiscount) {
      return '\$${discount.discountedPrice}';
    }
    return 'N/A';
  }

  Widget _buildBookDiscountPrice(dynamic discount) {
    if (discount is BookDiscount && discount.bookPrice != null) {
      return Row(
        children: [
          Text(
            'Original: \$${discount.bookPrice!.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Now: \$${discount.discountedPrice.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } else if (discount is BookDiscount) {
      return Text(
        'Price: \$${discount.discountedPrice.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    return const Text(
      'Price: N/A',
      style: TextStyle(fontSize: 12, color: Colors.grey),
    );
  }

  List<dynamic> _filterDiscountsByStatus(List<dynamic> discounts) {
    debugPrint(
      'DEBUG: Filtering ${discounts.length} discounts with status: $_selectedStatus',
    );

    if (_selectedStatus == null || _selectedStatus == 'all') {
      debugPrint('DEBUG: Showing all discounts');
      return discounts;
    }

    List<dynamic> filteredDiscounts;
    if (_selectedStatus == 'active') {
      filteredDiscounts = discounts
          .where((discount) => discount.isActive)
          .toList();
      debugPrint(
        'DEBUG: Filtered to ${filteredDiscounts.length} active discounts',
      );
    } else if (_selectedStatus == 'inactive') {
      filteredDiscounts = discounts
          .where((discount) => !discount.isActive)
          .toList();
      debugPrint(
        'DEBUG: Filtered to ${filteredDiscounts.length} inactive discounts',
      );
    } else {
      filteredDiscounts = discounts;
    }

    return filteredDiscounts;
  }
}
