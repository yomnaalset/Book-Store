import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/delivery_provider.dart';
import '../../../models/delivery_request.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../widgets/admin_search_bar.dart';
import '../../../widgets/library_manager/filters_bar.dart';
import '../../../widgets/empty_state.dart';
import '../../../../../routes/app_routes.dart';
import '../../../../../../core/localization/app_localizations.dart';

class DeliveryRequestsScreen extends StatefulWidget {
  const DeliveryRequestsScreen({super.key});

  @override
  State<DeliveryRequestsScreen> createState() => _DeliveryRequestsScreenState();
}

class _DeliveryRequestsScreenState extends State<DeliveryRequestsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDeliveryRequests();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadDeliveryRequests() async {
    debugPrint('DEBUG: DeliveryRequestsScreen - Loading delivery requests...');
    debugPrint(
      'DEBUG: DeliveryRequestsScreen - Search query: "${_searchController.text}"',
    );
    debugPrint(
      'DEBUG: DeliveryRequestsScreen - Status filter: "$_selectedStatus"',
    );

    final provider = context.read<DeliveryProvider>();
    await provider.loadDeliveryRequests(
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
      status: _selectedStatus,
    );

    // Check for authentication error
    if (provider.error != null && provider.error!.contains('401')) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.sessionExpiredPleaseLogInAgain),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        // Navigate to login screen
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.login,
          (route) => false,
        );
      }
    }
  }

  void _onSearch(String query) {
    debugPrint('DEBUG: DeliveryRequestsScreen - Search query: "$query"');

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set up debounced search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadDeliveryRequests();
    });
  }

  void _onSearchImmediate(String query) {
    debugPrint(
      'DEBUG: DeliveryRequestsScreen - Immediate search query: "$query"',
    );
    setState(() {});
    _loadDeliveryRequests();
  }

  void _onFilterChanged(String? status) {
    setState(() {
      _selectedStatus = status;
    });
    _loadDeliveryRequests();
  }

  void _navigateToMonitoringDetails(DeliveryRequest request) {
    // Delivery functionality has been removed from admin account
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localizations.deliveryMonitoringNoLongerAvailable),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.deliveryRequests),
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
                  hintText: localizations.searchDeliveryRequests,
                  onSubmitted: _onSearchImmediate,
                  onChanged: _onSearch,
                ),
                const SizedBox(height: 16),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return FiltersBar(
                      filterOptions: [
                        localizations.statusPending,
                        localizations.assigned,
                        localizations.inProgress,
                        localizations.statusCompleted,
                      ],
                      selectedFilter: _getDisplayStatus(
                        _selectedStatus,
                        localizations,
                      ),
                      onFilterChanged: (filter) {
                        final localizations = AppLocalizations.of(context);
                        if (filter == localizations.all) {
                          _onFilterChanged(null);
                        } else {
                          // Map UI filter values (localized) to backend status values
                          String? statusValue;
                          if (filter == localizations.statusPending) {
                            statusValue = 'pending';
                          } else if (filter == localizations.assigned) {
                            statusValue = 'assigned';
                          } else if (filter == localizations.inProgress) {
                            statusValue = 'in_progress';
                          } else if (filter == localizations.statusCompleted) {
                            statusValue = 'delivered';
                          } else {
                            statusValue = filter?.toLowerCase().replaceAll(
                              ' ',
                              '_',
                            );
                          }
                          _onFilterChanged(statusValue);
                        }
                      },
                      onClearFilters: () {
                        _onFilterChanged(null);
                      },
                    );
                  },
                ),
              ],
            ),
          ),

          // Delivery Requests List
          Expanded(
            child: Consumer<DeliveryProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.deliveryRequests.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null &&
                    provider.deliveryRequests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Column(
                              children: [
                                Text(
                                  '${localizations.error}: ${provider.error}',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                if (provider.error!.contains('401'))
                                  Text(
                                    localizations
                                        .sessionExpiredPleaseLogInAgain,
                                    style: const TextStyle(
                                      color: Colors.orange,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    provider.clearError();
                                    _loadDeliveryRequests();
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: Text(localizations.retry),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }

                if (provider.deliveryRequests.isEmpty) {
                  return EmptyState(
                    title: localizations.noDeliveryRequests,
                    icon: Icons.local_shipping,
                    message: localizations.thereAreNoDeliveryRequests,
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadDeliveryRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.deliveryRequests.length,
                    itemBuilder: (context, index) {
                      final request = provider.deliveryRequests[index];
                      return _buildDeliveryRequestCard(request);
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

  Widget _buildDeliveryRequestCard(DeliveryRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToMonitoringDetails(request),
        borderRadius: BorderRadius.circular(8),
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
                      'Delivery #${request.id}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  StatusChip(status: request.status),
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
                      request.order?.customerName ?? 'Unknown Customer',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Delivery Address
              Row(
                children: [
                  const Icon(Icons.location_on, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.order?.deliveryAddressText ?? 'No address',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Order ID
              Row(
                children: [
                  const Icon(Icons.inventory, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Order ID: ${request.orderId}',
                    style: const TextStyle(color: Colors.grey),
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
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Requested: ${_formatDate(request.createdAt)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),

              // Assigned Agent (if assigned)
              if (request.deliveryAgentId != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.delivery_dining,
                      size: 20,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Agent: ${request.deliveryAgentId ?? 'Unknown'}',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],

              // Expected Delivery Date
              if (request.scheduledDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.event, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Expected: ${_formatDate(request.scheduledDate!)}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),

              // Monitoring Action Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.location_searching,
                      color: Colors.blue,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Monitor Delivery',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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

  String? _getDisplayStatus(String? status, AppLocalizations localizations) {
    if (status == null) return null;

    switch (status) {
      case 'pending':
        return localizations.statusPending;
      case 'assigned':
        return localizations.assigned;
      case 'in_progress':
        return localizations.inProgress;
      case 'delivered':
        return localizations.statusCompleted;
      default:
        return status;
    }
  }
}
