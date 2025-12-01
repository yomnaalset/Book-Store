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
import 'complaint_detail_screen.dart';

class ComplaintsListScreen extends StatefulWidget {
  const ComplaintsListScreen({super.key});

  @override
  State<ComplaintsListScreen> createState() => _ComplaintsListScreenState();
}

class _ComplaintsListScreenState extends State<ComplaintsListScreen> {
  String _searchQuery = '';
  String? _selectedStatus;
  String? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  Future<void> _loadComplaints() async {
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

    final provider = context.read<ComplaintsProvider>();
    await provider.getComplaints(
      search: _searchQuery.isEmpty ? null : _searchQuery,
      status: _selectedStatus,
      // priority: _selectedPriority, // Temporarily commented out due to linter issue
    );
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

  void _onPriorityFilterChanged(String? filter) {
    setState(() {
      _selectedPriority = filter;
    });
    _loadComplaints();
  }

  void _navigateToComplaintDetails(Complaint complaint) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComplaintDetailScreen(complaint: complaint),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints'),
        actions: [
          IconButton(
            onPressed: () => _loadComplaints(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                AdminSearchBar(
                  hintText: 'Search complaints...',
                  onSubmitted: _onSearch,
                ),
                const SizedBox(height: 16),
                FiltersBar(
                  filterOptions: const [
                    'Open',
                    'In Progress',
                    'Resolved',
                    'Closed',
                  ],
                  selectedFilter: _selectedStatus,
                  onFilterChanged: (filter) {
                    _onStatusFilterChanged(
                      filter?.toLowerCase().replaceAll(' ', '_'),
                    );
                  },
                  onClearFilters: () => _onStatusFilterChanged(null),
                ),
                FiltersBar(
                  filterOptions: const ['Low', 'Medium', 'High', 'Urgent'],
                  selectedFilter: _selectedPriority,
                  onFilterChanged: (filter) {
                    if (filter == 'All') {
                      _onPriorityFilterChanged(null);
                    } else {
                      _onPriorityFilterChanged(
                        filter?.toLowerCase().replaceAll(' ', '_'),
                      );
                    }
                  },
                  onClearFilters: () => _onPriorityFilterChanged(null),
                ),
              ],
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${provider.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadComplaints,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.complaints.isEmpty) {
                  return EmptyState(
                    title: 'No Complaints',
                    message: 'No complaints found',
                    icon: Icons.report_problem,
                    actionText: 'Refresh',
                    onAction: _loadComplaints,
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Complaint #${complaint.id}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  StatusChip(status: complaint.status),
                ],
              ),
              const SizedBox(height: 8),

              // Subject
              Text(
                complaint.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
                  Text(
                    complaint.customerName ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.email,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    complaint.customerEmail ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Priority and Date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(complaint.priority),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      complaint.priority.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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

              // Assigned To
              if (complaint.assignedTo != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.assignment_ind,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Assigned to: ${complaint.assignedTo}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.yellow;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
