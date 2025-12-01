import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final bool isSmall;

  const StatusChip({super.key, required this.status, this.isSmall = false});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 6 : 8,
        vertical: isSmall ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: statusInfo['color'],
        borderRadius: BorderRadius.circular(isSmall ? 8 : 12),
      ),
      child: Text(
        statusInfo['label'],
        style: TextStyle(
          color: AppColors.white,
          fontSize: isSmall ? 10 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case DeliveryTask.statusAssigned:
        return {'label': 'Assigned', 'color': AppColors.warning};
      case DeliveryTask.statusAccepted:
        return {'label': 'Accepted', 'color': AppColors.info};
      case DeliveryTask.statusPickedUp:
        return {'label': 'Picked Up', 'color': AppColors.primary};
      case DeliveryTask.statusInTransit:
        return {'label': 'In Transit', 'color': AppColors.info};
      case DeliveryTask.statusDelivered:
        return {'label': 'Delivered', 'color': AppColors.success};
      case DeliveryTask.statusCompleted:
        return {'label': 'Completed', 'color': AppColors.success};
      case DeliveryTask.statusFailed:
        return {'label': 'Failed', 'color': AppColors.error};
      case DeliveryTask.statusCancelled:
        return {'label': 'Cancelled', 'color': AppColors.grey};
      default:
        return {'label': status, 'color': AppColors.grey};
    }
  }
}
