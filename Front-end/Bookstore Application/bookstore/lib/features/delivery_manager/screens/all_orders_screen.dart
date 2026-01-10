import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/unified_delivery.dart';
import '../services/unified_delivery_service.dart';
import '../../../features/auth/providers/auth_provider.dart';

class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen({super.key});

  @override
  State<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends State<AllOrdersScreen>
    with SingleTickerProviderStateMixin {
  List<UnifiedDelivery> _allDeliveries = [];
  bool _isLoading = false;
  String? _errorMessage;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllDeliveries();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllDeliveries() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token ?? authProvider.getCurrentToken();

      if (token != null) {
        UnifiedDeliveryService.setToken(token);
      }

      // Load all delivery types
      final results = await Future.wait([
        UnifiedDeliveryService.getDeliveryList(deliveryType: 'purchase'),
        UnifiedDeliveryService.getDeliveryList(deliveryType: 'borrow'),
        UnifiedDeliveryService.getDeliveryList(deliveryType: 'return'),
      ]);

      List<UnifiedDelivery> all = [];
      for (var result in results) {
        if (result['success'] == true) {
          // Handle different response formats
          List<dynamic> dataList;
          final data = result['data'];

          if (data is List) {
            dataList = data;
          } else if (data is Map<String, dynamic>) {
            // Handle paginated response or nested structure
            final results = data['results'];
            if (results is List) {
              dataList = results;
            } else if (results is Map<String, dynamic> &&
                results['results'] is List) {
              // Nested paginated response
              dataList = results['results'] as List;
            } else {
              dataList = [];
            }
          } else {
            dataList = [];
          }

          all.addAll(
            dataList.map((json) {
              try {
                if (json is Map<String, dynamic>) {
                  return UnifiedDelivery.fromJson(json);
                } else {
                  return null;
                }
              } catch (e) {
                debugPrint('Error parsing delivery item: $e');
                return null;
              }
            }).whereType<UnifiedDelivery>(),
          );
        }
      }

      setState(() {
        _allDeliveries = all;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading deliveries: $e';
        _isLoading = false;
      });
    }
  }

  List<UnifiedDelivery> _getDeliveriesByType(String type) {
    return _allDeliveries.where((d) => d.deliveryType == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'All Delivery Requests',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 179),
          tabs: const [
            Tab(text: 'Purchase', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'Borrow', icon: Icon(Icons.library_books)),
            Tab(text: 'Return', icon: Icon(Icons.undo)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllDeliveries,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAllDeliveries,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildDeliveryList(_getDeliveriesByType('purchase')),
                _buildDeliveryList(_getDeliveriesByType('borrow')),
                _buildDeliveryList(_getDeliveriesByType('return')),
              ],
            ),
    );
  }

  Widget _buildDeliveryList(List<UnifiedDelivery> deliveries) {
    final theme = Theme.of(context);
    if (deliveries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No delivery requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllDeliveries,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: deliveries.length,
        itemBuilder: (context, index) {
          final delivery = deliveries[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Navigate to detail screen
                },
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              delivery.deliveryType == 'purchase'
                                  ? 'Order #${delivery.orderNumber ?? delivery.id}'
                                  : delivery.deliveryType == 'borrow'
                                  ? 'Borrow Request #${delivery.id}'
                                  : 'Return Request #${delivery.id}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${delivery.customerName ?? "N/A"} - ${delivery.deliveryAddress}',
                              style: TextStyle(
                                fontSize: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            delivery.deliveryStatus,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          delivery.deliveryStatus.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(delivery.deliveryStatus),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return Colors.blue;
      case 'accepted':
        return Colors.green;
      case 'in_delivery':
        return Colors.purple;
      case 'completed':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
