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
          final data = result['data'] as List;
          all.addAll(data.map((json) => UnifiedDelivery.fromJson(json)));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Delivery Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Purchase', icon: Icon(Icons.shopping_cart)),
            Tab(text: 'Borrow', icon: Icon(Icons.library_books)),
            Tab(text: 'Return', icon: Icon(Icons.undo)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllDeliveries,
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
                  Text(_errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAllDeliveries,
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
    if (deliveries.isEmpty) {
      return Center(
        child: Text(
          'No delivery requests',
          style: Theme.of(context).textTheme.bodyLarge,
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
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text(
                delivery.deliveryType == 'purchase'
                    ? 'Order #${delivery.orderNumber ?? delivery.id}'
                    : delivery.deliveryType == 'borrow'
                    ? 'Borrow Request #${delivery.id}'
                    : 'Return Request #${delivery.id}',
              ),
              subtitle: Text(
                '${delivery.customerName ?? "N/A"} - ${delivery.deliveryAddress}',
              ),
              trailing: Chip(
                label: Text(delivery.deliveryStatus.toUpperCase()),
                backgroundColor: _getStatusColor(
                  delivery.deliveryStatus,
                ).withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _getStatusColor(delivery.deliveryStatus),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                // Navigate to detail screen
              },
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
