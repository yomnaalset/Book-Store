import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';
import '../../../core/translations.dart';
import 'status_chip.dart';

class TaskListTile extends StatelessWidget {
  final DeliveryTask task;
  final bool isUrgent;
  final VoidCallback? onTap;

  const TaskListTile({
    super.key,
    required this.task,
    this.isUrgent = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isUrgent ? 4 : 1,
      color: isUrgent ? AppColors.error.withValues(alpha: 26) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with task number and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${AppTranslations.t(context, 'task_number')} ${task.taskNumber}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isUrgent
                            ? AppColors.error
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  StatusChip(status: task.status),
                ],
              ),
              const SizedBox(height: 8),

              // Customer name
              Text(
                task.customerName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),

              // Task type
              Text(
                task.taskType,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              // Addresses
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.deliveryAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Estimated time
              if (task.estimatedDeliveryTime != null)
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(
                        task.estimatedDeliveryTime ?? DateTime.now(),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

              // Time remaining
              if (task.timeRemaining != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${AppTranslations.t(context, 'time_remaining')}: ${_formatDuration(task.timeRemaining ?? Duration.zero)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: task.timeRemaining!.inMinutes < 30
                          ? AppColors.warning
                          : AppColors.grey,
                      fontWeight: task.timeRemaining!.inMinutes < 30
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (taskDate == today) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (taskDate == today.add(const Duration(days: 1))) {
      return 'Tomorrow ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }
}
