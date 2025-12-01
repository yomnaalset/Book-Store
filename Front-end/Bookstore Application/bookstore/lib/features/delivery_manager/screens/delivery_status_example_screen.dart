import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/delivery_status_provider.dart';
import '../widgets/delivery_status_widget.dart';

/// Example screen showing how to properly use the delivery status system
class DeliveryStatusExampleScreen extends StatefulWidget {
  const DeliveryStatusExampleScreen({super.key});

  @override
  State<DeliveryStatusExampleScreen> createState() =>
      _DeliveryStatusExampleScreenState();
}

class _DeliveryStatusExampleScreenState
    extends State<DeliveryStatusExampleScreen> {
  @override
  void initState() {
    super.initState();
    // Load current status from server (no automatic status change)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialStatus();
    });
  }

  Future<void> _loadInitialStatus() async {
    final statusProvider = Provider.of<DeliveryStatusProvider>(
      context,
      listen: false,
    );
    await statusProvider.loadCurrentStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Status Example'),
        actions: const [
          // Use the proper status toggle button
          DeliveryStatusToggleButton(),
        ],
      ),
      body: Consumer<DeliveryStatusProvider>(
        builder: (context, statusProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Current status display
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const DeliveryStatusWidget(showToggle: true),
                        if (statusProvider.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${statusProvider.errorMessage}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Status information
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Status Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Current Status: ${statusProvider.currentStatus}'),
                        Text(
                          'Can Change Manually: ${statusProvider.canChangeManually}',
                        ),
                        Text('Is Online: ${statusProvider.isOnline}'),
                        Text('Is Offline: ${statusProvider.isOffline}'),
                        Text('Is Busy: ${statusProvider.isBusy}'),
                        Text('Is Loading: ${statusProvider.isLoading}'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Manual status controls (only show if can change manually)
                if (statusProvider.canChangeManually) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Manual Status Controls',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: statusProvider.isLoading
                                    ? null
                                    : () async {
                                        final success = await statusProvider
                                            .updateStatus('online');
                                        if (!success &&
                                            statusProvider.errorMessage !=
                                                null) {
                                          _showErrorSnackBar(
                                            statusProvider.errorMessage!,
                                          );
                                        }
                                      },
                                child: const Text('Go Online'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: statusProvider.isLoading
                                    ? null
                                    : () async {
                                        final success = await statusProvider
                                            .updateStatus('offline');
                                        if (!success &&
                                            statusProvider.errorMessage !=
                                                null) {
                                          _showErrorSnackBar(
                                            statusProvider.errorMessage!,
                                          );
                                        }
                                      },
                                child: const Text('Go Offline'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status Locked',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'You cannot change your status manually while busy. '
                            'The status will automatically change to online when delivery is completed.',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Refresh button
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Refresh Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () async {
                            await statusProvider.refreshStatusFromServer();
                          },
                          child: const Text('Refresh from Server'),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Use this button to refresh the status from the server '
                          'after a delivery is completed.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
