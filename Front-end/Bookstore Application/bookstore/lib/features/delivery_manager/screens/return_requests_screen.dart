import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../borrow/providers/return_request_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/search_filter_bar.dart';
import 'return_request_detail_screen.dart';

class ReturnRequestsScreen extends StatefulWidget {
  const ReturnRequestsScreen({super.key});

  @override
  State<ReturnRequestsScreen> createState() => _ReturnRequestsScreenState();
}

class _ReturnRequestsScreenState extends State<ReturnRequestsScreen> {
  String _searchQuery = '';
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    // Load return requests when the screen initializes (no filters initially)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReturnRequestsFromServer();
    });
  }

  // Load return requests from server with current filter parameters
  Future<void> _loadReturnRequestsFromServer() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final returnProvider = Provider.of<ReturnRequestProvider>(
      context,
      listen: false,
    );

    // Set the auth token before loading return requests
    if (authProvider.token != null) {
      returnProvider.setToken(authProvider.token!);
    }

    debugPrint(
      'ReturnRequestsScreen: Loading return requests from server with filters - status: $_selectedStatus, search: "$_searchQuery"',
    );

    try {
      await returnProvider.loadReturnRequests(
        status: _selectedStatus,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      debugPrint(
        'ReturnRequestsScreen: Return requests loaded successfully. Count: ${returnProvider.returnRequests.length}',
      );
    } catch (error) {
      debugPrint('ReturnRequestsScreen: Error loading return requests: $error');
    }
  }

  void _onSearchChanged(String query) {
    debugPrint('ReturnRequestsScreen: Search query changed to: "$query"');
    setState(() {
      _searchQuery = query;
    });
    // Reload return requests from server with new search query
    _loadReturnRequestsFromServer();
  }

  void _onFilterChanged(String? status) {
    debugPrint('ReturnRequestsScreen: Status filter changed to: $status');
    setState(() {
      _selectedStatus = status;
    });
    // Reload return requests from server with new status filter
    _loadReturnRequestsFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).returnRequests),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadReturnRequestsFromServer();
            },
          ),
        ],
      ),
      body: Consumer<ReturnRequestProvider>(
        builder: (context, returnProvider, child) {
          if (returnProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (returnProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ErrorMessage(message: returnProvider.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _loadReturnRequestsFromServer();
                    },
                    child: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            );
          }

          // Status filter options for return requests
          // For delivery manager, show ASSIGNED and IN_PROGRESS by default
          final statusFilterOptions = [
            'ASSIGNED',
            'IN_PROGRESS',
            'COMPLETED',
            'PENDING',
            'APPROVED',
          ];

          return Column(
            children: [
              // Search and Filter Bar
              SearchFilterBar(
                searchHint: 'Search return requests...',
                filterLabel: 'Status',
                filterOptions: statusFilterOptions,
                onSearchChanged: _onSearchChanged,
                onFilterChanged: _onFilterChanged,
              ),

              // Return Requests List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadReturnRequestsFromServer();
                  },
                  child: returnProvider.returnRequests.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.undo_outlined,
                                size: 64,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedStatus != null
                                    ? 'No matching return requests found'
                                    : AppLocalizations.of(
                                        context,
                                      ).noReturnRequests,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _searchQuery.isNotEmpty ||
                                        _selectedStatus != null
                                    ? 'Try adjusting your search or filter criteria'
                                    : AppLocalizations.of(
                                        context,
                                      ).noReturnRequestsDescription,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: returnProvider.returnRequests.length,
                          itemBuilder: (context, index) {
                            final returnRequest =
                                returnProvider.returnRequests[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(
                                  'Return Request #${returnRequest.id}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      'Book: ${returnRequest.borrowRequest.bookTitle ?? 'N/A'}',
                                    ),
                                    Text(
                                      'Customer: ${returnRequest.borrowRequest.customerName ?? 'N/A'}',
                                    ),
                                    Text(
                                      'Status: ${returnRequest.statusDisplay}',
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ReturnRequestDetailScreen(
                                            returnRequest: returnRequest,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            );
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
}
