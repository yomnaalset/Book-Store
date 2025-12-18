import 'package:flutter/material.dart';
import 'package:readgo/core/constants/app_colors.dart';

class DeliveryLocationsMapWidget extends StatelessWidget {
  final List<Map<String, dynamic>> deliveryManagers;
  final Function(int managerId)? onManagerSelected;

  const DeliveryLocationsMapWidget({
    super.key,
    required this.deliveryManagers,
    this.onManagerSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.map, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Delivery Manager Locations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Map Placeholder (In a real app, you'd use Google Maps or similar)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 48, color: AppColors.grey),
                  SizedBox(height: 8),
                  Text(
                    'Map View',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Delivery manager locations would be displayed here',
                    style: TextStyle(fontSize: 12, color: AppColors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Delivery Managers List
            if (deliveryManagers.isNotEmpty) ...[
              Text(
                'Active Delivery Managers (${deliveryManagers.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...deliveryManagers.map(
                (manager) => _buildManagerItem(context, manager),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info, color: AppColors.grey, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No delivery managers with location data available',
                        style: TextStyle(color: AppColors.grey, fontSize: 12),
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

  Widget _buildManagerItem(BuildContext context, Map<String, dynamic> manager) {
    final location = manager['location'];
    final hasLocation =
        location != null &&
        (location['latitude'] != null || location['address'] != null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => onManagerSelected?.call(manager['id']),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasLocation
                ? AppColors.success.withValues(alpha: 0.05)
                : AppColors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: hasLocation
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // Status Indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: hasLocation ? AppColors.success : AppColors.grey,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 12),

              // Manager Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      manager['name'] ?? 'Unknown Manager',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasLocation
                          ? _getLocationDisplay(location)
                          : 'No location set',
                      style: TextStyle(
                        fontSize: 12,
                        color: hasLocation
                            ? Theme.of(context).textTheme.bodySmall?.color
                            : AppColors.grey,
                        fontStyle: hasLocation
                            ? FontStyle.normal
                            : FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              // Action Icon
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLocationDisplay(Map<String, dynamic> location) {
    // Prefer address if available
    if (location['address'] != null &&
        location['address'].toString().isNotEmpty) {
      return location['address'];
    }

    // Fall back to coordinates
    if (location['latitude'] != null && location['longitude'] != null) {
      return 'Lat: ${location['latitude']}, Lng: ${location['longitude']}';
    }

    return 'No location set';
  }
}
