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
    final isSelected =
        currentStatus == status ||
        (currentStatus == 'busy' &&
            status == 'online'); // Handle legacy 'busy' status
    final isEnabled = canChangeManually || status == currentStatus;

    return Expanded(
      child: Opacity(
        opacity: isEnabled ? 1.0 : (isSelected ? 1.0 : 0.6),
        child: IgnorePointer(
          ignoring: !isEnabled,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (status != currentStatus && isEnabled) {
                  onStatusChanged(status);
                }
              },
              borderRadius: BorderRadius.circular(12),
              splashColor: color.withValues(alpha: 0.1),
              highlightColor: color.withValues(alpha: 0.05),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 12,
                ),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.15),
                            color.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : theme.colorScheme.surface,
                  border: isSelected
                      ? Border.all(color: color, width: 2.5)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                            spreadRadius: 0,
                          ),
                        ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.2)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            icon,
                            color: isSelected
                                ? color
                                : theme.colorScheme.onSurfaceVariant,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? color
                            : theme.colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
