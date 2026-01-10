import 'package:flutter/material.dart';

class DeliveryStatusIndicator extends StatelessWidget {
  final String status;

  const DeliveryStatusIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color textColor;
    IconData icon;
    String statusText;

    // Handle legacy 'busy' status by treating it as 'online'
    final normalizedStatus = status.toLowerCase() == 'busy'
        ? 'online'
        : status.toLowerCase();

    switch (normalizedStatus) {
      case 'online':
        textColor = Colors.green;
        icon = Icons.wifi;
        statusText = 'Online';
        break;
      case 'offline':
        textColor = Colors.red;
        icon = Icons.wifi_off;
        statusText = 'Offline';
        break;
      default:
        textColor = Colors.grey;
        icon = Icons.help_outline;
        statusText = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
