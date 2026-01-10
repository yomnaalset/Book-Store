import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../../../core/services/api_service.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../orders/models/order.dart';
import '../widgets/delivery_order_card.dart';
import '../widgets/location_tracking_widget.dart';
import '../../auth/providers/auth_provider.dart';

class DeliveryManagerDashboard extends StatefulWidget {
  const DeliveryManagerDashboard({super.key});

  @override
  State<DeliveryManagerDashboard> createState() =>
      _DeliveryManagerDashboardState();
}

class _DeliveryManagerDashboardState extends State<DeliveryManagerDashboard> {
  List<Order> _assignedOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _locationTimer;
  Map<String, dynamic>? _currentPosition;
  bool _isTrackingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAssignedOrders();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  /// Get headers with authentication token
  Map<String, String> _getAuthHeaders() {
    final authProvider = context.read<AuthProvider>();
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (authProvider.token != null && authProvider.token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${authProvider.token!}';
    }

    return headers;
  }

  Future<void> _loadAssignedOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get authentication token from AuthProvider
      final authProvider = context.read<AuthProvider>();
      if (authProvider.token == null || authProvider.token!.isEmpty) {
        setState(() {
          _errorMessage = 'Authentication required. Please login again.';
          _isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/delivery/orders/'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _assignedOrders = (data['results'] as List)
              .map((order) => Order.fromJson(order))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load assigned orders';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _startDelivery(String orderId) async {
    try {
      // Simulate getting current location (in real app, this would use GPS)
      final position = {
        'latitude': 40.7128,
        'longitude': -74.0060,
        'speed': 0.0,
      };

      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/api/delivery/orders/$orderId/start_delivery/',
        ),
        headers: _getAuthHeaders(),
        body: jsonEncode({
          'latitude': position['latitude'],
          'longitude': position['longitude'],
          'address': 'Starting delivery',
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery started successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadAssignedOrders();
        _startLocationTracking();
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Failed to start delivery'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting delivery: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _completeDelivery(String orderId) async {
    try {
      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/api/delivery/orders/$orderId/complete_delivery/',
        ),
        headers: _getAuthHeaders(),
        body: jsonEncode({
          'delivery_notes': 'Delivered successfully',
          'rating': 5,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery completed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        _loadAssignedOrders();
        _stopLocationTracking();
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['error'] ?? 'Failed to complete delivery',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing delivery: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startLocationTracking() {
    setState(() {
      _isTrackingEnabled = true;
      _currentPosition = {
        'latitude': 40.7128,
        'longitude': -74.0060,
        'speed': 0.0,
      };
    });

    // Update location every 30 seconds (simulated)
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateLocation();
    });
  }

  void _stopLocationTracking() {
    setState(() {
      _isTrackingEnabled = false;
    });
    _locationTimer?.cancel();
  }

  Future<void> _updateLocation() async {
    try {
      // Simulate location update (in real app, this would use GPS)
      setState(() {
        _currentPosition = {
          'latitude':
              40.7128 + (DateTime.now().millisecondsSinceEpoch % 100) / 10000,
          'longitude':
              -74.0060 + (DateTime.now().millisecondsSinceEpoch % 100) / 10000,
          'speed': (DateTime.now().millisecondsSinceEpoch % 50).toDouble(),
        };
      });

      // Send location update to server
      await http.patch(
        Uri.parse('${ApiService.baseUrl}/api/delivery/location/update/'),
        headers: _getAuthHeaders(),
        body: jsonEncode({
          'latitude': _currentPosition!['latitude'],
          'longitude': _currentPosition!['longitude'],
          'tracking_type': 'gps',
          'accuracy': 5.0,
          'speed': _currentPosition!['speed'],
        }),
      );
    } catch (e) {
      // Error updating location - silently handle
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Deliveries',
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAssignedOrders,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
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
                  ErrorMessage(message: _errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAssignedOrders,
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
          : _assignedOrders.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No assigned deliveries',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You will be notified when new orders are assigned',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Location Tracking Status
                if (_isTrackingEnabled) ...[
                  LocationTrackingWidget(
                    position: _currentPosition,
                    onStopTracking: _stopLocationTracking,
                  ),
                  const Divider(height: 1),
                ],

                // Orders List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAssignedOrders,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _assignedOrders.length,
                      itemBuilder: (context, index) {
                        final order = _assignedOrders[index];
                        return DeliveryOrderCard(
                          order: order,
                          onStartDelivery: () => _startDelivery(order.id),
                          onCompleteDelivery: () => _completeDelivery(order.id),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
