import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../orders/models/order.dart';
import '../../../orders/providers/orders_provider.dart';

class DeliveryLocationMapWidget extends StatefulWidget {
  final Order order;
  final Map<String, dynamic> locationData;

  const DeliveryLocationMapWidget({
    super.key,
    required this.order,
    required this.locationData,
  });

  @override
  State<DeliveryLocationMapWidget> createState() =>
      _DeliveryLocationMapWidgetState();
}

class _DeliveryLocationMapWidgetState extends State<DeliveryLocationMapWidget> {
  Map<String, dynamic>? _currentLocationData;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentLocationData = widget.locationData;
  }

  Future<void> _refreshLocation() async {
    if (!mounted) return;
    setState(() {
      _isRefreshing = true;
    });

    try {
      final provider = Provider.of<OrdersProvider>(context, listen: false);
      final locationData = await provider.getOrderDeliveryLocation(
        int.parse(widget.order.id),
      );

      if (!mounted) return;

      if (locationData != null) {
        setState(() {
          _currentLocationData = locationData;
        });
        _showSnackBarSafely('Location refreshed successfully', Colors.green);
      } else {
        _showSnackBarSafely(
          provider.errorMessage ?? 'Failed to refresh location',
          Colors.red,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBarSafely(
        'Error refreshing location: ${e.toString()}',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationData = _currentLocationData ?? widget.locationData;
    final location = locationData['location'] as Map<String, dynamic>?;
    final deliveryManager =
        locationData['delivery_manager'] as Map<String, dynamic>?;
    final latitude = location?['latitude'] as double?;
    final longitude = location?['longitude'] as double?;
    final address = location?['address'] as String?;
    final isTrackingActive =
        locationData['is_tracking_active'] as bool? ?? false;
    final lastUpdated = locationData['last_updated'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Location'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: Column(
        children: [
          // Delivery Manager Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_shipping, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Delivery Manager: ${deliveryManager?['name'] ?? 'Unknown'}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isTrackingActive ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isTrackingActive
                            ? 'Tracking Active'
                            : 'Tracking Inactive',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (lastUpdated != null) ...[
                      const SizedBox(width: 12),
                      Text(
                        'Updated: ${_formatDateTime(lastUpdated)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Map Placeholder (Replace with actual map widget like google_maps_flutter)
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.grey[200],
              child: latitude != null && longitude != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 80,
                          color: Colors.blue[700],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Latitude: ${latitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Longitude: ${longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (address != null && address.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              address,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => _openInMaps(latitude, longitude),
                          icon: const Icon(Icons.map),
                          label: const Text('Open in Maps'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 80,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Location not available',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          // Order Info Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${widget.order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Status: ${widget.order.statusDisplay}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBarSafely(String message, Color backgroundColor) {
    if (!mounted) return;
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
    } catch (e) {
      // Widget was disposed, ignore
      debugPrint('Error showing SnackBar: $e');
    }
  }

  Future<void> _openInMaps(double? latitude, double? longitude) async {
    if (latitude == null || longitude == null) {
      _showSnackBarSafely('Location coordinates are not available', Colors.red);
      return;
    }

    try {
      // Try multiple URL schemes in order of preference
      // Try launching directly without checking canLaunchUrl first
      final urls = [
        // Google Maps app (Android) - navigation mode
        Uri.parse('google.navigation:q=$latitude,$longitude'),
        // Google Maps app (Android/iOS) - search mode
        Uri.parse('comgooglemaps://?q=$latitude,$longitude'),
        // Geo scheme (Android) - opens default maps app
        Uri.parse('geo:$latitude,$longitude'),
        // Google Maps web URL (always works as fallback)
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        ),
      ];

      bool launched = false;
      for (final url in urls) {
        try {
          // Try to launch directly - canLaunchUrl can be unreliable
          await launchUrl(url, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        } catch (e) {
          // Try next URL if this one fails
          debugPrint('Failed to launch URL $url: $e');
          continue;
        }
      }

      if (!launched) {
        // Final fallback: try the web URL which should always work
        try {
          final webUrl = Uri.parse(
            'https://www.google.com/maps?q=$latitude,$longitude',
          );
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } catch (e) {
          _showSnackBarSafely(
            'Could not open maps. Please check your internet connection.',
            Colors.orange,
          );
        }
      }
    } catch (e) {
      _showSnackBarSafely('Error opening maps: ${e.toString()}', Colors.red);
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Unknown';
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }
}
