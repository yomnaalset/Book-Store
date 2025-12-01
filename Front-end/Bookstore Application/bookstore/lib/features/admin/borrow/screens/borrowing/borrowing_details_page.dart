import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../providers/admin_borrowing_provider.dart';
import '../../../../borrow/models/borrow_request.dart';
import '../../../../borrow/services/borrow_service.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/services/api_service.dart';

class BorrowingDetailsPage extends StatefulWidget {
  final BorrowRequest request;

  const BorrowingDetailsPage({super.key, required this.request});

  @override
  State<BorrowingDetailsPage> createState() => _BorrowingDetailsPageState();
}

class _BorrowingDetailsPageState extends State<BorrowingDetailsPage> {
  bool _isLoading = false;
  BorrowRequest? _currentRequest;
  final BorrowService _borrowService = BorrowService();

  @override
  void initState() {
    super.initState();
    _currentRequest = widget.request;
    // Defer the API call to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRequestDetails();
    });
  }

  Future<void> _fetchRequestDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get authentication token
      final authProvider = context.read<AuthProvider>();
      if (authProvider.token == null || authProvider.token!.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please login again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      // Set token before making the request
      _borrowService.setToken(authProvider.token!);

      // Fetch the specific request details from the server
      final freshRequest = await _borrowService.getBorrowRequest(
        widget.request.id.toString(),
      );

      if (mounted) {
        if (freshRequest != null) {
          setState(() {
            _currentRequest = freshRequest;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request not found'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load request details: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Request #${_currentRequest?.id ?? widget.request.id}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showActionDialog(),
            icon: const Icon(Icons.edit),
            tooltip: 'Manage Request',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentRequest == null
          ? const Center(child: Text('Request not found'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1 - Request Details
                  _buildSectionCard(
                    title: 'Request Details',
                    icon: Icons.book_outlined,
                    children: [
                      _buildInfoRow(
                        'Request Number',
                        '#${_currentRequest!.id}',
                      ),
                      _buildInfoRow(
                        'Sending Date',
                        _formatDate(_currentRequest!.requestDate),
                      ),
                      _buildInfoRow(
                        'Expected Return Date',
                        _currentRequest!.dueDate != null
                            ? _formatDate(_currentRequest!.dueDate!)
                            : 'Not set',
                      ),
                      _buildInfoRow(
                        'Request Status',
                        _getStatusDisplay(_currentRequest!.status),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 2 - Customer Information
                  _buildSectionCard(
                    title: 'Customer Information',
                    icon: Icons.person,
                    children: [
                      _buildInfoRow(
                        'Full Name',
                        _currentRequest!.customerName ?? 'Not provided',
                      ),
                      _buildInfoRow('Phone Number', _getCustomerPhone()),
                      _buildInfoRow('Email', _getCustomerEmail()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Section 3 - Borrowed Books
                  _buildSectionCard(
                    title: 'Borrowed Books',
                    icon: Icons.library_books,
                    children: [_buildBookCard(_currentRequest!)],
                  ),
                  const SizedBox(height: 16),

                  // Section 4 - Delivery Manager Information (if assigned)
                  if (_currentRequest?.deliveryPerson != null) ...[
                    _buildSectionCard(
                      title: 'Delivery Manager',
                      icon: Icons.local_shipping,
                      children: [
                        _buildInfoRow('Full Name', _getDeliveryManagerName()),
                        _buildInfoRow(
                          'Email',
                          _currentRequest!.deliveryPerson!.email.isNotEmpty
                              ? _currentRequest!.deliveryPerson!.email
                              : 'Not provided',
                        ),
                        _buildInfoRow(
                          'Phone Number',
                          _currentRequest!.deliveryPerson!.phone != null &&
                                  _currentRequest!
                                      .deliveryPerson!
                                      .phone!
                                      .isNotEmpty
                              ? _currentRequest!.deliveryPerson!.phone!
                              : 'Not provided',
                        ),
                        // View Delivery Manager Location Button
                        // Only show when status is "out_for_delivery"
                        if (_isDeliveryActive()) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _openDeliveryManagerLocation,
                              icon: const Icon(Icons.location_on, size: 20),
                              label: const Text(
                                'View Delivery Manager Current Location',
                                style: TextStyle(fontSize: 16),
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
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Section 5 - Administration Section (only show for pending requests)
                  if (_currentRequest != null &&
                      _canApproveOrReject(_currentRequest!)) ...[
                    _buildAdministrationSection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookCard(BorrowRequest request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Book cover placeholder
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.book, color: Colors.grey, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.bookTitle ?? request.book?.title ?? 'Unknown Book',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (request.book?.author != null) ...[
                    Text(
                      'by ${request.book!.author}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        'Duration: ${request.durationDays} days',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (request.isOverdue) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        'Overdue',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdministrationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Action buttons based on request status
            if (_canApproveOrReject(_currentRequest!)) ...[
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _approveRequest(),
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Approve Borrowing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _rejectRequest(),
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text('Reject Borrowing Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Show status message for non-pending requests
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _getStatusColor(
                    _currentRequest!.status,
                  ).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(
                      _currentRequest!.status,
                    ).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _getStatusMessage(_currentRequest!),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _getStatusColor(_currentRequest!.status),
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getCustomerPhone() {
    if (_currentRequest?.customer?.phone != null &&
        _currentRequest!.customer!.phone!.isNotEmpty) {
      return _currentRequest!.customer!.phone!;
    }
    return 'Not provided';
  }

  String _getCustomerEmail() {
    if (_currentRequest?.customer?.email != null &&
        _currentRequest!.customer!.email.isNotEmpty) {
      return _currentRequest!.customer!.email;
    }
    return 'Not provided';
  }

  String _getDeliveryManagerName() {
    if (_currentRequest?.deliveryPerson == null) {
      return 'Not provided';
    }

    final deliveryPerson = _currentRequest!.deliveryPerson!;

    // Try combining firstName and lastName manually first (most reliable)
    final firstName = deliveryPerson.firstName.trim();
    final lastName = deliveryPerson.lastName.trim();
    if (firstName.isNotEmpty || lastName.isNotEmpty) {
      final combinedName = '$firstName $lastName'.trim();
      if (combinedName.isNotEmpty) {
        return combinedName;
      }
    }

    // Try fullName getter (which combines firstName and lastName)
    if (deliveryPerson.fullName.isNotEmpty &&
        deliveryPerson.fullName.trim().isNotEmpty &&
        deliveryPerson.fullName.trim() != deliveryPerson.email) {
      return deliveryPerson.fullName.trim();
    }

    // Try name getter
    if (deliveryPerson.name.isNotEmpty &&
        deliveryPerson.name.trim().isNotEmpty &&
        deliveryPerson.name.trim() != deliveryPerson.email) {
      return deliveryPerson.name.trim();
    }

    // If all name fields are empty or only contain email, return "Not provided"
    return 'Not provided';
  }

  String _getStatusDisplay(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'active':
        return 'Borrowed';
      case 'returned':
        return 'Returned';
      case 'rejected':
        return 'Rejected';
      case 'overdue':
        return 'Overdue';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'returned':
        return Colors.grey;
      case 'rejected':
        return Colors.red;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusMessage(BorrowRequest request) {
    final status = request.status.toLowerCase();
    switch (status) {
      case 'approved':
        return '✓ Request has been approved';
      case 'rejected':
        return '✗ Request has been rejected';
      case 'active':
        return '📖 Book is currently borrowed';
      case 'returned':
        return '↩️ Book has been returned';
      case 'overdue':
        return '⚠️ Book is overdue';
      default:
        return 'Status: ${request.status}';
    }
  }

  bool _canApproveOrReject(BorrowRequest request) {
    // Only pending requests can be approved or rejected
    return request.status.toLowerCase() == 'pending';
  }

  void _showActionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('What action would you like to take for this request?'),
            const SizedBox(height: 20),
            if (_canApproveOrReject(_currentRequest!)) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _approveRequest();
                      },
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _rejectRequest();
                      },
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Text(
                _getStatusMessage(_currentRequest!),
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
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

  Future<void> _approveRequest() async {
    try {
      final provider = context.read<AdminBorrowingProvider>();

      // Load delivery managers first (without blocking UI)
      await provider.loadDeliveryManagers();

      if (!mounted) return;

      if (provider.deliveryManagers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No delivery managers available. Cannot approve request.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show delivery manager selection dialog (background remains visible)
      final selectedManagerId = await _showDeliveryManagerSelection(
        provider.deliveryManagers,
      );

      // Only show loading when actually making the API call
      if (selectedManagerId != null && mounted) {
        setState(() {
          _isLoading = true;
        });

        try {
          await provider.approveRequest(
            _currentRequest!.id,
            deliveryManagerId: selectedManagerId,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Borrowing request approved and assigned to delivery manager',
                ),
                backgroundColor: Colors.green,
              ),
            );
            await _fetchRequestDetails();
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to approve request: $e'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load delivery managers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<int?> _showDeliveryManagerSelection(
    List<Map<String, dynamic>> deliveryManagers,
  ) async {
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
                // Header
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
                        'Approve Borrowing Request',
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

                // Delivery Manager Selection
                const Text(
                  'Select a delivery manager for this request:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF495057),
                  ),
                ),
                const SizedBox(height: 16),

                // Delivery Manager List
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: deliveryManagers.length,
                    itemBuilder: (context, index) {
                      final manager = deliveryManagers[index];
                      final isAvailable = manager['is_available'] == true;
                      final statusColor = manager['status_color'] as String;
                      // Get status text with proper fallback and capitalization
                      final rawStatus =
                          manager['status_text'] as String? ??
                          manager['status_display'] as String? ??
                          manager['status'] as String? ??
                          manager['delivery_status'] as String? ??
                          'offline';
                      // Capitalize first letter: "online" -> "Online", "busy" -> "Busy", "offline" -> "Offline"
                      final statusText = rawStatus.isNotEmpty
                          ? rawStatus[0].toUpperCase() +
                                rawStatus.substring(1).toLowerCase()
                          : 'Offline';
                      final isSelected = selectedManagerId == manager['id'];

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
                                        0xFF28A745,
                                      ).withValues(alpha: 0.1)
                                    : isAvailable
                                    ? Colors.white
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF28A745)
                                      : isAvailable
                                      ? const Color(0xFFE9ECEF)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Status Indicator
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: statusColor == 'green'
                                          ? Colors.green
                                          : statusColor == 'orange'
                                          ? Colors.orange
                                          : statusColor == 'red'
                                          ? Colors.red
                                          : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Manager Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          manager['full_name'] as String,
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
                                              _getStatusIcon(statusText),
                                              size: 14,
                                              color: statusColor == 'green'
                                                  ? Colors.green
                                                  : statusColor == 'orange'
                                                  ? Colors.orange
                                                  : statusColor == 'red'
                                                  ? Colors.red
                                                  : Colors.grey,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: statusColor == 'green'
                                                    ? Colors.green
                                                    : statusColor == 'orange'
                                                    ? Colors.orange
                                                    : statusColor == 'red'
                                                    ? Colors.red
                                                    : Colors.grey,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Selection Indicator
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF28A745),
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

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
                          backgroundColor: const Color(0xFF28A745),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Confirm Approval'),
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

    return confirmed == true ? selectedManagerId : null;
  }

  Future<void> _rejectRequest() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Borrowing Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Enter rejection reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true && reasonController.text.isNotEmpty && mounted) {
      setState(() {
        _isLoading = true;
      });

      try {
        final provider = context.read<AdminBorrowingProvider>();
        await provider.rejectRequest(
          _currentRequest!.id,
          reasonController.text,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Borrowing request rejected successfully'),
              backgroundColor: Colors.orange,
            ),
          );
          await _fetchRequestDetails();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject request: $e'),
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
  }

  IconData _getStatusIcon(String statusText) {
    switch (statusText.toLowerCase()) {
      case 'online':
        return Icons.wifi;
      case 'busy':
        return Icons.local_shipping;
      case 'offline':
        return Icons.wifi_off;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Check if delivery is currently active (started but not finished)
  /// Button should appear ONLY when status is "out_for_delivery" (delivery in progress)
  /// Button should disappear when status is "delivered", "active", or any other status (delivery completed)
  bool _isDeliveryActive() {
    if (_currentRequest == null) return false;
    if (_currentRequest!.deliveryPerson == null) return false;

    // Normalize the status: lowercase, trim, replace spaces and hyphens with underscores
    final normalizedStatus = _currentRequest!.status
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^\w_]'), ''); // Remove any special characters

    // Button should ONLY be visible when status is exactly "out_for_delivery"
    // Hide when status is "delivered", "active", or any other status
    return normalizedStatus == 'out_for_delivery';
  }

  /// Open delivery manager location in Google Maps
  Future<void> _openDeliveryManagerLocation() async {
    if (!mounted) return;
    
    if (_currentRequest == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request information not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_currentRequest!.deliveryPerson == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Delivery manager information not available'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Verify that status is still out_for_delivery
    final status = _currentRequest!.status
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
    if (status != 'out_for_delivery') {
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

      // Fetch delivery manager's location from backend using borrow-specific endpoint
      // This endpoint only returns location when status is OUT_FOR_DELIVERY
      // Path: /api/borrow/borrowings/<id>/delivery-location/
      final response = await http.get(
        Uri.parse(
          '${ApiService.baseUrl}/borrow/borrowings/${_currentRequest!.id}/delivery-location/',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Handle the response format from GetDeliveryLocationView
        if (data['success'] == true && data['data'] != null) {
          final locationData = data['data']['location'];

          if (locationData != null &&
              locationData['latitude'] != null &&
              locationData['longitude'] != null) {
            final latitude = locationData['latitude'] as double;
            final longitude = locationData['longitude'] as double;

            // Open Google Maps with the location
            await _launchGoogleMaps(latitude, longitude);
          } else {
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
          }
        } else {
          final errorMessage = data['message'] ?? 'Failed to get location';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage =
            errorData['message'] ??
            errorData['error'] ??
            'Failed to get location';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }
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

  /// Launch Google Maps with the given coordinates
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not open maps. Please check your internet connection.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
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
}
