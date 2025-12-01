import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../../models/delivery_order.dart';
import '../../../models/delivery_agent.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/empty_state.dart';

class DeliveryAssignScreen extends StatefulWidget {
  const DeliveryAssignScreen({super.key});

  @override
  State<DeliveryAssignScreen> createState() => _DeliveryAssignScreenState();
}

class _DeliveryAssignScreenState extends State<DeliveryAssignScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Only load data when this screen is actually displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<DeliveryProvider>();
      await Future.wait([
        provider.getOrdersForDelivery(),
        provider.refreshAvailableAgents(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: ${e.toString()}')),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Delivery Agents'),
        actions: [
          IconButton(
            onPressed: () => _loadData(),
            icon: const Icon(Icons.refresh),
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
                          'Error: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.orders.isEmpty) {
                  return EmptyState(
                    message: 'No delivery orders found',
                    icon: Icons.local_shipping,
                    actionText: 'Refresh',
                    onAction: _loadData,
                  );
                }

                return Column(
                  children: [
                    // Available Agents Summary
                    if (provider.availableAgents.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        margin: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Available Agents',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${provider.availableAgents.length} agent${provider.availableAgents.length == 1 ? '' : 's'} available for assignment',
                              style: TextStyle(color: Colors.blue[700]),
                            ),
                          ],
                        ),
                      ),

                    // Delivery Orders List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: provider.orders.length,
                        itemBuilder: (context, index) {
                          final order = provider.orders[index];
                          return _buildDeliveryOrderCard(order, provider);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildDeliveryOrderCard(
    DeliveryOrder order,
    DeliveryProvider provider,
  ) {
    final isAssigned = order.deliveryAgent != null;
    final assignedAgent = order.deliveryAgent?.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Order #${order.id}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 16),

            // Customer Information
            Row(
              children: [
                const Icon(Icons.person, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        order.customerEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Order Details
            Row(
              children: [
                const Icon(Icons.inventory, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${order.order?.items.length ?? 0} item${(order.order?.items.length ?? 0) == 1 ? '' : 's'}',
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Assignment Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isAssigned
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isAssigned
                      ? Colors.green.withValues(alpha: 0.3)
                      : Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isAssigned ? Icons.check_circle : Icons.pending,
                    color: isAssigned ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isAssigned
                          ? 'Assigned to: $assignedAgent'
                          : 'No agent assigned',
                      style: TextStyle(
                        color: isAssigned
                            ? Colors.green[700]
                            : Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            if (!isAssigned) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAssignAgentDialog(order, provider),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Assign Agent'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _showReassignAgentDialog(order, provider),
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Reassign'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _unassignAgent(order, provider),
                      icon: const Icon(Icons.person_remove),
                      label: const Text('Unassign'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAssignAgentDialog(DeliveryOrder order, DeliveryProvider provider) {
    if (provider.availableAgents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available agents to assign')),
      );
      return;
    }

    DeliveryAgent? selectedAgent = provider.availableAgents.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Delivery Agent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select an agent to assign:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<DeliveryAgent>(
              initialValue: selectedAgent,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Agent',
              ),
              items: provider.availableAgents
                  .map(
                    (agent) => DropdownMenuItem(
                      value: agent,
                      child: Text('${agent.name} (${agent.phone})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedAgent = value;
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _assignAgent(order, selectedAgent!, provider);
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }

  void _showReassignAgentDialog(
    DeliveryOrder order,
    DeliveryProvider provider,
  ) {
    DeliveryAgent? selectedAgent = provider.availableAgents.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reassign Delivery Agent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Currently assigned to: ${order.deliveryAgent?.name ?? 'No one'}',
            ),
            const SizedBox(height: 16),
            const Text('Select new agent:'),
            const SizedBox(height: 16),
            DropdownButtonFormField<DeliveryAgent>(
              initialValue: selectedAgent,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'New Agent',
              ),
              items: provider.availableAgents
                  .map(
                    (agent) => DropdownMenuItem(
                      value: agent,
                      child: Text('${agent.name} (${agent.phone})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  selectedAgent = value;
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
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _assignAgent(order, selectedAgent!, provider);
            },
            child: const Text('Reassign'),
          ),
        ],
      ),
    );
  }

  Future<void> _assignAgent(
    DeliveryOrder order,
    DeliveryAgent agent,
    DeliveryProvider provider,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await provider.assignAgent(int.parse(order.id), agent.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Agent ${agent.name} assigned successfully')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error assigning agent: ${e.toString()}')),
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

  Future<void> _unassignAgent(
    DeliveryOrder order,
    DeliveryProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unassign Agent'),
        content: Text(
          'Are you sure you want to unassign ${order.deliveryAgent?.name ?? 'the agent'} from this delivery order?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await provider.unassignAgent(int.parse(order.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Agent unassigned successfully')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error unassigning agent: ${e.toString()}')),
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
  }
}
