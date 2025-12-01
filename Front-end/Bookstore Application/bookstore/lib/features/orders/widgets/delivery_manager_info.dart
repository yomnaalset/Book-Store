import 'package:flutter/material.dart';
import '../../orders/models/order.dart';

class DeliveryManagerInfo extends StatelessWidget {
  final Order order;
  final Map<String, dynamic>? deliveryManagerLocation;

  const DeliveryManagerInfo({
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
                Icon(Icons.person, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Delivery Manager',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Delivery Manager Details
            _buildDeliveryManagerDetails(),

            const SizedBox(height: 16),

            // Contact Actions
            _buildContactActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryManagerDetails() {
    // This would typically come from the order data or delivery assignment
    final deliveryManager = {
      'name': 'Mike Johnson',
      'phone': '+1 (555) 123-4567',
      'rating': 4.8,
      'photo': 'https://via.placeholder.com/60',
      'vehicle': 'Toyota Camry',
      'license_plate': 'ABC-1234',
    };

    return Row(
      children: [
        // Profile Photo
        CircleAvatar(
          radius: 30,
          backgroundImage: deliveryManager['photo'] != null
              ? NetworkImage(deliveryManager['photo'] as String)
              : null,
          child: deliveryManager['photo'] == null
              ? const Icon(Icons.person, size: 30)
              : null,
        ),

        const SizedBox(width: 16),

        // Manager Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deliveryManager['name'] as String,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // Rating
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${deliveryManager['rating']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Vehicle Info
              Text(
                '${deliveryManager['vehicle']} • ${deliveryManager['license_plate']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 4),

              // Phone
              Text(
                deliveryManager['phone'] as String,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _callDeliveryManager,
            icon: const Icon(Icons.phone, size: 18),
            label: const Text('Call'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _messageDeliveryManager,
            icon: const Icon(Icons.message, size: 18),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  void _callDeliveryManager() {
    // Implement phone call functionality
    // This would typically use url_launcher to make a phone call
  }

  void _messageDeliveryManager() {
    // Implement messaging functionality
    // This could open a messaging app or in-app chat
  }
}
