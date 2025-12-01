import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../borrow/models/return_request.dart';
import '../../../../borrow/providers/return_request_provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/widgets/common/loading_indicator.dart';
import '../../../../borrow/services/return_request_service.dart';

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
    final status = returnRequest.status.toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Request Details'),
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
            if (returnRequest.deliveryManagerId != null)
              _buildDeliveryManagerCard(returnRequest),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description, color: Color(0xFF2C3E50), size: 20),
                SizedBox(width: 8),
                Text(
                  'Request Details',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Request Number', '#${returnRequest.id}'),
            _buildInfoRow(
              'Sending Date',
              _formatDate(returnRequest.requestedAt),
            ),
            if (borrowRequest.dueDate != null)
              _buildInfoRow(
                'Expected Return Date',
                _formatDate(borrowRequest.dueDate!),
              ),
            _buildInfoRow(
              'Request Status',
              _getStatusDisplay(returnRequest.status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard(dynamic borrowRequest) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person, color: Color(0xFF2C3E50), size: 20),
                SizedBox(width: 8),
                Text(
                  'Customer Information',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCustomerDetailRow(
              'Full Name',
              borrowRequest.customerName ?? 'Not provided',
              Icons.person_outline,
            ),
            _buildCustomerDetailRow(
              'Phone Number',
              _getCustomerPhone(borrowRequest),
              Icons.phone,
            ),
            _buildCustomerDetailRow(
              'Email',
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
                    color: value == 'Not provided'
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

  String _getCustomerPhone(dynamic borrowRequest) {
    if (borrowRequest.customer?.phone != null &&
        borrowRequest.customer!.phone!.isNotEmpty) {
      return borrowRequest.customer!.phone!;
    }
    return 'Not provided';
  }

  String _getCustomerEmail(dynamic borrowRequest) {
    if (borrowRequest.customer?.email != null &&
        borrowRequest.customer!.email.isNotEmpty) {
      return borrowRequest.customer!.email;
    }
    return 'Not provided';
  }

  Widget _buildBorrowedBookCard(dynamic borrowRequest) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.book, color: Color(0xFF2C3E50), size: 20),
                SizedBox(width: 8),
                Text(
                  'Borrowed Book',
                  style: TextStyle(
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.book_outlined,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        borrowRequest.bookTitle ?? 'N/A',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF495057),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Duration: ${borrowRequest.durationDays > 0 ? borrowRequest.durationDays : 'N/A'} ${borrowRequest.durationDays > 0 ? 'days' : ''}',
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.local_shipping, color: Color(0xFF2C3E50), size: 20),
                SizedBox(width: 8),
                Text(
                  'Assigned Delivery Manager',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCustomerDetailRow(
              'Full Name',
              returnRequest.deliveryManagerName ?? 'Not provided',
              Icons.person_outline,
            ),
            _buildCustomerDetailRow(
              'Phone Number',
              returnRequest.deliveryManagerPhone ?? 'Not provided',
              Icons.phone,
            ),
            _buildCustomerDetailRow(
              'Email',
              returnRequest.deliveryManagerEmail ?? 'Not provided',
              Icons.email,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard(ReturnRequest returnRequest, String status) {
    // Case 1: Status = PENDING - Show "Accept Request" button
    if (status == 'pending' || status.toUpperCase() == 'PENDING') {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFF2C3E50), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Actions',
                    style: TextStyle(
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
                  label: const Text('Accept Request'),
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
    if (status == 'approved' || status.toUpperCase() == 'APPROVED') {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.settings, color: Color(0xFF2C3E50), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Actions',
                    style: TextStyle(
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
                  label: const Text('Assign Delivery Manager'),
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

  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'return_requested':
        return 'Return Requested';
      case 'return_approved':
        return 'Return Approved';
      case 'return_assigned':
        return 'Return Assigned';
      default:
        return status;
    }
  }
}
