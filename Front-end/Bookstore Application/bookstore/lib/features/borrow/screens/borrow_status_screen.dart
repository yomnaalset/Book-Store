import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../../shared/widgets/error_message.dart';
import '../models/borrowing.dart';
import '../providers/borrow_provider.dart';
import '../../auth/providers/auth_provider.dart';

class BorrowStatusScreen extends StatefulWidget {
  const BorrowStatusScreen({super.key});

  @override
  State<BorrowStatusScreen> createState() => _BorrowStatusScreenState();
}

class _BorrowStatusScreenState extends State<BorrowStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBorrowData();
    });
  }

  Future<void> _loadBorrowData() async {
    final borrowProvider = Provider.of<BorrowProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Ensure provider has the current token
    if (authProvider.token != null) {
      borrowProvider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Borrow status - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
      );
    } else {
      debugPrint('DEBUG: Borrow status - No token available from AuthProvider');
    }

    await borrowProvider.loadBorrowHistory();
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.info; // Blue instead of orange
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
        horizontal: AppDimensions.paddingS,
        vertical: AppDimensions.paddingXS,
      ),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(status).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: AppDimensions.fontSizeXS,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(status),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildBorrowCard(BorrowRequest request) {
    final daysRemaining =
        request.dueDate?.difference(DateTime.now()).inDays ?? 0;
    final isOverdue = daysRemaining < 0;
    final requestDate = _formatDate(request.requestDate);
    final dueDate = request.dueDate != null
        ? _formatDate(request.dueDate!)
        : 'N/A';
    final statusColor = _getStatusColor(request.status);
    final deliveryManager = request.deliveryPerson;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingL),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: statusColor.withValues(alpha: 0.2), width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/borrow-status-detail',
            arguments: {'borrowRequestId': request.id},
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.white, statusColor.withValues(alpha: 0.03)],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header with Request ID and Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.paddingS,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#${request.id}',
                                  style: const TextStyle(
                                    fontSize: AppDimensions.fontSizeXS,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacingS),
                          Text(
                            request.book?.title ?? 'Unknown Book',
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeXL,
                              fontWeight: FontWeight.bold,
                              color: context.textColor,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppDimensions.spacingXS),
                          if (request.book?.authors?.isNotEmpty ?? false)
                            Row(
                              children: [
                                Icon(
                                  Icons.person_outline,
                                  size: 16,
                                  color: context.secondaryTextColor,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    request.book!.authors!.first,
                                    style: TextStyle(
                                      fontSize: AppDimensions.fontSizeM,
                                      color: context.secondaryTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    _buildStatusChip(request.status),
                  ],
                ),

                const SizedBox(height: AppDimensions.spacingL),

                // Book Cover and Key Info Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Book Cover with enhanced styling
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          request.book?.coverImageUrl ?? '',
                          width: 90,
                          height: 135,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
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
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.book,
                                color: AppColors.white,
                                size: 50,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingL),
                    // Key Information
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoItem(
                            Icons.calendar_today_outlined,
                            'Request Date',
                            requestDate,
                          ),
                          const SizedBox(height: AppDimensions.spacingM),
                          if (request.dueDate != null)
                            _buildInfoItem(
                              isOverdue
                                  ? Icons.warning_amber_rounded
                                  : Icons.event_outlined,
                              'Due Date',
                              dueDate,
                              isWarning: isOverdue,
                            ),
                          const SizedBox(height: AppDimensions.spacingM),
                          _buildInfoItem(
                            Icons.access_time_outlined,
                            'Duration',
                            '${request.durationDays} days',
                          ),
                          if (isOverdue &&
                              request.status.toLowerCase() == 'active') ...[
                            const SizedBox(height: AppDimensions.spacingM),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.paddingS,
                                vertical: AppDimensions.paddingXS,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.error.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    color: AppColors.error,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${daysRemaining.abs()} days overdue',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: AppDimensions.fontSizeXS,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // Delivery Manager Section (if assigned)
                if (deliveryManager != null) ...[
                  const SizedBox(height: AppDimensions.spacingL),
                  Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingM),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.info.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.info,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.local_shipping,
                            color: AppColors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Delivery Manager',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeXS,
                                  color: context.secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                deliveryManager.fullName.isNotEmpty
                                    ? deliveryManager.fullName
                                    : 'Assigned',
                                style: TextStyle(
                                  fontSize: AppDimensions.fontSizeM,
                                  color: context.textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (deliveryManager.email.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  deliveryManager.email,
                                  style: TextStyle(
                                    fontSize: AppDimensions.fontSizeXS,
                                    color: context.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Order Status and Timeline Section
                const SizedBox(height: AppDimensions.spacingL),
                Container(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  decoration: BoxDecoration(
                    color: AppColors.greyLight.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: context.secondaryTextColor,
                          ),
                          const SizedBox(width: AppDimensions.spacingS),
                          Text(
                            'Order Status',
                            style: TextStyle(
                              fontSize: AppDimensions.fontSizeS,
                              fontWeight: FontWeight.w600,
                              color: context.textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingS),
                      Text(
                        request.statusDisplay ??
                            request.status.replaceAll('_', ' ').toUpperCase(),
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeM,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      if (request.approvalDate != null ||
                          request.deliveryDate != null ||
                          request.finalReturnDate != null) ...[
                        const SizedBox(height: AppDimensions.spacingM),
                        const Divider(height: 1),
                        const SizedBox(height: AppDimensions.spacingM),
                        Wrap(
                          spacing: AppDimensions.spacingS,
                          runSpacing: AppDimensions.spacingS,
                          children: [
                            if (request.approvalDate != null)
                              _buildDetailChip(
                                Icons.check_circle_outline,
                                'Approved',
                                _formatDate(request.approvalDate!),
                              ),
                            if (request.deliveryDate != null)
                              _buildDetailChip(
                                Icons.local_shipping_outlined,
                                'Delivered',
                                _formatDate(request.deliveryDate!),
                              ),
                            if (request.finalReturnDate != null)
                              _buildDetailChip(
                                Icons.assignment_returned_outlined,
                                'Returned',
                                _formatDate(request.finalReturnDate!),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    IconData icon,
    String label,
    String value, {
    bool isWarning = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isWarning ? AppColors.error : context.secondaryTextColor,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeXS,
                  color: context.secondaryTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeS,
                  color: isWarning ? AppColors.error : context.textColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingS,
        vertical: AppDimensions.paddingXS,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryLight, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: AppDimensions.fontSizeXS,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: AppDimensions.fontSizeXS,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrow Status'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Consumer<BorrowProvider>(
        builder: (context, borrowProvider, child) {
          if (borrowProvider.isLoading) {
            return const LoadingIndicator();
          }

          if (borrowProvider.errorMessage != null) {
            return ErrorMessage(
              message: borrowProvider.errorMessage!,
              onRetry: () => borrowProvider.loadBorrowHistory(),
            );
          }

          final requests = borrowProvider.borrowRequests;

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.library_books_outlined,
                    size: 64,
                    color: context.secondaryTextColor,
                  ),
                  const SizedBox(height: AppDimensions.spacingM),
                  Text(
                    'No borrow requests found',
                    style: TextStyle(
                      fontSize: AppDimensions.fontSizeL,
                      color: context.textColor,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingS),
                  Text(
                    'Your borrow history will appear here',
                    style: TextStyle(
                      fontSize: AppDimensions.fontSizeM,
                      color: context.secondaryTextColor,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => borrowProvider.loadBorrowHistory(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                return _buildBorrowCard(requests[index]);
              },
            ),
          );
        },
      ),
    );
  }
}
