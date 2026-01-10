import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../providers/borrow_provider.dart';
import '../models/borrow_request.dart';
import '../models/borrow_extension.dart';
import '../models/borrow_fine.dart';

class BorrowManagementScreen extends StatefulWidget {
  const BorrowManagementScreen({super.key});

  @override
  State<BorrowManagementScreen> createState() => _BorrowManagementScreenState();
}

class _BorrowManagementScreenState extends State<BorrowManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _selectedFilter = 'all';
  String _selectedSortBy = 'newest';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Borrow Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'Active Loans', icon: Icon(Icons.book_outlined)),
            Tab(text: 'Requests', icon: Icon(Icons.pending_actions)),
            Tab(text: 'Extensions', icon: Icon(Icons.schedule)),
            Tab(text: 'Fines', icon: Icon(Icons.warning)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            color: AppColors.background,
            child: Column(
              children: [
                // Search Field
                CustomTextField(
                  controller: _searchController,
                  label: 'Search',
                  hint: 'Search by user, book, or ID',
                  prefixIcon: const Icon(Icons.search),
                  onChanged: _filterData,
                ),
                const SizedBox(height: AppDimensions.spacingM),

                // Filter and Sort Row
                Row(
                  children: [
                    // Filter Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingM,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFilter,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('All'),
                              ),
                              DropdownMenuItem(
                                value: 'overdue',
                                child: Text('Overdue'),
                              ),
                              DropdownMenuItem(
                                value: 'due_soon',
                                child: Text('Due Soon'),
                              ),
                              DropdownMenuItem(
                                value: 'extended',
                                child: Text('Extended'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedFilter = value!;
                              });
                              _filterData(_searchController.text);
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingM),

                    // Sort Dropdown
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingM,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedSortBy,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(
                                value: 'newest',
                                child: Text('Newest'),
                              ),
                              DropdownMenuItem(
                                value: 'oldest',
                                child: Text('Oldest'),
                              ),
                              DropdownMenuItem(
                                value: 'due_date',
                                child: Text('Due Date'),
                              ),
                              DropdownMenuItem(
                                value: 'user',
                                child: Text('User'),
                              ),
                              DropdownMenuItem(
                                value: 'book',
                                child: Text('Book'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedSortBy = value!;
                              });
                              _filterData(_searchController.text);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveLoansTab(),
                _buildRequestsTab(),
                _buildExtensionsTab(),
                _buildFinesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveLoansTab() {
    return Consumer<BorrowProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: LoadingIndicator());
        }

        final activeLoans = provider.activeBorrows;
        if (activeLoans.isEmpty) {
          return _buildEmptyState(
            icon: Icons.book_outlined,
            title: 'No Active Loans',
            message: 'There are currently no active book loans.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          itemCount: activeLoans.length,
          itemBuilder: (context, index) {
            final loan = activeLoans[index];
            return _buildLoanCard(loan);
          },
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return Consumer<BorrowProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: LoadingIndicator());
        }

        final requests = provider.borrowRequests;
        if (requests.isEmpty) {
          return _buildEmptyState(
            icon: Icons.pending_actions,
            title: 'No Pending Requests',
            message: 'There are currently no pending borrow requests.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildRequestCard(request);
          },
        );
      },
    );
  }

  Widget _buildExtensionsTab() {
    return Consumer<BorrowProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: LoadingIndicator());
        }

        final extensions = provider.borrowExtensions;
        if (extensions.isEmpty) {
          return _buildEmptyState(
            icon: Icons.schedule,
            title: 'No Extensions',
            message: 'There are currently no loan extensions.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          itemCount: extensions.length,
          itemBuilder: (context, index) {
            final extension = extensions[index];
            return _buildExtensionCard(extension);
          },
        );
      },
    );
  }

  Widget _buildFinesTab() {
    return Consumer<BorrowProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: LoadingIndicator());
        }

        final fines = provider.borrowFines;
        if (fines.isEmpty) {
          return _buildEmptyState(
            icon: Icons.warning,
            title: 'No Fines',
            message: 'There are currently no outstanding fines.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          itemCount: fines.length,
          itemBuilder: (context, index) {
            final fine = fines[index];
            return _buildFineCard(fine);
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppColors.textHint),
          const SizedBox(height: AppDimensions.spacingL),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanCard(BorrowRequest loan) {
    final isOverdue = loan.dueDate?.isBefore(DateTime.now()) ?? false;
    final minutesUntilDue =
        loan.dueDate?.difference(DateTime.now()).inMinutes ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: InkWell(
        onTap: () => _viewLoanDetails(loan),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      loan.book?.title ?? 'Unknown Book',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isOverdue ? AppColors.error : AppColors.success,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isOverdue ? 'Overdue' : 'Active',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingS),
              Text('Borrower ID: ${loan.userId}'),
              Text('Author: ${loan.book?.author ?? 'Unknown'}'),
              Text('Requested: ${_formatDate(loan.requestDate)}'),
              Text(
                'Due: ${loan.dueDate != null ? _formatDate(loan.dueDate!) : 'Not set'}',
              ),
              if (isOverdue)
                Text(
                  'Overdue by ${minutesUntilDue.abs()} minutes',
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else if (minutesUntilDue <= 180) // 3 hours = 180 minutes
                Text(
                  'Due in $minutesUntilDue minutes',
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: AppDimensions.spacingM),
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'View Details',
                      onPressed: () => _viewLoanDetails(loan),
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: CustomButton(
                      text: 'Return',
                      onPressed: () => _returnBook(loan),
                      backgroundColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: CustomButton(
                      text: 'Extend',
                      onPressed: () => _extendLoan(loan),
                      backgroundColor: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(BorrowRequest request) {
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
                  child: Text(
                    request.book?.title ?? 'Unknown Book',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getRequestStatusColor(request.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text('Requester ID: ${request.userId}'),
            Text('Author: ${request.book?.author ?? 'Unknown'}'),
            Text('Requested: ${_formatDate(request.requestDate)}'),
            Text('Duration: ${request.durationDays} days'),
            if (request.notes != null) Text('Notes: ${request.notes}'),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Approve',
                    onPressed: () => _approveRequest(request),
                    backgroundColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: CustomButton(
                    text: 'Reject',
                    onPressed: () => _rejectRequest(request),
                    backgroundColor: AppColors.error,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: CustomButton(
                    text: 'View',
                    onPressed: () => _viewRequestDetails(request),
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExtensionCard(BorrowExtension extension) {
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
                  child: Text(
                    'Extension Request #${extension.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getExtensionStatusColor(extension.status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    extension.status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text('Borrower ID: ${extension.userId}'),
            Text('Requested: ${_formatDate(extension.requestDate)}'),
            Text(
              'Extension Period: ${extension.newDueDate.difference(extension.originalDueDate).inDays} days',
            ),
            Text('New Due Date: ${_formatDate(extension.newDueDate)}'),
            if (extension.reason != null) Text('Reason: ${extension.reason}'),
            const SizedBox(height: AppDimensions.spacingM),
            Row(
              children: [
                Expanded(
                  child: CustomButton(
                    text: 'Approve',
                    onPressed: () => _approveExtension(extension),
                    backgroundColor: AppColors.success,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: CustomButton(
                    text: 'Reject',
                    onPressed: () => _rejectExtension(extension),
                    backgroundColor: AppColors.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFineCard(BorrowFine fine) {
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
                  child: Text(
                    'Fine #${fine.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fine.paidAt != null
                        ? AppColors.success
                        : AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    fine.paidAt != null ? 'PAID' : 'UNPAID',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text('Borrower ID: ${fine.userId}'),
            Text('Amount: \$${fine.amount.toStringAsFixed(2)}'),
            Text('Reason: ${fine.reason}'),
            Text('Created: ${_formatDate(fine.createdAt)}'),
            if (fine.paidAt != null) Text('Paid: ${_formatDate(fine.paidAt!)}'),
            const SizedBox(height: AppDimensions.spacingM),
            if (fine.paidAt == null)
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: 'Mark as Paid',
                      onPressed: () => _markFineAsPaid(fine),
                      backgroundColor: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: CustomButton(
                      text: 'View Details',
                      onPressed: () => _viewFineDetails(fine),
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getRequestStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  Color _getExtensionStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warning;
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _viewLoanDetails(BorrowRequest loan) {
    Navigator.pushNamed(
      context,
      '/borrow-status-detail',
      arguments: {'borrowRequestId': loan.id},
    );
  }

  void _returnBook(BorrowRequest loan) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Return Book'),
        content: Text('Mark "${loan.book?.title}" as returned?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Return book feature coming soon!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            child: const Text('Return'),
          ),
        ],
      ),
    );
  }

  void _extendLoan(BorrowRequest loan) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Extend loan feature coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _approveRequest(BorrowRequest request) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Approve request feature coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _rejectRequest(BorrowRequest request) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reject request feature coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _viewRequestDetails(BorrowRequest request) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request details feature coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _approveExtension(BorrowExtension extension) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Approve extension feature coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _rejectExtension(BorrowExtension extension) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reject extension feature coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _markFineAsPaid(BorrowFine fine) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mark fine as paid feature coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _viewFineDetails(BorrowFine fine) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fine details feature coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _loadData() async {
    final provider = Provider.of<BorrowProvider>(context, listen: false);
    await provider.loadActiveBorrows();
    await provider.loadBorrowHistory();
    await provider.loadBorrowExtensions();
    await provider.loadBorrowFines();
  }

  void _filterData(String query) {}
}
