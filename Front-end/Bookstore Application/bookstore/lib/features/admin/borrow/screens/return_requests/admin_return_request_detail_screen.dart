import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../borrow/models/return_request.dart';
import '../../../../borrow/providers/return_request_provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/widgets/common/loading_indicator.dart';
import '../../../../borrow/services/return_request_service.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../core/localization/app_localizations.dart';

class AdminReturnRequestDetailScreen extends StatefulWidget {
  final int returnRequestId;

  const AdminReturnRequestDetailScreen({
    super.key,
    required this.returnRequestId,
  });

  @override
  State<AdminReturnRequestDetailScreen> createState() =>
      _AdminReturnRequestDetailScreenState();
}

class _AdminReturnRequestDetailScreenState
    extends State<AdminReturnRequestDetailScreen> {
  final ReturnRequestService _service = ReturnRequestService();
  ReturnRequest? _returnRequest;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _deliveryManagers = [];

  @override
  void initState() {
    super.initState();
    _loadReturnRequestDetails();
  }

  Future<void> _loadReturnRequestDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = context.read<AuthProvider>();
      if (authProvider.token != null) {
        _service.setToken(authProvider.token!);
      }

      final returnRequest = await _service.getReturnRequestById(
        widget.returnRequestId,
      );

      if (mounted) {
        setState(() {
          _returnRequest = returnRequest;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDeliveryManagers() async {
    try {
      _deliveryManagers = await _service.getAvailableDeliveryManagers();
    } catch (e) {
      debugPrint('Error loading delivery managers: $e');
    }
  }

  Future<void> _acceptRequest() async {
    if (_returnRequest == null) return;

    await _loadDeliveryManagers();

    if (!mounted) return;

    if (_deliveryManagers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No delivery managers available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? selectedManagerId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with green checkmark icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF28A745).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF28A745),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Select Delivery Manager',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Select a delivery manager for this request:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF495057),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _deliveryManagers.length,
                    itemBuilder: (context, index) {
                      final manager = _deliveryManagers[index];
                      final isAvailable = manager['is_available'] == true;
                      final isSelected = selectedManagerId == manager['id'];
                      final rawStatus =
                          manager['status_text'] as String? ??
                          manager['status_display'] as String? ??
                          manager['status'] as String? ??
                          'offline';
                      final statusText = rawStatus.isNotEmpty
                          ? rawStatus[0].toUpperCase() +
                                rawStatus.substring(1).toLowerCase()
                          : 'Offline';
                      final statusColor =
                          manager['status_color'] as String? ?? 'grey';

                      // Determine status color
                      Color statusColorValue;
                      IconData statusIcon;
                      if (statusText.toLowerCase() == 'online' ||
                          statusColor == 'green') {
                        statusColorValue = Colors.green;
                        statusIcon = Icons.wifi;
                      } else if (statusText.toLowerCase() == 'busy' ||
                          statusColor == 'orange') {
                        statusColorValue = Colors.orange;
                        statusIcon = Icons.local_shipping;
                      } else {
                        statusColorValue = Colors.grey;
                        statusIcon = Icons.wifi_off;
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isAvailable
                                ? () {
                                    setState(() {
                                      selectedManagerId = manager['id'] as int;
                                    });
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(
                                        0xFF007BFF,
                                      ).withValues(alpha: 0.1)
                                    : isAvailable
                                    ? Colors.white
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF007BFF)
                                      : isAvailable
                                      ? const Color(0xFFE9ECEF)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Status indicator dot
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: statusColorValue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          manager['full_name'] as String? ??
                                              'Unknown',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: isAvailable
                                                ? Colors.black
                                                : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              statusIcon,
                                              size: 14,
                                              color: statusColorValue,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: statusColorValue,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF007BFF),
                                      size: 20,
                                    )
                                  else if (!isAvailable)
                                    const Icon(
                                      Icons.block,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.grey),
                          foregroundColor: Colors.blue,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedManagerId != null
                            ? () => Navigator.of(context).pop(true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedManagerId != null
                              ? const Color(0xFF007BFF)
                              : Colors.grey,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && selectedManagerId != null && mounted) {
      try {
        final provider = context.read<ReturnRequestProvider>();
        final authProvider = context.read<AuthProvider>();
        if (authProvider.token != null) {
          provider.setToken(authProvider.token!);
        }

        // Approve and assign delivery manager in one step
        final success = await provider.approveReturnRequest(
          widget.returnRequestId,
          selectedManagerId!,
        );

        if (mounted) {
          try {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Return request approved and assigned to delivery manager successfully',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
              _loadReturnRequestDetails();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    provider.errorMessage ??
                        'Failed to approve and assign delivery manager',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            // Context might be invalid, log error but don't crash
            debugPrint('Error showing SnackBar: $e');
          }
        }
      } catch (e) {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          } catch (snackBarError) {
            // Context might be invalid, log error but don't crash
            debugPrint('Error showing error SnackBar: $snackBarError');
            debugPrint('Original error: $e');
          }
        }
      }
    }
  }

  Future<void> _assignDeliveryManager() async {
    if (_returnRequest == null) return;

    await _loadDeliveryManagers();

    if (!mounted) return;

    if (_deliveryManagers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No delivery managers available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    int? selectedManagerId;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Delivery Manager',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _deliveryManagers.length,
                    itemBuilder: (context, index) {
                      final manager = _deliveryManagers[index];
                      final isAvailable = manager['is_available'] == true;
                      final isSelected = selectedManagerId == manager['id'];
                      final statusText =
                          manager['status_text'] as String? ??
                          manager['status_display'] as String? ??
                          'Offline';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: isAvailable
                                ? () {
                                    setState(() {
                                      selectedManagerId = manager['id'] as int;
                                    });
                                  }
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.blue.shade50
                                    : isAvailable
                                    ? Colors.white
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          manager['full_name'] as String? ??
                                              'Unknown',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: isAvailable
                                                ? Colors.black
                                                : Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          statusText,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: isAvailable
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.blue,
                                      size: 20,
                                    )
                                  else if (!isAvailable)
                                    const Icon(
                                      Icons.block,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedManagerId != null
                            ? () => Navigator.of(context).pop(true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Assign'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed == true && selectedManagerId != null && mounted) {
      try {
        final provider = context.read<ReturnRequestProvider>();
        final authProvider = context.read<AuthProvider>();
        if (authProvider.token != null) {
          provider.setToken(authProvider.token!);
        }

        final success = await provider.assignDeliveryManagerToReturnRequest(
          widget.returnRequestId,
          selectedManagerId!,
        );

        if (mounted) {
          try {
            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Delivery manager assigned successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              _loadReturnRequestDetails();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    provider.errorMessage ??
                        'Failed to assign delivery manager',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          } catch (e) {
            // Context might be invalid, log error but don't crash
            debugPrint('Error showing SnackBar: $e');
          }
        }
      } catch (e) {
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
            );
          } catch (snackBarError) {
            // Context might be invalid, log error but don't crash
            debugPrint('Error showing error SnackBar: $snackBarError');
            debugPrint('Original error: $e');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Return Request Details'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: LoadingIndicator()),
      );
    }

    if (_errorMessage != null || _returnRequest == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Return Request Details'),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage ?? 'Failed to load return request',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadReturnRequestDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final returnRequest = _returnRequest!;
    final borrowRequest = returnRequest.borrowRequest;

    // GOLDEN RULE: After assignment, status comes from DeliveryRequest.status (via delivery_request_status)
    // The model's fromJson already uses delivery_request_status as primary if available
    // So returnRequest.status should already have the DeliveryRequest status after assignment
    final status = returnRequest.status.toLowerCase();

    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.returnRequestDetails),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReturnRequestDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRequestDetailsCard(returnRequest, borrowRequest),
            const SizedBox(height: 16),
            _buildCustomerInfoCard(borrowRequest),
            const SizedBox(height: 16),
            _buildBorrowedBookCard(borrowRequest),
            const SizedBox(height: 16),
            // Penalty Information Card (always shown)
            _buildPenaltyInformationCard(returnRequest),
            const SizedBox(height: 16),
            // Payment Information Card (only shown if penalty exists)
            if (returnRequest.hasPenalty == true)
              _buildPaymentInformationCard(returnRequest),
            if (returnRequest.hasPenalty == true) const SizedBox(height: 16),
            if (returnRequest.deliveryManagerId != null)
              _buildDeliveryManagerCard(returnRequest),
            if (returnRequest.deliveryManagerId != null)
              const SizedBox(height: 16),
            _buildActionsCard(returnRequest, status),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestDetailsCard(
    ReturnRequest returnRequest,
    dynamic borrowRequest,
  ) {
    final localizations = AppLocalizations.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.description,
                  color: Color(0xFF2C3E50),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  localizations.requestDetails,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              localizations.requestNumberLabel,
              '#${returnRequest.id}',
            ),
            _buildInfoRow(
              localizations.sendingDate,
              _formatDate(returnRequest.requestedAt),
            ),
            if (borrowRequest.dueDate != null)
              _buildInfoRow(
                localizations.expectedReturnDate,
                _formatDate(borrowRequest.dueDate!),
              ),
            _buildInfoRow(
              localizations.requestStatus,
              _getStatusDisplayForAdmin(returnRequest),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard(dynamic borrowRequest) {
    final localizations = AppLocalizations.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF2C3E50), size: 20),
                const SizedBox(width: 8),
                Text(
                  localizations.customerInformation,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCustomerDetailRow(
              localizations.fullName,
              borrowRequest.customerName ?? localizations.notProvided,
              Icons.person_outline,
            ),
            _buildCustomerDetailRow(
              localizations.phoneNumber,
              (borrowRequest.customer?.phone != null &&
                      borrowRequest.customer!.phone!.isNotEmpty)
                  ? borrowRequest.customer!.phone!
                  : localizations.notFound,
              Icons.phone,
            ),
            _buildCustomerDetailRow(
              localizations.emailLabel,
              _getCustomerEmail(borrowRequest),
              Icons.email,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C757D)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6C757D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: value == AppLocalizations.of(context).notProvided
                        ? Colors.red[600]
                        : const Color(0xFF495057),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCustomerEmail(dynamic borrowRequest) {
    final localizations = AppLocalizations.of(context);
    if (borrowRequest.customer?.email != null &&
        borrowRequest.customer!.email.isNotEmpty) {
      return borrowRequest.customer!.email;
    }
    return localizations.notProvided;
  }

  Widget _buildPenaltyInformationCard(ReturnRequest returnRequest) {
    final localizations = AppLocalizations.of(context);
    final hasPenalty = returnRequest.hasPenalty == true;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFFF9800),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  localizations.penaltyInformation,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasPenalty)
              Text(
                localizations.noPenaltyForThisOrder,
                style: const TextStyle(fontSize: 16, color: Color(0xFF6C757D)),
              )
            else ...[
              _buildInfoRow(
                '${localizations.penaltyApplied}:',
                localizations.yes,
              ),
              if (returnRequest.penaltyAmount != null)
                _buildInfoRow(
                  '${localizations.penaltyAmountLabel}:',
                  '\$${returnRequest.penaltyAmount!.toStringAsFixed(2)}',
                ),
              if (returnRequest.overdueDays != null)
                _buildInfoRow(
                  '${localizations.daysOverdue}:',
                  '${returnRequest.overdueDays}',
                ),
              if (returnRequest.dueDate != null)
                _buildInfoRow(
                  '${localizations.dueDateLabel}:',
                  _formatDate(returnRequest.dueDate!),
                ),
              _buildInfoRow(
                '${localizations.penaltyReasonLabel}:',
                localizations.exceededBorrowingPeriod,
              ),
              // Fine action buttons or confirmation label
              _buildFineActionButtons(returnRequest),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFineActionButtons(ReturnRequest returnRequest) {
    final hasPenalty = returnRequest.hasPenalty == true;
    final isFinalized = returnRequest.isFinalized == true;

    // Don't show buttons if no penalty
    if (!hasPenalty) {
      return const SizedBox.shrink();
    }

    // If finalized, show confirmation label
    if (isFinalized) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(
              'Fine Confirmed',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }

    // Show buttons if not finalized
    return Column(
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleConfirmFine(returnRequest),
                icon: const Icon(Icons.check_circle, size: 20),
                label: const Text('Confirm Fine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _handleIncreaseFine(returnRequest),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Increase Fine'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handleConfirmFine(ReturnRequest returnRequest) async {
    if (!mounted) return;

    // Capture authProvider before async gap
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Fine'),
        content: const Text(
          'Are you sure you want to confirm this fine? Once confirmed, the fine cannot be modified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      if (token != null) {
        _service.setToken(token);
      }

      await _service.confirmReturnFine(widget.returnRequestId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fine has been successfully confirmed'),
            backgroundColor: Colors.green,
          ),
        );
        _loadReturnRequestDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleIncreaseFine(ReturnRequest returnRequest) async {
    if (!mounted) return;

    // Capture authProvider before async gap
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final token = authProvider.token;

    final TextEditingController amountController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Increase Fine'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the additional amount to add to the fine:'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Additional Amount (\$)',
                prefixText: '\$',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid amount greater than 0'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.of(context).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Increase'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final additionalAmount = double.tryParse(amountController.text);
    if (additionalAmount == null || additionalAmount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid amount'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      if (token != null) {
        _service.setToken(token);
      }

      await _service.increaseReturnFine(
        widget.returnRequestId,
        additionalAmount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fine increased by \$${additionalAmount.toStringAsFixed(2)}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadReturnRequestDetails();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPaymentInformationCard(ReturnRequest returnRequest) {
    final localizations = AppLocalizations.of(context);
    final hasPenalty = returnRequest.hasPenalty == true;

    // Don't show payment section if no penalty
    if (!hasPenalty) {
      return const SizedBox.shrink();
    }

    // Get payment method display
    String paymentMethodDisplay = localizations.notSelected;
    if (returnRequest.paymentMethod != null) {
      final method = returnRequest.paymentMethod!.toLowerCase();
      if (method == 'cash') {
        paymentMethodDisplay = localizations.paymentMethodCash;
      } else if (method == 'card') {
        paymentMethodDisplay = localizations.mastercard;
      } else {
        paymentMethodDisplay = returnRequest.paymentMethod!;
      }
    }

    // Get payment status display
    String paymentStatusDisplay = localizations.paymentStatusUnpaid;
    Color statusColor = Colors.red;
    if (returnRequest.paymentStatus != null) {
      final status = returnRequest.paymentStatus!.toLowerCase();
      if (status == 'paid' || status == 'completed') {
        paymentStatusDisplay = localizations.paymentStatusPaid;
        statusColor = Colors.green;
      } else if (status == 'pending_payment') {
        paymentStatusDisplay = 'Pending Payment';
        statusColor = Colors.orange;
      } else if (status == 'pending' || status == 'pending_cash_payment') {
        paymentStatusDisplay = localizations.paymentStatusPending;
        statusColor = Colors.orange;
      } else if (status == 'unpaid' || status == 'not_paid') {
        paymentStatusDisplay = localizations.paymentStatusUnpaid;
        statusColor = Colors.red;
      } else {
        // Capitalize first letter for display
        paymentStatusDisplay = status[0].toUpperCase() + status.substring(1);
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment, color: Color(0xFF2C3E50), size: 20),
                const SizedBox(width: 8),
                Text(
                  localizations.paymentInformation,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              '${localizations.paymentMethodLabel}:',
              paymentMethodDisplay,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    '${localizations.paymentStatusLabel}:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6C757D),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      paymentStatusDisplay,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBorrowedBookCard(dynamic borrowRequest) {
    final localizations = AppLocalizations.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.book, color: Color(0xFF2C3E50), size: 20),
                const SizedBox(width: 8),
                Text(
                  localizations.borrowedBook,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child:
                      borrowRequest.book?.coverImageUrl != null &&
                          borrowRequest.book!.coverImageUrl!.isNotEmpty
                      ? Image.network(
                          borrowRequest.book!.coverImageUrl!,
                          width: 60,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.book_outlined,
                                color: Colors.grey,
                                size: 30,
                              ),
                            );
                          },
                        )
                      : Container(
                          width: 60,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.book_outlined,
                            color: Colors.grey,
                            size: 30,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        borrowRequest.bookTitle ?? localizations.notAvailable,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF495057),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${localizations.duration}: ${borrowRequest.durationDays > 0 ? '${borrowRequest.durationDays} ${localizations.days}' : localizations.notAvailable}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6C757D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryManagerCard(ReturnRequest returnRequest) {
    final localizations = AppLocalizations.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping,
                  color: Color(0xFF2C3E50),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  localizations.assignedDeliveryManager,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCustomerDetailRow(
              localizations.fullName,
              returnRequest.deliveryManagerName ?? localizations.notProvided,
              Icons.person_outline,
            ),
            _buildCustomerDetailRow(
              localizations.phoneNumber,
              (returnRequest.deliveryManagerPhone != null &&
                      returnRequest.deliveryManagerPhone!.isNotEmpty)
                  ? returnRequest.deliveryManagerPhone!
                  : localizations.notFound,
              Icons.phone,
            ),
            _buildCustomerDetailRow(
              localizations.emailLabel,
              returnRequest.deliveryManagerEmail ?? localizations.notProvided,
              Icons.email,
            ),
            // Button to view delivery manager's current location
            // Only show when return is in progress (IN_PROGRESS status)
            Builder(
              builder: (context) {
                final isActive = _isReturnActive(returnRequest);
                if (isActive) {
                  return Column(
                    children: [
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _openDeliveryManagerLocation(returnRequest);
                          },
                          icon: const Icon(Icons.location_on, size: 20),
                          label: Text(
                            localizations.viewDeliveryManagerLocation,
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4285F4),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Check if return is currently active (in progress)
  /// Button should appear ONLY when delivery_request_status is "in_delivery"
  /// According to unified delivery status: use deliveryRequestStatus as source of truth
  bool _isReturnActive(ReturnRequest returnRequest) {
    // CRITICAL: Use deliveryRequestStatus (from API) as single source of truth
    // Do NOT use deliveryRequest.status (nested object) - it's outdated
    final deliveryStatus =
        (returnRequest.deliveryRequestStatus ?? returnRequest.status)
            .toLowerCase();

    // Button only shows when delivery is actively in progress (in_delivery)
    // Hide when completed or any other status
    if (deliveryStatus != 'in_delivery') {
      return false;
    }

    // Also check if location data is available (still use deliveryRequest for location)
    if (returnRequest.deliveryRequest != null) {
      return returnRequest.deliveryRequest!.canTrackLocation;
    }
    return false;
  }

  Future<void> _openDeliveryManagerLocation(ReturnRequest returnRequest) async {
    if (!mounted) return;

    if (returnRequest.deliveryManagerId == null) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.deliveryManagerInformationNotAvailable),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // CRITICAL: Use deliveryRequestStatus (from API) as single source of truth
    // Do NOT use deliveryRequest.status (nested object) - it's outdated
    final deliveryStatus =
        (returnRequest.deliveryRequestStatus ?? returnRequest.status)
            .toLowerCase();
    if (deliveryStatus != 'in_delivery') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location tracking is only available during active delivery.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Get auth token
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Try to fetch location from return request endpoint first
      // Pattern: /api/returns/requests/<id>/delivery-location/
      try {
        final response = await http.get(
          Uri.parse(
            '${ApiService.baseUrl}/returns/requests/${returnRequest.id}/delivery-location/',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final locationData = data['data']['location'] ?? data['data'];
            if (locationData != null &&
                locationData['latitude'] != null &&
                locationData['longitude'] != null) {
              final latitude = locationData['latitude'] as double;
              final longitude = locationData['longitude'] as double;
              await _launchGoogleMaps(latitude, longitude);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Return request location endpoint not available: $e');
      }

      // Fallback: Try to get location from delivery manager's profile
      // Pattern: /api/delivery-profiles/<delivery_manager_id>/
      try {
        final response = await http.get(
          Uri.parse(
            '${ApiService.baseUrl}/delivery-profiles/${returnRequest.deliveryManagerId}/',
          ),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['data'] != null) {
            final locationData = data['data']['location'] ?? data['data'];
            if (locationData != null &&
                locationData['latitude'] != null &&
                locationData['longitude'] != null) {
              final latitude = locationData['latitude'] as double;
              final longitude = locationData['longitude'] as double;
              await _launchGoogleMaps(latitude, longitude);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Delivery manager location endpoint error: $e');
      }

      // If both endpoints fail, show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Delivery manager location is not available at the moment.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _launchGoogleMaps(double latitude, double longitude) async {
    try {
      // Try multiple URL schemes in order of preference
      final urls = [
        // Google Maps app (Android) - navigation mode
        Uri.parse('google.navigation:q=$latitude,$longitude'),
        // Google Maps app (Android/iOS) - search mode
        Uri.parse('comgooglemaps://?q=$latitude,$longitude'),
        // Geo scheme (Android) - opens default maps app
        Uri.parse('geo:$latitude,$longitude'),
        // Google Maps web URL (always works as fallback)
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        ),
      ];

      bool launched = false;
      for (final url in urls) {
        try {
          // Try to launch directly - canLaunchUrl can be unreliable
          await launchUrl(url, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        } catch (e) {
          // Try next URL if this one fails
          debugPrint('Failed to launch URL $url: $e');
          continue;
        }
      }

      if (!launched) {
        // Final fallback: try the web URL which should always work
        try {
          final webUrl = Uri.parse(
            'https://www.google.com/maps?q=$latitude,$longitude',
          );
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint('Failed to launch web URL: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open maps application'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error launching Google Maps: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildActionsCard(ReturnRequest returnRequest, String status) {
    final localizations = AppLocalizations.of(context);
    final normalizedStatus = status.toLowerCase();

    // ========================================
    // DEBUG: Log all relevant values to diagnose the issue
    // ========================================
    debugPrint('=== AdminReturnRequestDetail: _buildActionsCard DEBUG ===');
    debugPrint('  returnRequest.id: ${returnRequest.id}');
    debugPrint('  returnRequest.status: ${returnRequest.status}');
    debugPrint('  status parameter: $status');
    debugPrint('  normalizedStatus: $normalizedStatus');
    debugPrint('  deliveryManagerId: ${returnRequest.deliveryManagerId}');
    debugPrint('  deliveryManagerName: ${returnRequest.deliveryManagerName}');
    debugPrint(
      '  deliveryRequestStatus: ${returnRequest.deliveryRequestStatus}',
    );
    debugPrint('  deliveryRequest: ${returnRequest.deliveryRequest}');
    if (returnRequest.deliveryRequest != null) {
      debugPrint(
        '  deliveryRequest.status (LEGACY - DO NOT USE): ${returnRequest.deliveryRequest!.status}',
      );
    }
    debugPrint('=== END DEBUG ===');

    // ========================================
    // GOLDEN RULE: Admin's role ends when DeliveryRequest is created with a delivery manager
    // The single source of truth after assignment is DeliveryRequest.status
    // ========================================

    // Check 1: If a delivery manager has been assigned, admin actions are done
    // This is the most robust check - regardless of status string
    if (returnRequest.deliveryManagerId != null &&
        returnRequest.deliveryManagerId!.isNotEmpty) {
      debugPrint(
        'AdminReturnRequestDetail: Delivery manager assigned (${returnRequest.deliveryManagerId}), hiding actions',
      );
      return const SizedBox.shrink();
    }

    // Check 2: If DeliveryRequest exists with any processing status, hide actions
    if (returnRequest.deliveryRequest != null) {
      final deliveryStatus = returnRequest.deliveryRequest!.status
          .toLowerCase();
      if (deliveryStatus == 'assigned' ||
          deliveryStatus == 'accepted' ||
          deliveryStatus == 'in_progress' ||
          deliveryStatus == 'in_delivery' ||
          deliveryStatus == 'completed' ||
          deliveryStatus == 'delivered') {
        debugPrint(
          'AdminReturnRequestDetail: DeliveryRequest status is $deliveryStatus, hiding actions',
        );
        return const SizedBox.shrink();
      }
    }

    // Check 3: Status-based check (fallback for when delivery_request_status is used)
    if (normalizedStatus == 'assigned' ||
        normalizedStatus == 'accepted' ||
        normalizedStatus == 'in_progress' ||
        normalizedStatus == 'completed' ||
        normalizedStatus == 'in_delivery' ||
        normalizedStatus == 'delivered') {
      debugPrint(
        'AdminReturnRequestDetail: Status is $normalizedStatus, hiding actions',
      );
      return const SizedBox.shrink();
    }

    // Case 1: Status = PENDING (no delivery manager yet) - Show "Accept Request" button
    if (normalizedStatus == 'pending') {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.settings,
                    color: Color(0xFF2C3E50),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    localizations.actions,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _acceptRequest,
                  icon: const Icon(Icons.check_circle),
                  label: Text(localizations.acceptRequest),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Case 2: Status = APPROVED - Show "Assign Delivery Manager" button
    if (normalizedStatus == 'approved') {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.settings,
                    color: Color(0xFF2C3E50),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    localizations.actions,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _assignDeliveryManager,
                  icon: const Icon(Icons.person_add),
                  label: Text(localizations.assignDeliveryManager),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Case 3: Status = ASSIGNED or other - No actions (delivery manager section already shown)
    return const SizedBox.shrink();
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6C757D),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Get status display for admin - uses DeliveryRequest.status if available
  /// This is the correct way: Admin should see DeliveryRequest status, not ReturnRequest.status
  String _getStatusDisplayForAdmin(ReturnRequest returnRequest) {
    final localizations = AppLocalizations.of(context);

    // CRITICAL: Use deliveryRequestStatus (from API) as single source of truth
    // Do NOT use deliveryRequest.status (nested object) or returnRequest.status - they're outdated
    final deliveryRequestStatus = returnRequest.deliveryRequestStatus;

    // If deliveryRequestStatus exists, use it (this is the correct source after assignment)
    if (deliveryRequestStatus != null && deliveryRequestStatus.isNotEmpty) {
      // Use deliveryRequestStatus directly from API
      final deliveryStatus = deliveryRequestStatus.toLowerCase();

      // Map DeliveryRequest statuses to user-friendly messages
      switch (deliveryStatus) {
        case 'assigned':
          return 'Delivery Manager Assigned'; // or localizations.deliveryManagerAssigned if available
        case 'accepted':
          return 'Awaiting Delivery'; // Delivery manager accepted, waiting for pickup
        case 'in_delivery':
        case 'in_progress':
          return 'In Delivery'; // Currently being delivered/returned
        case 'completed':
          return 'Completed'; // Delivery/return completed
        case 'pending':
          // This shouldn't happen after assignment, but handle it
          return 'Awaiting Delivery Manager Acceptance';
        default:
          // Fallback to localized status
          return localizations.getReturnRequestStatusLabel(
            deliveryRequestStatus,
          );
      }
    }

    // No deliveryRequestStatus - fallback to ReturnRequest status
    return localizations.getReturnRequestStatusLabel(returnRequest.status);
  }
}
