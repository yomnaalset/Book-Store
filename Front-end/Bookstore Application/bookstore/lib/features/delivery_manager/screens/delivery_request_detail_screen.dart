import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../models/unified_delivery.dart';
import '../services/unified_delivery_service.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../providers/delivery_status_provider.dart';

class DeliveryRequestDetailScreen extends StatefulWidget {
  final UnifiedDelivery delivery;

  const DeliveryRequestDetailScreen({super.key, required this.delivery});

  @override
  State<DeliveryRequestDetailScreen> createState() =>
      _DeliveryRequestDetailScreenState();
}

class _DeliveryRequestDetailScreenState
    extends State<DeliveryRequestDetailScreen> {
  UnifiedDelivery? _delivery;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _delivery = widget.delivery;
    _loadDeliveryDetails();
  }

  Future<void> _loadDeliveryDetails() async {
    if (_delivery == null) return;

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

      final result = await UnifiedDeliveryService.getDeliveryDetail(
        _delivery!.id,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          // Handle both wrapped and direct data formats
          final deliveryData = result['data'] ?? result;
          try {
            _delivery = UnifiedDelivery.fromJson(deliveryData);
            _isLoading = false;
            _errorMessage = null;
          } catch (parseError) {
            debugPrint('Error parsing delivery data: $parseError');
            _errorMessage = 'Error parsing delivery data: $parseError';
            _isLoading = false;
          }
        });

        // Show success message if refresh was triggered manually
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery details refreshed'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load details';
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage ?? 'Failed to refresh'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading details: $e';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleAccept() async {
    if (_delivery == null) return;
    try {
      final result = await UnifiedDeliveryService.acceptDelivery(_delivery!.id);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delivery request accepted')),
        );
        _loadDeliveryDetails();

        // Refresh delivery manager status from server
        // Backend sets status to 'busy' when delivery is accepted
        try {
          final statusProvider = Provider.of<DeliveryStatusProvider>(
            context,
            listen: false,
          );
          await statusProvider.loadCurrentStatus();
          debugPrint(
            'DeliveryRequestDetailScreen: Refreshed delivery manager status after accepting delivery',
          );
        } catch (e) {
          debugPrint(
            'DeliveryRequestDetailScreen: Error refreshing delivery status: $e',
          );
        }
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

  Future<void> _handleReject() async {
    if (_delivery == null) return;
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
          _delivery!.id,
          result,
        );
        if (!mounted) return;
        if (apiResult['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Delivery request rejected')),
          );
          _loadDeliveryDetails();
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

  Future<void> _handleStart() async {
    if (_delivery == null) return;
    try {
      final result = await UnifiedDeliveryService.startDelivery(_delivery!.id);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Delivery started')));
        _loadDeliveryDetails();

        // Refresh delivery manager status from server
        // Backend sets status to 'busy' when delivery starts
        try {
          final statusProvider = Provider.of<DeliveryStatusProvider>(
            context,
            listen: false,
          );
          await statusProvider.loadCurrentStatus();
          debugPrint(
            'DeliveryRequestDetailScreen: Refreshed delivery manager status after starting delivery',
          );
        } catch (e) {
          debugPrint(
            'DeliveryRequestDetailScreen: Error refreshing delivery status: $e',
          );
        }
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

  Future<void> _handleUpdateLocation() async {
    if (_delivery == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required to update location',
              ),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is permanently denied. Please enable it in app settings.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location services are disabled. Please enable them.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (!mounted) return;

      // Update location via API
      final result = await UnifiedDeliveryService.updateLocation(
        _delivery!.id,
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh delivery details to show updated location
        _loadDeliveryDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to update location'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleComplete() async {
    if (_delivery == null) return;
    try {
      final result = await UnifiedDeliveryService.completeDelivery(
        _delivery!.id,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Delivery completed')));
        _loadDeliveryDetails();
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
    final delivery = _delivery;

    if (_isLoading && delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Request Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Request Details')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDeliveryDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (delivery == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Request Details')),
        body: const Center(child: Text('No delivery data available')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle(delivery)),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _loadDeliveryDetails,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDeliveryDetails,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeaderCard(delivery),
              const SizedBox(height: 16),
              _buildCustomerInfoCard(delivery),
              if (delivery.order != null) ...[
                const SizedBox(height: 16),
                _buildOrderInfoCard(delivery),
              ],
              const SizedBox(height: 16),
              _buildActionButtons(delivery),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitle(UnifiedDelivery delivery) {
    switch (delivery.deliveryType) {
      case 'purchase':
        return 'Purchase Delivery #${delivery.orderNumber ?? delivery.id}';
      case 'borrow':
        return 'Borrow Delivery #${delivery.id}';
      case 'return':
        return 'Return Delivery #${delivery.id}';
      default:
        return 'Delivery Request #${delivery.id}';
    }
  }

  Widget _buildHeaderCard(UnifiedDelivery delivery) {
    return Card(
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
                    _getTitle(delivery),
                    style: const TextStyle(
                      fontSize: 20,
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
            Text(
              'Type: ${delivery.deliveryTypeDisplay}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${delivery.deliveryStatusDisplay}',
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard(UnifiedDelivery delivery) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Name', delivery.customerName ?? 'N/A'),
            if (delivery.customerEmail != null)
              _buildInfoRow('Email', delivery.customerEmail!),
            if (delivery.customerPhone != null)
              _buildInfoRow('Phone', delivery.customerPhone!),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderInfoCard(UnifiedDelivery delivery) {
    if (delivery.order == null) return const SizedBox.shrink();

    final order = delivery.order!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (order['order_number'] != null)
              _buildInfoRow('Order Number', order['order_number'].toString()),
            if (order['total_amount'] != null)
              _buildInfoRow('Total Amount', order['total_amount'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: isError ? Colors.red : null),
            ),
          ),
        ],
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
    switch (delivery.deliveryStatus) {
      case 'assigned':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Accept'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _handleReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
            onPressed: _handleStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Start Delivery'),
          ),
        );
      case 'in_delivery':
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _handleUpdateLocation,
                icon: const Icon(Icons.location_on),
                label: const Text('Update Location'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Complete Delivery'),
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
