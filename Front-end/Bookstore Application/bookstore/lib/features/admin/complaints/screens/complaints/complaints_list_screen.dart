import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/complaints_provider.dart';
import '../../../models/complaint.dart';
import '../../../widgets/library_manager/admin_search_bar.dart';
import '../../../widgets/library_manager/filters_bar.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/localization/app_localizations.dart';
import 'complaint_detail_screen.dart';

class ComplaintsListScreen extends StatefulWidget {
  const ComplaintsListScreen({super.key});

  @override
  State<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends State<ComplaintsListScreen> {
  String _searchQuery = '';
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    // Defer loading until after the first frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComplaints();
    });
  }

  Future<void> _loadComplaints() async {
    if (!mounted) return;

    // Check authentication first
    final authProvider = context.read<AuthProvider>();
    developer.log(
      'ComplaintsListScreen: User authenticated: ${authProvider.isAuthenticated}',
    );
    developer.log('ComplaintsListScreen: User role: ${authProvider.userRole}');
    developer.log(
      'ComplaintsListScreen: Token available: ${authProvider.token != null}',
    );

    if (!authProvider.isAuthenticated) {
      developer.log(
        'ComplaintsListScreen: User not authenticated, redirecting to login',
      );
      // You might want to redirect to login here
      return;
    }

    if (authProvider.userRole != 'library_admin' &&
        authProvider.userRole != 'system_admin' &&
        authProvider.userRole != 'delivery_admin') {
      developer.log(
        'ComplaintsListScreen: User does not have permission to view complaints',
      );
      // You might want to show an error message here
      return;
    }

    if (!mounted) return;

    final provider = context.read<ComplaintsProvider>();
    try {
      await provider.getComplaints(
        search: _searchQuery.isEmpty ? null : _searchQuery,
        status: _selectedStatus,
        // priority: _selectedPriority, // Temporarily commented out due to linter issue
      );
    } catch (e) {
      developer.log('ComplaintsListScreen: Exception loading complaints: $e');
      // Error is already handled in the provider, just log it
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadComplaints();
  }

  void _onStatusFilterChanged(String? filter) {
    setState(() {
      _selectedStatus = filter;
    });
    _loadComplaints();
  }

  void _navigateToComplaintDetails(Complaint complaint) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintDetailScreen(complaint: complaint),
      ),
    );

    // Refresh complaints list if complaint was updated
    if (result == true && mounted) {
      _loadComplaints();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.complaints),
        actions: [
          IconButton(
            onPressed: () => _loadComplaints(),
            icon: const Icon(Icons.refresh),
            tooltip: localizations.refresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Column(
                  children: [
                    AdminSearchBar(
                      hintText: localizations.searchComplaints,
                      onSubmitted: _onSearch,
                    ),
                    const SizedBox(height: 16),
                    FiltersBar(
                      filterOptions: [
                        localizations.open,
                        localizations.inProgress,
                        localizations.resolved,
                      ],
                      selectedFilter: _convertStatusToDisplay(
                        _selectedStatus,
                        localizations,
                      ),
                      onFilterChanged: (filter) {
                        _onStatusFilterChanged(
                          _convertDisplayToStatus(filter, localizations),
                        );
                      },
                      onClearFilters: () => _onStatusFilterChanged(null),
                    ),
                  ],
                );
              },
            ),
          ),

          // Complaints List
          Expanded(
            child: Consumer<ComplaintsProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.complaints.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.complaints.isEmpty) {
                  return Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                localizations.errorLoadingComplaints,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                provider.error ?? localizations.unknownError,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  provider.clearError();
                                  _loadComplaints();
                                },
                                icon: const Icon(Icons.refresh),
                                label: Text(localizations.retry),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }

                if (provider.complaints.isEmpty) {
                  return Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return EmptyState(
                        title: localizations.noComplaints,
                        message: localizations.noComplaintsFound,
                        icon: Icons.report_problem,
                        actionText: localizations.refresh,
                        onAction: _loadComplaints,
                      );
                    },
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: provider.complaints.length,
                  itemBuilder: (context, index) {
                    final complaint = provider.complaints[index];
                    return _buildComplaintCard(complaint);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplaintCard(Complaint complaint) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () => _navigateToComplaintDetails(complaint),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with ID and Status
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          localizations.complaintNumber(complaint.id),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      StatusChip(status: complaint.status),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),

              // Subject
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  String displayTitle = complaint.title;
                  // Translate common complaint titles
                  final titleLower = complaint.title.toLowerCase();
                  if (titleLower.contains('complaint about the app') ||
                      titleLower.contains('complaint about app')) {
                    displayTitle = localizations.complaintAboutTheApp;
                  }
                  return Text(
                    displayTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              const SizedBox(height: 8),

              // Description
              Text(
                complaint.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),

              // Customer Info
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        complaint.customerName ?? localizations.unknown,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.email,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        complaint.customerEmail ?? localizations.unknown,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date
              Row(
                children: [
                  const Spacer(),
                  Text(
                    _formatDate(complaint.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String? _convertStatusToDisplay(
    String? status,
    AppLocalizations localizations,
  ) {
    if (status == null) return null;
    switch (status) {
      case 'open':
        return localizations.open;
      case 'in_progress':
        return localizations.inProgress;
      case 'resolved':
        return localizations.resolved;
      case 'closed':
        return localizations.closed;
      default:
        return status;
    }
  }

  String? _convertDisplayToStatus(
    String? display,
    AppLocalizations localizations,
  ) {
    if (display == null) return null;
    if (display == localizations.open) return 'open';
    if (display == localizations.inProgress) return 'in_progress';
    if (display == localizations.resolved) return 'resolved';
    if (display == localizations.closed) return 'closed';
    return display.toLowerCase().replaceAll(' ', '_');
  }
}
