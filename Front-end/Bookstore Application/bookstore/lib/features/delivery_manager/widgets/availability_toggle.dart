import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';

class AvailabilityToggle extends StatelessWidget {
  final String currentStatus;
  final Function(String) onStatusChanged;
  final bool canChangeManually;

  const AvailabilityToggle({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
    this.canChangeManually = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    return Column(
      children: [
        Row(
          children: [
            _buildStatusButton(
              'online',
              localizations.online,
              Icons.circle,
              AppColors.success,
              theme,
            ),
            const SizedBox(width: 12),
            _buildStatusButton(
              'busy',
              localizations.busy,
              Icons.schedule,
              AppColors.warning,
              theme,
            ),
            const SizedBox(width: 12),
            _buildStatusButton(
              'offline',
              localizations.offline,
              Icons.circle_outlined,
              AppColors.error,
              theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusButton(
    String status,
    String label,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    final isSelected = currentStatus == status;
    // Busy button is automatically managed - users cannot manually select it
    final isBusyButton = status == 'busy';
    // Disable manual selection of busy status
    final isEnabled =
        !isBusyButton && (canChangeManually || status == currentStatus);

    return Expanded(
      child: Opacity(
        opacity: isEnabled ? 1.0 : (isSelected ? 1.0 : 0.6),
        child: IgnorePointer(
          ignoring: !isEnabled,
          child: InkWell(
            onTap: () {
              if (status != currentStatus && isEnabled) {
                onStatusChanged(status);
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected
                    ? color.withValues(alpha: 0.1)
                    : theme.colorScheme.surface,
                border: Border.all(
                  color: isSelected ? color : theme.colorScheme.outline,
                  width: isSelected ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Icon(
                        icon,
                        color: isSelected
                            ? color
                            : theme.colorScheme.onSurfaceVariant,
                        size: 24,
                      ),
                      // Show lock icon on busy status when it's disabled
                      if (isBusyButton && isSelected)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Icon(Icons.lock, size: 12, color: color),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? color
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
