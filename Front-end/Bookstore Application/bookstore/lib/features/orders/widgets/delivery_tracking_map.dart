import 'package:flutter/material.dart';
import '../../orders/models/order.dart';

class DeliveryTrackingMap extends StatelessWidget {
  final Order order;
  final Map<String, dynamic>? deliveryManagerLocation;

  const DeliveryTrackingMap({
    super.key,
    required this.order,
    this.deliveryManagerLocation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Delivery Tracking',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Map Container (Simplified without Google Maps dependency)
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.grey[100],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildMapPlaceholder(),
              ),
            ),

            const SizedBox(height: 16),

            // Delivery Info
            _buildDeliveryInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    if (deliveryManagerLocation == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Location tracking not available',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final lat = deliveryManagerLocation!['latitude']?.toDouble() ?? 0.0;
    final lng = deliveryManagerLocation!['longitude']?.toDouble() ?? 0.0;
    final address = deliveryManagerLocation!['address'] ?? 'Current location';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[100]!, Colors.blue[50]!],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 48, color: Colors.blue[700]),
            const SizedBox(height: 8),
            Text(
              'Delivery Manager Location',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lat: ${lat.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.blue[600]),
            ),
            Text(
              'Lng: ${lng.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.blue[600]),
            ),
            const SizedBox(height: 8),
            Text(
              address,
              style: TextStyle(fontSize: 12, color: Colors.blue[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    if (deliveryManagerLocation == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Location tracking will be available once delivery starts',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      );
    }

    final lastUpdate = deliveryManagerLocation!['last_updated'];
    final speed = deliveryManagerLocation!['speed']?.toDouble() ?? 0.0;
    final eta = deliveryManagerLocation!['eta'] ?? 'Calculating...';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.speed, color: Colors.blue[700], size: 16),
              const SizedBox(width: 8),
              Text(
                'Speed: ${speed.toStringAsFixed(1)} km/h',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, color: Colors.blue[700], size: 16),
              const SizedBox(width: 8),
              Text(
                'ETA: $eta',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (lastUpdate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.update, color: Colors.blue[700], size: 16),
                const SizedBox(width: 8),
                Text(
                  'Last update: ${_formatLastUpdate(lastUpdate)}',
                  style: TextStyle(color: Colors.blue[700], fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatLastUpdate(String lastUpdate) {
    try {
      final dateTime = DateTime.parse(lastUpdate);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
