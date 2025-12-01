import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_borrowing_provider.dart';
import '../../../../borrow/models/borrow_request.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../widgets/admin_search_bar.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../routes/app_routes.dart';

class BorrowingPage extends StatefulWidget {
  const BorrowingPage({super.key});

  @override
  State<BorrowingPage> createState() => _BorrowingPageState();
}

class _BorrowingPageState extends State<BorrowingPage>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  Timer? _searchDebounceTimer;
  late TabController _tabController;

  // Status tabs as per specification
  final List<String> _statusTabs = [
    'All',
    'Pending',
    'Approved',
    'Borrowed',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Defer loading until after the initial build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRequests();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    final selectedTab = _statusTabs[_tabController.index];
    String? status;

    switch (selectedTab) {
      case 'All':
        status = null;
        break;
      case 'Pending':
        status = 'pending';
        break;
      case 'Approved':
        status = 'approved';
        break;
      case 'Borrowed':
        status = 'active';
        break;
      case 'Rejected':
        status = 'rejected';
        break;
    }

    if (mounted) {
      setState(() {
        _selectedStatus = status;
      });
      _loadRequests();
    }
  }

  Future<void> _loadRequests() async {
    final provider = context.read<AdminBorrowingProvider>();
    final authProvider = context.read<AuthProvider>();

    // Ensure provider has the current token
    if (authProvider.token != null) {
      provider.setToken(authProvider.token!);
      debugPrint(
        'DEBUG: Borrowing page - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
      );
    } else {
      debugPrint(
        'DEBUG: Borrowing page - No token available from AuthProvider',
      );
    }

    // Load borrowings based on current filter
    if (_selectedStatus != null && _selectedStatus != 'All') {
      await provider.loadAllBorrowingsWithStatus(status: _selectedStatus!);
    } else {
      await provider.loadAllBorrowings();
    }
  }

  void _onSearch(String query) {
    debugPrint('DEBUG: Search called with query: "$query"');
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // Set new timer for debounced search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          // Trigger rebuild to apply search filter
        });
      }
    });
  }

  void _onSearchImmediate(String query) {
    debugPrint('DEBUG: Immediate search called with query: "$query"');
    // Update search controller text
    _searchController.text = query;

    // Reset to first page and load immediately
    if (mounted) {
      setState(() {
        // Trigger rebuild to apply search filter
      });
    }
  }

  void _navigateToBorrowingDetails(BorrowRequest request) {
    Navigator.pushNamed(
      context,
      AppRoutes.managerBorrowDetails,
      arguments: request,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrow Requests'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Refresh icon
          IconButton(
            onPressed: () => _loadRequests(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Borrow Requests',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _statusTabs.map((status) => Tab(text: status)).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AdminSearchBar(
              hintText: 'Search borrowing requests...',
              controller: _searchController,
              onChanged: _onSearch,
              onSubmitted: _onSearchImmediate,
            ),
          ),

          // Requests List
          Expanded(
            child: Consumer<AdminBorrowingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.allBorrowings.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null &&
                    provider.allBorrowings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${provider.errorMessage}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            provider.clearError();
                            _loadRequests();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                // Filter requests based on search query
                List<BorrowRequest> filteredRequests = provider.allBorrowings
                    .cast<BorrowRequest>()
                    .where((request) {
                      if (_searchController.text.isEmpty) return true;

                      final searchLower = _searchController.text.toLowerCase();
                      final customerName = (request.customerName ?? '')
                          .toLowerCase();
                      final bookTitle =
                          (request.bookTitle ?? request.book?.title ?? '')
                              .toLowerCase();
                      final requestId = 'request #${request.id}'.toLowerCase();

                      return customerName.contains(searchLower) ||
                          bookTitle.contains(searchLower) ||
                          requestId.contains(searchLower);
                    })
                    .toList();

                if (filteredRequests.isEmpty) {
                  return EmptyState(
                    title: 'No Borrow Requests',
                    message: _getEmptyMessage(),
                    icon: Icons.book_outlined,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: 16.0,
                  ),
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final request = filteredRequests[index];
                    return _buildBorrowingCard(request);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBorrowingCard(BorrowRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToBorrowingDetails(request),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with request number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Request #${request.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  StatusChip(status: request.status),
                ],
              ),
              const SizedBox(height: 12),

              // User name
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'User: ${request.customerName ?? 'Unknown User'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Order date
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Requested: ${_formatDate(request.requestDate)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Expected return date
              Row(
                children: [
                  const Icon(Icons.event, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Expected Return: ${request.dueDate != null ? _formatDate(request.dueDate!) : 'Not set'}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Book title
              Row(
                children: [
                  const Icon(Icons.book, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Book: ${request.bookTitle ?? request.book?.title ?? 'Unknown Book'}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      overflow: TextOverflow.ellipsis,
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

  String _getEmptyMessage() {
    switch (_selectedStatus) {
      case 'pending':
        return 'No pending borrow requests found';
      case 'approved':
        return 'No approved borrow requests found';
      case 'active':
        return 'No active borrowings found';
      case 'rejected':
        return 'No rejected requests found';
      default:
        return 'No borrow requests found';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
