import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/translations.dart';
import '../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';
import '../providers/delivery_tasks_provider.dart';
import '../widgets/status_chip.dart';
import '../widgets/route_stepper.dart';
import 'messages_screen.dart';
import 'eta_update_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final DeliveryTask task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late DeliveryTask _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '${AppTranslations.t(context, 'task_number')} ${_currentTask.taskNumber}',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MessagesScreen(task: _currentTask),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Task Status Card
            _buildStatusCard(),
            const SizedBox(height: 16),

            // Route Stepper
            _buildRouteStepper(),
            const SizedBox(height: 16),

            // Task Information
            _buildTaskInfo(),
            const SizedBox(height: 16),

            // Customer Information
            _buildCustomerInfo(),
            const SizedBox(height: 16),

            // Book Information
            _buildBookInfo(),
            const SizedBox(height: 16),

            // Delivery Information
            _buildDeliveryInfo(),
            const SizedBox(height: 16),

            // Notes Section
            _buildNotesSection(),
            const SizedBox(height: 16),

            // Action Buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppTranslations.t(context, 'status'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StatusChip(status: _currentTask.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _currentTask.status,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStepper() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Progress',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RouteStepper(
              currentStatus: _currentTask.status,
              onStepChanged: (status) {
                _handleStatusChange(status);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Task Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Task Type', _currentTask.taskType),
            _buildInfoRow('Task Number', _currentTask.taskId),
            _buildInfoRow('Order Number', _currentTask.orderId),
            _buildInfoRow(
              'Assigned At',
              _formatDateTime(_currentTask.assignedAt ?? DateTime.now()),
            ),
            if (_currentTask.estimatedDeliveryTime != null)
              _buildInfoRow(
                'Estimated Delivery',
                _formatDateTime(_currentTask.estimatedDeliveryTime!),
              ),
            if (_currentTask.timeRemaining != null)
              _buildInfoRow(
                'Time Remaining',
                _formatDuration(_currentTask.timeRemaining!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Customer Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Name', _currentTask.customer['name'] ?? 'N/A'),
            _buildInfoRow('Phone', _currentTask.customer['phone'] ?? 'N/A'),
            _buildInfoRow('Email', _currentTask.customer['email'] ?? 'N/A'),
          ],
        ),
      ),
    );
  }

  Widget _buildBookInfo() {
    if (_currentTask.orderItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Book Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._currentTask.orderItems.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['bookTitle'] ?? 'Unknown Book',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'by ${item['bookAuthor'] ?? 'Unknown Author'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Qty: ${item['quantity'] ?? 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Delivery Address', _currentTask.deliveryAddress),
            _buildInfoRow('Delivery City', _currentTask.deliveryCity),
            if (_currentTask.deliveryNotes != null &&
                _currentTask.deliveryNotes!.isNotEmpty)
              _buildInfoRow('Notes', _currentTask.deliveryNotes!),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  onPressed: _addNotes,
                  tooltip: 'Add Notes',
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_currentTask.deliveryNotes != null &&
                _currentTask.deliveryNotes!.isNotEmpty)
              Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      _currentTask.deliveryNotes!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _editNotes,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit Note'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _deleteNotes,
                          icon: const Icon(Icons.delete_outlined, size: 18),
                          label: const Text('Delete Note'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: AppColors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'No notes added yet. Tap the + button to add notes.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // All action buttons in vertical layout
            _buildActionButton(
              'Update Location',
              Icons.my_location,
              AppColors.primary,
              _updateCurrentLocation,
            ),
            const SizedBox(height: 12),

            _buildActionButton(
              'Contact Customer',
              Icons.message_outlined,
              AppColors.primary,
              _contactCustomer,
            ),
            const SizedBox(height: 12),

            _buildActionButton(
              'ETA',
              Icons.schedule_outlined,
              AppColors.primary,
              _navigateToETAUpdate,
            ),
            const SizedBox(height: 12),

            _buildActionButton(
              'View Route',
              Icons.route,
              AppColors.primary,
              _viewRoute,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String text,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isEnabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isEnabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled
              ? color
              : AppColors.grey.withValues(alpha: 0.3),
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          disabledBackgroundColor: AppColors.grey.withValues(alpha: 0.3),
          disabledForegroundColor: AppColors.grey,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }

  // New action methods
  void _updateCurrentLocation() async {
    try {
      // Request location permission
      final permission = await Permission.location.request();
      if (!mounted) return;

      if (permission != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to update location'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      // Update location in backend
      final provider = Provider.of<DeliveryTasksProvider>(
        context,
        listen: false,
      );

      // First update the location via the location service
      final locationSuccess = await provider.updateLocation(
        _currentTask.id,
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

      if (locationSuccess) {
        // Then log the location update activity
        final activitySuccess = await provider.logLocationUpdateActivity(
          _currentTask.orderId,
          position.latitude,
          position.longitude,
        );

        if (!mounted) return;

        if (activitySuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location updated and activity logged successfully',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location updated but failed to log activity'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to update location'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _contactCustomer() async {
    // Log the contact activity using the correct API
    final provider = Provider.of<DeliveryTasksProvider>(context, listen: false);

    final success = await provider.logContactCustomerActivity(
      _currentTask.orderId,
      'phone', // Default contact method
    );

    if (!mounted) return;

    if (success) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MessagesScreen(task: _currentTask),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to log contact activity'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _viewRoute() async {
    // Get current location for route calculation
    try {
      // Request location permission
      final permission = await Permission.location.request();
      if (!mounted) return;

      if (permission != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required to show route'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;

      // Log the route view activity using the correct API
      final provider = Provider.of<DeliveryTasksProvider>(
        context,
        listen: false,
      );

      // Create route points with current location and destination
      // For now, we'll use a sample destination. In a real app, you'd geocode the delivery address
      final routePoints = [
        {
          'lat': position.latitude,
          'lng': position.longitude,
        }, // Current location
        {'lat': 24.7200, 'lng': 46.6900}, // Sample destination coordinates
      ];

      // Log the route activity
      await provider.logRouteUpdateActivity(_currentTask.orderId, routePoints);

      // Open Google Maps with route to delivery address
      final deliveryAddress = _currentTask.deliveryAddress;
      if (deliveryAddress.isNotEmpty) {
        final encodedAddress = Uri.encodeComponent(deliveryAddress);

        // Create Google Maps URL with current location as origin and delivery address as destination
        final mapsUrl =
            'https://www.google.com/maps/dir/?api=1&origin=${position.latitude},${position.longitude}&destination=$encodedAddress&travelmode=driving';

        // Try to open in Google Maps
        final canLaunch = await launchUrl(
          Uri.parse(mapsUrl),
          mode: LaunchMode.externalApplication,
        );

        if (!canLaunch) {
          // Fallback to any maps app
          final fallbackUrl = 'geo:0,0?q=$encodedAddress';
          await launchUrl(
            Uri.parse(fallbackUrl),
            mode: LaunchMode.externalApplication,
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No delivery address available'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error getting location: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _addNotes() {
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Notes'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter notes about this delivery...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          controller: notesController,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter some notes'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Adding notes...'),
                  backgroundColor: AppColors.primary,
                ),
              );

              // Store context before async operations
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Call the API to add notes
              final provider = Provider.of<DeliveryTasksProvider>(
                context,
                listen: false,
              );

              final success = await provider.addOrderNotes(
                _currentTask.orderId,
                notes,
              );

              if (!mounted) return;

              if (success) {
                // Notes are already logged via addOrderNotes method
                // Update local task with new notes
                setState(() {
                  _currentTask = _currentTask.copyWith(
                    deliveryNotes: notes,
                    updatedAt: DateTime.now(),
                  );
                });

                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Notes added successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(provider.error ?? 'Failed to add notes'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _editNotes() {
    final TextEditingController notesController = TextEditingController(
      text: _currentTask.deliveryNotes ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: 'Enter notes about this delivery...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          controller: notesController,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final notes = notesController.text.trim();
              if (notes.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter some notes'),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Updating notes...'),
                  backgroundColor: AppColors.primary,
                ),
              );

              // Store context before async operations
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Call the API to update notes
              final provider = Provider.of<DeliveryTasksProvider>(
                context,
                listen: false,
              );

              final success = await provider.editOrderNotes(
                _currentTask.orderId,
                notes,
              );

              if (!mounted) return;

              if (success) {
                // Notes are already logged via editOrderNotes method
                // Update local task with new notes
                setState(() {
                  _currentTask = _currentTask.copyWith(
                    deliveryNotes: notes,
                    updatedAt: DateTime.now(),
                  );
                });

                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Notes updated successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(provider.error ?? 'Failed to update notes'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteNotes() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notes'),
        content: const Text(
          'Are you sure you want to delete these notes? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading indicator
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Deleting notes...'),
                  backgroundColor: AppColors.primary,
                ),
              );

              // Store context before async operations
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              // Call the API to delete notes
              final provider = Provider.of<DeliveryTasksProvider>(
                context,
                listen: false,
              );

              final success = await provider.deleteOrderNotes(
                _currentTask.orderId,
              );

              if (!mounted) return;

              if (success) {
                // Notes are already logged via deleteOrderNotes method
                // Update local task with empty notes
                setState(() {
                  _currentTask = _currentTask.copyWith(
                    deliveryNotes: '',
                    updatedAt: DateTime.now(),
                  );
                });

                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Notes deleted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              } else {
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(provider.error ?? 'Failed to delete notes'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToETAUpdate() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ETAUpdateScreen(task: _currentTask),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  void _handleStatusChange(String newStatus) async {
    final provider = Provider.of<DeliveryTasksProvider>(context, listen: false);

    debugPrint('🚀 TaskDetailScreen: Starting status change to $newStatus');
    debugPrint('🚀 TaskDetailScreen: Current task ID: ${_currentTask.id}');

    try {
      // Update the task status
      await provider.updateTaskStatus(_currentTask.id, newStatus);

      if (mounted) {
        // Check if there was an error
        if (provider.error != null) {
          debugPrint('🚀 TaskDetailScreen: Provider error: ${provider.error}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update status: ${provider.error}'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          debugPrint('🚀 TaskDetailScreen: Status update successful');
          setState(() {
            _currentTask = _currentTask.copyWith(
              status: newStatus,
              updatedAt: DateTime.now(),
            );
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Status updated to ${_getStatusDisplay(newStatus)}',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('🚀 TaskDetailScreen: Exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
}
