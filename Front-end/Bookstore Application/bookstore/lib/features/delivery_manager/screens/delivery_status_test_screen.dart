import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/delivery_status_provider.dart';
import '../widgets/delivery_status_widget.dart';

/// Test screen to verify the unified delivery status logic
class DeliveryStatusTestScreen extends StatefulWidget {
  const DeliveryStatusTestScreen({super.key});

  @override
  State<DeliveryStatusTestScreen> createState() =>
      _DeliveryStatusTestScreenState();
}

class _DeliveryStatusTestScreenState extends State<DeliveryStatusTestScreen> {
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
        title: const Text('Delivery Status Test'),
        actions: const [DeliveryStatusToggleButton()],
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

                // Test scenarios
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Test Scenarios',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Scenario 1: Manual toggle (only online/offline)
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: statusProvider.isLoading
                                  ? null
                                  : () async {
                                      final success = await statusProvider
                                          .updateStatus('online');
                                      if (!success &&
                                          statusProvider.errorMessage != null) {
                                        _showErrorSnackBar(
                                          statusProvider.errorMessage!,
                                        );
                                      }
                                    },
                              child: const Text('Set Online'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: statusProvider.isLoading
                                  ? null
                                  : () async {
                                      final success = await statusProvider
                                          .updateStatus('offline');
                                      if (!success &&
                                          statusProvider.errorMessage != null) {
                                        _showErrorSnackBar(
                                          statusProvider.errorMessage!,
                                        );
                                      }
                                    },
                              child: const Text('Set Offline'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Scenario 2: Try to set busy (should fail)
                        ElevatedButton(
                          onPressed: statusProvider.isLoading
                              ? null
                              : () async {
                                  // This should fail as busy is not allowed for manual changes
                                  final success = await statusProvider
                                      .updateStatus('busy');
                                  if (!success &&
                                      statusProvider.errorMessage != null) {
                                    _showErrorSnackBar(
                                      statusProvider.errorMessage!,
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                          child: const Text('Try Set Busy (Should Fail)'),
                        ),

                        const SizedBox(height: 8),

                        // Scenario 3: Refresh from server
                        ElevatedButton(
                          onPressed: () async {
                            await statusProvider.refreshStatusFromServer();
                          },
                          child: const Text('Refresh from Server'),
                        ),
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

                // Expected behavior
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected Behavior',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '✅ Manual changes: Only online ↔ offline\n'
                          '❌ Manual changes: Cannot set busy\n'
                          '🔄 Automatic changes: Server controls busy status\n'
                          '📱 UI: Toggle only shows online/offline options\n'
                          '🔄 Sync: Status refreshes after delivery operations',
                          style: TextStyle(fontSize: 12),
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
