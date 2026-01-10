import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../borrow/models/borrow_request.dart';
import '../../../providers/admin_borrowing_provider.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../widgets/admin_search_bar.dart';
import '../../../widgets/empty_state.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/localization/app_localizations.dart';
import 'borrowing_request_detail_screen.dart';

class BorrowingRequestsScreen extends StatefulWidget {
  const BorrowingRequestsScreen({super.key});

  @override
  State<BorrowingRequestsScreen> createState() =>
      _BorrowingRequestsScreenState();
}

class _BorrowingRequestsScreenState extends State<BorrowingRequestsScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  Timer? _searchDebounceTimer;
  late TabController _tabController;
  List<BorrowRequest> _allRequests = [];
  List<BorrowRequest> _filteredRequests = [];

  // Status tabs - will be localized in build method
  List<String> _getStatusTabs(AppLocalizations localizations) => [
    localizations.all,
    localizations.pending,
    localizations.approved,
    localizations.borrowed,
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with default length, will be updated in build
    _tabController = TabController(length: 4, vsync: this);

    // Add listener to TabController
    _tabController.addListener(() {
      debugPrint(
        'DEBUG: TabController listener triggered with index: ${_tabController.index}, indexIsChanging: ${_tabController.indexIsChanging}',
      );
      // Always call _onTabChanged when the index changes
      if (!_tabController.indexIsChanging && mounted) {
        final localizations = AppLocalizations.of(context);
        _onTabChanged(_tabController.index, localizations);
      }
    });

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

  void _onTabChanged(int index, AppLocalizations localizations) {
    final statusTabs = _getStatusTabs(localizations);
    final selectedTab = statusTabs[index];
    String? status;

    debugPrint('DEBUG: Tab changed to: $selectedTab (index: $index)');

    // Compare with localized strings
    if (selectedTab == localizations.all) {
      status = null;
    } else if (selectedTab == localizations.pending) {
      status = 'pending';
    } else if (selectedTab == localizations.approved) {
      status = 'approved';
    } else if (selectedTab == localizations.borrowed) {
      status = 'active';
    }

    debugPrint('DEBUG: Selected status: $status');

    if (mounted) {
      setState(() {
        _selectedStatus = status;
      });
      // Load requests with the new status filter
      _loadRequests();
    }
  }

  Future<void> _loadRequests() async {
    // Capture context before async operation
    final provider = context.read<AdminBorrowingProvider>();
    final authProvider = context.read<AuthProvider>();

    // Use a microtask to ensure this runs after the current build phase
    await Future.microtask(() async {
      // Ensure provider has the current token
      if (authProvider.token == null || authProvider.token!.isEmpty) {
        debugPrint(
          'DEBUG: Borrowing requests - No token available from AuthProvider',
        );
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
      debugPrint(
        'DEBUG: Borrowing requests - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
      );

      // Load borrowings with filters
      final backendStatus = _mapStatusToBackend(_selectedStatus);
      await provider.loadAllBorrowingsWithFilters(
        status: backendStatus,
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
      );

      // Update local state
      if (mounted) {
        setState(() {
          _allRequests = provider.allBorrowings;
          _filteredRequests = _allRequests;
        });
      }
    });
  }

  void _onSearch(String query) {
    debugPrint('DEBUG: Search called with query: "$query"');
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // Update search controller text
    _searchController.text = query;

    // Set new timer for debounced search
    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadRequests();
      }
    });
  }

  void _onSearchImmediate(String query) {
    debugPrint('DEBUG: Immediate search called with query: "$query"');
    // Update search controller text
    _searchController.text = query;

    // Reset to first page and load immediately
    if (mounted) {
      _loadRequests();
    }
  }

  String? _mapStatusToBackend(String? frontendStatus) {
    if (frontendStatus == null || frontendStatus == 'All') {
      return null;
    }

    // Map frontend display names to backend status values
    switch (frontendStatus.toLowerCase()) {
      case 'pending':
        return 'pending';
      case 'approved':
        return 'approved';
      case 'rejected':
        return 'rejected';
      case 'active':
        return 'active';
      case 'delivered':
        return 'delivered';
      case 'returned':
        return 'returned';
      case 'overdue':
        return 'overdue';
      default:
        return frontendStatus.toLowerCase();
    }
  }

  Future<void> _approveRequest(BorrowRequest request) async {
    final provider = context.read<AdminBorrowingProvider>();

    // Load delivery managers first
    await provider.loadDeliveryManagers();

    if (!mounted) return;

    debugPrint(
      'DEBUG: Delivery managers loaded: ${provider.deliveryManagers.length}',
    );
    debugPrint('DEBUG: Delivery managers data: ${provider.deliveryManagers}');
    // Log each manager's status
    for (var manager in provider.deliveryManagers) {
      debugPrint(
        'DEBUG: Manager ${manager['id']} - ${manager['full_name']}: '
        'status=${manager['status']}, delivery_status=${manager['delivery_status']}, '
        'status_text=${manager['status_text']}, is_available=${manager['is_available']}',
      );
    }

    if (provider.deliveryManagers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No delivery managers available. Cannot approve request.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? selectedManagerId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF28A745).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF28A745),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Approve Borrowing Request',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Delivery Manager Selection
                const Text(
                  'Select a delivery manager for this request:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF495057),
                  ),
                ),
                const SizedBox(height: 16),

                // Delivery Manager List
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.deliveryManagers.length,
                    itemBuilder: (context, index) {
                      final manager = provider.deliveryManagers[index];
                      final isAvailable = manager['is_available'] == true;
                      final statusColor = manager['status_color'] as String;
                      // Get status text with proper fallback and capitalization
                      final rawStatus =
                          manager['status_text'] as String? ??
                          manager['status_display'] as String? ??
                          manager['status'] as String? ??
                          manager['delivery_status'] as String? ??
                          'offline';
                      // Capitalize first letter: "online" -> "Online", "offline" -> "Offline"
                      // Note: Legacy 'busy' status is handled as 'online'
                      final statusText = rawStatus.isNotEmpty
                          ? rawStatus[0].toUpperCase() +
                                rawStatus.substring(1).toLowerCase()
                          : 'Offline';
                      final isSelected = selectedManagerId == manager['id'];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isAvailable
                                ? () {
                                    setState(() {
                                      selectedManagerId = manager['id'] as int;
                                    });
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFF28A745,
                                      ).withValues(alpha: 0.1)
                                    : isAvailable
                                    ? Colors.white
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF28A745)
                                      : isAvailable
                                      ? const Color(0xFFE9ECEF)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Status Indicator
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: statusColor == 'green'
                                          ? Colors.green
                                          : statusColor == 'orange'
                                          ? Colors.orange
                                          : statusColor == 'red'
                                          ? Colors.red
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Manager Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          manager['full_name'] as String,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isAvailable
                                                ? Colors.black
                                                : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              _getStatusIcon(statusText),
                                              size: 14,
                                              color: statusColor == 'green'
                                                  ? Colors.green
                                                  : statusColor == 'orange'
                                                  ? Colors.orange
                                                  : statusColor == 'red'
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: statusColor == 'green'
                                                    ? Colors.green
                                                    : statusColor == 'orange'
                                                    ? Colors.orange
                                                    : statusColor == 'red'
                                                    ? Colors.red
                                                    : Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Selection Indicator
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF28A745),
                                      size: 20,
                                    )
                                  else if (!isAvailable)
                                    const Icon(
                                      Icons.block,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedManagerId != null
                            ? () => Navigator.of(context).pop(true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Confirm Approval'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && selectedManagerId != null && mounted) {
      try {
        await provider.approveRequest(
          request.id,
          deliveryManagerId: selectedManagerId,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Borrowing request approved and assigned to delivery manager',
              ),
              backgroundColor: Colors.green,
            ),
          );
          _loadRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to approve request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectRequest(BorrowRequest request) async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Borrowing Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.isNotEmpty && mounted) {
      try {
        final provider = context.read<AdminBorrowingProvider>();
        await provider.rejectRequest(request.id, reasonController.text);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Borrowing request rejected successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          _loadRequests();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final statusTabs = _getStatusTabs(localizations);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.borrowRequests),
        backgroundColor: const Color(0xFFB5E7FF),
        foregroundColor: Colors.white,
        actions: [
          // Refresh icon
          IconButton(
            onPressed: () => _loadRequests(),
            icon: const Icon(Icons.refresh),
            tooltip: localizations.refreshRequests,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: statusTabs.map((status) => Tab(text: status)).toList(),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          onTap: (index) {
            debugPrint('DEBUG: TabBar onTap called with index: $index');
            // Update the selected status and reload requests
            _onTabChanged(index, localizations);
          },
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return AdminSearchBar(
                  hintText: localizations.searchBorrowingRequests,
                  controller: _searchController,
                  onChanged: _onSearch,
                  onSubmitted: _onSearchImmediate,
                );
              },
            ),
          ),

          // Requests List
          Expanded(
            child: Consumer<AdminBorrowingProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && _allRequests.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.errorMessage != null && _allRequests.isEmpty) {
                  return Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${localizations.errorLoadingRequests}: ${provider.errorMessage}',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                provider.clearError();
                                _loadRequests();
                              },
                              child: Text(localizations.retry),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                if (_filteredRequests.isEmpty && _allRequests.isNotEmpty) {
                  return Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return EmptyState(
                        title: localizations.noMatchingRequests,
                        icon: Icons.search_off,
                        message: localizations.noMatchingRequestsMessage,
                      );
                    },
                  );
                }

                if (_allRequests.isEmpty) {
                  return Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return EmptyState(
                        title: localizations.noBorrowingRequests,
                        icon: Icons.book_outlined,
                        message: localizations.noBorrowingRequestsMessage,
                      );
                    },
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadRequests,
                  color: const Color(0xFFB5E7FF),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredRequests.length,
                    itemBuilder: (context, index) {
                      final request = _filteredRequests[index];
                      return _buildRequestCard(request);
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

  Widget _buildRequestCard(BorrowRequest request) {
    return GestureDetector(
      onTap: () => _navigateToDetail(request),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations.requestNumber(request.id),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        );
                      },
                    ),
                  ),
                  // UNIFIED DELIVERY STATUS: Use the primary status (which is now delivery_request_status when available)
                  // For customers: status = delivery_request_status (unified)
                  // For admins: status = delivery_request_status (unified), borrowStatus = original borrow status
                  Builder(
                    builder: (context) {
                      // Use the unified status (status field now contains delivery_request_status when available)
                      final statusToShow = request.status;
                      // Debug logging
                      debugPrint('DEBUG: StatusChip - Request #${request.id}:');
                      debugPrint(
                        '  - Unified status (primary): ${request.status}',
                      );
                      debugPrint(
                        '  - borrowStatus (admin-only): ${request.borrowStatus}',
                      );
                      debugPrint(
                        '  - deliveryRequest.status: ${request.deliveryRequest?.status}',
                      );
                      debugPrint('  - Final status shown: $statusToShow');
                      return StatusChip(status: statusToShow);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Information Container
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
                ),
                child: Column(
                  children: [
                    // Customer Information
                    Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 20,
                          color: Color(0xFF6C757D),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(
                                context,
                              );
                              String customerText;
                              if (request.customerName?.isNotEmpty == true) {
                                customerText =
                                    '${localizations.customerLabel}: ${request.customerName}';
                              } else if (request
                                      .customer
                                      ?.fullName
                                      .isNotEmpty ==
                                  true) {
                                customerText =
                                    '${localizations.customerLabel}: ${request.customer!.fullName}';
                              } else {
                                customerText =
                                    '${localizations.userId}: ${request.userId ?? 'N/A'}';
                              }
                              return Text(
                                customerText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF495057),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Book Information
                    Row(
                      children: [
                        const Icon(
                          Icons.book,
                          size: 20,
                          color: Color(0xFF6C757D),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Builder(
                            builder: (context) {
                              final localizations = AppLocalizations.of(
                                context,
                              );
                              String bookText;
                              if (request.bookTitle?.isNotEmpty == true) {
                                bookText =
                                    '${localizations.bookLabel}: ${request.bookTitle}';
                              } else if (request.book?.title.isNotEmpty ==
                                  true) {
                                bookText =
                                    '${localizations.bookLabel}: ${request.book!.title}';
                              } else {
                                bookText =
                                    '${localizations.bookId}: ${request.bookId ?? 'N/A'}';
                              }
                              return Text(
                                bookText,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF495057),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Request Date
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Color(0xFF6C757D),
                        ),
                        const SizedBox(width: 8),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              '${localizations.requested}: ${_formatDate(request.requestDate)}',
                              style: const TextStyle(
                                color: Color(0xFF6C757D),
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons - Only show for pending requests
              if (_canApproveOrReject(request)) ...[
                Row(
                  children: [
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return ElevatedButton.icon(
                            onPressed: () => _approveRequest(request),
                            icon: const Icon(Icons.check, size: 18),
                            label: Text(localizations.approve),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF28A745),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return OutlinedButton.icon(
                            onPressed: () => _rejectRequest(request),
                            icon: const Icon(Icons.close, size: 18),
                            label: Text(localizations.reject),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC3545),
                              side: const BorderSide(color: Color(0xFFDC3545)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Show status message for non-pending requests
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: request.status.toLowerCase() == 'approved'
                        ? const Color(0xFFD4EDDA)
                        : request.status.toLowerCase() == 'rejected'
                        ? const Color(0xFFF8D7DA)
                        : const Color(0xFFE2E3E5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: request.status.toLowerCase() == 'approved'
                          ? const Color(0xFFC3E6CB)
                          : request.status.toLowerCase() == 'rejected'
                          ? const Color(0xFFF5C6CB)
                          : const Color(0xFFD6D8DB),
                    ),
                  ),
                  child: Text(
                    _getStatusMessage(request),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: request.status.toLowerCase() == 'approved'
                          ? const Color(0xFF155724)
                          : request.status.toLowerCase() == 'rejected'
                          ? const Color(0xFF721C24)
                          : const Color(0xFF383D41),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetail(BorrowRequest request) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            BorrowingRequestDetailScreen(requestId: request.id),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _canApproveOrReject(BorrowRequest request) {
    // Only pending requests can be approved or rejected
    return request.status.toLowerCase() == 'pending';
  }

  String _getStatusMessage(BorrowRequest request) {
    final status = request.status.toLowerCase();
    switch (status) {
      case 'approved':
        return '✓ Request has been approved';
      case 'rejected':
        return '✗ Request has been rejected';
      case 'delivered':
        return '📦 Book has been delivered';
      case 'active':
        return '📖 Book is currently borrowed';
      case 'returned':
        return '↩️ Book has been returned';
      case 'cancelled':
        return '❌ Request was cancelled';
      case 'late':
        return '⚠️ Book is overdue';
      case 'extended':
        return '⏰ Borrowing period has been extended';
      default:
        return 'Status: ${request.status}';
    }
  }

  IconData _getStatusIcon(String statusText) {
    switch (statusText.toLowerCase()) {
      case 'online':
        return Icons.wifi;
      case 'busy':
        return Icons.local_shipping;
      case 'offline':
        return Icons.wifi_off;
      default:
        return Icons.help_outline;
    }
  }
}
