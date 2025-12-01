import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/complaints_provider.dart';
import '../../../models/complaint.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../../auth/providers/auth_provider.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;

  const ComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final _responseController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ComplaintsProvider>();
      await provider.updateComplaintStatus(widget.complaint.id, newStatus);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _assignComplaint() async {
    // For now, we'll use a simple dialog to assign to a manager
    // In a real app, you'd have a list of available managers
    final assignedTo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Complaint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select a manager to assign this complaint to:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('John Manager'),
              onTap: () => Navigator.pop(context, 'John Manager'),
            ),
            ListTile(
              title: const Text('Jane Supervisor'),
              onTap: () => Navigator.pop(context, 'Jane Supervisor'),
            ),
            ListTile(
              title: const Text('Mike Admin'),
              onTap: () => Navigator.pop(context, 'Mike Admin'),
            ),
          ],
        ),
      ),
    );

    if (assignedTo != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (!mounted) return;
        final provider = context.read<ComplaintsProvider>();
        // Use the current user's ID as the assigned staff
        final authProvider = context.read<AuthProvider>();
        final currentUserId = authProvider.user?.id;
        if (currentUserId != null) {
          await provider.assignComplaint(widget.complaint.id, currentUserId);
        } else {
          throw Exception('User not authenticated');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Complaint assigned to $assignedTo')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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

  Future<void> _addResponse() async {
    if (_responseController.text.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ComplaintsProvider>();
      await provider.addComplaintResponse(
        widget.complaint.id,
        _responseController.text.trim(),
      );

      _responseController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Response added successfully')),
        );
        // Refresh the complaint data
        final updatedComplaint = await provider.getComplaintById(
          widget.complaint.id,
        );
        if (updatedComplaint != null) {
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resolveComplaint() async {
    final resolution = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Complaint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a resolution summary:'),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Resolution',
                border: OutlineInputBorder(),
                hintText: 'Describe how the complaint was resolved...',
              ),
              maxLines: 3,
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _responseController.text),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (resolution != null && resolution.trim().isNotEmpty) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (!mounted) return;
        final provider = context.read<ComplaintsProvider>();
        await provider.resolveComplaint(widget.complaint.id, resolution.trim());

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Complaint resolved successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complaint #${widget.complaint.id}'),
        actions: [
          if (widget.complaint.status != Complaint.statusResolved)
            PopupMenuButton<String>(
              onSelected: _updateStatus,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: Complaint.statusPending,
                  child: Text('Mark Under Review'),
                ),
                const PopupMenuItem(
                  value: Complaint.statusInProgress,
                  child: Text('Mark In Progress'),
                ),
                const PopupMenuItem(
                  value: Complaint.statusResolved,
                  child: Text('Mark Resolved'),
                ),
                const PopupMenuItem(
                  value: Complaint.statusClosed,
                  child: Text('Mark Closed'),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.complaint.title,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              StatusChip(status: widget.complaint.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.complaint.description,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Details Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Complaint Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow('Type', widget.complaint.type),
                          _buildDetailRow(
                            'Priority',
                            widget.complaint.priority,
                          ),
                          _buildDetailRow('Status', widget.complaint.status),
                          _buildDetailRow(
                            'Created',
                            _formatDate(widget.complaint.createdAt),
                          ),
                          if (widget.complaint.updatedAt !=
                              widget.complaint.createdAt)
                            _buildDetailRow(
                              'Updated',
                              _formatDate(widget.complaint.updatedAt),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Customer Information Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Customer Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            'Name',
                            widget.complaint.customerName ?? 'Unknown',
                          ),
                          _buildDetailRow(
                            'Email',
                            widget.complaint.customerEmail ?? 'Unknown',
                          ),
                          if (widget.complaint.assignedToName != null)
                            _buildDetailRow(
                              'Assigned To',
                              widget.complaint.assignedToName!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resolution Card (if resolved)
                  if (widget.complaint.resolution != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Resolution',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(widget.complaint.resolution!),
                            if (widget.complaint.resolvedAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Resolved on: ${_formatDate(widget.complaint.resolvedAt!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Responses Card - Not implemented in current model
                  // Card(
                  //   child: Padding(
                  //     padding: const EdgeInsets.all(16.0),
                  //     child: Column(
                  //       crossAxisAlignment: CrossAxisAlignment.start,
                  //       children: [
                  //         const Text(
                  //           'Responses',
                  //           style: TextStyle(
                  //             fontSize: 18,
                  //             fontWeight: FontWeight.bold,
                  //           ),
                  //         ),
                  //         const SizedBox(height: 16),
                  //         // Responses would be displayed here when implemented
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(height: 16),

                  // Add Response Section
                  if (widget.complaint.status != Complaint.statusResolved) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add Response',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _responseController,
                              decoration: const InputDecoration(
                                labelText: 'Your Response',
                                border: OutlineInputBorder(),
                                hintText: 'Type your response here...',
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _addResponse,
                                    child: const Text('Add Response'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _assignComplaint,
                                    child: const Text('Assign'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Action Buttons
                  if (widget.complaint.status != Complaint.statusResolved) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _resolveComplaint,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Resolve Complaint'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
