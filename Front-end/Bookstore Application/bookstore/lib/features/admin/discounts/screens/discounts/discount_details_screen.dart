import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/discount.dart';
import '../../../models/book_discount.dart';
import '../../../../../routes/app_routes.dart';
import '../../providers/discounts_provider.dart';
import '../../../../auth/providers/auth_provider.dart';

class DiscountDetailsScreen extends StatefulWidget {
  final dynamic discount; // Can be Discount or BookDiscount

  const DiscountDetailsScreen({super.key, required this.discount});

  @override
  State<DiscountDetailsScreen> createState() => _DiscountDetailsScreenState();
}

class _DiscountDetailsScreenState extends State<DiscountDetailsScreen> {
  dynamic _currentDiscount; // Can be Discount or BookDiscount
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentDiscount = widget.discount;
    _loadDiscountDetails();
  }

  Future<void> _loadDiscountDetails() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = context.read<DiscountsProvider>();
      final authProvider = context.read<AuthProvider>();

      // Ensure provider has the current token
      if (authProvider.token != null && !provider.hasValidToken) {
        provider.setToken(authProvider.token);
        debugPrint(
          'DEBUG: Discount Details - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
        );
      } else if (authProvider.token == null) {
        debugPrint(
          'DEBUG: Discount Details - No token available from AuthProvider',
        );
        setState(() {
          _isLoading = false;
          _error = 'No authentication token available';
        });
        return;
      }

      // Fetch fresh discount data from server
      dynamic freshDiscount;
      if (widget.discount is Discount) {
        freshDiscount = await provider.getDiscountById(
          int.parse(widget.discount.id),
        );
      } else if (widget.discount is BookDiscount) {
        freshDiscount = await provider.getBookDiscountById(
          int.parse(widget.discount.id),
        );
      } else {
        throw Exception('Unknown discount type');
      }

      if (mounted) {
        setState(() {
          _currentDiscount = freshDiscount;
          _isLoading = false;
        });
        debugPrint('DEBUG: Discount Details - Fresh data loaded successfully');
      }
    } catch (e) {
      debugPrint('DEBUG: Discount Details - Error loading fresh data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator while fetching data
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Discount Details'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Show error state if there was an error
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Discount Details'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading discount details',
                style: TextStyle(fontSize: 18, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDiscountDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Use current discount data (either from props or fresh from API)
    final discount = _currentDiscount ?? widget.discount;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Check if discount is expired by comparing dates only (ignore time)
    bool isExpired = false;
    if (discount.endDate != null) {
      final endDateOnly = DateTime(
        discount.endDate!.year,
        discount.endDate!.month,
        discount.endDate!.day,
      );
      isExpired = endDateOnly.isBefore(today);
    }

    // A discount is active if it's marked as active in the database AND not expired
    final isActive = discount.isActive && !isExpired;

    // Debug information
    debugPrint('DEBUG: Discount Details - Code: ${discount.code}');
    debugPrint('DEBUG: Discount Details - isActive: ${discount.isActive}');
    debugPrint('DEBUG: Discount Details - endDate: ${discount.endDate}');
    debugPrint('DEBUG: Discount Details - today: $today');
    debugPrint('DEBUG: Discount Details - isExpired: $isExpired');
    debugPrint('DEBUG: Discount Details - calculated isActive: $isActive');

    if (discount.endDate != null) {
      final endDateOnly = DateTime(
        discount.endDate!.year,
        discount.endDate!.month,
        discount.endDate!.day,
      );
      debugPrint('DEBUG: Discount Details - endDateOnly: $endDateOnly');
      debugPrint(
        'DEBUG: Discount Details - endDateOnly comparison: ${endDateOnly.isBefore(today)}',
      );
      debugPrint(
        'DEBUG: Discount Details - endDate year: ${discount.endDate!.year}, month: ${discount.endDate!.month}, day: ${discount.endDate!.day}',
      );
      debugPrint(
        'DEBUG: Discount Details - today year: ${today.year}, month: ${today.month}, day: ${today.day}',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discount Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadDiscountDetails,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
          IconButton(
            onPressed: () => _navigateToEdit(context),
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Discount',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Discount Code Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: isActive
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.local_offer,
                            color: isActive ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                discount.code,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Discount Code',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _getDiscountValue(discount),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        StatusChip(status: isActive ? 'active' : 'inactive'),
                        const Spacer(),
                        Switch(
                          value:
                              isActive, // Use the calculated isActive instead of discount.isActive
                          onChanged: null, // Read-only in details view
                          activeThumbColor: Colors.green,
                          inactiveThumbColor: Colors.grey,
                          trackColor: WidgetStateProperty.resolveWith<Color>((
                            states,
                          ) {
                            if (states.contains(WidgetState.selected)) {
                              return Colors.green.withValues(alpha: 0.3);
                            }
                            return Colors.grey.withValues(alpha: 0.3);
                          }),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Discount Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Discount Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Discount Code', discount.code, Icons.tag),
                    _buildInfoRow(
                      'Discount Type',
                      _getDiscountType(discount),
                      Icons.local_offer,
                    ),
                    _buildInfoRow(
                      'Discount Value',
                      _getDiscountValue(discount),
                      Icons.attach_money,
                    ),
                    if (_getUsageLimit(discount) != null)
                      _buildInfoRow(
                        'Max Uses Per Customer',
                        '${_getUsageLimit(discount)}',
                        Icons.person,
                      ),
                    _buildInfoRow(
                      'Status',
                      isActive ? 'Active' : 'Inactive',
                      Icons.toggle_on,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Validity & Status
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Validity & Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Created Date',
                      _formatDate(discount.createdAt),
                      Icons.calendar_today,
                    ),
                    if (discount.endDate != null)
                      _buildInfoRow(
                        'Expiration Date',
                        _formatDate(discount.endDate!),
                        Icons.event,
                      ),
                    if (discount.endDate != null)
                      _buildInfoRow(
                        'Days Until Expiry',
                        _getDaysUntilExpiry(discount.endDate!),
                        Icons.timer,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _navigateToEdit(context),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Discount'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to List'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Format with leading zeros for consistent display
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String _getDiscountValue(dynamic discount) {
    if (discount is Discount) {
      return '${discount.value}%';
    } else if (discount is BookDiscount) {
      return '\$${discount.discountedPrice}';
    }
    return 'N/A';
  }

  int? _getUsageLimit(dynamic discount) {
    if (discount is Discount) {
      return discount.usageLimit;
    } else if (discount is BookDiscount) {
      return discount.usageLimitPerCustomer;
    }
    return null;
  }

  String _getDiscountType(dynamic discount) {
    if (discount is Discount) {
      return 'Percentage';
    } else if (discount is BookDiscount) {
      return 'Fixed Price';
    }
    return 'Unknown';
  }

  String _getDaysUntilExpiry(DateTime expiryDate) {
    final now = DateTime.now();
    // Normalize dates to compare only date parts (ignore time)
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    final difference = expiry.difference(today).inDays;

    debugPrint('DEBUG: Period calculation - Today: $today');
    debugPrint('DEBUG: Period calculation - Expiry: $expiry');
    debugPrint('DEBUG: Period calculation - Difference: $difference days');

    if (difference < 0) {
      return 'Expired ${(-difference)} days ago';
    } else if (difference == 0) {
      return 'Expires today';
    } else {
      return '$difference days remaining';
    }
  }

  void _navigateToEdit(BuildContext context) async {
    final discount = _currentDiscount ?? widget.discount;
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final provider = context.read<DiscountsProvider>();
      final authProvider = context.read<AuthProvider>();

      // Ensure provider has the current token
      if (authProvider.token != null && !provider.hasValidToken) {
        provider.setToken(authProvider.token);
      }

      if (authProvider.token != null) {
        debugPrint(
          'DEBUG: Edit from Details - Fetching fresh data for discount ID: ${discount.id}',
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
        if (discount is Discount) {
          freshDiscount = await provider.getDiscountById(
            int.parse(discount.id),
          );
        } else if (discount is BookDiscount) {
          freshDiscount = await provider.getBookDiscountById(
            int.parse(discount.id),
          );
        } else {
          throw Exception('Unknown discount type');
        }
        debugPrint('DEBUG: Edit from Details - Fresh data loaded successfully');

        // Close loading dialog
        if (mounted) {
          navigator.pop();
        }

        // Navigate to edit form with fresh data
        if (mounted) {
          final updatedDiscount = await navigator.pushNamed(
            AppRoutes.managerDiscountForm,
            arguments: discount is Discount
                ? {'discount': freshDiscount}
                : {'bookDiscount': freshDiscount},
          );

          // If the edit form returned updated data, refresh the current discount
          if (updatedDiscount != null) {
            setState(() {
              _currentDiscount = updatedDiscount;
            });
            debugPrint(
              'DEBUG: Discount Details - Updated with data from edit form',
            );
          }
        }
      } else {
        // No token available, navigate with existing data
        final updatedDiscount = await navigator.pushNamed(
          AppRoutes.managerDiscountForm,
          arguments: discount is Discount
              ? {'discount': discount}
              : {'bookDiscount': discount},
        );

        // If the edit form returned updated data, refresh the current discount
        if (updatedDiscount != null) {
          setState(() {
            _currentDiscount = updatedDiscount;
          });
          debugPrint(
            'DEBUG: Discount Details - Updated with data from edit form (no token)',
          );
        }
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (mounted) {
        navigator.pop();
      }

      // Show error and navigate with existing data as fallback
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Failed to load fresh data: $e'),
            backgroundColor: Colors.orange,
          ),
        );

        final updatedDiscount = await navigator.pushNamed(
          AppRoutes.managerDiscountForm,
          arguments: discount is Discount
              ? {'discount': discount}
              : {'bookDiscount': discount},
        );

        // If the edit form returned updated data, refresh the current discount
        if (updatedDiscount != null) {
          setState(() {
            _currentDiscount = updatedDiscount;
          });
          debugPrint(
            'DEBUG: Discount Details - Updated with data from edit form (error fallback)',
          );
        }
      }
    }
  }
}

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    String displayText;

    switch (status.toLowerCase()) {
      case 'active':
        backgroundColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        displayText = 'Active';
        break;
      case 'inactive':
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        displayText = 'Inactive';
        break;
      default:
        backgroundColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
        displayText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 12,
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
