import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../borrow/models/borrow_fine.dart';
import '../../../../borrow/providers/borrowing_provider.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../widgets/admin_search_bar.dart';
import '../../../widgets/library_manager/filters_bar.dart';
import '../../../widgets/empty_state.dart';

class BorrowingFinesScreen extends StatefulWidget {
  const BorrowingFinesScreen({super.key});

  @override
  State<BorrowingFinesScreen> createState() => _BorrowingFinesScreenState();
}

class _BorrowingFinesScreenState extends State<BorrowingFinesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFines();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFines() async {
    final provider = context.read<BorrowingProvider>();
    await provider.loadBorrowingData();
  }

  void _onSearch(String query) {
    _loadFines();
  }

  void _onFilterChanged(String? status) {
    setState(() {
      _selectedStatus = status;
    });
    _loadFines();
  }

  Future<void> _markAsPaid(BorrowFine fine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Fine as Paid'),
        content: const Text('Are you sure you want to mark this fine as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!mounted) return;
        final provider = context.read<BorrowingProvider>();
        await provider.updateFineStatus(fine.id, 'paid');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fine marked as paid successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadFines();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update fine status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _waiveFine(BorrowFine fine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Waive Fine'),
        content: const Text(
          'Are you sure you want to waive this fine? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Waive Fine'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!mounted) return;
        final provider = context.read<BorrowingProvider>();
        await provider.updateFineStatus(fine.id, 'waived');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Fine waived successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadFines();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to waive fine: $e'),
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
        title: const Text('Borrowing Fines'),
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
                  hintText: 'Search fines...',
                  onSubmitted: _onSearch,
                ),
                const SizedBox(height: 16),
                FiltersBar(
                  filterOptions: const ['Unpaid', 'Paid', 'Waived'],
                  selectedFilter: _selectedStatus,
                  onFilterChanged: (filter) {
                    if (filter == 'All') {
                      _onFilterChanged(null);
                    } else {
                      _onFilterChanged(
                        filter?.toLowerCase().replaceAll(' ', '_') ?? '',
                      );
                    }
                  },
                  onClearFilters: () {
                    _onFilterChanged(null);
                  },
                ),
              ],
            ),
          ),

          // Fines List
          Expanded(
            child: Consumer<BorrowingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.fines.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.fines.isEmpty) {
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
                            _loadFines();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.fines.isEmpty) {
                  return const EmptyState(
                    title: 'No Fines',
                    icon: Icons.money_off,
                    message: 'There are no fines at the moment.',
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadFines,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.fines.length,
                    itemBuilder: (context, index) {
                      final fine = provider.fines[index];
                      return _buildFineCard(fine);
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

  Widget _buildFineCard(BorrowFine fine) {
    final isPaid = fine.status == 'paid';
    final isWaived = fine.status == 'waived';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      color: isPaid
          ? Colors.green[50]
          : isWaived
          ? Colors.orange[50]
          : null,
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
                    'Fine #${fine.id}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StatusChip(status: fine.status),
              ],
            ),

            const SizedBox(height: 16),

            // Fine Amount
            Row(
              children: [
                const Icon(Icons.attach_money, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Amount: \$${fine.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Borrow Request ID
            Row(
              children: [
                const Icon(Icons.book, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Borrow Request: #${fine.borrowRequestId}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Reason
            if (fine.reason != null && fine.reason!.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.note, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reason: ${fine.reason!}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Created Date
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Created: ${_formatDate(fine.createdAt)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),

            // Paid Date (if paid)
            if (fine.paidDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Paid: ${_formatDate(fine.paidDate!)}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            // Paid By (if paid)
            if (fine.paidByName != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person, size: 20, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Paid by: ${fine.paidByName}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Action Buttons (only show for unpaid fines)
            if (!isPaid && !isWaived) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _markAsPaid(fine),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Mark as Paid'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _waiveFine(fine),
                      icon: const Icon(Icons.cancel, size: 18),
                      label: const Text('Waive Fine'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: const BorderSide(color: Colors.orange),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
