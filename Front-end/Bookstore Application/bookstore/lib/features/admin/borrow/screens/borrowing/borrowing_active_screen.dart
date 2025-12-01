import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../borrow/models/borrow_request.dart';
import '../../../../borrow/providers/borrowing_provider.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../widgets/admin_search_bar.dart';
import '../../../widgets/library_manager/filters_bar.dart';
import '../../../widgets/empty_state.dart';

class BorrowingActiveScreen extends StatefulWidget {
  const BorrowingActiveScreen({super.key});

  @override
  State<BorrowingActiveScreen> createState() => _BorrowingActiveScreenState();
}

class _BorrowingActiveScreenState extends State<BorrowingActiveScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadActiveBorrowings();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadActiveBorrowings() {
    final provider = context.read<BorrowingProvider>();
    provider.getActiveBorrowings();
  }

  void _onSearch(String query) {
    _loadActiveBorrowings();
  }

  void _onFilterChanged(String? status) {
    setState(() {
      _selectedStatus = status;
    });
    _loadActiveBorrowings();
  }

  Future<void> _confirmReturn(BorrowRequest borrowing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Book Return'),
        content: const Text(
          'Are you sure you want to confirm the return of this book?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm Return'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!mounted) return;
        final provider = context.read<BorrowingProvider>();
        await provider.confirmBookReturn(borrowing.id.toString());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Book return confirmed successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadActiveBorrowings();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to confirm return: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Borrowings'),
        backgroundColor: const Color(0xFFB5E7FF),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search and Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                AdminSearchBar(
                  hintText: 'Search borrowings...',
                  onChanged: (value) => _onSearch(value),
                ),
                const SizedBox(height: 16),
                FiltersBar(
                  filterOptions: const ['Active', 'Extended', 'Overdue'],
                  selectedFilter: _selectedStatus,
                  onFilterChanged: (filter) {
                    if (filter == 'All') {
                      _onFilterChanged(null);
                    } else {
                      _onFilterChanged(
                        filter!.toLowerCase().replaceAll(' ', '_'),
                      );
                    }
                  },
                  onClearFilters: () => _onFilterChanged(null),
                ),
              ],
            ),
          ),

          // Active Borrowings List
          Expanded(
            child: Consumer<BorrowingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.activeBorrowings == 0) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.activeBorrowings == 0) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            provider.clearError();
                            _loadActiveBorrowings();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.activeBorrowings == 0) {
                  return const EmptyState(
                    title: 'No Active Borrowings',
                    icon: Icons.book_outlined,
                    message: 'There are no active borrowings at the moment.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadActiveBorrowings(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.borrowRequests.length,
                    itemBuilder: (context, index) {
                      final borrowing = provider.borrowRequests[index];
                      return _buildBorrowingCard(borrowing);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowingCard(BorrowRequest borrowing) {
    final isOverdue = borrowing.isOverdue;
    final daysRemaining = borrowing.finalReturnDate != null
        ? borrowing.finalReturnDate!.difference(DateTime.now()).inDays
        : borrowing.requestDate.difference(DateTime.now()).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: isOverdue ? Colors.red[50] : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Borrowing #${borrowing.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StatusChip(status: borrowing.status),
                if (isOverdue)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'OVERDUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Customer Information
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    borrowing.customerName ?? 'Unknown Customer',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Book Information
            Row(
              children: [
                const Icon(Icons.book, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    borrowing.book?.title ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Borrow Date
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Borrowed: ${_formatDate(borrowing.requestDate)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Return Date
            Row(
              children: [
                const Icon(Icons.event, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Expected Return: ${_formatDate(borrowing.finalReturnDate ?? borrowing.requestDate.add(const Duration(days: 7)))}',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : Colors.grey,
                    fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),

            if (daysRemaining > 0 && !isOverdue) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '$daysRemaining days remaining',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            if (isOverdue) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.warning, size: 20, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(
                    '${daysRemaining.abs()} days overdue',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmReturn(borrowing),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Confirm Return'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
