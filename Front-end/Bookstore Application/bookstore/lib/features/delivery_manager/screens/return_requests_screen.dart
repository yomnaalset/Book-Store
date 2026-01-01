import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/constants/app_colors.dart';
import '../models/unified_delivery.dart';
import '../services/unified_delivery_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import 'delivery_request_detail_screen.dart';

class ReturnRequestsScreen extends StatefulWidget {
  const ReturnRequestsScreen({super.key});

  @override
  State<ReturnRequestsScreen> createState() => _ReturnRequestsScreenState();
}

class _ReturnRequestsScreenState extends State<ReturnRequestsScreen> {
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
        deliveryType: 'return',
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
          _errorMessage = result['message'] ?? 'Failed to load return requests';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading return requests: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAccept(int deliveryId) async {
    try {
      final result = await UnifiedDeliveryService.acceptDelivery(deliveryId);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery request accepted')),
        );
        _loadDeliveries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to accept')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleReject(int deliveryId) async {
    final reasonController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Delivery Request'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason',
            hintText: 'Enter reason for rejection',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, reasonController.text),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final apiResult = await UnifiedDeliveryService.rejectDelivery(
          deliveryId,
          result,
        );
        if (!mounted) return;
        if (apiResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery request rejected')),
          );
          _loadDeliveries();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(apiResult['message'] ?? 'Failed to reject')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _handleStart(int deliveryId) async {
    try {
      final result = await UnifiedDeliveryService.startDelivery(deliveryId);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Delivery started')));
        _loadDeliveries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to start')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _handleComplete(int deliveryId) async {
    try {
      final result = await UnifiedDeliveryService.completeDelivery(deliveryId);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Delivery completed')));
        _loadDeliveries();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to complete')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.returnRequests),
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
                'No return delivery requests',
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
              builder: (context) => DeliveryRequestDetailScreen(
                delivery: delivery,
              ),
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
                  Text(
                    'Return Request #${delivery.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _buildStatusChip(delivery.deliveryStatus),
                ],
              ),
              const SizedBox(height: 12),
              Text('Customer: ${delivery.customerName ?? "N/A"}'),
              const SizedBox(height: 8),
              Text('Address: ${delivery.deliveryAddress.isNotEmpty ? delivery.deliveryAddress : "Not provided"}'),
              if (delivery.deliveryCity != null) ...[
                const SizedBox(height: 4),
                Text('City: ${delivery.deliveryCity}'),
              ],
              const SizedBox(height: 16),
              _buildActionButtons(delivery),
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

  Widget _buildActionButtons(UnifiedDelivery delivery) {
    // Unified button display logic based on status
    switch (delivery.deliveryStatus) {
      case 'assigned':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleAccept(delivery.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                child: const Text('Accept'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _handleReject(delivery.id),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                child: const Text('Reject'),
              ),
            ),
          ],
        );
      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _handleStart(delivery.id),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Start Delivery'),
          ),
        );
      case 'in_delivery':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Navigate to location update screen
                },
                icon: const Icon(Icons.location_on),
                label: const Text('Update Location'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () => _handleComplete(delivery.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                child: const Text('Complete'),
              ),
            ),
          ],
        );
      case 'completed':
      case 'rejected':
      default:
        return const SizedBox.shrink();
    }
  }
}
