import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/customer_complaints_provider.dart';
import '../models/customer_complaint.dart';
import '../../../core/localization/app_localizations.dart';
import 'add_complaint_screen.dart';
import 'complaint_detail_screen.dart';

class CustomerComplaintsListScreen extends StatefulWidget {
  const CustomerComplaintsListScreen({super.key});

  @override
  State<CustomerComplaintsListScreen> createState() =>
      _CustomerComplaintsListScreenState();
}

class _CustomerComplaintsListScreenState
    extends State<CustomerComplaintsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadComplaints();
    });
  }

  Future<void> _loadComplaints() async {
    if (!mounted) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final complaintsProvider = Provider.of<CustomerComplaintsProvider>(
      context,
      listen: false,
    );

    if (authProvider.token != null) {
      complaintsProvider.setToken(authProvider.token);
      await complaintsProvider.loadComplaints();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.complaints,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withValues(alpha: 204),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Consumer<CustomerComplaintsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.complaints.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.complaints.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.errorLoadingComplaints,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.error ?? localizations.unknownError,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadComplaints,
                    child: Text(localizations.retry),
                  ),
                ],
              ),
            );
          }

          if (provider.complaints.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.feedback_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.noComplaintsYet,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    localizations.tapToSubmitComplaint,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadComplaints,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.complaints.length,
              itemBuilder: (context, index) {
                final complaint = provider.complaints[index];
                return _buildComplaintCard(context, complaint);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddComplaintScreen()),
          );
          if (result == true) {
            _loadComplaints();
          }
        },
        icon: const Icon(Icons.add),
        label: Text(localizations.addComplaint),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  Widget _buildComplaintCard(
    BuildContext context,
    CustomerComplaint complaint,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (complaint.status) {
      case CustomerComplaint.statusPending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending_outlined;
        break;
      case CustomerComplaint.statusUnderReview:
        statusColor = Colors.blue;
        statusIcon = Icons.rate_review_outlined;
        break;
      case CustomerComplaint.statusResolved:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ComplaintDetailScreen(complaintId: complaint.id),
            ),
          );
          if (result == true) {
            _loadComplaints();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        String displayTitle =
                            complaint.title ?? localizations.complaint;
                        // Translate common complaint titles
                        if (complaint.title != null) {
                          final titleLower = complaint.title!.toLowerCase();
                          if (titleLower.contains('complaint about the app') ||
                              titleLower.contains('complaint about app')) {
                            displayTitle = localizations.complaintAboutTheApp;
                          }
                        }
                        return Text(
                          displayTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 16, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              _getLocalizedStatus(
                                complaint.status,
                                localizations,
                              ),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                complaint.message,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    '${localizations.submitted}: ${_formatDate(complaint.createdAt, localizations)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date, AppLocalizations localizations) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return localizations.justNow;
        }
        return '${difference.inMinutes} ${localizations.minutesAgo}';
      }
      return '${difference.inHours} ${localizations.hoursAgo}';
    } else if (difference.inDays == 1) {
      return localizations.yesterday;
    } else if (difference.inDays < 7) {
      return '${difference.inDays} ${localizations.daysAgo}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _getLocalizedStatus(String status, AppLocalizations localizations) {
    switch (status) {
      case CustomerComplaint.statusPending:
        return localizations.pending;
      case CustomerComplaint.statusUnderReview:
        return localizations.underReview;
      case CustomerComplaint.statusResolved:
        return localizations.resolved;
      default:
        return localizations.pending;
    }
  }
}
