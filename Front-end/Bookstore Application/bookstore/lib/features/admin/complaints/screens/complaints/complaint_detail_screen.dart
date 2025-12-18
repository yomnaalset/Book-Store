import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/complaints_provider.dart';
import '../../../models/complaint.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../../../core/localization/app_localizations.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final Complaint complaint;

  const ComplaintDetailScreen({super.key, required this.complaint});

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  final _responseController = TextEditingController();
  bool _isLoading = false;
  Complaint? _currentComplaint;

  @override
  void initState() {
    super.initState();
    _currentComplaint = widget.complaint;
    _loadComplaintDetails();
  }

  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaintDetails() async {
    if (!mounted) return;

    try {
      final provider = context.read<ComplaintsProvider>();
      final updatedComplaint = await provider.getComplaintById(
        widget.complaint.id,
      );
      if (updatedComplaint != null && mounted) {
        setState(() {
          _currentComplaint = updatedComplaint;
        });
      }
    } catch (e) {
      // Silently fail - use original complaint data
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ComplaintsProvider>();
      await provider.updateComplaintStatusViaPost(
        widget.complaint.id,
        newStatus,
      );

      // Refresh complaint details
      await _loadComplaintDetails();

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        final statusLabel = newStatus == 'in_progress'
            ? localizations.replied
            : newStatus == 'open'
            ? localizations.open
            : newStatus == 'resolved'
            ? localizations.resolved
            : newStatus == 'closed'
            ? localizations.closed
            : newStatus
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map(
                    (word) => word.isEmpty
                        ? ''
                        : word[0].toUpperCase() + word.substring(1),
                  )
                  .join(' ');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.statusUpdatedTo(statusLabel)),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.error}: ${e.toString()}'),
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

  Future<void> _sendReply() async {
    final localizations = AppLocalizations.of(context);
    if (_responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(localizations.pleaseEnterResponse),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ComplaintsProvider>();

      // Use the new reply endpoint which handles both response and status update
      await provider.sendComplaintReply(
        widget.complaint.id,
        _responseController.text.trim(),
      );

      _responseController.clear();

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.replySentSuccessfully),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh the complaint data
        await _loadComplaintDetails();
      }
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorSendingReply(e.toString())),
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
    final complaint = _currentComplaint ?? widget.complaint;
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.complaintNumber(complaint.id)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadComplaintDetails,
            tooltip: localizations.refreshComplaintDetails,
          ),
          PopupMenuButton<String>(
            onSelected: _updateStatus,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'open',
                child: Text(localizations.markAsOpen),
              ),
              PopupMenuItem(
                value: 'in_progress',
                child: Text(localizations.markAsReplied),
              ),
              PopupMenuItem(
                value: 'resolved',
                child: Text(localizations.markResolved),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                                child: Builder(
                                  builder: (context) {
                                    final localizations = AppLocalizations.of(
                                      context,
                                    );
                                    String displayTitle = complaint.title;
                                    // Translate common complaint titles
                                    final titleLower = complaint.title
                                        .toLowerCase();
                                    if (titleLower.contains(
                                          'complaint about the app',
                                        ) ||
                                        titleLower.contains(
                                          'complaint about app',
                                        )) {
                                      displayTitle =
                                          localizations.complaintAboutTheApp;
                                    }
                                    return Text(
                                      displayTitle,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              StatusChip(status: complaint.status),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            complaint.description,
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
                          Text(
                            localizations.complaintDetailsLabel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            localizations.status,
                            _getLocalizedStatus(
                              complaint.status,
                              localizations,
                            ),
                          ),
                          _buildDetailRow(
                            localizations.created,
                            _formatDate(complaint.createdAt),
                          ),
                          if (complaint.updatedAt != complaint.createdAt)
                            _buildDetailRow(
                              localizations.updated,
                              _formatDate(complaint.updatedAt),
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
                          Text(
                            localizations.customerInformation,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            localizations.nameLabel,
                            complaint.customerName ?? localizations.unknown,
                          ),
                          _buildDetailRow(
                            localizations.emailLabel,
                            complaint.customerEmail ?? localizations.unknown,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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
                  if (widget.complaint.status != Complaint.statusResolved &&
                      widget.complaint.status != 'resolved') ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.reply,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  localizations.replyToComplaint,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _responseController,
                              decoration: InputDecoration(
                                labelText: localizations.yourResponse,
                                hintText: localizations.typeYourReply,
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).colorScheme.surface.withValues(alpha: 0.3),
                              ),
                              maxLines: 5,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _sendReply,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const Icon(Icons.send),
                                label: Text(
                                  _isLoading
                                      ? localizations.sending
                                      : localizations.sendReply,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(
                                    context,
                                  ).colorScheme.primary,
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

  String _getLocalizedStatus(String status, AppLocalizations localizations) {
    switch (status) {
      case 'open':
        return localizations.open;
      case 'in_progress':
        return localizations.inProgress;
      case 'resolved':
        return localizations.resolved;
      case 'closed':
        return localizations.closed;
      default:
        return status;
    }
  }
}
