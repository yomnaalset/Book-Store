import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/delivery_provider.dart';
import '../../../models/delivery_order.dart';
import '../../../models/delivery_agent.dart';
import '../../../../../shared/widgets/status_chip.dart';
import '../../../../../shared/widgets/empty_state.dart';
import '../../../../../../core/localization/app_localizations.dart';

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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizations.errorLoadingData(e.toString()))),
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
        title: Text(localizations.assignDeliveryAgents),
        actions: [
          IconButton(
            onPressed: () => _loadData(),
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
                          onPressed: _loadData,
                          child: Text(localizations.retry),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.orders.isEmpty) {
                  return EmptyState(
                    message: localizations.noDeliveryOrdersFound,
                    icon: Icons.local_shipping,
                    actionText: localizations.refresh,
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
                                  localizations.availableAgents,
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
                              localizations.agentsAvailableForAssignment(
                                provider.availableAgents.length,
                              ),
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
                          return _buildDeliveryOrderCard(
                            order,
                            provider,
                            context,
                          );
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
    BuildContext context,
  ) {
    final localizations = AppLocalizations.of(context);
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
                    '${localizations.orders} #${order.id}',
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
                  '${order.order?.items.length ?? 0} ${(order.order?.items.length ?? 0) == 1 ? localizations.itemsLabel : localizations.itemsLabelPlural}',
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
                          ? localizations.assignedTo(assignedAgent ?? '')
                          : localizations.noAgentAssigned,
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
                      label: Text(localizations.assignAgent),
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
                      label: Text(localizations.reassign),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _unassignAgent(order, provider),
                      icon: const Icon(Icons.person_remove),
                      label: Text(localizations.unassign),
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
    final localizations = AppLocalizations.of(context);
    if (provider.availableAgents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.noAvailableAgentsToAssign)),
      );
      return;
    }

    DeliveryAgent? selectedAgent = provider.availableAgents.first;

    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.assignDeliveryAgent),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(localizations.selectAgentToAssign),
              const SizedBox(height: 16),
              DropdownButtonFormField<DeliveryAgent>(
                initialValue: selectedAgent,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: localizations.agent,
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
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _assignAgent(order, selectedAgent!, provider);
              },
              child: Text(localizations.assignAgent),
            ),
          ],
        );
      },
    );
  }

  void _showReassignAgentDialog(
    DeliveryOrder order,
    DeliveryProvider provider,
  ) {
    DeliveryAgent? selectedAgent = provider.availableAgents.first;

    showDialog(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.reassignDeliveryAgent),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                localizations.currentlyAssignedTo(
                  order.deliveryAgent?.name ?? localizations.noOne,
                ),
              ),
              const SizedBox(height: 16),
              Text(localizations.selectNewAgent),
              const SizedBox(height: 16),
              DropdownButtonFormField<DeliveryAgent>(
                initialValue: selectedAgent,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: localizations.newAgent,
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
              child: Text(localizations.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _assignAgent(order, selectedAgent!, provider);
              },
              child: Text(localizations.reassign),
            ),
          ],
        );
      },
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
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.agentAssignedSuccessfully(agent.name)),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorAssigningAgent(e.toString())),
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

  Future<void> _unassignAgent(
    DeliveryOrder order,
    DeliveryProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(localizations.unassignAgent),
          content: Text(
            localizations.areYouSureUnassign(
              order.deliveryAgent?.name ?? localizations.agent,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(localizations.unassign),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await provider.unassignAgent(int.parse(order.id));

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(localizations.agentUnassignedSuccessfully)),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.errorUnassigningAgent(e.toString())),
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
  }
}
