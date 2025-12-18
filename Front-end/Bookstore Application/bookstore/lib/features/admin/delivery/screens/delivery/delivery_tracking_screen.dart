import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../../models/delivery_assignment.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/empty_state.dart';
import '../../../../../../core/localization/app_localizations.dart';

class DeliveryTrackingScreen extends StatefulWidget {
  const DeliveryTrackingScreen({super.key});

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDeliveryData();
  }

  Future<void> _loadDeliveryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<DeliveryProvider>();
      await provider.loadDeliveryAssignments();
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorLoadingDeliveryData(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.deliveryTracking),
        actions: [
          IconButton(
            onPressed: _loadDeliveryData,
            icon: const Icon(Icons.refresh),
            tooltip: localizations.refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<DeliveryProvider>(
              builder: (context, provider, child) {
                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${localizations.error}: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadDeliveryData,
                          child: Text(localizations.retry),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.deliveryAssignments.isEmpty) {
                  return EmptyState(
                    message: localizations.noDeliveryAssignmentsFound,
                    icon: Icons.local_shipping,
                    actionText: localizations.refresh,
                    onAction: _loadDeliveryData,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: provider.deliveryAssignments.length,
                  itemBuilder: (context, index) {
                    final assignment = provider.deliveryAssignments[index];
                    return _buildDeliveryAssignmentCard(assignment, provider);
                  },
                );
              },
            ),
    );
  }

  Widget _buildDeliveryAssignmentCard(
    DeliveryAssignment assignment,
    DeliveryProvider provider,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Assignment Info
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assignment #${assignment.id}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Order #${assignment.orderId}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: assignment.status),
              ],
            ),
            const SizedBox(height: 16),

            // Delivery Details
            _buildDeliveryDetails(assignment),
            const SizedBox(height: 16),

            // Assignment Status
            _buildAssignmentStatus(assignment),
            const SizedBox(height: 16),

            // Progress Timeline
            _buildProgressTimeline(assignment),
            const SizedBox(height: 16),

            // Action Buttons
            _buildActionButtons(assignment, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryDetails(DeliveryAssignment assignment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delivery Information',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  assignment.deliveryAddress,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule, size: 20, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                'Scheduled: ${_formatDate(assignment.scheduledDate)}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          if (assignment.deliveredDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 20, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Delivered: ${_formatDate(assignment.deliveredDate!)}',
                  style: const TextStyle(fontSize: 14, color: Colors.green),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentStatus(DeliveryAssignment assignment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assignment Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 8),
          if (assignment.deliveryManager != null) ...[
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Agent: ${assignment.deliveryManager!.name}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Phone: ${assignment.deliveryManager!.phone}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'No agent assigned',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressTimeline(DeliveryAssignment assignment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Timeline',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 8),
          _buildTimelineItem('Created', assignment.createdAt, true),
          _buildTimelineItem('Scheduled', assignment.scheduledDate, true),
          if (assignment.deliveredDate != null)
            _buildTimelineItem('Delivered', assignment.deliveredDate!, true),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, DateTime date, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isCompleted ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            '$title: ${_formatDate(date)}',
            style: TextStyle(
              fontSize: 14,
              color: isCompleted ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    DeliveryAssignment assignment,
    DeliveryProvider provider,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _viewDetails(assignment),
            icon: const Icon(Icons.visibility),
            label: const Text('View Details'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _updateStatus(assignment, provider),
            icon: const Icon(Icons.update),
            label: const Text('Update Status'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _viewDetails(DeliveryAssignment assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assignment #${assignment.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order ID: ${assignment.orderId}'),
            Text('Status: ${assignment.status}'),
            Text('Address: ${assignment.deliveryAddress}'),
            Text('Scheduled: ${_formatDate(assignment.scheduledDate)}'),
            if (assignment.deliveryManager != null) ...[
              Text('Agent: ${assignment.deliveryManager!.name}'),
              Text('Phone: ${assignment.deliveryManager!.phone}'),
            ],
            if (assignment.notes != null) Text('Notes: ${assignment.notes}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _updateStatus(DeliveryAssignment assignment, DeliveryProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select new status:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: assignment.status,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Status',
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
                DropdownMenuItem(
                  value: 'in_progress',
                  child: Text('In Progress'),
                ),
                DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) {
                if (value != null) {
                  provider.updateDeliveryStatus(assignment.id, value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Status updated successfully'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
