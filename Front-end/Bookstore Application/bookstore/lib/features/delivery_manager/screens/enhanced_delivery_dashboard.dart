import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/services/api_service.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';
import '../providers/delivery_tasks_provider.dart';
import '../providers/delivery_status_provider.dart';
import '../widgets/enhanced_delivery_card.dart';
import '../widgets/location_tracking_widget.dart';
import '../widgets/delivery_status_widget.dart';

class EnhancedDeliveryDashboard extends StatefulWidget {
  const EnhancedDeliveryDashboard({super.key});

  @override
  State<EnhancedDeliveryDashboard> createState() =>
      _EnhancedDeliveryDashboardState();
}

class _EnhancedDeliveryDashboardState extends State<EnhancedDeliveryDashboard> {
  List<DeliveryTask> _assignedTasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  Timer? _locationTimer;
  Map<String, dynamic>? _currentPosition;
  bool _isTrackingEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadAssignedTasks();
    _initializeLocationTracking();
    _loadDeliveryStatus();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAssignedTasks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<DeliveryTasksProvider>(
        context,
        listen: false,
      );
      await provider.loadTasks();

      if (mounted) {
        setState(() {
          _assignedTasks = provider.tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load tasks: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _initializeLocationTracking() {
    // Location tracking initialization (no automatic status change)
    debugPrint('Location tracking initialized');
  }

  Future<void> _loadDeliveryStatus() async {
    // Load current delivery status from server (no automatic status change)
    final statusProvider = Provider.of<DeliveryStatusProvider>(
      context,
      listen: false,
    );
    await statusProvider.loadCurrentStatus();
  }

  Future<void> _startDelivery(String taskId) async {
    try {
      // The backend will automatically change status to busy when delivery starts
      // No manual status change needed here

      // Simulate getting current location (in real app, this would use GPS)
      final position = {
        'latitude': 40.7128,
        'longitude': -74.0060,
        'speed': 0.0,
      };

      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/api/delivery/tasks/$taskId/start_delivery/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'latitude': position['latitude'],
          'longitude': position['longitude'],
          'address': 'Starting delivery',
          'is_tracking_active': true,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery started successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _loadAssignedTasks();
        _startLocationTracking();

        // Refresh status from server to get the updated status (server automatically sets to busy)
        if (mounted) {
          final statusProvider = Provider.of<DeliveryStatusProvider>(
            context,
            listen: false,
          );
          await statusProvider.refreshStatusFromServer();
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorData['error'] ?? 'Failed to start delivery'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting delivery: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _completeDelivery(String taskId) async {
    try {
      final response = await http.patch(
        Uri.parse(
          '${ApiService.baseUrl}/api/delivery/tasks/$taskId/complete_delivery/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'delivery_notes': 'Delivered successfully',
          'rating': 5,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Delivery completed successfully'),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _loadAssignedTasks();
        _stopLocationTracking();

        // Refresh status from server to get the updated status (server automatically sets to online)
        if (mounted) {
          final statusProvider = Provider.of<DeliveryStatusProvider>(
            context,
            listen: false,
          );
          await statusProvider.refreshStatusFromServer();
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorData['error'] ?? 'Failed to complete delivery',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing delivery: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _startLocationTracking() {
    setState(() {
      _isTrackingEnabled = true;
      _currentPosition = {
        'latitude': 40.7128,
        'longitude': -74.0060,
        'speed': 0.0,
      };
    });

    // Update location every 30 seconds (simulated)
    _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updateLocation();
    });
  }

  void _stopLocationTracking() {
    setState(() {
      _isTrackingEnabled = false;
    });
    _locationTimer?.cancel();
  }

  Future<void> _updateLocation() async {
    try {
      // Simulate location update (in real app, this would use GPS)
      setState(() {
        _currentPosition = {
          'latitude':
              40.7128 + (DateTime.now().millisecondsSinceEpoch % 100) / 10000,
          'longitude':
              -74.0060 + (DateTime.now().millisecondsSinceEpoch % 100) / 10000,
          'speed': (DateTime.now().millisecondsSinceEpoch % 50).toDouble(),
        };
      });

      // Send location update to server
      await http.patch(
        Uri.parse('${ApiService.baseUrl}/api/delivery/location/update/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'latitude': _currentPosition!['latitude'],
          'longitude': _currentPosition!['longitude'],
          'tracking_type': 'gps',
          'accuracy': 5.0,
          'speed': _currentPosition!['speed'],
          'is_tracking_active': true,
        }),
      );
    } catch (e) {
      // Error updating location - silently handle
      debugPrint('Error updating location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'My Deliveries',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          // Status Toggle Button
          const DeliveryStatusToggleButton(),
          Container(
            margin: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAssignedTasks,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: LoadingIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  ErrorMessage(message: _errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadAssignedTasks,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _assignedTasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No assigned deliveries',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You will be notified when new orders are assigned',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Location Tracking Status
                if (_isTrackingEnabled) ...[
                  LocationTrackingWidget(
                    position: _currentPosition,
                    onStopTracking: _stopLocationTracking,
                  ),
                  const Divider(height: 1),
                ],

                // Tasks List
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAssignedTasks,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _assignedTasks.length,
                      itemBuilder: (context, index) {
                        final task = _assignedTasks[index];
                        return EnhancedDeliveryCard(
                          task: task,
                          onStartDelivery: () => _startDelivery(task.id),
                          onCompleteDelivery: () => _completeDelivery(task.id),
                          isTrackingEnabled: _isTrackingEnabled,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
