import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class LocationTrackingWidget extends StatelessWidget {
  final Map<String, dynamic>? position;
  final VoidCallback onStopTracking;

  const LocationTrackingWidget({
    super.key,
    required this.position,
    required this.onStopTracking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Location Icon
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.my_location,
              color: AppColors.success,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // Location Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Location Tracking Active',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                if (position != null) ...[
                  Text(
                    'Lat: ${position!['latitude']?.toStringAsFixed(6) ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'Lng: ${position!['longitude']?.toStringAsFixed(6) ?? 'N/A'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (position!['speed'] != null)
                    Text(
                      'Speed: ${position!['speed']?.toStringAsFixed(1) ?? '0'} km/h',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ] else
                  const Text(
                    'Getting location...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),

          // Stop Tracking Button
          IconButton(
            onPressed: onStopTracking,
            icon: const Icon(Icons.stop, color: AppColors.error),
            tooltip: 'Stop Tracking',
          ),
        ],
      ),
    );
  }
}
