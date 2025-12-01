import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../borrow/models/return_request.dart';
import '../../borrow/providers/return_request_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/services/auth_api_service.dart';
import '../../../core/services/location_service.dart';
import '../providers/delivery_status_provider.dart';

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
  bool _returnStarted = false; // Track if Start Return has been called
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _currentReturnRequest = widget.returnRequest;
    _loadReturnRequest();
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
          // If pickedUpAt is set, return has been started
          _returnStarted = returnRequest.pickedUpAt != null;
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
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load return request from database';
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
                  _returnStarted = returnRequest.pickedUpAt != null;
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
          setState(() {
            _isLoading = false;
            _errorMessage = 'Session expired. Please login again.';
          });
        }
      } else {
        // Other errors
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error loading return request: ${e.toString()}';
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Return request accepted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _errorMessage =
              returnProvider.errorMessage ?? 'Failed to accept return request';
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
        setState(() {
          _currentReturnRequest = updatedRequest;
          // Update local state based on actual data from server
          // If pickedUpAt is set, return has been started
          if (updatedRequest.pickedUpAt != null) {
            _returnStarted = true;
          }
        });

        // Refresh delivery status from server (backend automatically sets it to 'busy')
        try {
          if (authProvider.token != null) {
            statusProvider.setToken(authProvider.token!);
            await statusProvider.loadCurrentStatus();
            debugPrint(
              'DeliveryStatusProvider: Status refreshed after starting return',
            );
          }
        } catch (e) {
          debugPrint('Error refreshing delivery status: $e');
          // Don't fail the return process if status refresh fails
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Return process started successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _errorMessage =
              returnProvider.errorMessage ?? 'Failed to start return process';
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
        setState(() {
          _errorMessage =
              'Could not get current location. Please enable location services and grant permission.';
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              returnProvider.errorMessage ?? 'Failed to update location';
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error in _updateCurrentLocation: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error updating location: ${e.toString()}';
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Return'),
        content: const Text(
          'Are you sure you want to complete this return? This will mark the book as successfully returned.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete'),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Return completed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _errorMessage =
              returnProvider.errorMessage ?? 'Failed to complete return';
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

    final status = _currentReturnRequest!.status.toUpperCase();
    final isAssigned =
        status == 'ASSIGNED' || _currentReturnRequest!.isAssigned;
    final isInProgress =
        status == 'IN_PROGRESS' || _currentReturnRequest!.isInProgress;
    final isCompleted =
        status == 'COMPLETED' || _currentReturnRequest!.isCompleted;

    // Track if return has been started - check actual data from server first
    // Use pickedUpAt timestamp from database as the source of truth
    final bool returnStarted =
        _currentReturnRequest!.pickedUpAt != null || _returnStarted;

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
            const Text(
              'Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  child: ElevatedButton.icon(
                    onPressed: _acceptReturnRequest,
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      'Accept Return Request',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              // Step 3: Start Return (when status is IN_PROGRESS after accept, but not started yet)
              if (isInProgress && !isAssigned && !returnStarted)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _startReturn,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text(
                      'Start Return',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              // Step 4 & 5: After Start Return, show Complete and Update Location buttons
              if (isInProgress && !isAssigned && returnStarted)
                Column(
                  children: [
                    // Step 5: Complete Return
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _completeReturn,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Book Returned (Complete Return)',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                        label: const Text(
                          'Update Current Location',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
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
        title: Text('Return Request #${returnRequest.id}'),
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
                            'Status',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontSize: 14,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            returnRequest.statusDisplay,
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
                            Text(
                              'Book Information',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Book',
                              returnRequest.borrowRequest.bookTitle ?? 'N/A',
                            ),
                            _buildInfoRow(
                              'Expected Return Date',
                              returnRequest.borrowRequest.dueDate != null
                                  ? '${returnRequest.borrowRequest.dueDate!.day}/${returnRequest.borrowRequest.dueDate!.month}/${returnRequest.borrowRequest.dueDate!.year}'
                                  : 'N/A',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Customer Information
                    Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Customer Information',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              'Name',
                              returnRequest.borrowRequest.customerName ?? 'N/A',
                            ),
                            _buildInfoRow(
                              'Email',
                              returnRequest.borrowRequest.customer?.email ??
                                  'N/A',
                            ),
                            _buildInfoRow(
                              'Phone',
                              returnRequest.borrowRequest.customer?.phone ??
                                  'N/A',
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
                            Text(
                              'Request Information',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('Request ID', returnRequest.id),
                            _buildInfoRow(
                              'Requested At',
                              '${returnRequest.requestedAt.day}/${returnRequest.requestedAt.month}/${returnRequest.requestedAt.year}',
                            ),
                            if (returnRequest.acceptedAt != null)
                              _buildInfoRow(
                                'Accepted At',
                                '${returnRequest.acceptedAt!.day}/${returnRequest.acceptedAt!.month}/${returnRequest.acceptedAt!.year}',
                              ),
                            if (returnRequest.completedAt != null)
                              _buildInfoRow(
                                'Completed At',
                                '${returnRequest.completedAt!.day}/${returnRequest.completedAt!.month}/${returnRequest.completedAt!.year}',
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
}
