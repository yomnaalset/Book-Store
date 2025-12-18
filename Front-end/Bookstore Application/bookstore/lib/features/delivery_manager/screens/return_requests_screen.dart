import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../borrow/providers/return_request_provider.dart';
import '../../borrow/models/return_request.dart';
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
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return SearchFilterBar(
                    initialSearchQuery: _searchQuery,
                    initialFilterValue: _selectedStatus,
                    searchHint: localizations.searchReturnRequests,
                    filterLabel: localizations.status,
                    filterOptions: statusFilterOptions,
                    onSearchChanged: _onSearchChanged,
                    onFilterChanged: _onFilterChanged,
                  );
                },
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
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Column(
                                    children: [
                                      Text(
                                        _searchQuery.isNotEmpty ||
                                                _selectedStatus != null
                                            ? localizations
                                                  .noMatchingReturnRequests
                                            : localizations.noReturnRequests,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _searchQuery.isNotEmpty ||
                                                _selectedStatus != null
                                            ? localizations
                                                  .tryAdjustingSearchOrFilterReturn
                                            : localizations
                                                  .noReturnRequestsDescription,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  );
                                },
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
                            return _buildReturnRequestCard(
                              context,
                              returnRequest,
                              theme,
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

  Widget _buildReturnRequestCard(
    BuildContext context,
    ReturnRequest returnRequest,
    ThemeData theme,
  ) {
    // Get status color
    Color statusColor;
    switch (returnRequest.status) {
      case 'IN_PROGRESS':
        statusColor = Colors.blue;
        break;
      case 'COMPLETED':
        statusColor = Colors.green;
        break;
      case 'PENDING':
        statusColor = Colors.orange;
        break;
      case 'APPROVED':
        statusColor = Colors.teal;
        break;
      case 'ASSIGNED':
        statusColor = Colors.purple;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ReturnRequestDetailScreen(returnRequest: returnRequest),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Content Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Book Name
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              returnRequest.borrowRequest.bookTitle ??
                                  localizations.unknownBook,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            // Customer Name
                            Text(
                              '${localizations.customer}: ${returnRequest.borrowRequest.customerName ?? localizations.unknown}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Fine Information (if fine exists)
                            if (returnRequest.fineAmount > 0) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      size: 14,
                                      color: Colors.orange,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Fine: \$${returnRequest.fineAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${AppLocalizations.of(context).status}: ${AppLocalizations.of(context).getReturnRequestStatusLabel(returnRequest.status)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow Icon
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
