import 'package:flutter/material.dart';
import 'package:readgo/core/constants/app_colors.dart';

class DeliveryManagerLocationWidget extends StatelessWidget {
  final String managerName;
  final Map<String, dynamic>? location;
  final VoidCallback? onTap;

  const DeliveryManagerLocationWidget({
    super.key,
    required this.managerName,
    this.location,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        location != null &&
        (location!['latitude'] != null || location!['address'] != null);

    return Card(
      color: Theme.of(context).cardColor,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Location Icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasLocation
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasLocation ? Icons.location_on : Icons.location_off,
                  color: hasLocation ? AppColors.success : AppColors.grey,
                  size: 20,
                ),
              ),

              const SizedBox(width: 12),

              // Location Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      managerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasLocation ? _getLocationDisplay() : 'No location set',
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
                    if (hasLocation &&
                        location!['location_updated_at'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Updated: ${_formatDate(location!['location_updated_at'])}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action Icon
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLocationDisplay() {
    if (location == null) return 'No location set';

    // Prefer address if available
    if (location!['address'] != null &&
        location!['address'].toString().isNotEmpty) {
      return location!['address'];
    }

    // Fall back to coordinates
    if (location!['latitude'] != null && location!['longitude'] != null) {
      return 'Lat: ${location!['latitude']}, Lng: ${location!['longitude']}';
    }

    return 'No location set';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }
}
