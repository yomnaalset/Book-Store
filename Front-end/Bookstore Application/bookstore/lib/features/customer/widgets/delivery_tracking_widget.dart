import 'package:flutter/material.dart';
import 'package:readgo/core/constants/app_colors.dart';

class DeliveryTrackingWidget extends StatelessWidget {
  final Map<String, dynamic> deliveryRep;
  final VoidCallback? onLocationTap;

  const DeliveryTrackingWidget({
    super.key,
    required this.deliveryRep,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    final location = deliveryRep['location'];
    final hasLocation =
        location != null &&
        (location['latitude'] != null || location['address'] != null);

    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.local_shipping, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Delivery Information',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Delivery Representative Info
            _buildInfoRow(
              'Delivery Representative',
              deliveryRep['name'] ?? 'Not assigned',
              Icons.person,
            ),

            _buildInfoRow(
              'Contact Phone',
              deliveryRep['contact_phone'] ?? 'Not provided',
              Icons.phone,
            ),

            _buildInfoRow(
              'Status',
              deliveryRep['status'] ?? 'Unknown',
              Icons.info,
              valueColor: _getStatusColor(deliveryRep['status']),
            ),

            if (deliveryRep['estimated_delivery_time'] != null)
              _buildInfoRow(
                'Estimated Delivery',
                _formatDateTime(deliveryRep['estimated_delivery_time']),
                Icons.schedule,
              ),

            const SizedBox(height: 16),

            // Location Section
            if (hasLocation) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Delivery Manager Location',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        if (onLocationTap != null)
                          TextButton(
                            onPressed: onLocationTap,
                            child: const Text('View on Map'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getLocationDisplay(location),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    if (location['location_updated_at'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Last updated: ${_formatDateTime(location['location_updated_at'])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.grey.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.grey.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.location_off, color: AppColors.grey, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Delivery manager location not available',
                        style: TextStyle(
                          color: AppColors.grey,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Icon(icon, size: 16, color: AppColors.grey),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'assigned':
        return AppColors.primary;
      case 'picked_up':
        return AppColors.warning;
      case 'in_transit':
        return AppColors.info;
      case 'delivered':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      default:
        return AppColors.grey;
    }
  }

  String _getLocationDisplay(Map<String, dynamic> location) {
    // Prefer address if available
    if (location['address'] != null &&
        location['address'].toString().isNotEmpty) {
      return location['address'];
    }

    // Fall back to coordinates
    if (location['latitude'] != null && location['longitude'] != null) {
      return 'Latitude: ${location['latitude']}, Longitude: ${location['longitude']}';
    }

    return 'No location set';
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'Not specified';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }
}
