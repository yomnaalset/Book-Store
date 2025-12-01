import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../../core/services/api_service.dart';
import '../models/borrow_request.dart';
import '../services/borrow_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../borrow/providers/return_request_provider.dart';

class BorrowStatusDetailScreen extends StatefulWidget {
  final int borrowRequestId;

  const BorrowStatusDetailScreen({super.key, required this.borrowRequestId});

  @override
  State<BorrowStatusDetailScreen> createState() =>
      _BorrowStatusDetailScreenState();
}

class _BorrowStatusDetailScreenState extends State<BorrowStatusDetailScreen> {
  BorrowRequest? _borrowRequest;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBorrowRequest();
  }

  Future<void> _loadBorrowRequest() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Authentication required. Please log in again.';
            _isLoading = false;
          });
        }
        return;
      }

      final borrowService = BorrowService();
      borrowService.setToken(token);

      debugPrint(
        'BorrowStatusDetailScreen: Fetching borrow request ${widget.borrowRequestId} from server...',
      );

      // Use getBorrowRequest to get a single borrow request by ID
      final borrowRequest = await borrowService.getBorrowRequest(
        widget.borrowRequestId.toString(),
      );

      if (!mounted) return;

      if (borrowRequest != null) {
        setState(() {
          _borrowRequest = borrowRequest;
          _isLoading = false;
        });
        debugPrint(
          'BorrowStatusDetailScreen: Successfully loaded borrow request. Status: ${borrowRequest.status}',
        );
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Borrow request not found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('BorrowStatusDetailScreen: Error loading borrow request: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load borrow request: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.info;
      case 'approved':
        return AppColors.success;
      case 'borrowed':
      case 'active':
        return AppColors.primary;
      case 'returned':
        return AppColors.success;
      case 'overdue':
        return AppColors.error;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: _getStatusColor(status)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: AppDimensions.fontSizeXS,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(status),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: AppDimensions.fontSizeS,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXS),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: AppDimensions.fontSizeM,
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
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if delivery is currently active (started but not finished)
  /// Button should appear ONLY when status is "out_for_delivery" (delivery in progress)
  /// Button should disappear when status is "delivered", "active", or any other status (delivery completed)
  bool _isDeliveryActive() {
    if (_borrowRequest == null) return false;
    if (_borrowRequest!.deliveryPerson == null) return false;

    // Normalize the status: lowercase, trim, replace spaces and hyphens with underscores
    final normalizedStatus = _borrowRequest!.status
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^\w_]'), ''); // Remove any special characters

    // Button should ONLY be visible when status is exactly "out_for_delivery"
    // Hide when status is "delivered", "active", or any other status
    return normalizedStatus == 'out_for_delivery';
  }

  /// Open delivery manager location in Google Maps
  Future<void> _openDeliveryManagerLocation() async {
    if (!mounted) return;

    if (_borrowRequest == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request information not available'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    if (_borrowRequest!.deliveryPerson == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery manager information not available'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // Verify that status is still out_for_delivery
    final status = _borrowRequest!.status
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
    if (status != 'out_for_delivery') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location tracking is only available during active delivery.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    try {
      // Get auth token
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please log in again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Fetch delivery manager's location from backend using borrow-specific endpoint
      // This endpoint only returns location when status is OUT_FOR_DELIVERY
      // Path: /api/borrow/borrowings/<id>/delivery-location/
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/borrow/borrowings/${_borrowRequest!.id}/delivery-location/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle the response format from GetDeliveryLocationView
        if (data['success'] == true && data['data'] != null) {
          final locationData = data['data']['location'];

          if (locationData != null &&
              locationData['latitude'] != null &&
              locationData['longitude'] != null) {
            final latitude = locationData['latitude'] as double;
            final longitude = locationData['longitude'] as double;

            // Open Google Maps with the location
            await _launchGoogleMaps(latitude, longitude);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Delivery manager location is not available at the moment.',
                  ),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          }
        } else {
          final errorMessage = data['message'] ?? 'Failed to get location';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['message'] ??
            errorData['error'] ??
            'Failed to get location';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Launch Google Maps with the given coordinates
  Future<void> _launchGoogleMaps(double latitude, double longitude) async {
    try {
      // Try multiple URL schemes in order of preference
      final urls = [
        // Google Maps app (Android) - navigation mode
        Uri.parse('google.navigation:q=$latitude,$longitude'),
        // Google Maps app (Android/iOS) - search mode
        Uri.parse('comgooglemaps://?q=$latitude,$longitude'),
        // Geo scheme (Android) - opens default maps app
        Uri.parse('geo:$latitude,$longitude'),
        // Google Maps web URL (always works as fallback)
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        ),
      ];

      bool launched = false;
      for (final url in urls) {
        try {
          // Try to launch directly - canLaunchUrl can be unreliable
          await launchUrl(url, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        } catch (e) {
          // Try next URL if this one fails
          debugPrint('Failed to launch URL $url: $e');
          continue;
        }
      }

      if (!launched) {
        // Final fallback: try the web URL which should always work
        try {
          final webUrl = Uri.parse(
            'https://www.google.com/maps?q=$latitude,$longitude',
          );
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not open maps. Please check your internet connection.',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleReturn() async {
    if (_borrowRequest == null) return;
    if (!mounted) return;

    // Capture providers before async operations
    final returnProvider = Provider.of<ReturnRequestProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token != null) {
      returnProvider.setToken(authProvider.token!);
    }

    try {
      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Creating return request...'),
            backgroundColor: AppColors.primary,
          ),
        );
      } catch (_) {
        // Widget disposed, ignore
      }

      final success = await returnProvider.createReturnRequest(
        _borrowRequest!.id,
      );

      if (!mounted) return;

      if (success) {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Return request created successfully'),
                backgroundColor: AppColors.success,
              ),
            );
          } catch (_) {
            // Widget disposed, ignore
          }
        }
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  returnProvider.errorMessage ??
                      'Failed to create return request',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          } catch (_) {
            // Widget disposed, ignore
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      } catch (_) {
        // Widget disposed, ignore
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Borrow Status'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: const Center(child: LoadingIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Borrow Status'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ErrorMessage(message: _errorMessage!),
              const SizedBox(height: AppDimensions.spacingM),
              ElevatedButton(
                onPressed: _loadBorrowRequest,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_borrowRequest == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Borrow Status'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: const Center(child: Text('Borrow request not found')),
      );
    }

    final request = _borrowRequest!;
    final daysRemaining =
        request.dueDate?.difference(DateTime.now()).inDays ?? 0;
    final isOverdue = daysRemaining < 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrow Status'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBorrowRequest,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          children: [
            // Main Order Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: _getStatusColor(request.status).withValues(alpha: 0.2),
                  width: 1.5,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.white,
                      _getStatusColor(request.status).withValues(alpha: 0.03),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Request ID and Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.paddingM,
                              vertical: AppDimensions.paddingS,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.receipt_long,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppDimensions.spacingXS),
                                Text(
                                  'Request #${request.id}',
                                  style: const TextStyle(
                                    fontSize: AppDimensions.fontSizeS,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatusChip(request.status),
                        ],
                      ),

                      const SizedBox(height: AppDimensions.spacingL),

                      // Book Cover and Info
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Book Cover
                          Container(
                            width: 90,
                            height: 135,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: request.book?.coverImageUrl != null
                                  ? Image.network(
                                      request.book!.coverImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              color: AppColors.surface,
                                              child: const Icon(
                                                Icons.book,
                                                size: 40,
                                                color: AppColors.textSecondary,
                                              ),
                                            );
                                          },
                                    )
                                  : Container(
                                      color: AppColors.surface,
                                      child: const Icon(
                                        Icons.book,
                                        size: 40,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingM),
                          // Book Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.book?.title ?? 'Unknown Book',
                                  style: const TextStyle(
                                    fontSize: AppDimensions.fontSizeXL,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (request.book?.author != null) ...[
                                  const SizedBox(
                                    height: AppDimensions.spacingXS,
                                  ),
                                  Text(
                                    request.book!.author!,
                                    style: const TextStyle(
                                      fontSize: AppDimensions.fontSizeM,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppDimensions.spacingL),
                      const Divider(height: 1),

                      // Order Status Section
                      const SizedBox(height: AppDimensions.spacingM),
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: _getStatusColor(request.status),
                          ),
                          const SizedBox(width: AppDimensions.spacingS),
                          const Text(
                            'Order Status',
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeL,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                      Container(
                        padding: const EdgeInsets.all(AppDimensions.paddingM),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            request.status,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(
                              request.status,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          request.statusDisplay ??
                              request.status.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontSize: AppDimensions.fontSizeM,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(request.status),
                          ),
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spacingL),
                      const Divider(height: 1),

                      // Order Information
                      const SizedBox(height: AppDimensions.spacingM),
                      const Text(
                        'Order Information',
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingM),
                      _buildInfoItem(
                        Icons.calendar_today,
                        'Request Date',
                        _formatDate(request.requestDate),
                      ),
                      if (request.deliveryDate != null)
                        _buildInfoItem(
                          Icons.local_shipping,
                          'Delivery Date',
                          _formatDate(request.deliveryDate!),
                        ),
                      if (request.dueDate != null)
                        _buildInfoItem(
                          Icons.event,
                          'Due Date',
                          _formatDate(request.dueDate!),
                        ),
                      if (request.finalReturnDate != null)
                        _buildInfoItem(
                          Icons.check_circle,
                          'Return Date',
                          _formatDate(request.finalReturnDate!),
                        ),
                      _buildInfoItem(
                        Icons.access_time,
                        'Duration',
                        '${request.durationDays} days',
                      ),

                      // Delivery Manager Section
                      if (request.deliveryPerson != null) ...[
                        const SizedBox(height: AppDimensions.spacingL),
                        const Divider(height: 1),
                        const SizedBox(height: AppDimensions.spacingM),
                        const Row(
                          children: [
                            Icon(
                              Icons.local_shipping,
                              size: 20,
                              color: AppColors.info,
                            ),
                            SizedBox(width: AppDimensions.spacingS),
                            Text(
                              'Delivery Manager',
                              style: TextStyle(
                                fontSize: AppDimensions.fontSizeL,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingS),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: AppColors.info,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacingM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request.deliveryPerson!.fullName,
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeM,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.spacingXS,
                                    ),
                                    Text(
                                      request.deliveryPerson!.email,
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeS,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // View Delivery Manager Location Button
                        // Only show when status is "out_for_delivery"
                        if (_isDeliveryActive()) ...[
                          const SizedBox(height: AppDimensions.spacingM),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openDeliveryManagerLocation,
                              icon: const Icon(Icons.location_on, size: 20),
                              label: const Text(
                                'View Delivery Manager Current Location',
                                style: TextStyle(fontSize: 16),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppDimensions.paddingM,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],

                      // Overdue Warning
                      if (isOverdue &&
                          request.status.toLowerCase() == 'active') ...[
                        const SizedBox(height: AppDimensions.spacingL),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning, color: AppColors.error),
                              const SizedBox(width: AppDimensions.spacingS),
                              Expanded(
                                child: Text(
                                  'Overdue by ${daysRemaining.abs()} days',
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                    fontSize: AppDimensions.fontSizeM,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Return Button
                      if (request.status.toLowerCase() == 'active') ...[
                        const SizedBox(height: AppDimensions.spacingL),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleReturn,
                            icon: const Icon(Icons.assignment_return),
                            label: const Text('Return Book'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppDimensions.paddingM,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
