import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../models/unified_delivery.dart';
import '../services/unified_delivery_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'delivery_request_detail_screen.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  List<UnifiedDelivery> _deliveries = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
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

      final result = await UnifiedDeliveryService.getDeliveryList(
        deliveryType: 'purchase',
      );

      if (result['success'] == true) {
        final data = result['data'] as List;
        setState(() {
          _deliveries = data
              .map((json) => UnifiedDelivery.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load purchase orders';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading purchase orders: $e';
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.purchaseOrders),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeliveries,
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
                    onPressed: _loadDeliveries,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _deliveries.isEmpty
          ? Center(
              child: Text(
                'No purchase delivery requests',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadDeliveries,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _deliveries.length,
                itemBuilder: (context, index) {
                  final delivery = _deliveries[index];
                  return _buildDeliveryCard(delivery);
                },
              ),
            ),
    );
  }

  Widget _buildDeliveryCard(UnifiedDelivery delivery) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  DeliveryRequestDetailScreen(delivery: delivery),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Order #${delivery.orderNumber ?? delivery.id}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(delivery.deliveryStatus),
                ],
              ),
              const SizedBox(height: 12),
              Text('Customer: ${delivery.customerName ?? "N/A"}'),
              const SizedBox(height: 8),
              Text(
                'Address: ${delivery.deliveryAddress.isNotEmpty ? delivery.deliveryAddress : "Not provided"}',
              ),
              if (delivery.deliveryCity != null) ...[
                const SizedBox(height: 4),
                Text('City: ${delivery.deliveryCity}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        break;
      case 'assigned':
        color = Colors.blue;
        break;
      case 'accepted':
        color = Colors.green;
        break;
      case 'in_delivery':
        color = Colors.purple;
        break;
      case 'completed':
        color = Colors.grey;
        break;
      case 'rejected':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Chip(
      label: Text(status.toUpperCase()),
      backgroundColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
    );
  }

}
