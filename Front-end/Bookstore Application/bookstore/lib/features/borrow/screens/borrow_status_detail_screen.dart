import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../../core/services/api_service.dart';
import '../models/borrow_request.dart';
import '../services/borrow_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../borrow/providers/return_request_provider.dart';
import '../../borrow/models/return_request.dart';
import '../services/return_request_service.dart';

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
  bool _hasReturnRequest = false; // Track if a return request exists
  bool _paymentMethodSelected =
      false; // Track if payment method has been selected

  @override
  void initState() {
    super.initState();
    _loadBorrowRequest();
    _checkReturnRequest();
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
          final localizations = AppLocalizations.of(context);
          setState(() {
            _errorMessage = localizations.authenticationRequired;
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
        // Check for return request after loading borrow request
        _checkReturnRequest();
      } else {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          setState(() {
            _errorMessage = localizations.borrowRequestNotFound;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('BorrowStatusDetailScreen: Error loading borrow request: $e');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = localizations.failedToLoadBorrowRequest(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkReturnRequest() async {
    if (_borrowRequest == null) return;
    if (!mounted) return;

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final returnProvider = Provider.of<ReturnRequestProvider>(
        context,
        listen: false,
      );

      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      // Load return requests
      await returnProvider.loadReturnRequests();

      // Check if a return request exists for this borrow request
      final returnRequests = returnProvider.returnRequests;
      ReturnRequest? matchingReturnRequest;
      try {
        matchingReturnRequest = returnRequests.firstWhere(
          (rr) => rr.borrowRequest.id == _borrowRequest!.id,
        );
      } catch (e) {
        matchingReturnRequest = null;
      }

      final hasReturnRequest = matchingReturnRequest != null;

      // Check if payment method has been selected
      final paymentMethodSelected =
          matchingReturnRequest?.paymentMethod != null &&
          matchingReturnRequest!.paymentMethod!.isNotEmpty;

      if (mounted) {
        setState(() {
          _hasReturnRequest = hasReturnRequest;
          _paymentMethodSelected = paymentMethodSelected;
        });
      }
    } catch (e) {
      debugPrint('BorrowStatusDetailScreen: Error checking return request: $e');
      // Don't show error to user, just assume no return request exists
      if (mounted) {
        setState(() {
          _hasReturnRequest = false;
          _paymentMethodSelected = false;
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
    final localizations = AppLocalizations.of(context);
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
        localizations.getBorrowStatusLabel(status).toUpperCase(),
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

  String _getFineStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'unpaid':
        return 'Unpaid';
      case 'pending_cash_payment':
        return 'Pending Cash Payment';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  Color _getFineStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return AppColors.success;
      case 'unpaid':
        return AppColors.error;
      case 'pending_cash_payment':
        return AppColors.warning;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Check if delivery location tracking is available
  /// Button should appear ONLY when DeliveryRequest.status == 'in_delivery'
  /// Button should disappear when DeliveryRequest.status == 'completed'
  /// This protects privacy and prevents unnecessary tracking
  bool _canTrackDeliveryLocation() {
    if (_borrowRequest == null) return false;

    // Use DeliveryRequest if available
    if (_borrowRequest!.deliveryRequest != null) {
      final deliveryStatus = _borrowRequest!.deliveryRequest!.status
          .toLowerCase();
      // Button only shows when delivery is actively in progress (in_delivery)
      // Hide when completed or any other status
      return deliveryStatus == 'in_delivery' &&
          _borrowRequest!.deliveryRequest!.canTrackLocation;
    }

    // Fallback to old logic for backward compatibility (if DeliveryRequest not available)
    if (_borrowRequest!.deliveryPerson == null) return false;

    // Normalize the status: lowercase, trim, replace spaces and hyphens with underscores
    final normalizedStatus = _borrowRequest!.status
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^\w_]'), ''); // Remove any special characters

    // Button should be visible when status is "out_for_delivery" (delivery)
    // OR "out_for_return_pickup" (return pickup)
    return normalizedStatus == 'out_for_delivery' ||
        normalizedStatus == 'out_for_return_pickup';
  }

  /// Open delivery manager location in Google Maps
  /// Uses DeliveryRequest location data when available (only when status is 'in_delivery')
  Future<void> _openDeliveryManagerLocation() async {
    if (!mounted) return;

    if (_borrowRequest == null) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.requestInformationNotAvailable),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // Priority 1: Use DeliveryRequest location if available (new approach)
    if (_borrowRequest!.deliveryRequest != null) {
      final deliveryRequest = _borrowRequest!.deliveryRequest!;

      // Verify status is in_delivery
      if (deliveryRequest.status.toLowerCase() != 'in_delivery') {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.locationTrackingAvailable),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      // Use location from DeliveryRequest
      if (deliveryRequest.latitude != null &&
          deliveryRequest.longitude != null) {
        await _launchGoogleMaps(
          deliveryRequest.latitude!,
          deliveryRequest.longitude!,
        );
        return;
      } else {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.deliveryManagerLocationNotAvailable),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }
    }

    // Priority 2: Fallback to old API endpoint (backward compatibility)
    if (_borrowRequest!.deliveryPerson == null) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.deliveryManagerInfoNotAvailable),
            backgroundColor: AppColors.warning,
          ),
        );
      }
      return;
    }

    // Verify that status is out_for_delivery or out_for_return_pickup
    final status = _borrowRequest!.status
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^\w_]'), ''); // Remove any special characters
    if (status != 'out_for_delivery' && status != 'out_for_return_pickup') {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.locationTrackingAvailable),
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
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.authenticationRequired),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Fetch delivery manager's location from backend using borrow-specific endpoint
      // This endpoint returns location when status is OUT_FOR_DELIVERY or OUT_FOR_RETURN_PICKUP
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
              final localizations = AppLocalizations.of(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    localizations.deliveryManagerLocationNotAvailable,
                  ),
                  backgroundColor: AppColors.warning,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            final localizations = AppLocalizations.of(context);
            final errorMessage =
                data['message'] ?? localizations.failedToGetLocation;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: AppColors.warning,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['message'] ??
              errorData['error'] ??
              localizations.failedToGetLocation;
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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.error}: ${e.toString()}'),
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
      final localizations = AppLocalizations.of(context);

      // Check if return request already exists
      if (_hasReturnRequest) {
        // Find the return request ID and confirm pickup
        await returnProvider.loadReturnRequests();
        final returnRequests = returnProvider.returnRequests;
        ReturnRequest? matchingReturnRequest;
        try {
          matchingReturnRequest = returnRequests.firstWhere(
            (rr) => rr.borrowRequest.id == _borrowRequest!.id,
          );
        } catch (e) {
          matchingReturnRequest = null;
        }

        if (matchingReturnRequest != null) {
          // Call the confirm pickup API
          final returnService = ReturnRequestService();
          returnService.setToken(authProvider.token);

          try {
            final result = await returnService.confirmReturnPickup(
              int.parse(matchingReturnRequest.id),
            );

            // Reload data after confirming
            await _loadBorrowRequest();
            await _checkReturnRequest();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    result['message'] ??
                        'Return pickup confirmed. The delivery manager will contact you soon.',
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 3),
                ),
              );
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
        return;
      }

      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.creatingReturnRequest),
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
        // Wait a moment for backend to save the status change
        await Future.delayed(const Duration(milliseconds: 500));

        // Reload return requests to update the UI
        await _checkReturnRequest();

        // Reload the borrow request to get updated status
        // Force reload by creating a new service instance
        await _loadBorrowRequest();

        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.returnRequestCreatedSuccessfully),
                backgroundColor: AppColors.success,
              ),
            );
          } catch (_) {
            // Widget disposed, ignore
          }
        }
        // Don't navigate away, just update the UI to hide the button
        // if (mounted) {
        //   Navigator.pop(context);
        // }
      } else {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  returnProvider.errorMessage ??
                      localizations.failedToCreateReturnRequest,
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
      final localizations = AppLocalizations.of(context);
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.error}: ${e.toString()}'),
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
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            localizations.borrowStatus,
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
        body: const Center(child: LoadingIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            localizations.borrowStatus,
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
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ErrorMessage(message: _errorMessage!),
              const SizedBox(height: AppDimensions.spacingM),
              ElevatedButton(
                onPressed: _loadBorrowRequest,
                child: Text(localizations.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_borrowRequest == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            localizations.borrowStatus,
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
        body: Center(child: Text(localizations.borrowRequestNotFound)),
      );
    }

    final request = _borrowRequest!;
    final now = DateTime.now();
    final dueDate = request.dueDate;

    // Calculate if the book is overdue (current date > due date)
    final isOverdue = dueDate != null && now.isAfter(dueDate);

    // Calculate fine amount if overdue - $0.10 per hour
    final hourFineRate = 0.10;
    double fineAmount = 0.0;
    int hoursOverdue = 0;

    // If payment method is selected (fine is finalized), use backend values
    // Otherwise calculate in real-time
    final backendFine = request.fineAmount ?? 0.0;

    if (_paymentMethodSelected && backendFine > 0) {
      // Fine is finalized - use backend values (don't recalculate)
      fineAmount = backendFine;
      // Calculate hours from finalized fine amount (reverse calculation)
      hoursOverdue = (fineAmount / hourFineRate).round();
      debugPrint(
        'BorrowStatus: Fine FINALIZED - Hours: $hoursOverdue, Fine: \$${fineAmount.toStringAsFixed(2)}, _paymentMethodSelected: $_paymentMethodSelected',
      );
    } else if (isOverdue) {
      // Fine not finalized - calculate in real-time
      hoursOverdue = now.difference(dueDate).inHours;
      fineAmount = hoursOverdue * hourFineRate;
      debugPrint(
        'BorrowStatus: Fine LIVE - Hours: $hoursOverdue, Fine: \$${fineAmount.toStringAsFixed(2)}, _paymentMethodSelected: $_paymentMethodSelected, backendFine: $backendFine',
      );
    }

    debugPrint(
      'BorrowStatus: Final - fineAmount: \$${fineAmount.toStringAsFixed(2)}, isOverdue: $isOverdue, _paymentMethodSelected: $_paymentMethodSelected',
    );

    // Check if status allows showing return button and fine
    final status = request.status.toLowerCase();
    final canShowReturnAndFine =
        (status == 'delivered' || status == 'active') && isOverdue;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.borrowStatus,
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadBorrowRequest,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Order Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color:
                      (request.deliveryRequest != null
                              ? AppColors.info
                              : _getStatusColor(request.status))
                          .withValues(alpha: 0.2),
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
                      (request.deliveryRequest != null
                              ? AppColors.info
                              : _getStatusColor(request.status))
                          .withValues(alpha: 0.03),
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
                                  localizations.requestNumber(request.id),
                                  style: const TextStyle(
                                    fontSize: AppDimensions.fontSizeS,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // UNIFIED DELIVERY STATUS: Always show the primary status (delivery_request_status when available)
                          // The status field now contains the unified status from delivery_request_status
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
                              child:
                                  request.book?.coverImageUrl != null &&
                                      request.book!.coverImageUrl!.isNotEmpty
                                  ? Image.network(
                                      request.book!.coverImageUrl!,
                                      width: 90,
                                      height: 135,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Container(
                                              width: 90,
                                              height: 135,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    AppColors.primaryLight,
                                                    AppColors.primary,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.book,
                                                size: 40,
                                                color: AppColors.white,
                                              ),
                                            );
                                          },
                                    )
                                  : Container(
                                      width: 90,
                                      height: 135,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            AppColors.primaryLight,
                                            AppColors.primary,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.book,
                                        size: 40,
                                        color: AppColors.white,
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
                            color: request.deliveryRequest != null
                                ? AppColors.info
                                : _getStatusColor(request.status),
                          ),
                          const SizedBox(width: AppDimensions.spacingS),
                          Text(
                            localizations.orderStatusLabel,
                            style: const TextStyle(
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // UNIFIED DELIVERY STATUS: Always show the primary unified status
                            // The status field now contains delivery_request_status when available
                            Row(
                              children: [
                                Icon(
                                  Icons.local_shipping,
                                  size: 20,
                                  color: _getStatusColor(request.status),
                                ),
                                const SizedBox(width: AppDimensions.spacingS),
                                Expanded(
                                  child: Text(
                                    // Use unified status label - this now reflects delivery_request_status
                                    localizations.getBorrowStatusLabel(
                                      request.status,
                                    ),
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeM,
                                      fontWeight: FontWeight.w600,
                                      color: _getStatusColor(request.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppDimensions.spacingL),
                      const Divider(height: 1),

                      // Order Information
                      const SizedBox(height: AppDimensions.spacingM),
                      Text(
                        localizations.orderInformation,
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingM),
                      _buildInfoItem(
                        Icons.calendar_today,
                        localizations.requestDate,
                        _formatDate(request.requestDate),
                      ),
                      if (request.deliveryDate != null)
                        _buildInfoItem(
                          Icons.local_shipping,
                          localizations.deliveryDate,
                          _formatDate(request.deliveryDate!),
                        ),
                      if (request.dueDate != null) ...[
                        _buildInfoItem(
                          Icons.event,
                          localizations.dueDate,
                          _formatDate(request.dueDate!),
                        ),
                        // Show overdue indicator and fine if book is overdue
                        if (isOverdue) ...[
                          const SizedBox(height: AppDimensions.spacingXS),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.paddingM,
                              vertical: AppDimensions.paddingS,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 16,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingXS,
                                    ),
                                    Text(
                                      'Overdue by $hoursOverdue hour${hoursOverdue != 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeS,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                // Show fine amount when overdue
                                const SizedBox(height: AppDimensions.spacingXS),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.attach_money,
                                      size: 16,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(
                                      width: AppDimensions.spacingXS,
                                    ),
                                    Text(
                                      '${localizations.fineAmount}: \$${fineAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: AppDimensions.fontSizeM,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                      // Delivery Manager Section
                      if (request.deliveryPerson != null) ...[
                        const SizedBox(height: AppDimensions.spacingL),
                        const Divider(height: 1),
                        const SizedBox(height: AppDimensions.spacingM),
                        Row(
                          children: [
                            const Icon(
                              Icons.local_shipping,
                              size: 20,
                              color: AppColors.info,
                            ),
                            const SizedBox(width: AppDimensions.spacingS),
                            Text(
                              localizations.deliveryManager,
                              style: const TextStyle(
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
                        // Only show when DeliveryRequest.status == 'in_delivery' (protects privacy)
                        if (_canTrackDeliveryLocation()) ...[
                          const SizedBox(height: AppDimensions.spacingM),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openDeliveryManagerLocation,
                              icon: const Icon(Icons.location_on, size: 20),
                              label: Text(
                                localizations.viewDeliveryManagerLocation,
                                style: const TextStyle(fontSize: 16),
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

                      // Fine Information Section (show when overdue and status is delivered or active)
                      if (canShowReturnAndFine && fineAmount > 0) ...[
                        const SizedBox(height: AppDimensions.spacingL),
                        const Divider(height: 1),
                        const SizedBox(height: AppDimensions.spacingM),
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingM),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    localizations.fineApplied,
                                    style: const TextStyle(
                                      fontSize: AppDimensions.fontSizeM,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppDimensions.spacingS),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hours Overdue: $hoursOverdue',
                                    style: const TextStyle(
                                      fontSize: AppDimensions.fontSizeS,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Builder(
                                    builder: (context) {
                                      final localizations = AppLocalizations.of(
                                        context,
                                      );
                                      return Text(
                                        '${localizations.fineAmount}: \$${fineAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: AppDimensions.fontSizeL,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                      );
                                    },
                                  ),
                                  if (request.fineStatus != null &&
                                      request.fineStatus!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Payment Status: ${_getFineStatusDisplay(request.fineStatus!)}',
                                      style: TextStyle(
                                        fontSize: AppDimensions.fontSizeXS,
                                        color: _getFineStatusColor(
                                          request.fineStatus!,
                                        ),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: AppDimensions.spacingM),
                              // Show "Payment Method" button if fine is not paid AND payment method not selected
                              if (!_paymentMethodSelected &&
                                  (request.fineStatus == null ||
                                      request.fineStatus!.toLowerCase() !=
                                          'paid')) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      // Get or create return request first, then navigate to payment
                                      try {
                                        final returnProvider =
                                            Provider.of<ReturnRequestProvider>(
                                              context,
                                              listen: false,
                                            );
                                        final authProvider =
                                            Provider.of<AuthProvider>(
                                              context,
                                              listen: false,
                                            );

                                        if (authProvider.token != null) {
                                          returnProvider.setToken(
                                            authProvider.token!,
                                          );
                                        }

                                        ReturnRequest? returnRequest;

                                        // First, check if a return request already exists
                                        if (_hasReturnRequest) {
                                          // Return request exists, load it directly
                                          await returnProvider
                                              .loadReturnRequests();
                                          final returnRequests =
                                              returnProvider.returnRequests;
                                          try {
                                            returnRequest = returnRequests
                                                .firstWhere(
                                                  (rr) =>
                                                      rr.borrowRequest.id ==
                                                      request.id,
                                                );
                                          } catch (e) {
                                            // Return request not found in list
                                            returnRequest = null;
                                          }
                                        } else {
                                          // Create return request if it doesn't exist
                                          final success = await returnProvider
                                              .createReturnRequest(request.id);

                                          if (!success) {
                                            // Check if return request already exists (from error message)
                                            final errorMessage =
                                                returnProvider.errorMessage ??
                                                '';
                                            final alreadyExists =
                                                errorMessage.contains(
                                                  'already exists',
                                                ) ||
                                                errorMessage.contains(
                                                  'A return request already exists',
                                                ) ||
                                                errorMessage.contains(
                                                  'Failed to create return request',
                                                );

                                            if (alreadyExists) {
                                              // Load return requests and find the existing one
                                              await returnProvider
                                                  .loadReturnRequests();
                                              final returnRequests =
                                                  returnProvider.returnRequests;
                                              try {
                                                returnRequest = returnRequests
                                                    .firstWhere(
                                                      (rr) =>
                                                          rr.borrowRequest.id ==
                                                          request.id,
                                                    );
                                              } catch (e) {
                                                // Return request not found in list
                                                returnRequest = null;
                                              }
                                            }

                                            // If we couldn't find an existing return request, show error
                                            if (returnRequest == null) {
                                              if (!mounted) return;
                                              if (!context.mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    returnProvider
                                                            .errorMessage ??
                                                        'Failed to create return request',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.error,
                                                ),
                                              );
                                              return;
                                            }
                                          } else {
                                            // Get return request details to get fineId
                                            // The return request list should have the newly created one
                                            await returnProvider
                                                .loadReturnRequests();
                                            final returnRequests =
                                                returnProvider.returnRequests;
                                            try {
                                              returnRequest = returnRequests
                                                  .firstWhere(
                                                    (rr) =>
                                                        rr.borrowRequest.id ==
                                                        request.id,
                                                  );
                                            } catch (e) {
                                              returnRequest =
                                                  returnRequests.isNotEmpty
                                                  ? returnRequests.first
                                                  : null;
                                            }
                                          }
                                        }

                                        if (returnRequest == null) {
                                          if (!mounted) return;
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Failed to get return request details',
                                              ),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                          return;
                                        }

                                        if (!mounted) return;
                                        if (!context.mounted) return;

                                        // Fetch return request details to get fine information
                                        final returnRequestId =
                                            int.tryParse(returnRequest.id) ?? 0;
                                        final returnRequestService =
                                            ReturnRequestService();
                                        if (authProvider.token != null) {
                                          returnRequestService.setToken(
                                            authProvider.token!,
                                          );
                                        }
                                        final returnRequestDetail =
                                            await returnRequestService
                                                .getReturnRequestById(
                                                  returnRequestId,
                                                );

                                        // Get fineId from return request detail
                                        // The backend should include fine in the response
                                        final fineId =
                                            returnRequestDetail.fineId;

                                        if (fineId == null) {
                                          if (!mounted) return;
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Fine not found. Please try again.',
                                              ),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                          return;
                                        }

                                        // Navigate to payment method selection with fineId
                                        if (!mounted) return;
                                        if (!context.mounted) return;
                                        final result =
                                            await Navigator.pushNamed(
                                              context,
                                              '/fine-payment-method',
                                              arguments: {
                                                'fineId': fineId,
                                                'fineAmount': fineAmount,
                                                'hoursOverdue': hoursOverdue,
                                              },
                                            );
                                        // Reload borrow request after payment and update return request flag
                                        if (result == true && mounted) {
                                          await _loadBorrowRequest();
                                          await _checkReturnRequest();
                                        }
                                      } catch (e) {
                                        if (mounted) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Error: ${e.toString()}',
                                              ),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.payment),
                                    label: Text(localizations.paymentMethod),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.white,
                                    ),
                                  ),
                                ),
                              ],
                              // Show "Return Book" button if fine is paid OR payment method is selected
                              if (_paymentMethodSelected ||
                                  (request.fineStatus != null &&
                                      request.fineStatus!.toLowerCase() ==
                                          'paid')) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: _handleReturn,
                                    icon: const Icon(Icons.assignment_return),
                                    label: Text(localizations.returnBook),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      // Overdue Warning (without fine section)
                      if (isOverdue &&
                          (status == 'active' || status == 'delivered') &&
                          !canShowReturnAndFine) ...[
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
                                  'Overdue by $hoursOverdue hour${hoursOverdue != 1 ? 's' : ''}',
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

                      // Return Button - Show for active or delivered status (books that can be returned)
                      // Only show if no return request already exists
                      // For active: only show if not overdue (overdue books need to pay fine first)
                      // For delivered: always show (delivered books can always be returned)
                      if (!_hasReturnRequest &&
                          status == 'active' &&
                          !isOverdue) ...[
                        const SizedBox(height: AppDimensions.spacingL),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleReturn,
                            icon: const Icon(Icons.assignment_return),
                            label: Text(localizations.returnBook),
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
                      // Return Button for delivered status (always show, regardless of overdue)
                      // Only show if no return request already exists
                      if (!_hasReturnRequest && status == 'delivered') ...[
                        const SizedBox(height: AppDimensions.spacingL),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _handleReturn,
                            icon: const Icon(Icons.assignment_return),
                            label: Text(localizations.returnBook),
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
