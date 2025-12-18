import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/borrowing_delivery_provider.dart';
import '../widgets/borrow_order_card.dart';
import '../../orders/models/order.dart';
import '../widgets/search_filter_bar.dart';

/// Borrow Requests Screen with complete workflow management
/// Shows all requests with dropdown filter: All, Pending, In Delivery, Completed
class BorrowRequestsScreen extends StatefulWidget {
  const BorrowRequestsScreen({super.key});

  @override
  State<BorrowRequestsScreen> createState() => _BorrowRequestsScreenState();
}

class _BorrowRequestsScreenState extends State<BorrowRequestsScreen> {
  String _searchQuery = '';
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();

    // Load borrowing requests when the screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final borrowProvider = Provider.of<BorrowingDeliveryProvider>(
      context,
      listen: false,
    );

    // Ensure we have a valid token
    if (authProvider.token == null) {
      debugPrint('BorrowRequestsScreen: No auth token available');
      return;
    }

    debugPrint(
      'BorrowRequestsScreen: Setting token ${authProvider.token!.substring(0, 20)}...',
    );

    // Set the auth token before loading requests
    borrowProvider.setToken(authProvider.token);
    await _loadBorrowRequestsFromServer();
  }

  Future<void> _loadBorrowRequestsFromServer() async {
    final borrowProvider = Provider.of<BorrowingDeliveryProvider>(
      context,
      listen: false,
    );

    debugPrint(
      'BorrowRequestsScreen: Loading borrow requests from server with filters - status: $_selectedStatus, search: "$_searchQuery"',
    );

    try {
      await borrowProvider.loadBorrowRequests(
        status: _selectedStatus,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      debugPrint(
        'BorrowRequestsScreen: Borrow requests loaded successfully. Count: ${borrowProvider.allRequests.length}',
      );
    } catch (error) {
      debugPrint('BorrowRequestsScreen: Error loading borrow requests: $error');
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _loadBorrowRequestsFromServer();
  }

  void _onFilterChanged(String? status) {
    setState(() {
      _selectedStatus = status;
    });
    _loadBorrowRequestsFromServer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).borrowRequests),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBorrowRequestsFromServer,
          ),
        ],
      ),
      body: Consumer<BorrowingDeliveryProvider>(
        builder: (context, borrowProvider, child) {
          if (borrowProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (borrowProvider.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ErrorMessage(message: borrowProvider.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );

                      borrowProvider.setToken(authProvider.token);
                      _loadBorrowRequestsFromServer();
                    },
                    child: Text(AppLocalizations.of(context).retry),
                  ),
                ],
              ),
            );
          }

          final orders = borrowProvider.allRequests;

          return Column(
            children: [
              // Search and Filter Bar
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return SearchFilterBar(
                    searchHint: localizations.searchBorrowRequests,
                    filterLabel: localizations.status,
                    filterOptions: borrowProvider.statusFilterOptions,
                    onSearchChanged: _onSearchChanged,
                    onFilterChanged: _onFilterChanged,
                  );
                },
              ),

              // Orders List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadBorrowRequestsFromServer,
                  child: orders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.book_online,
                                size: 64,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    _searchQuery.isNotEmpty ||
                                            _selectedStatus != null
                                        ? localizations.noMatchingBorrowRequests
                                        : localizations.noBorrowRequests,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    _searchQuery.isNotEmpty ||
                                            _selectedStatus != null
                                        ? localizations
                                              .tryAdjustingSearchOrFilter
                                        : localizations
                                              .noBorrowRequestsDescription,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  );
                                },
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildOrderCard(order),
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

  Widget _buildOrderCard(Order order) {
    // Determine card type based on order status
    BorrowOrderCardType cardType;
    VoidCallback? onAccept;
    VoidCallback? onReject;
    VoidCallback? onStartDelivery;
    VoidCallback? onComplete;

    final status = order.status.toLowerCase();

    // Pending statuses - need Accept/Reject
    if (status == 'pending' ||
        status == 'confirmed' ||
        status == 'assigned' ||
        status == 'assigned_to_delivery') {
      cardType = BorrowOrderCardType.pending;
      onAccept = () => _handleAcceptRequest(order.id);
      onReject = () => _handleRejectRequest(order.id);
    }
    // In-progress statuses - delivery is ongoing
    else if (status == 'pending_delivery' ||
        status == 'preparing' ||
        status == 'out_for_delivery' ||
        status == 'in_delivery') {
      cardType = BorrowOrderCardType.inProgress;
      if (status == 'pending_delivery' || status == 'preparing') {
        onStartDelivery = () => _handleStartDelivery(order.id);
      } else if (status == 'in_delivery' || status == 'out_for_delivery') {
        onComplete = () => _handleCompleteDelivery(order.id);
      }
    }
    // Completed statuses
    else {
      cardType = BorrowOrderCardType.completed;
    }

    return BorrowOrderCard(
      order: order,
      cardType: cardType,
      onAccept: onAccept,
      onReject: onReject,
      onStartDelivery: onStartDelivery,
      onComplete: onComplete,
    );
  }

  // Action Handlers

  Future<void> _handleAcceptRequest(String orderId) async {
    final provider = Provider.of<BorrowingDeliveryProvider>(
      context,
      listen: false,
    );

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Delivery Request'),
        content: const Text(
          'By accepting this request, your status will automatically change to BUSY. '
          'You won\'t be able to change your status manually until you complete the delivery.\n\n'
          'Do you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.acceptRequest(orderId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request accepted! Your status is now BUSY.'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload requests after accepting
          _loadBorrowRequestsFromServer();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage ?? 'Failed to accept request',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleRejectRequest(String orderId) async {
    final provider = Provider.of<BorrowingDeliveryProvider>(
      context,
      listen: false,
    );

    // Show reason dialog
    final TextEditingController reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Delivery Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a rejection reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.trim().isNotEmpty) {
      final success = await provider.rejectRequest(
        orderId,
        reasonController.text.trim(),
      );

      if (mounted) {
        if (success) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Request rejected successfully'),
                backgroundColor: Colors.orange,
              ),
            );
          } catch (_) {
            // Widget disposed, ignore
          }
          // Reload requests after rejecting
          _loadBorrowRequestsFromServer();
        } else {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  provider.errorMessage ?? 'Failed to reject request',
                ),
                backgroundColor: Colors.red,
              ),
            );
          } catch (_) {
            // Widget disposed, ignore
          }
        }
      }
    }

    reasonController.dispose();
  }

  Future<void> _handleStartDelivery(String orderId) async {
    final provider = Provider.of<BorrowingDeliveryProvider>(
      context,
      listen: false,
    );

    // Get delivery manager ID from auth provider before async gap
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final deliveryManagerId = authProvider.user?.id;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Delivery'),
        content: const Text(
          'Confirm that you have picked up the book and are ready to start delivery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start Delivery'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (deliveryManagerId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to get delivery manager ID. Please login again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final success = await provider.startDelivery(orderId, deliveryManagerId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery started! Status remains BUSY.'),
              backgroundColor: Colors.blue,
            ),
          );
          // Reload requests after starting delivery
          _loadBorrowRequestsFromServer();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage ?? 'Failed to start delivery',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleCompleteDelivery(String orderId) async {
    final provider = Provider.of<BorrowingDeliveryProvider>(
      context,
      listen: false,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Delivery'),
        content: const Text(
          'Confirm that the book has been delivered to the customer.\n\n'
          'Your status will automatically change to ONLINE after completion.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.completeDelivery(orderId);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery completed! Your status is now ONLINE.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          // Reload requests after completing delivery
          _loadBorrowRequestsFromServer();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.errorMessage ?? 'Failed to complete delivery',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Enum for card types
enum BorrowOrderCardType { pending, inProgress, completed }
