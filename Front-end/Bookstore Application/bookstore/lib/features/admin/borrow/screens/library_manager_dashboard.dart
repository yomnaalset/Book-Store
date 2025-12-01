import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../borrow/models/borrow_request.dart';
import '../../../admin/providers/admin_borrowing_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class LibraryManagerBorrowingDashboard extends StatefulWidget {
  const LibraryManagerBorrowingDashboard({super.key});

  @override
  State<LibraryManagerBorrowingDashboard> createState() =>
      _LibraryManagerBorrowingDashboardState();
}

class _LibraryManagerBorrowingDashboardState
    extends State<LibraryManagerBorrowingDashboard>
    with TickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final provider = Provider.of<AdminBorrowingProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token != null) {
      provider.setToken(authProvider.token!);
      provider.loadPendingRequests();
      provider.loadOverdueBorrowings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrowing Management'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: TabController(length: 3, vsync: this, initialIndex: 0),
          onTap: (index) {
            // Tab selection handled by TabController
          },
          tabs: const [
            Tab(text: 'Pending Requests'),
            Tab(text: 'Overdue'),
            Tab(text: 'All Borrowings'),
          ],
        ),
      ),
      body: Consumer<AdminBorrowingProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const LoadingIndicator();
          }

          return TabBarView(
            children: [
              _buildPendingRequestsTab(provider),
              _buildOverdueTab(provider),
              _buildAllBorrowingsTab(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPendingRequestsTab(AdminBorrowingProvider provider) {
    if (provider.pendingRequests.isEmpty) {
      return const EmptyState(
        message: 'No pending borrowing requests',
        icon: Icons.pending_actions,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: provider.pendingRequests.length,
      itemBuilder: (context, index) {
        final request = provider.pendingRequests[index];
        return _buildRequestCard(request, provider);
      },
    );
  }

  Widget _buildOverdueTab(AdminBorrowingProvider provider) {
    if (provider.overdueBorrowings.isEmpty) {
      return const EmptyState(
        message: 'No overdue borrowings',
        icon: Icons.schedule,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: provider.overdueBorrowings.length,
      itemBuilder: (context, index) {
        final request = provider.overdueBorrowings[index];
        return _buildOverdueCard(request, provider);
      },
    );
  }

  Widget _buildAllBorrowingsTab(AdminBorrowingProvider provider) {
    if (provider.allBorrowings.isEmpty) {
      return const EmptyState(
        message: 'No borrowing records found',
        icon: Icons.book,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: provider.allBorrowings.length,
      itemBuilder: (context, index) {
        final request = provider.allBorrowings[index];
        return _buildBorrowingCard(request, provider);
      },
    );
  }

  Widget _buildRequestCard(
    BorrowRequest request,
    AdminBorrowingProvider provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.book?.title ?? 'Unknown Book',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                      Text(
                        'Customer: ${request.customerName ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Duration: ${request.durationDays} days',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Requested: ${request.requestDate.day}/${request.requestDate.month}/${request.requestDate.year}',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: request.status),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Approve',
                    onPressed: () => _approveRequest(request, provider),
                    backgroundColor: AppColors.success,
                    textColor: AppColors.white,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: CustomButton(
                    text: 'Reject',
                    onPressed: () => _rejectRequest(request, provider),
                    backgroundColor: AppColors.error,
                    textColor: AppColors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverdueCard(
    BorrowRequest request,
    AdminBorrowingProvider provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.book?.title ?? 'Unknown Book',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                      Text(
                        'Customer: ${request.customerName ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Due Date: ${request.dueDate?.day}/${request.dueDate?.month}/${request.dueDate?.year ?? 'N/A'}',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (request.fineAmount != null)
                        Text(
                          'Fine: \$${request.fineAmount!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: AppDimensions.fontSizeS,
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                const StatusChip(status: 'late'),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),
            CustomButton(
              text: 'Send Reminder',
              onPressed: () => _sendReminder(request, provider),
              backgroundColor: AppColors.warning,
              textColor: AppColors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBorrowingCard(
    BorrowRequest request,
    AdminBorrowingProvider provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.book?.title ?? 'Unknown Book',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                      Text(
                        'Customer: ${request.customerName ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Status: ${_getStatusText(request.status)}',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'Requested: ${request.requestDate.day}/${request.requestDate.month}/${request.requestDate.year}',
                        style: const TextStyle(
                          fontSize: AppDimensions.fontSizeS,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: request.status),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _approveRequest(
    BorrowRequest request,
    AdminBorrowingProvider provider,
  ) async {
    final success = await provider.approveRequest(request.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        provider.loadPendingRequests();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to approve request'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _rejectRequest(BorrowRequest request, AdminBorrowingProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => _RejectRequestDialog(
        request: request,
        onReject: (reason) async {
          final success = await provider.rejectRequest(request.id, reason);

          if (mounted && dialogContext.mounted) {
            Navigator.pop(dialogContext);
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request rejected successfully!'),
                  backgroundColor: AppColors.success,
                ),
              );
              provider.loadPendingRequests();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    provider.errorMessage ?? 'Failed to reject request',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _sendReminder(
    BorrowRequest request,
    AdminBorrowingProvider provider,
  ) async {
    final success = await provider.sendReminder(request.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder sent successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to send reminder'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Under Review';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'awaiting_pickup':
        return 'Awaiting Pickup';
      case 'pending_delivery':
        return 'Pending Delivery';
      case 'delivered':
        return 'Delivered';
      case 'active':
        return 'Active';
      case 'return_requested':
        return 'Return Requested';
      case 'returned':
        return 'Returned';
      case 'late':
        return 'Late';
      default:
        return 'Unknown';
    }
  }
}

class _RejectRequestDialog extends StatefulWidget {
  final BorrowRequest request;
  final Function(String) onReject;

  const _RejectRequestDialog({required this.request, required this.onReject});

  @override
  State<_RejectRequestDialog> createState() => _RejectRequestDialogState();
}

class _RejectRequestDialogState extends State<_RejectRequestDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject Borrowing Request'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Book: ${widget.request.book?.title ?? 'Unknown'}'),
          const SizedBox(height: AppDimensions.spacingM),
          const Text('Please provide a reason for rejection:'),
          const SizedBox(height: AppDimensions.spacingS),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'Enter rejection reason...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_reasonController.text.trim().isNotEmpty) {
              widget.onReject(_reasonController.text.trim());
            }
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
