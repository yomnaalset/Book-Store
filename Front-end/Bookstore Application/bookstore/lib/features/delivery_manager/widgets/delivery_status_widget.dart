import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/delivery_status_provider.dart';
import '../../../core/constants/app_colors.dart';

/// Widget for displaying and controlling delivery status
class DeliveryStatusWidget extends StatelessWidget {
  final bool showToggle;
  final VoidCallback? onStatusChanged;

  const DeliveryStatusWidget({
    super.key,
    this.showToggle = true,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DeliveryStatusProvider>(
      builder: (context, statusProvider, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator
            _buildStatusIndicator(statusProvider.currentStatus),
            const SizedBox(width: 8),

            // Status text
            Text(
              _getStatusText(statusProvider.currentStatus),
              style: TextStyle(
                color: _getStatusColor(statusProvider.currentStatus),
                fontWeight: FontWeight.w500,
              ),
            ),

            // Toggle switch (if enabled and not busy)
            if (showToggle && statusProvider.canChangeManually) ...[
              const SizedBox(width: 12),
              _buildStatusToggle(statusProvider),
            ],

            // Loading indicator
            if (statusProvider.isLoading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatusIndicator(String status) {
    IconData icon;
    Color color;

    switch (status) {
      case 'online':
        icon = Icons.wifi;
        color = Colors.green;
        break;
      case 'busy':
        icon = Icons.local_shipping;
        color = Colors.orange;
        break;
      case 'offline':
      default:
        icon = Icons.wifi_off;
        color = Colors.red;
        break;
    }

    return Icon(icon, color: color, size: 20);
  }

  Widget _buildStatusToggle(DeliveryStatusProvider statusProvider) {
    return Switch(
      value: statusProvider.isOnline,
      onChanged: (bool value) async {
        if (!statusProvider.canChangeManually) {
          _showBusyMessage(statusProvider);
          return;
        }

        final newStatus = value ? 'online' : 'offline';
        final success = await statusProvider.updateStatus(newStatus);

        if (!success && statusProvider.errorMessage != null) {
          _showErrorMessage(statusProvider.errorMessage!);
        }

        onStatusChanged?.call();
      },
      activeThumbColor: Colors.green,
      inactiveThumbColor: Colors.red,
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'online':
        return 'Online';
      case 'busy':
        return 'Busy';
      case 'offline':
        return 'Offline';
      default:
        return 'Unknown';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'online':
        return Colors.green;
      case 'busy':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showBusyMessage(DeliveryStatusProvider statusProvider) {
    // This would typically show a snackbar or dialog
    debugPrint('Cannot change status while busy');
  }

  void _showErrorMessage(String message) {
    // This would typically show a snackbar or dialog
    debugPrint('Status update error: $message');
  }
}

/// Simple status indicator widget (read-only)
class DeliveryStatusIndicator extends StatelessWidget {
  final String status;
  final double size;

  const DeliveryStatusIndicator({
    super.key,
    required this.status,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (status) {
      case 'online':
        icon = Icons.wifi;
        color = Colors.green;
        break;
      case 'busy':
        icon = Icons.local_shipping;
        color = Colors.orange;
        break;
      case 'offline':
      default:
        icon = Icons.wifi_off;
        color = Colors.red;
        break;
    }

    return Icon(icon, color: color, size: size);
  }
}

/// Status toggle button for app bar
class DeliveryStatusToggleButton extends StatelessWidget {
  const DeliveryStatusToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeliveryStatusProvider>(
      builder: (context, statusProvider, child) {
        return PopupMenuButton<String>(
          icon: DeliveryStatusIndicator(status: statusProvider.currentStatus),
          enabled:
              statusProvider.canChangeManually && !statusProvider.isLoading,
          onSelected: (status) async {
            if (!statusProvider.canChangeManually) {
              _showBusyMessage(context);
              return;
            }

            final success = await statusProvider.updateStatus(status);

            if (!success && statusProvider.errorMessage != null) {
              if (context.mounted) {
                _showErrorMessage(context, statusProvider.errorMessage!);
              }
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'online',
              child: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Go Online'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'offline',
              child: Row(
                children: [
                  Icon(Icons.wifi_off, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Go Offline'),
                ],
              ),
            ),
            // Note: 'busy' status is not included as it's controlled automatically by the server
          ],
        );
      },
    );
  }

  void _showBusyMessage(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'You cannot change status while busy. Status will automatically change to online when delivery is completed.',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
