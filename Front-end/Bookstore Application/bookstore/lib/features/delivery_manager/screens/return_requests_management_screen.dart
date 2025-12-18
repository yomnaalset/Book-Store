import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/localization/app_localizations.dart';
import '../../borrow/providers/return_request_provider.dart';
import '../../borrow/models/return_request.dart';
import '../../auth/providers/auth_provider.dart';

class DeliveryManagerReturnRequestsScreen extends StatefulWidget {
  const DeliveryManagerReturnRequestsScreen({super.key});

  @override
  State<DeliveryManagerReturnRequestsScreen> createState() =>
      _DeliveryManagerReturnRequestsScreenState();
}

class _DeliveryManagerReturnRequestsScreenState
    extends State<DeliveryManagerReturnRequestsScreen> {
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadReturnRequests();
  }

  Future<void> _loadReturnRequests() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final returnProvider = Provider.of<ReturnRequestProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      returnProvider.setToken(authProvider.token!);
    }

    await returnProvider.loadReturnRequests(status: _selectedStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Requests'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReturnRequests,
          ),
        ],
      ),
      body: Consumer<ReturnRequestProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  ElevatedButton(
                    onPressed: _loadReturnRequests,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final returnRequests = provider.returnRequests;

          if (returnRequests.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_return_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: AppDimensions.spacingM),
                  Text(
                    'No return requests available',
                    style: TextStyle(
                      fontSize: AppDimensions.fontSizeL,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Filter chips
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM,
                  vertical: AppDimensions.paddingS,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All', null),
                      const SizedBox(width: AppDimensions.spacingS),
                      _buildFilterChip('Pending Pickup', 'pending_pickup'),
                      const SizedBox(width: AppDimensions.spacingS),
                      _buildFilterChip('In Return', 'in_return'),
                      const SizedBox(width: AppDimensions.spacingS),
                      _buildFilterChip('Returning', 'returning_to_library'),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1.0, color: AppColors.divider),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadReturnRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    itemCount: returnRequests.length,
                    itemBuilder: (context, index) {
                      final returnRequest = returnRequests[index];
                      return _buildReturnRequestCard(returnRequest);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, String? status) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
        _loadReturnRequests();
      },
    );
  }

  Widget _buildReturnRequestCard(ReturnRequest returnRequest) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        returnRequest.borrowRequest.book?.title ??
                            returnRequest.borrowRequest.bookTitle ??
                            'Unknown Book',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXS),
                      Text(
                        'Customer: ${returnRequest.borrowRequest.customerName ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingS,
                    vertical: AppDimensions.paddingXS,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      returnRequest.status,
                    ).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                    border: Border.all(
                      color: _getStatusColor(returnRequest.status),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(
                      context,
                    ).getReturnRequestStatusLabel(returnRequest.status),
                    style: TextStyle(
                      fontSize: AppDimensions.fontSizeXS,
                      color: _getStatusColor(returnRequest.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            if (returnRequest.borrowRequest.deliveryAddress != null)
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppDimensions.spacingXS),
                  Expanded(
                    child: Text(
                      returnRequest.borrowRequest.deliveryAddress!,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            if (returnRequest.fineAmount > 0) ...[
              const SizedBox(height: AppDimensions.spacingS),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingS),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      color: AppColors.warning,
                      size: 16,
                    ),
                    const SizedBox(width: AppDimensions.spacingXS),
                    Text(
                      'Fine: \$${returnRequest.fineAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.spacingM),
            // Action buttons based on status
            if (returnRequest.isPendingPickup)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _acceptReturnRequest(returnRequest),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Accept Return Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                  ),
                ),
              )
            else if (returnRequest.isInReturn)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _markBookCollected(returnRequest),
                  icon: const Icon(Icons.inventory),
                  label: const Text('Book Collected'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                  ),
                ),
              )
            else if (returnRequest.isReturningToLibrary)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _completeReturn(returnRequest),
                  icon: const Icon(Icons.done_all),
                  label: const Text('Delivered to Library'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_pickup':
        return AppColors.warning;
      case 'in_return':
        return AppColors.info;
      case 'returning_to_library':
        return AppColors.primary;
      case 'returned_successfully':
        return AppColors.success;
      case 'late_return':
        return AppColors.error;
      case 'cancelled':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _acceptReturnRequest(ReturnRequest returnRequest) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Accepting return request...'),
        backgroundColor: AppColors.primary,
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final returnProvider = Provider.of<ReturnRequestProvider>(
        context,
        listen: false,
      );
      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      final success = await returnProvider.acceptReturnRequest(
        int.parse(returnRequest.id),
      );

      if (!mounted) return;

      if (success) {
        await _loadReturnRequests();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Return request accepted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              returnProvider.errorMessage ?? 'Failed to accept return request',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _markBookCollected(ReturnRequest returnRequest) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Marking book as collected...'),
        backgroundColor: AppColors.primary,
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final returnProvider = Provider.of<ReturnRequestProvider>(
        context,
        listen: false,
      );
      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      final updatedRequest = await returnProvider.markBookCollected(
        int.parse(returnRequest.id),
      );

      if (!mounted) return;

      if (updatedRequest != null) {
        await _loadReturnRequests();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Book marked as collected'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              returnProvider.errorMessage ?? 'Failed to mark book as collected',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _completeReturn(ReturnRequest returnRequest) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Completing return...'),
        backgroundColor: AppColors.primary,
      ),
    );

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final returnProvider = Provider.of<ReturnRequestProvider>(
        context,
        listen: false,
      );
      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
      }

      final success = await returnProvider.completeReturn(
        int.parse(returnRequest.id),
      );

      if (!mounted) return;

      if (success) {
        await _loadReturnRequests();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              returnRequest.hasFine
                  ? 'Return completed. Fine amount: \$${returnRequest.fineAmount.toStringAsFixed(2)}'
                  : 'Return completed successfully',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              returnProvider.errorMessage ?? 'Failed to complete return',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
