import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../borrow/models/return_request.dart';
import '../../borrow/providers/return_request_provider.dart';
import '../../borrow/services/fine_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_api_service.dart';
import '../../../core/services/location_service.dart';
import '../providers/delivery_status_provider.dart';
import '../../../core/localization/app_localizations.dart';

class ReturnRequestDetailScreen extends StatefulWidget {
  final ReturnRequest returnRequest;

  const ReturnRequestDetailScreen({super.key, required this.returnRequest});

  @override
  State<ReturnRequestDetailScreen> createState() =>
      _ReturnRequestDetailScreenState();
}

class _ReturnRequestDetailScreenState extends State<ReturnRequestDetailScreen> {
  ReturnRequest? _currentReturnRequest;
  bool _isLoading = false;
  String? _errorMessage;
  // Removed _returnStarted - now using pickedUpAt from server data as source of truth
  final LocationService _locationService = LocationService();
  final FineService _fineService = FineService();

  @override
  void initState() {
    super.initState();
    // Initialize with widget data for immediate display, but always reload from server
    _currentReturnRequest = widget.returnRequest;
    _initializeServices();
    // CRITICAL: Always reload from server on init to ensure UI reflects backend state
    _loadReturnRequest();
    // Also refresh delivery manager status to ensure consistency
    // Defer to avoid calling notifyListeners during build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshDeliveryManagerStatus();
    });
  }

  /// Refresh delivery manager status from server
  /// Called on init and after critical actions to ensure consistency
  Future<void> _refreshDeliveryManagerStatus() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final statusProvider = Provider.of<DeliveryStatusProvider>(
        context,
        listen: false,
      );

      if (authProvider.token != null) {
        statusProvider.setToken(authProvider.token!);
        await statusProvider.loadCurrentStatus();
        debugPrint(
          'ReturnRequestDetailScreen: Delivery manager status refreshed on init',
        );
      }
    } catch (e) {
      debugPrint(
        'ReturnRequestDetailScreen: Error refreshing status on init: $e',
      );
      // Non-critical - don't block UI
    }
  }

  void _initializeServices() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      _fineService.setToken(authProvider.token!);
    }
  }

  Future<void> _loadReturnRequest() async {
    if (_currentReturnRequest == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final returnProvider = Provider.of<ReturnRequestProvider>(
      context,
      listen: false,
    );

    // Get fresh token from auth provider
    String? token = authProvider.token;
    if (token != null) {
      returnProvider.setToken(token);
    }

    try {
      // Always fetch fresh data from database
      final returnRequest = await returnProvider.getReturnRequestById(
        int.parse(_currentReturnRequest!.id),
      );
      if (returnRequest != null && mounted) {
        setState(() {
          _currentReturnRequest = returnRequest;
          // Update local state based on actual data from server
          // Button visibility now uses pickedUpAt directly from server data
          _isLoading = false;
        });
        debugPrint(
          'ReturnRequestDetailScreen: Loaded fresh data from database',
        );
        debugPrint(
          'ReturnRequestDetailScreen: Status: ${returnRequest.status}',
        );
        debugPrint(
          'ReturnRequestDetailScreen: pickedUpAt: ${returnRequest.pickedUpAt}',
        );
        debugPrint(
          'ReturnRequestDetailScreen: completedAt: ${returnRequest.completedAt}',
        );
      } else if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _isLoading = false;
          _errorMessage = localizations.failedToLoadReturnRequest;
        });
      }
    } catch (e) {
      debugPrint('Error loading return request: $e');

      // Check if error is due to expired token (401)
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('401') ||
          errorString.contains('unauthorized') ||
          errorString.contains('token') && errorString.contains('invalid')) {
        // Try to refresh token and retry
        debugPrint(
          'ReturnRequestDetailScreen: Token expired, attempting refresh...',
        );
        try {
          if (authProvider.refreshToken != null &&
              authProvider.refreshToken!.isNotEmpty) {
            final refreshResponse = await AuthApiService.refreshToken(
              authProvider.refreshToken!,
            );
            if (refreshResponse.success &&
                refreshResponse.accessToken != null) {
              debugPrint(
                'ReturnRequestDetailScreen: Token refreshed successfully',
              );
              // Update token in auth provider
              authProvider.setToken(refreshResponse.accessToken!);
              // Update token in return provider
              returnProvider.setToken(refreshResponse.accessToken!);

              // Retry the request with new token
              final returnRequest = await returnProvider.getReturnRequestById(
                int.parse(_currentReturnRequest!.id),
              );
              if (returnRequest != null && mounted) {
                setState(() {
                  _currentReturnRequest = returnRequest;
                  // Button visibility now uses pickedUpAt directly from server data
                  _isLoading = false;
                });
                return; // Success, exit early
              }
            }
          }
        } catch (refreshError) {
          debugPrint(
            'ReturnRequestDetailScreen: Token refresh failed: $refreshError',
          );
        }

        // If refresh failed or no refresh token, show error
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          setState(() {
            _isLoading = false;
            _errorMessage = localizations.sessionExpiredPleaseLoginAgain;
          });
        }
      } else {
        // Other errors
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          setState(() {
            _isLoading = false;
            _errorMessage = localizations.errorLoadingReturnRequest(
              e.toString(),
            );
          });
        }
      }
    }
  }

  Future<void> _acceptReturnRequest() async {
    if (_currentReturnRequest == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final returnProvider = Provider.of<ReturnRequestProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      final success = await returnProvider.acceptReturnRequest(
        int.parse(_currentReturnRequest!.id),
      );

      if (success && mounted) {
        await _loadReturnRequest();
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.returnRequestAcceptedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              returnProvider.errorMessage ??
              localizations.failedToAcceptReturnRequest;
        });
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        final errorString = e.toString();
        // Check if it's the specific "Failed to start return process" error
        if (errorString.toLowerCase().contains(
          'failed to start return process',
        )) {
          setState(() {
            _errorMessage = localizations.exceptionFailedToStartReturnProcess;
          });
        } else {
          setState(() {
            _errorMessage = errorString;
          });
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

  Future<void> _startReturn() async {
    if (_currentReturnRequest == null) return;

    // Get providers before async operations to avoid BuildContext usage across async gaps
    final returnProvider = Provider.of<ReturnRequestProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final statusProvider = Provider.of<DeliveryStatusProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      final updatedRequest = await returnProvider.markBookCollected(
        int.parse(_currentReturnRequest!.id),
      );

      if (updatedRequest != null && mounted) {
        // CRITICAL: Reload return request from server to get latest status and pickedUpAt
        // This ensures UI reflects actual backend state
        await _loadReturnRequest();

        // Refresh delivery status from server (backend automatically sets it to 'busy')
        // This is critical to show correct status in UI
        try {
          if (authProvider.token != null) {
            statusProvider.setToken(authProvider.token!);
            await statusProvider.loadCurrentStatus();
            debugPrint(
              'DeliveryStatusProvider: Status refreshed after starting return - Status: ${statusProvider.currentStatus}',
            );
          }
        } catch (e) {
          debugPrint('Error refreshing delivery status: $e');
          // Don't fail the return process if status refresh fails
        }

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.returnProcessStartedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              returnProvider.errorMessage ??
              localizations.failedToStartReturnProcess;
        });
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        final errorString = e.toString();
        // Check if it's the specific "Failed to start return process" error
        if (errorString.toLowerCase().contains(
          'failed to start return process',
        )) {
          setState(() {
            _errorMessage = localizations.exceptionFailedToStartReturnProcess;
          });
        } else {
          setState(() {
            _errorMessage = errorString;
          });
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

  Future<void> _updateCurrentLocation() async {
    if (!mounted) return;

    // Get providers before async call to avoid BuildContext usage across async gaps
    final returnProvider = Provider.of<ReturnRequestProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current location with timeout protection
      Position? position;
      try {
        position = await _locationService.getCurrentLocation().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('Location request timed out');
            return null;
          },
        );
      } catch (e) {
        debugPrint('Error getting location: $e');
        position = null;
      }

      if (!mounted) return;

      if (position == null) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage = localizations.couldNotGetCurrentLocation;
          _isLoading = false;
        });
        return;
      }

      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      if (!mounted) return;

      final success = await returnProvider.updateLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        speed: position.speed,
      );

      if (!mounted) return;

      if (success) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.locationUpdatedSuccessfully),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _isLoading = false;
          _errorMessage =
              returnProvider.errorMessage ??
              localizations.failedToUpdateLocation;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _updateCurrentLocation: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _isLoading = false;
          _errorMessage = localizations.errorUpdatingLocation(e.toString());
        });
      }
    } finally {
      // Ensure loading state is always reset, even if something unexpected happens
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _completeReturn() async {
    if (_currentReturnRequest == null) return;

    // Show confirmation dialog
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.completeReturn),
        content: Text(localizations.completeReturnConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(localizations.completeReturn),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Get providers before async operations to avoid BuildContext usage across async gaps
    final returnProvider = Provider.of<ReturnRequestProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final statusProvider = Provider.of<DeliveryStatusProvider>(
      context,
      listen: false,
    );

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      final success = await returnProvider.completeReturn(
        int.parse(_currentReturnRequest!.id),
      );

      if (success && mounted) {
        await _loadReturnRequest();

        // Refresh delivery status from server (backend automatically sets it to 'online' if no other active tasks)
        try {
          if (authProvider.token != null) {
            statusProvider.setToken(authProvider.token!);
            await statusProvider.loadCurrentStatus();
            debugPrint(
              'DeliveryStatusProvider: Status refreshed after completing return',
            );
          }
        } catch (e) {
          debugPrint('Error refreshing delivery status: $e');
          // Don't fail the return process if status refresh fails
        }

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.returnCompletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              returnProvider.errorMessage ??
              localizations.failedToCompleteReturn;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
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

  Widget _buildActionButtons() {
    if (_currentReturnRequest == null) return const SizedBox.shrink();

    // CRITICAL: Button visibility rules - STRICTLY based on server data only
    // No local state assumptions - backend is single source of truth

    // Normalize status from server (remove any local state checks)
    final status = _currentReturnRequest!.status.toUpperCase().trim();
    final isAssigned = status == 'ASSIGNED';
    final isAccepted = status == 'ACCEPTED';
    final isApproved = status == 'APPROVED';
    final isInProgress = status == 'IN_PROGRESS';
    final isCompleted = status == 'COMPLETED';

    // Track if return has been started - ALWAYS use actual data from server
    // Use pickedUpAt timestamp from database as the source of truth
    final bool returnStarted = _currentReturnRequest!.pickedUpAt != null;

    // If completed, don't show any action buttons
    if (isCompleted) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                return Text(
                  AppLocalizations.of(context).actions,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ErrorMessage(message: _errorMessage!),
              ),
            if (_isLoading)
              const Center(child: LoadingIndicator())
            else ...[
              // Step 2: Accept Return Request (when status is ASSIGNED)
              if (isAssigned)
                SizedBox(
                  width: double.infinity,
                  child: Builder(
                    builder: (context) {
                      return ElevatedButton.icon(
                        onPressed: _acceptReturnRequest,
                        icon: const Icon(Icons.check_circle),
                        label: Text(
                          AppLocalizations.of(context).acceptReturnRequest,
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      );
                    },
                  ),
                ),
              // Step 3: Start Return button visibility rules (STRICT - based on server data only)
              // Visible ONLY when:
              // 1. Status is ASSIGNED, ACCEPTED, or APPROVED (from server)
              // 2. pickedUpAt is null (return hasn't started yet)
              // 3. NOT completed
              if ((isAssigned || isAccepted || isApproved) &&
                  !returnStarted &&
                  !isCompleted)
                SizedBox(
                  width: double.infinity,
                  child: Builder(
                    builder: (context) {
                      return ElevatedButton.icon(
                        onPressed: _startReturn,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(
                          AppLocalizations.of(context).startReturn,
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      );
                    },
                  ),
                ),
              // Step 4 & 5: Complete Return & Update Location buttons visibility rules (STRICT)
              // Visible ONLY when:
              // 1. Status is IN_PROGRESS (from server)
              // 2. pickedUpAt is set (return has been started - from server)
              // 3. NOT completed
              // Both conditions must be true - no local state assumptions
              if (isInProgress && returnStarted && !isCompleted)
                Column(
                  children: [
                    // Fine Cash Payment Confirmation (if fine exists and payment method is cash)
                    if (_currentReturnRequest!.fineAmount > 0 &&
                        _currentReturnRequest!.borrowRequest.paymentMethod ==
                            'cash' &&
                        _currentReturnRequest!.borrowRequest.fineStatus !=
                            'paid')
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _confirmCashPayment,
                              icon: const Icon(Icons.money),
                              label: Builder(
                                builder: (context) {
                                  return Text(
                                    AppLocalizations.of(
                                      context,
                                    ).confirmCashPayment,
                                    style: const TextStyle(fontSize: 16),
                                  );
                                },
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    // Step 5: Complete Return
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _completeReturn,
                                icon: const Icon(Icons.check_circle_outline),
                                label: Text(
                                  localizations.bookReturnedComplete,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Step 4: Update Location
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _updateCurrentLocation,
                                icon: const Icon(Icons.location_on),
                                label: Text(
                                  localizations.updateCurrentLocation,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Always use current data from database, fallback to widget data only for initial display
    final returnRequest = _currentReturnRequest ?? widget.returnRequest;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).returnRequestNumber(returnRequest.id),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReturnRequest,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadReturnRequest,
        child: _isLoading && _currentReturnRequest == null
            ? const Center(child: LoadingIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Card
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context).status,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontSize: 14,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(
                              context,
                            ).getReturnRequestStatusLabel(returnRequest.status),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Book Information
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      localizations.bookInformation,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      localizations.bookTitle,
                                      returnRequest.borrowRequest.bookTitle ??
                                          localizations.notAvailable,
                                    ),
                                    _buildInfoRow(
                                      localizations.expectedReturnDate,
                                      returnRequest.borrowRequest.dueDate !=
                                              null
                                          ? '${returnRequest.borrowRequest.dueDate!.day}/${returnRequest.borrowRequest.dueDate!.month}/${returnRequest.borrowRequest.dueDate!.year}'
                                          : localizations.notAvailable,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Fine Information (if fine exists)
                    if (_currentReturnRequest!.fineAmount > 0)
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.orange,
                                            size: 24,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            localizations.fineInformation,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      _buildInfoRow(
                                        localizations.bookTitle,
                                        returnRequest.borrowRequest.bookTitle ??
                                            localizations.notAvailable,
                                      ),
                                      _buildInfoRow(
                                        localizations.customer,
                                        returnRequest
                                                .borrowRequest
                                                .customerName ??
                                            localizations.notAvailable,
                                      ),
                                      _buildInfoRow(
                                        localizations.fineAmount,
                                        '\$${returnRequest.fineAmount.toStringAsFixed(2)}',
                                      ),
                                      if (_currentReturnRequest!
                                              .borrowRequest
                                              .fineStatus !=
                                          null) ...[
                                        _buildInfoRow(
                                          localizations.paymentStatus,
                                          _getFineStatusDisplay(
                                            _currentReturnRequest!
                                                .borrowRequest
                                                .fineStatus!,
                                            localizations,
                                          ),
                                        ),
                                        if (_currentReturnRequest!
                                                .borrowRequest
                                                .paymentMethod !=
                                            null)
                                          _buildInfoRow(
                                            localizations.paymentMethod,
                                            _getPaymentMethodDisplay(
                                              _currentReturnRequest!
                                                  .borrowRequest
                                                  .paymentMethod!,
                                              localizations,
                                            ),
                                          ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_currentReturnRequest!.fineAmount > 0)
                      const SizedBox(height: 16),

                    // Customer Information
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      localizations.customerInformation,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      localizations.nameLabel,
                                      returnRequest
                                              .borrowRequest
                                              .customerName ??
                                          localizations.notAvailable,
                                    ),
                                    _buildInfoRow(
                                      localizations.emailLabel,
                                      returnRequest
                                              .borrowRequest
                                              .customer
                                              ?.email ??
                                          localizations.notAvailable,
                                    ),
                                    _buildInfoRow(
                                      localizations.phoneLabel,
                                      _getPhoneDisplay(
                                        returnRequest
                                            .borrowRequest
                                            .customer
                                            ?.phone,
                                        localizations,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Request Information
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (context) {
                                final localizations = AppLocalizations.of(
                                  context,
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      localizations.requestInformation,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildInfoRow(
                                      localizations.requestId,
                                      returnRequest.id,
                                    ),
                                    _buildInfoRow(
                                      localizations.requestedAt,
                                      '${returnRequest.requestedAt.day}/${returnRequest.requestedAt.month}/${returnRequest.requestedAt.year}',
                                    ),
                                    if (returnRequest.acceptedAt != null)
                                      _buildInfoRow(
                                        localizations.acceptedAt,
                                        '${returnRequest.acceptedAt!.day}/${returnRequest.acceptedAt!.month}/${returnRequest.acceptedAt!.year}',
                                      ),
                                    if (returnRequest.completedAt != null)
                                      _buildInfoRow(
                                        localizations.completedAt,
                                        '${returnRequest.completedAt!.day}/${returnRequest.completedAt!.month}/${returnRequest.completedAt!.year}',
                                      ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons
                    _buildActionButtons(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }

  String _getPhoneDisplay(String? phone, AppLocalizations localizations) {
    if (phone == null || phone.isEmpty) {
      return localizations.notAvailable;
    }
    // Check if phone is "not found" (from backend) and translate it
    if (phone.toLowerCase().trim() == 'not found') {
      return localizations.notFound;
    }
    return phone;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCashPayment() async {
    if (_currentReturnRequest == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.confirmCashPayment),
          content: Text(
            localizations.confirmCashPaymentMessage(
              _currentReturnRequest!.fineAmount.toStringAsFixed(2),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(localizations.confirm),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _fineService.confirmCashPayment(
        borrowRequestId: int.parse(
          _currentReturnRequest!.borrowRequest.id.toString(),
        ),
      );

      if (result['success'] == true && mounted) {
        await _loadReturnRequest();
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.cashPaymentConfirmedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        final localizations = AppLocalizations.of(context);
        setState(() {
          _errorMessage =
              result['message'] ?? localizations.failedToConfirmCashPayment;
        });
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        final errorString = e.toString();
        // Check if it's the specific "Failed to start return process" error
        if (errorString.toLowerCase().contains(
          'failed to start return process',
        )) {
          setState(() {
            _errorMessage = localizations.exceptionFailedToStartReturnProcess;
          });
        } else {
          setState(() {
            _errorMessage = errorString;
          });
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

  String _getFineStatusDisplay(String status, AppLocalizations localizations) {
    switch (status.toLowerCase()) {
      case 'paid':
        return localizations.fineStatusPaid;
      case 'unpaid':
        return localizations.fineStatusUnpaid;
      case 'pending_cash_payment':
        return localizations.fineStatusPendingCashPayment;
      case 'failed':
        return localizations.fineStatusFailed;
      default:
        return status;
    }
  }

  String _getPaymentMethodDisplay(
    String method,
    AppLocalizations localizations,
  ) {
    switch (method.toLowerCase()) {
      case 'cash':
        return localizations.paymentMethodCashDisplay;
      case 'mastercard':
        return localizations.paymentMethodMastercardDisplay;
      default:
        return method;
    }
  }
}
