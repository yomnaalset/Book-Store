import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TaskFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const TaskFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? AppColors.white
              : (isDark ? AppColors.white : AppColors.textPrimary),
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: onSelected,
      backgroundColor: isDark ? Colors.grey.shade800 : AppColors.white,
      selectedColor: AppColors.primary,
      checkmarkColor: AppColors.white,
      side: BorderSide(
        color: isSelected
            ? AppColors.primary
            : (isDark
                  ? Colors.grey.shade600
                  : AppColors.grey.withValues(alpha: 77)),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
