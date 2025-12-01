import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';

class RouteStepper extends StatelessWidget {
  final String currentStatus;
  final Function(String)? onStepChanged;

  const RouteStepper({
    super.key,
    required this.currentStatus,
    this.onStepChanged,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _getSteps();
    final currentStepIndex = _getCurrentStepIndex();

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = index < currentStepIndex;
        final isCurrent = index == currentStepIndex;
        final isClickable = _isStepClickable(index, currentStepIndex);

        return GestureDetector(
          onTap: isClickable
              ? () => _onStepTap(context, step['status']!)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                // Step Circle
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted || isCurrent
                        ? (isCompleted ? AppColors.success : AppColors.primary)
                        : AppColors.grey.withValues(alpha: 77),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(
                            Icons.check,
                            color: AppColors.white,
                            size: 16,
                          )
                        : Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isCurrent
                                  ? AppColors.white
                                  : AppColors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                // Step Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['title']!,
                        style: TextStyle(
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCompleted || isCurrent
                              ? AppColors.textPrimary
                              : AppColors.grey,
                          fontSize: 14,
                        ),
                      ),
                      if (step['subtitle'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          step['subtitle']!,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status Icon - Now clickable
                GestureDetector(
                  onTap: isClickable
                      ? () => _onStepTap(context, step['status']!)
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: isCurrent
                        ? const Icon(
                            Icons.radio_button_checked,
                            color: AppColors.primary,
                            size: 20,
                          )
                        : isCompleted
                        ? const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                            size: 20,
                          )
                        : Icon(
                            Icons.radio_button_unchecked,
                            color: isClickable
                                ? AppColors.primary.withValues(alpha: 0.6)
                                : AppColors.grey.withValues(alpha: 128),
                            size: 20,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  bool _isStepClickable(int stepIndex, int currentStepIndex) {
    // Allow clicking on the current step and the next step
    return stepIndex == currentStepIndex || stepIndex == currentStepIndex + 1;
  }

  void _onStepTap(BuildContext context, String status) {
    if (onStepChanged != null) {
      onStepChanged!(status);
    } else {
      // Show a dialog to confirm status change
      _showStatusChangeDialog(context, status);
    }
  }

  void _showStatusChangeDialog(BuildContext context, String status) {
    final statusDisplay = _getStatusDisplay(status);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Status'),
          content: Text(
            'Are you sure you want to change the status to "$statusDisplay"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Here you would typically call a method to update the status
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Status change to $statusDisplay requested'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  String _getStatusDisplay(String status) {
    switch (status) {
      case DeliveryTask.statusAssigned:
        return 'Task Assigned';
      case DeliveryTask.statusAccepted:
        return 'Task Accepted';
      case DeliveryTask.statusPickedUp:
        return 'Picked Up';
      case DeliveryTask.statusInTransit:
        return 'In Transit';
      case DeliveryTask.statusDelivered:
        return 'Delivered';
      case DeliveryTask.statusCompleted:
        return 'Completed';
      default:
        return status;
    }
  }

  List<Map<String, String?>> _getSteps() {
    return [
      {
        'title': 'Task Assigned',
        'subtitle': 'Waiting for acceptance',
        'status': DeliveryTask.statusAssigned,
      },
      {
        'title': 'Task Accepted',
        'subtitle': 'Ready to start pickup',
        'status': DeliveryTask.statusAccepted,
      },
      {
        'title': 'Picked Up',
        'subtitle': 'Books collected from library',
        'status': DeliveryTask.statusPickedUp,
      },
      {
        'title': 'In Transit',
        'subtitle': 'On the way to customer',
        'status': DeliveryTask.statusInTransit,
      },
      {
        'title': 'Delivered',
        'subtitle': 'Successfully delivered to customer',
        'status': DeliveryTask.statusDelivered,
      },
      {
        'title': 'Completed',
        'subtitle': 'Task completed successfully',
        'status': DeliveryTask.statusCompleted,
      },
    ];
  }

  int _getCurrentStepIndex() {
    switch (currentStatus) {
      case DeliveryTask.statusAssigned:
        return 0;
      case DeliveryTask.statusAccepted:
        return 1;
      case DeliveryTask.statusPickedUp:
        return 2;
      case DeliveryTask.statusInTransit:
        return 3;
      case DeliveryTask.statusDelivered:
        return 4;
      case DeliveryTask.statusCompleted:
        return 5;
      case DeliveryTask.statusFailed:
        return -1; // Special case for failed tasks
      case DeliveryTask.statusCancelled:
        return -1; // Special case for cancelled tasks
      default:
        return 0;
    }
  }
}
