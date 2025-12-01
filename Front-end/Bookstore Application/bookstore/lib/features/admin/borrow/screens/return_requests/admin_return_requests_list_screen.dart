import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../borrow/models/return_request.dart';
import '../../../../borrow/providers/return_request_provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../widgets/admin_search_bar.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../../../routes/app_routes.dart';

class AdminReturnRequestsListScreen extends StatefulWidget {
  const AdminReturnRequestsListScreen({super.key});

  @override
  State<AdminReturnRequestsListScreen> createState() =>
      _AdminReturnRequestsListScreenState();
}

class _AdminReturnRequestsListScreenState
    extends State<AdminReturnRequestsListScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  Timer? _searchDebounceTimer;
  late TabController _tabController;

  // Status tabs
  final List<String> _statusTabs = ['All', 'Requested', 'Approved', 'Assigned'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statusTabs.length, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _onTabChanged(_tabController.index);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReturnRequests();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    final selectedTab = _statusTabs[index];
    String? status;

    switch (selectedTab) {
      case 'All':
        status = null;
        break;
      case 'Requested':
        status = 'PENDING'; // ReturnRequest status, not BorrowRequest status
        break;
      case 'Approved':
        status = 'APPROVED'; // ReturnRequest status
        break;
      case 'Assigned':
        status = 'ASSIGNED'; // ReturnRequest status
        break;
    }

    if (mounted) {
      setState(() {
        _selectedStatus = status;
      });
      _loadReturnRequests();
    }
  }

  Future<void> _loadReturnRequests() async {
    final provider = context.read<ReturnRequestProvider>();
    final authProvider = context.read<AuthProvider>();

    await Future.microtask(() async {
      if (authProvider.token == null || authProvider.token!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      provider.setToken(authProvider.token!);

      debugPrint('Loading return requests with status: $_selectedStatus');
      await provider.loadReturnRequests(
        status: _selectedStatus,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );

      if (mounted) {
        debugPrint('Return requests loaded: ${provider.returnRequests.length}');
        if (provider.errorMessage != null) {
          debugPrint('Error loading return requests: ${provider.errorMessage}');
        }
      }
    });
  }

  void _onSearch(String query) {
    _searchDebounceTimer?.cancel();
    _searchController.text = query;
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadReturnRequests();
      }
    });
  }

  void _onSearchImmediate(String query) {
    _searchController.text = query;
    if (mounted) {
      _loadReturnRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Requests'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _loadReturnRequests(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Requests',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _statusTabs.map((status) => Tab(text: status)).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          onTap: (index) {
            _onTabChanged(index);
          },
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AdminSearchBar(
              hintText: 'Search return requests...',
              controller: _searchController,
              onChanged: _onSearch,
              onSubmitted: _onSearchImmediate,
            ),
          ),

          // Requests List
          Expanded(
            child: Consumer<ReturnRequestProvider>(
              builder: (context, provider, child) {
                // Show loading indicator when loading and no data
                if (provider.isLoading && provider.returnRequests.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Show error message if there's an error and no data
                if (provider.errorMessage != null &&
                    provider.returnRequests.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${provider.errorMessage}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              _loadReturnRequests();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB5E7FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Show empty state when no return requests
                if (provider.returnRequests.isEmpty && !provider.isLoading) {
                  return const EmptyState(
                    title: 'No Return Requests',
                    icon: Icons.assignment_return_outlined,
                    message: 'There are no return requests at the moment.',
                    iconColor: Color(0xFF6C757D),
                    titleStyle: TextStyle(
                      color: Color(0xFF2C3E50),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                    messageStyle: TextStyle(
                      color: Color(0xFF6C757D),
                      fontSize: 14,
                    ),
                  );
                }

                // Show list of return requests
                return RefreshIndicator(
                  onRefresh: _loadReturnRequests,
                  color: const Color(0xFFB5E7FF),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.returnRequests.length,
                    itemBuilder: (context, index) {
                      final returnRequest = provider.returnRequests[index];
                      return _buildReturnRequestCard(returnRequest);
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

  Widget _buildReturnRequestCard(ReturnRequest returnRequest) {
    final borrowRequest = returnRequest.borrowRequest;
    final status = returnRequest.status;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToDetail(returnRequest),
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
                    'Request #${returnRequest.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  StatusChip(status: status),
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
                      'User: ${borrowRequest.customerName?.isNotEmpty == true ? borrowRequest.customerName : (borrowRequest.customer?.fullName.isNotEmpty == true ? borrowRequest.customer!.fullName : 'Unknown User')}',
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

              // Request date
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Requested: ${_formatDate(returnRequest.requestedAt)}',
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
                    'Expected Return: ${borrowRequest.dueDate != null ? _formatDate(borrowRequest.dueDate!) : 'Not set'}',
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
                      'Book: ${(borrowRequest.bookTitle?.isNotEmpty == true) ? borrowRequest.bookTitle : (borrowRequest.book?.title.isNotEmpty == true ? borrowRequest.book!.title : 'Unknown Book')}',
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

  void _navigateToDetail(ReturnRequest returnRequest) {
    Navigator.pushNamed(
      context,
      AppRoutes.adminReturnRequestDetail,
      arguments: int.parse(returnRequest.id),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
