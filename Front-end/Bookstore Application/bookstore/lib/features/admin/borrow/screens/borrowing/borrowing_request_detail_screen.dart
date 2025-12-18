import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../borrow/models/borrow_request.dart';
import '../../../../borrow/models/return_request.dart';
import '../../../../borrow/services/borrow_service.dart';
import '../../../../borrow/providers/return_request_provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../widgets/library_manager/status_chip.dart';
import '../../../../../core/services/api_service.dart';
import '../../../../../shared/widgets/custom_text_field.dart';
import '../../../../../core/localization/app_localizations.dart';

class BorrowingRequestDetailScreen extends StatefulWidget {
  final int requestId;

  const BorrowingRequestDetailScreen({super.key, required this.requestId});

  @override
  State<BorrowingRequestDetailScreen> createState() =>
      _BorrowingRequestDetailScreenState();
}

class _BorrowingRequestDetailScreenState
    extends State<BorrowingRequestDetailScreen> {
  final BorrowService _borrowService = BorrowService();
  BorrowRequest? _request;
  ReturnRequest? _returnRequest;
  bool _isLoading = true;
  bool _isLoadingReturnRequest = false;
  String? _errorMessage;

  // Form controllers for customer information
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerEmailController = TextEditingController();
  bool _isEditingCustomer = false;
  final _customerFormKey = GlobalKey<FormState>();

  // Form controllers for delivery manager information
  final _deliveryManagerNameController = TextEditingController();
  final _deliveryManagerPhoneController = TextEditingController();
  final _deliveryManagerEmailController = TextEditingController();
  bool _isEditingDeliveryManager = false;
  final _deliveryManagerFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadRequestDetails();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerEmailController.dispose();
    _deliveryManagerNameController.dispose();
    _deliveryManagerPhoneController.dispose();
    _deliveryManagerEmailController.dispose();
    super.dispose();
  }

  void _initializeFormControllers() {
    if (_request == null) return;
    final localizations = AppLocalizations.of(context);

    // Initialize customer form controllers
    _customerNameController.text = _getCustomerName();
    _customerPhoneController.text =
        _getCustomerPhone() == localizations.notProvided
        ? ''
        : _getCustomerPhone();
    _customerEmailController.text =
        _getCustomerEmail() == localizations.notProvided
        ? ''
        : _getCustomerEmail();

    // Initialize delivery manager form controllers
    if (_request!.deliveryPerson != null) {
      _deliveryManagerNameController.text = _getDeliveryManagerName();
      final phone =
          _request!.deliveryPerson!.phone != null &&
              _request!.deliveryPerson!.phone!.isNotEmpty
          ? _request!.deliveryPerson!.phone!
          : '';
      _deliveryManagerPhoneController.text = phone;
      _deliveryManagerEmailController.text =
          _request!.deliveryPerson!.email.isNotEmpty
          ? _request!.deliveryPerson!.email
          : '';
    }
  }

  Future<void> _loadReturnRequest() async {
    if (_request == null) {
      debugPrint('DEBUG: _loadReturnRequest - _request is null, returning');
      return;
    }

    debugPrint('=== LOAD RETURN REQUEST START ===');
    debugPrint(
      'DEBUG: Loading return request for borrow request ID: ${_request!.id}',
    );

    try {
      setState(() {
        _isLoadingReturnRequest = true;
      });

      final authProvider = context.read<AuthProvider>();
      final returnProvider = context.read<ReturnRequestProvider>();

      if (authProvider.token != null) {
        returnProvider.setToken(authProvider.token!);
        debugPrint('DEBUG: Token set for return provider');
      } else {
        debugPrint('DEBUG: WARNING - No token available');
      }

      // Load all return requests (admins can see all)
      debugPrint('DEBUG: Calling loadReturnRequests()...');
      await returnProvider.loadReturnRequests();
      final returnRequests = returnProvider.returnRequests;

      debugPrint('DEBUG: Loaded ${returnRequests.length} return requests');
      debugPrint('DEBUG: Looking for borrow request ID: ${_request!.id}');
      if (returnRequests.isNotEmpty) {
        debugPrint(
          'DEBUG: Return requests: ${returnRequests.map((r) => 'RR#${r.id} -> BR#${r.borrowRequest.id}').join(', ')}',
        );
      } else {
        debugPrint('DEBUG: No return requests found in response');
      }

      try {
        final returnReq = returnRequests.firstWhere(
          (rr) => rr.borrowRequest.id == _request!.id,
        );

        debugPrint(
          'DEBUG: Found return request: ${returnReq.id} with status: ${returnReq.status}',
        );

        if (mounted) {
          setState(() {
            _returnRequest = returnReq;
            _isLoadingReturnRequest = false;
          });
        }
      } catch (e) {
        debugPrint(
          'DEBUG: No return request found for borrow request ${_request!.id}: $e',
        );
        if (mounted) {
          setState(() {
            _returnRequest = null;
            _isLoadingReturnRequest = false;
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('DEBUG: Error loading return request: $e');
      debugPrint('DEBUG: Error stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingReturnRequest = false;
        });
      }
    }
    debugPrint('=== LOAD RETURN REQUEST END ===');
  }

  Future<void> _loadRequestDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final authProvider = context.read<AuthProvider>();
      if (authProvider.token != null) {
        _borrowService.setToken(authProvider.token!);
      }

      final request = await _borrowService.getBorrowRequest(
        widget.requestId.toString(),
      );

      debugPrint('DEBUG: ===== REQUEST LOADED =====');
      debugPrint('DEBUG: Request is null: ${request == null}');

      if (request != null) {
        debugPrint('DEBUG: Request ID: ${request.id}');
        debugPrint('DEBUG: Request status: ${request.status}');
        debugPrint(
          'DEBUG: Delivery Person: ${request.deliveryPerson != null ? "EXISTS" : "NULL"}',
        );
        if (request.deliveryPerson != null) {
          debugPrint(
            'DEBUG: Delivery Person ID: ${request.deliveryPerson!.id}',
          );
          debugPrint(
            'DEBUG: Delivery Person Name: ${request.deliveryPerson!.firstName} ${request.deliveryPerson!.lastName}',
          );
          debugPrint(
            'DEBUG: Delivery Person Email: ${request.deliveryPerson!.email}',
          );
        }
      }

      if (mounted) {
        setState(() {
          _request = request;
          _isLoading = false;
          // CRITICAL: Debug inside setState to confirm it's triggered
          debugPrint('DEBUG: ===== SETSTATE FIRED =====');
          debugPrint('DEBUG: SETSTATE - _request is null: ${_request == null}');
          if (_request != null) {
            debugPrint('DEBUG: SETSTATE - NEW STATUS = "${_request!.status}"');
            debugPrint(
              'DEBUG: SETSTATE - Delivery Person: ${_request!.deliveryPerson != null ? "EXISTS" : "NULL"}',
            );
            // Check button visibility immediately inside setState
            final statusCheck = _request!.status
                .toLowerCase()
                .trim()
                .replaceAll(' ', '_')
                .replaceAll('-', '_');
            final isOutForDelivery = statusCheck == 'out_for_delivery';
            debugPrint('DEBUG: SETSTATE - Status normalized: "$statusCheck"');
            debugPrint(
              'DEBUG: SETSTATE - Is out_for_delivery? $isOutForDelivery',
            );
            debugPrint(
              'DEBUG: SETSTATE - Button should be visible: $isOutForDelivery',
            );
          }
          debugPrint('DEBUG: ===== SETSTATE END =====');
        });

        if (_request != null) {
          // Initialize form controllers when request is loaded
          _initializeFormControllers();
          debugPrint('DEBUG: ===== AFTER SETSTATE =====');
          debugPrint('DEBUG: Request status: ${_request!.status}');
          debugPrint(
            'DEBUG: Delivery Person: ${_request!.deliveryPerson != null ? "EXISTS" : "NULL"}',
          );
          if (_request!.deliveryPerson != null) {
            debugPrint(
              'DEBUG: Delivery Person ID: ${_request!.deliveryPerson!.id}',
            );
            debugPrint(
              'DEBUG: Delivery Person Name: ${_request!.deliveryPerson!.firstName} ${_request!.deliveryPerson!.lastName}',
            );
            debugPrint(
              'DEBUG: Delivery Person Email: ${_request!.deliveryPerson!.email}',
            );
          }
          debugPrint('DEBUG: ===== BUTTON VISIBILITY CHECK =====');
          debugPrint('DEBUG: Will check button visibility on next build...');
          debugPrint(
            'DEBUG: Status lowercase: ${_request!.status.toLowerCase()}',
          );
          debugPrint(
            'DEBUG: Is return_requested? ${_request!.status.toLowerCase() == 'return_requested'}',
          );

          // Load return request if status is return_requested
          final statusLower = _request!.status.toLowerCase().trim();
          debugPrint('=== LOAD RETURN REQUEST CHECK ===');
          debugPrint('DEBUG: Status lower trimmed: "$statusLower"');
          debugPrint(
            'DEBUG: Contains return: ${statusLower.contains('return')}',
          );
          debugPrint(
            'DEBUG: Equals return_requested: ${statusLower == 'return_requested'}',
          );

          if (statusLower == 'return_requested' ||
              statusLower.contains('return')) {
            debugPrint('DEBUG: Loading return request...');
            _loadReturnRequest();
          } else {
            debugPrint(
              'DEBUG: NOT loading return request - status does not match',
            );
          }
          debugPrint('==================================');
        }
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

  @override
  Widget build(BuildContext context) {
    // CRITICAL: Debug to confirm build() is being called
    debugPrint('DEBUG: ===== BUILD METHOD CALLED =====');
    debugPrint('DEBUG: BUILD - _request is null: ${_request == null}');
    if (_request != null) {
      debugPrint('DEBUG: BUILD - Request status: "${_request!.status}"');
      debugPrint(
        'DEBUG: BUILD - Delivery Person: ${_request!.deliveryPerson != null ? "EXISTS" : "NULL"}',
      );
      // Check button visibility during build
      final isActive = _isDeliveryActive();
      debugPrint('DEBUG: BUILD - Button should be visible: $isActive');
    }
    debugPrint('DEBUG: ===== BUILD METHOD END =====');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppLocalizations.of(context).requestNumber(widget.requestId),
        ),
        backgroundColor: const Color(0xFFB5E7FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: AppLocalizations.of(context).refreshRequestDetails,
            onPressed: () {
              debugPrint('DEBUG: Refresh button pressed');
              _loadRequestDetails();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadRequestDetails();
        },
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).errorLoadingRequestDetails,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadRequestDetails,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      );
    }

    if (_request == null) {
      return Center(child: Text(AppLocalizations.of(context).requestNotFound));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildCustomerInfoCard(),
          const SizedBox(height: 16),
          _buildBorrowedBooksCard(),
          const SizedBox(height: 16),
          // Show old delivery manager ONLY if status is NOT return_requested, return_approved, or return_assigned
          Builder(
            builder: (context) {
              if (_request == null) return const SizedBox.shrink();
              final statusLower = _request!.status.toLowerCase().trim();
              final isReturnFlow =
                  statusLower == 'return_requested' ||
                  statusLower == 'return_approved' ||
                  statusLower == 'return_assigned';

              // Hide old delivery manager during return flow
              if (isReturnFlow) {
                return const SizedBox.shrink();
              }

              // Show old delivery manager for other statuses
              if (_request?.deliveryPerson != null) {
                return Column(
                  children: [
                    _buildDeliveryManagerCard(),
                    const SizedBox(height: 16),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          _buildAdministrationCard(),
          const SizedBox(height: 16),
          // Actions Section - Only show for return_requested and return_approved
          Builder(
            builder: (context) {
              if (_request == null) return const SizedBox.shrink();
              final statusLower = _request!.status.toLowerCase().trim();
              final shouldShowActions =
                  statusLower == 'return_requested' ||
                  statusLower == 'return_approved';

              if (shouldShowActions) {
                return Column(
                  children: [
                    _buildActionsSection(),
                    const SizedBox(height: 16),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Assigned Delivery Manager Section - Only show when return_assigned
          Builder(
            builder: (context) {
              if (_request == null) return const SizedBox.shrink();
              final statusLower = _request!.status.toLowerCase().trim();

              if (statusLower == 'return_assigned' &&
                  _request?.deliveryPerson != null) {
                return Column(
                  children: [
                    _buildAssignedDeliveryManagerCard(),
                    const SizedBox(height: 16),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Show return request section if status is return_requested
          Builder(
            builder: (context) {
              debugPrint('=== BUILDING RETURN REQUEST SECTION ===');
              debugPrint('DEBUG: _request is null: ${_request == null}');
              if (_request != null) {
                debugPrint(
                  'DEBUG: Borrow request status: "${_request!.status}"',
                );
                debugPrint(
                  'DEBUG: Status lower: "${_request!.status.toLowerCase().trim()}"',
                );
              }
              return _buildReturnRequestSection();
            },
          ),
          _buildDetailsCard(),
          const SizedBox(height: 16),
          _buildTimelineCard(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
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
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).requestNumber(_request!.id),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ),
                StatusChip(status: _request!.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.book, color: Color(0xFF6C757D)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getBookName(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF495057),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF6C757D)),
                const SizedBox(width: 8),
                Text(
                  _request!.customerName ?? 'Unknown Customer',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF495057),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _customerFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFF2C3E50), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations.customerInformation,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        );
                      },
                    ),
                  ),
                  if (!_isEditingCustomer)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF2C3E50)),
                      onPressed: () {
                        setState(() {
                          _isEditingCustomer = true;
                        });
                      },
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: _saveCustomerInfo,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _isEditingCustomer = false;
                              _initializeFormControllers();
                            });
                          },
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isEditingCustomer) ...[
                CustomTextField(
                  controller: _customerNameController,
                  labelText: AppLocalizations.of(context).fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                  enabled: _isEditingCustomer,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context).fullNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _customerPhoneController,
                  labelText: AppLocalizations.of(context).phoneNumber,
                  prefixIcon: const Icon(Icons.phone),
                  keyboardType: TextInputType.phone,
                  enabled: _isEditingCustomer,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{7,20}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return AppLocalizations.of(
                          context,
                        ).pleaseEnterValidPhoneNumber;
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _customerEmailController,
                  labelText: AppLocalizations.of(context).email,
                  prefixIcon: const Icon(Icons.email),
                  keyboardType: TextInputType.emailAddress,
                  enabled: _isEditingCustomer,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context).emailRequired;
                    }
                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return AppLocalizations.of(
                        context,
                      ).pleaseEnterValidEmailAddress;
                    }
                    return null;
                  },
                ),
              ] else ...[
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Column(
                      children: [
                        _buildCustomerDetailRow(
                          '${localizations.fullName}:',
                          _getCustomerName(),
                          Icons.person_outline,
                        ),
                        _buildCustomerDetailRow(
                          '${localizations.phoneNumber}:',
                          _getCustomerPhone(),
                          Icons.phone,
                        ),
                        _buildCustomerDetailRow(
                          '${localizations.email}:',
                          _getCustomerEmail(),
                          Icons.email,
                        ),
                        if (_request!.customer?.address != null)
                          _buildCustomerDetailRow(
                            '${localizations.deliveryAddress}:',
                            _request!.customer!.address!,
                            Icons.location_on,
                          ),
                        if (_request!.customer?.city != null)
                          _buildCustomerDetailRow(
                            '${localizations.deliveryCity}:',
                            _request!.customer!.city!,
                            Icons.location_city,
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
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
          // Circular icon container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, size: 20, color: const Color(0xFF6C757D)),
            ),
          ),
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
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: value == localizations.notProvided
                            ? Colors.red[600]
                            : const Color(0xFF495057),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCustomerName() {
    if (_request!.customerName != null && _request!.customerName!.isNotEmpty) {
      return _request!.customerName!;
    }
    if (_request!.customer != null) {
      return _request!.customer!.fullName;
    }
    final localizations = AppLocalizations.of(context);
    return localizations.notProvided;
  }

  String _getCustomerPhone() {
    if (_request!.customer?.phone != null &&
        _request!.customer!.phone!.isNotEmpty) {
      return _request!.customer!.phone!;
    }
    final localizations = AppLocalizations.of(context);
    return localizations.notProvided;
  }

  String _getCustomerEmail() {
    if (_request!.customer?.email != null &&
        _request!.customer!.email.isNotEmpty) {
      return _request!.customer!.email;
    }
    final localizations = AppLocalizations.of(context);
    return localizations.notProvided;
  }

  Widget _buildBorrowedBooksCard() {
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
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations.borrowedBooks,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    );
                  },
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
                        _getBookName(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF495057),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            '${localizations.duration}: ${_request!.durationDays} ${localizations.days}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6C757D),
                            ),
                          );
                        },
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

  Widget _buildReturnRequestSection() {
    if (_request == null) {
      debugPrint('=== RETURN REQUEST SECTION: _request is null ===');
      return const SizedBox.shrink();
    }

    final statusLower = _request!.status.toLowerCase().trim();
    final shouldShow =
        statusLower == 'return_requested' || statusLower.contains('return');

    debugPrint('=== RETURN REQUEST CARD CHECK ===');
    debugPrint('DEBUG: Request ID: ${_request!.id}');
    debugPrint('DEBUG: Status: "${_request!.status}"');
    debugPrint('DEBUG: Status lowercase: "$statusLower"');
    debugPrint('DEBUG: Should show card: $shouldShow');
    debugPrint('DEBUG: Will build return request card now');
    debugPrint('================================');

    if (!shouldShow) {
      debugPrint(
        'DEBUG: NOT showing return request card - status does not match',
      );
      return const SizedBox.shrink();
    }

    debugPrint('DEBUG: Building return request card widget');
    return Column(
      children: [_buildReturnRequestCard(), const SizedBox(height: 16)],
    );
  }

  Widget _buildReturnRequestCard() {
    // Always show something when status is return_requested
    debugPrint('=== BUILDING RETURN REQUEST CARD ===');
    debugPrint('DEBUG: _buildReturnRequestCard called');
    debugPrint('DEBUG: _isLoadingReturnRequest: $_isLoadingReturnRequest');
    debugPrint('DEBUG: _returnRequest is null: ${_returnRequest == null}');
    if (_request != null) {
      debugPrint('DEBUG: Borrow request status: "${_request!.status}"');
    }

    if (_isLoadingReturnRequest) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_returnRequest == null) {
      // Show a card with approval button even when return request hasn't loaded yet
      // This ensures admins can approve return requests even if loading fails
      debugPrint('DEBUG: Showing placeholder card with approval button');
      debugPrint('DEBUG: Borrow request status: ${_request?.status}');

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
                    Icons.assignment_return,
                    color: Color(0xFF2C3E50),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations.returnRequestLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations.statusPendingApproval,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    localizations.returnRequestInitiatedMessage,
                    style: const TextStyle(color: Color(0xFF6C757D)),
                  );
                },
              ),
            ],
          ),
        ),
      );
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
                const Icon(
                  Icons.assignment_return,
                  color: Color(0xFF2C3E50),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations.returnRequestLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _getReturnStatusColor(
                  _returnRequest!.status,
                ).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getReturnStatusColor(_returnRequest!.status),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getReturnStatusIcon(_returnRequest!.status),
                    color: _getReturnStatusColor(_returnRequest!.status),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          '${localizations.status}: ${localizations.getReturnRequestStatusLabel(_returnRequest!.status)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getReturnStatusColor(
                              _returnRequest!.status,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_returnRequest!.fineAmount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            '${localizations.fine}: \$${_returnRequest!.fineAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build Actions Section - Shows only "Approve Return Request" button
  Widget _buildActionsSection() {
    if (_request == null) return const SizedBox.shrink();

    final statusLower = _request!.status.toLowerCase().trim();

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
                const Icon(Icons.settings, color: Color(0xFF2C3E50), size: 20),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations.actions,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (statusLower == 'return_requested')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _approveReturnRequestOnly,
                  icon: const Icon(Icons.check_circle),
                  label: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(localizations.approveReturnRequest);
                    },
                  ),
                ),
              )
            else if (statusLower == 'return_approved')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _assignDeliveryManager,
                  icon: const Icon(Icons.person_add),
                  label: Text(
                    AppLocalizations.of(context).assignDeliveryManager,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
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
      ),
    );
  }

  /// Build Assigned Delivery Manager Card - Shows when return_assigned
  Widget _buildAssignedDeliveryManagerCard() {
    if (_request?.deliveryPerson == null) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _deliveryManagerFormKey,
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
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations.assignedDeliveryManager,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        );
                      },
                    ),
                  ),
                  if (!_isEditingDeliveryManager)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF2C3E50)),
                      onPressed: () {
                        setState(() {
                          _isEditingDeliveryManager = true;
                        });
                      },
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: _saveDeliveryManagerInfo,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _isEditingDeliveryManager = false;
                              _initializeFormControllers();
                            });
                          },
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isEditingDeliveryManager) ...[
                CustomTextField(
                  controller: _deliveryManagerNameController,
                  labelText: AppLocalizations.of(context).fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                  enabled: _isEditingDeliveryManager,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context).fullNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _deliveryManagerPhoneController,
                  labelText: AppLocalizations.of(context).phoneNumber,
                  prefixIcon: const Icon(Icons.phone),
                  keyboardType: TextInputType.phone,
                  enabled: _isEditingDeliveryManager,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{7,20}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return AppLocalizations.of(
                          context,
                        ).pleaseEnterValidPhoneNumber;
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _deliveryManagerEmailController,
                  labelText: AppLocalizations.of(context).email,
                  prefixIcon: const Icon(Icons.email),
                  keyboardType: TextInputType.emailAddress,
                  enabled: _isEditingDeliveryManager,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context).emailRequired;
                    }
                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return AppLocalizations.of(
                        context,
                      ).pleaseEnterValidEmailAddress;
                    }
                    return null;
                  },
                ),
              ] else ...[
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return _buildCustomerDetailRow(
                      '${localizations.fullName}:',
                      _getDeliveryManagerName(),
                      Icons.person_outline,
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return _buildCustomerDetailRow(
                      '${localizations.phoneNumber}:',
                      _request!.deliveryPerson!.phone != null &&
                              _request!.deliveryPerson!.phone!.isNotEmpty
                          ? _request!.deliveryPerson!.phone!
                          : localizations.notProvided,
                      Icons.phone,
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return _buildCustomerDetailRow(
                      '${localizations.email}:',
                      _request!.deliveryPerson!.email.isNotEmpty
                          ? _request!.deliveryPerson!.email
                          : localizations.notProvided,
                      Icons.email,
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Step 2: Approve return request only
  Future<void> _approveReturnRequestOnly() async {
    if (_request == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(localizations.requestInformationNotAvailable);
              },
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final returnProvider = context.read<ReturnRequestProvider>();
    final authProvider = context.read<AuthProvider>();

    if (authProvider.token != null) {
      returnProvider.setToken(authProvider.token!);
    }

    try {
      final success = await returnProvider.approveReturnRequestOnly(
        _request!.id,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(localizations.returnRequestApprovedSuccessfully);
              },
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Reload request details to get updated status
        await _loadRequestDetails();

        // After approval, show delivery manager selection popup
        _assignDeliveryManager();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  returnProvider.errorMessage ??
                      localizations.failedToApproveReturnRequest,
                );
              },
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text('${localizations.error}: ${e.toString()}');
              },
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Step 3: Assign delivery manager to return request
  Future<void> _assignDeliveryManager() async {
    if (_request == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(localizations.requestInformationNotAvailable);
              },
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final returnProvider = context.read<ReturnRequestProvider>();
    final authProvider = context.read<AuthProvider>();

    if (authProvider.token != null) {
      returnProvider.setToken(authProvider.token!);
    }

    // Load delivery managers
    final managers = await returnProvider.getAvailableDeliveryManagers();

    if (!mounted) return;

    if (managers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(localizations.noDeliveryManagersAvailable);
            },
          ),
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
                Row(
                  children: [
                    const Icon(
                      Icons.person_add,
                      color: Color(0xFF007BFF),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final localizations = AppLocalizations.of(context);
                          return Text(
                            localizations.selectDeliveryManager,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations.selectDeliveryManagerToAssignReturnRequest,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: managers.length,
                    itemBuilder: (context, index) {
                      final manager = managers[index];
                      final isAvailable = manager['is_available'] == true;
                      final statusColor =
                          manager['status_color'] as String? ?? 'grey';
                      final rawStatus =
                          manager['status_text'] as String? ??
                          manager['status_display'] as String? ??
                          manager['status'] as String? ??
                          manager['delivery_status'] as String? ??
                          'offline';
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
                                              _getManagerStatusIcon(statusText),
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
                        child: Text(AppLocalizations.of(context).cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedManagerId != null
                            ? () => Navigator.of(context).pop(true)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF007BFF),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(AppLocalizations.of(context).assignManager),
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
        final success = await returnProvider.assignReturnDeliveryManager(
          _request!.id,
          selectedManagerId!,
        );

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations.deliveryManagerAssignedSuccessfully,
                    );
                  },
                ),
                backgroundColor: Colors.green,
              ),
            );
            _loadReturnRequest();
            _loadRequestDetails();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      returnProvider.errorMessage ??
                          localizations.failedToAssignDeliveryManager,
                    );
                  },
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text('${localizations.error}: ${e.toString()}');
                },
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Color _getReturnStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending_pickup':
        return Colors.orange;
      case 'in_return':
        return Colors.blue;
      case 'returning_to_library':
        return Colors.purple;
      case 'returned_successfully':
        return Colors.green;
      case 'late_return':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getReturnStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending_pickup':
        return Icons.schedule;
      case 'in_return':
        return Icons.local_shipping;
      case 'returning_to_library':
        return Icons.inventory;
      case 'returned_successfully':
        return Icons.check_circle;
      case 'late_return':
        return Icons.warning;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  IconData _getManagerStatusIcon(String statusText) {
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

  Widget _buildDeliveryManagerCard() {
    debugPrint('DEBUG: ===== _buildDeliveryManagerCard CALLED =====');
    debugPrint('DEBUG: _request is null: ${_request == null}');
    debugPrint(
      'DEBUG: deliveryPerson is null: ${_request?.deliveryPerson == null}',
    );

    if (_request?.deliveryPerson == null) {
      debugPrint(
        'DEBUG: _buildDeliveryManagerCard - deliveryPerson is null, returning empty widget',
      );
      return const SizedBox.shrink();
    }

    debugPrint(
      'DEBUG: _buildDeliveryManagerCard - Building card for delivery person: ${_request!.deliveryPerson!.id}',
    );
    debugPrint('DEBUG: Current request status: "${_request!.status}"');
    debugPrint('DEBUG: Status type: ${_request!.status.runtimeType}');

    // Check button visibility immediately for debugging
    final isActive = _isDeliveryActive();
    debugPrint(
      'DEBUG: _buildDeliveryManagerCard - Button should be visible: $isActive',
    );

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _deliveryManagerFormKey,
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
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Text(
                          localizations.assignedDeliveryManager,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        );
                      },
                    ),
                  ),
                  if (!_isEditingDeliveryManager)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Color(0xFF2C3E50)),
                      onPressed: () {
                        setState(() {
                          _isEditingDeliveryManager = true;
                        });
                      },
                    )
                  else
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: _saveDeliveryManagerInfo,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _isEditingDeliveryManager = false;
                              _initializeFormControllers();
                            });
                          },
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (_isEditingDeliveryManager) ...[
                CustomTextField(
                  controller: _deliveryManagerNameController,
                  labelText: AppLocalizations.of(context).fullName,
                  prefixIcon: const Icon(Icons.person_outline),
                  enabled: _isEditingDeliveryManager,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context).fullNameRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _deliveryManagerPhoneController,
                  labelText: AppLocalizations.of(context).phoneNumber,
                  prefixIcon: const Icon(Icons.phone),
                  keyboardType: TextInputType.phone,
                  enabled: _isEditingDeliveryManager,
                  validator: (value) {
                    if (value != null && value.trim().isNotEmpty) {
                      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{7,20}$');
                      if (!phoneRegex.hasMatch(value.trim())) {
                        return AppLocalizations.of(
                          context,
                        ).pleaseEnterValidPhoneNumber;
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  controller: _deliveryManagerEmailController,
                  labelText: AppLocalizations.of(context).email,
                  prefixIcon: const Icon(Icons.email),
                  keyboardType: TextInputType.emailAddress,
                  enabled: _isEditingDeliveryManager,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return AppLocalizations.of(context).emailRequired;
                    }
                    final emailRegex = RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    );
                    if (!emailRegex.hasMatch(value.trim())) {
                      return AppLocalizations.of(
                        context,
                      ).pleaseEnterValidEmailAddress;
                    }
                    return null;
                  },
                ),
              ] else ...[
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return _buildCustomerDetailRow(
                      '${localizations.fullName}:',
                      _getDeliveryManagerName(),
                      Icons.person_outline,
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return _buildCustomerDetailRow(
                      '${localizations.phoneNumber}:',
                      _request!.deliveryPerson!.phone != null &&
                              _request!.deliveryPerson!.phone!.isNotEmpty
                          ? _request!.deliveryPerson!.phone!
                          : localizations.notProvided,
                      Icons.phone,
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return _buildCustomerDetailRow(
                      '${localizations.email}:',
                      _request!.deliveryPerson!.email.isNotEmpty
                          ? _request!.deliveryPerson!.email
                          : localizations.notProvided,
                      Icons.email,
                    );
                  },
                ),
              ],
              // Button to view delivery manager's current location
              // Only show when delivery is active (status is "out_for_delivery")
              // Hide when status is "delivered" or "active" (delivery completed)
              Builder(
                builder: (context) {
                  // CRITICAL: Check button visibility during widget build
                  final isActive = _isDeliveryActive();
                  debugPrint('DEBUG: ===== BUTTON RENDERING CHECK =====');
                  debugPrint(
                    'DEBUG: BUTTON RENDER - Status: "${_request!.status}"',
                  );
                  debugPrint('DEBUG: BUTTON RENDER - isActive: $isActive');
                  debugPrint(
                    'DEBUG: BUTTON RENDER - Will render button: $isActive',
                  );
                  debugPrint('DEBUG: ===== BUTTON RENDERING END =====');

                  if (isActive) {
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              debugPrint(
                                'DEBUG: View Delivery Manager Location button pressed',
                              );
                              _openDeliveryManagerLocation();
                            },
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
                    );
                  } else {
                    debugPrint(
                      'DEBUG: BUTTON RENDER - Button NOT rendered (isActive = false)',
                    );
                    return const SizedBox.shrink();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Check if delivery is currently active (started but not finished)
  /// Button should appear ONLY when status is "out_for_delivery" (delivery in progress)
  /// Button should disappear when status is "delivered" or "active" (delivery completed)
  bool _isDeliveryActive() {
    debugPrint('DEBUG: ===== _isDeliveryActive CALLED =====');

    if (_request == null) {
      debugPrint('DEBUG: _isDeliveryActive - _request is null -> FALSE');
      return false;
    }

    if (_request!.deliveryPerson == null) {
      debugPrint('DEBUG: _isDeliveryActive - deliveryPerson is null -> FALSE');
      return false;
    }

    // Get the raw status string
    final rawStatus = _request!.status;
    debugPrint(
      'DEBUG: _isDeliveryActive - Raw status: "$rawStatus" (type: ${rawStatus.runtimeType})',
    );
    debugPrint('DEBUG: _isDeliveryActive - Status length: ${rawStatus.length}');
    debugPrint(
      'DEBUG: _isDeliveryActive - Status code units: ${rawStatus.codeUnits}',
    );

    // Normalize the status: lowercase, trim, replace spaces and hyphens with underscores
    final normalizedStatus = rawStatus
        .toLowerCase()
        .trim()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll(RegExp(r'[^\w_]'), ''); // Remove any special characters
    debugPrint(
      'DEBUG: _isDeliveryActive - Normalized status: "$normalizedStatus"',
    );
    debugPrint(
      'DEBUG: _isDeliveryActive - Comparing: "$normalizedStatus" == "out_for_delivery"',
    );

    // Button should ONLY be visible when status is exactly "out_for_delivery"
    // Hide when status is "delivered", "active", or any other status
    final isOutForDelivery = normalizedStatus == 'out_for_delivery';

    debugPrint(
      'DEBUG: _isDeliveryActive - Comparison result: $isOutForDelivery',
    );
    debugPrint('DEBUG: _isDeliveryActive - Final result: $isOutForDelivery');
    debugPrint('DEBUG: ===== _isDeliveryActive END =====');

    return isOutForDelivery;
  }

  String _getDeliveryManagerName() {
    if (_request?.deliveryPerson == null) {
      final localizations = AppLocalizations.of(context);
      return localizations.notProvided;
    }

    final deliveryPerson = _request!.deliveryPerson!;

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

    // Fallback to email if name is not available
    final localizations = AppLocalizations.of(context);
    return deliveryPerson.email.isNotEmpty
        ? deliveryPerson.email
        : localizations.notProvided;
  }

  Future<void> _openDeliveryManagerLocation() async {
    if (!mounted) return;

    if (_request == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(localizations.requestInformationNotAvailable);
              },
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (_request!.deliveryPerson == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.deliveryManagerInformationNotAvailable,
                );
              },
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Verify that status is still out_for_delivery
    final status = _request!.status.toLowerCase().trim().replaceAll(' ', '_');
    if (status != 'out_for_delivery') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations
                      .locationTrackingOnlyAvailableDuringActiveDelivery,
                );
              },
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
      final localizations = AppLocalizations.of(context);

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    localizations.authenticationRequiredPleaseLogInAgain,
                  );
                },
              ),
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
          '${ApiService.baseUrl}/borrow/borrowings/${_request!.id}/delivery-location/',
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
                SnackBar(
                  content: Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations
                            .deliveryManagerLocationNotAvailableAtTheMoment,
                      );
                    },
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      data['message'] ?? localizations.failedToGetLocation,
                    );
                  },
                ),
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
            localizations.failedToGetLocation;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).error}: ${e.toString()}',
            ),
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
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations
                          .couldNotOpenMapsPleaseCheckYourInternetConnection,
                    );
                  },
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).errorOpeningMaps(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAdministrationCard() {
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
                  Icons.admin_panel_settings,
                  color: Color(0xFF2C3E50),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Text(
                      localizations.administration,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _getStatusColor(_request!.status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _getStatusColor(_request!.status),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(_request!.status),
                    color: _getStatusColor(_request!.status),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusMessage(_request!.status),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(_request!.status),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'active':
        return Icons.book;
      case 'delivered':
        return Icons.local_shipping;
      case 'returned':
        return Icons.assignment_return;
      case 'overdue':
        return Icons.warning;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusMessage(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppLocalizations.of(context).requestIsPendingApproval;
      case 'approved':
        return AppLocalizations.of(context).requestHasBeenApproved;
      case 'rejected':
        return AppLocalizations.of(context).requestHasBeenRejected;
      case 'active':
        return AppLocalizations.of(context).bookIsCurrentlyBorrowed;
      case 'delivered':
        return AppLocalizations.of(context).bookHasBeenDelivered;
      case 'returned':
        return AppLocalizations.of(context).bookHasBeenReturned;
      case 'return_requested':
        return AppLocalizations.of(context).returnRequestPendingApproval;
      case 'return_approved':
        return AppLocalizations.of(
          context,
        ).returnRequestApprovedAssignDeliveryManager;
      case 'return_assigned':
        return AppLocalizations.of(context).returnAssignedToDeliveryManager;
      case 'overdue':
        return AppLocalizations.of(context).bookIsOverdue;
      default:
        return '${AppLocalizations.of(context).status}: $status';
    }
  }

  Widget _buildDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.requestDetails,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              AppLocalizations.of(context).requestDate,
              _formatDate(_request!.requestDate),
              Icons.calendar_today,
            ),
            if (_request!.approvalDate != null)
              _buildDetailRow(
                AppLocalizations.of(context).approvalDate,
                _formatDate(_request!.approvalDate!),
                Icons.check_circle,
              ),
            if (_request!.dueDate != null)
              _buildDetailRow(
                AppLocalizations.of(context).dueDate,
                _formatDate(_request!.dueDate!),
                Icons.schedule,
              ),
            if (_request!.deliveryDate != null)
              _buildDetailRow(
                AppLocalizations.of(context).deliveryDate,
                _formatDate(_request!.deliveryDate!),
                Icons.local_shipping,
              ),
            if (_request!.returnDate != null)
              _buildDetailRow(
                AppLocalizations.of(context).returnDate,
                _formatDate(_request!.returnDate!),
                Icons.assignment_return,
              ),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return _buildDetailRow(
                  localizations.duration,
                  '${_request!.durationDays} ${localizations.days}',
                  Icons.access_time,
                );
              },
            ),
            if (_request!.deliveryAddress != null)
              _buildDetailRow(
                AppLocalizations.of(context).deliveryAddress,
                _request!.deliveryAddress!,
                Icons.location_on,
              ),
            if (_request!.additionalNotes != null &&
                _request!.additionalNotes!.isNotEmpty)
              _buildDetailRow(
                AppLocalizations.of(context).notes,
                _request!.additionalNotes!,
                Icons.note,
              ),
            if (_request!.rejectionReason != null)
              _buildDetailRow(
                AppLocalizations.of(context).rejectionReason,
                _request!.rejectionReason!,
                Icons.cancel,
                textColor: Colors.red,
              ),
            if (_request!.fineAmount != null && _request!.fineAmount! > 0)
              _buildDetailRow(
                AppLocalizations.of(context).fineAmount,
                '\$${_request!.fineAmount!.toStringAsFixed(2)}',
                Icons.monetization_on,
                textColor: Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    IconData icon, {
    Color? textColor,
  }) {
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
                    color: textColor ?? const Color(0xFF495057),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineCard() {
    if (_request!.timeline == null || _request!.timeline!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.requestTimelineLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ...(_request!.timeline!.asMap().entries.map((entry) {
              final index = entry.key;
              final event = entry.value;
              final isLast = index == _request!.timeline!.length - 1;

              return _buildTimelineItem(event, isLast);
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(TimelineEvent event, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _getStatusColor(event.status),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: const Color(0xFFE9ECEF),
                margin: const EdgeInsets.only(top: 4),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.description,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF495057),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(event.date),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C757D),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'active':
        return Colors.blue;
      case 'delivered':
        return Colors.green;
      case 'returned':
        return Colors.purple;
      case 'overdue':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _saveCustomerInfo() async {
    if (!_customerFormKey.currentState!.validate()) {
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    localizations.authenticationRequiredPleaseLogInAgain,
                  );
                },
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Update customer information via API
      // Note: This assumes the backend supports updating customer info through the borrow request
      // If not, you may need to update the user profile directly
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/borrow/borrowings/${_request!.id}/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'customer_name': _customerNameController.text.trim(),
          'customer_phone': _customerPhoneController.text.trim(),
          'customer_email': _customerEmailController.text.trim(),
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    localizations.customerInformationUpdatedSuccessfully,
                  );
                },
              ),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _isEditingCustomer = false;
          });
          // Reload request details to get updated information
          await _loadRequestDetails();
        } else {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['message'] ??
              errorData['error'] ??
              AppLocalizations.of(context).failedToUpdateCustomerInformation;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).error}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveDeliveryManagerInfo() async {
    if (_request?.deliveryPerson == null) {
      return;
    }

    if (!_deliveryManagerFormKey.currentState!.validate()) {
      return;
    }

    try {
      final authProvider = context.read<AuthProvider>();
      final token = authProvider.token;

      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    localizations.authenticationRequiredPleaseLogInAgain,
                  );
                },
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Update delivery manager information via API
      // Note: This assumes the backend supports updating delivery manager info through the borrow request
      // If not, you may need to update the user profile directly
      final response = await http.patch(
        Uri.parse('${ApiService.baseUrl}/borrow/borrowings/${_request!.id}/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'delivery_manager_name': _deliveryManagerNameController.text.trim(),
          'delivery_manager_phone': _deliveryManagerPhoneController.text.trim(),
          'delivery_manager_email': _deliveryManagerEmailController.text.trim(),
        }),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return Text(
                    localizations.deliveryManagerInformationUpdatedSuccessfully,
                  );
                },
              ),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _isEditingDeliveryManager = false;
          });
          // Reload request details to get updated information
          await _loadRequestDetails();
        } else {
          final errorData = jsonDecode(response.body);
          final errorMessage =
              errorData['message'] ??
              errorData['error'] ??
              AppLocalizations.of(
                context,
              ).failedToUpdateDeliveryManagerInformation;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context).error}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getBookName() {
    // First try to use the bookTitle field we added
    if (_request!.bookTitle != null && _request!.bookTitle!.isNotEmpty) {
      return _request!.bookTitle!;
    }

    // Fall back to book object if available
    if (_request!.book != null) {
      // Try to access the name field (backend sends 'name', not 'title')
      final bookName =
          _request!.book!.toJson()['name'] ?? _request!.book!.title;
      if (bookName != null && bookName.isNotEmpty) {
        return bookName;
      }
    }

    // Final fallback
    return '${AppLocalizations.of(context).bookId}: ${_request!.bookId ?? AppLocalizations.of(context).notProvided}';
  }
}
