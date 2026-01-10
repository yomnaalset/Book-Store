import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../borrow/models/borrow_request.dart';
import '../../../core/services/api_config.dart';

class BorrowService {
  String? _token;
  static String get _baseUrl => ApiConfig.getBaseUrl();

  void setToken(String token) {
    _token = token;
    debugPrint('BorrowService: Token set: ${token.substring(0, 20)}...');
  }

  Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
      debugPrint('BorrowService: Authorization header added');
      debugPrint(
        'BorrowService: Token length: ${_token!.length}, first 30 chars: ${_token!.substring(0, _token!.length > 30 ? 30 : _token!.length)}...',
      );
      debugPrint(
        'BorrowService: Full Authorization header: Bearer ${_token!.substring(0, _token!.length > 50 ? 50 : _token!.length)}...',
      );
    } else {
      debugPrint(
        'BorrowService: WARNING - No token available for Authorization header',
      );
    }

    debugPrint('BorrowService: Headers keys: ${headers.keys.toList()}');
    return headers;
  }

  Future<List<BorrowRequest>> getPendingRequests() async {
    try {
      debugPrint('BorrowService: Getting pending requests...');
      debugPrint(
        'BorrowService: Token status: ${_token != null ? 'present' : 'null'}',
      );
      debugPrint(
        'BorrowService: Request URL: $_baseUrl/borrow/requests/pending/',
      );

      final response = await http.get(
        Uri.parse('$_baseUrl/borrow/requests/pending/'),
        headers: _headers,
      );

      debugPrint('BorrowService: Response status: ${response.statusCode}');
      debugPrint('BorrowService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((item) => BorrowRequest.fromJson(item))
              .toList();
        }
      }
      throw Exception('Failed to load pending requests');
    } catch (e) {
      throw Exception('Error loading pending requests: $e');
    }
  }

  Future<List<BorrowRequest>> getOverdueBorrowings() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/borrow/borrowings/overdue/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((item) => BorrowRequest.fromJson(item))
              .toList();
        }
      }
      throw Exception('Failed to load overdue borrowings');
    } catch (e) {
      throw Exception('Error loading overdue borrowings: $e');
    }
  }

  Future<List<BorrowRequest>> getAllBorrowings() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/borrow/requests/all/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((item) => BorrowRequest.fromJson(item))
              .toList();
        }
      }
      throw Exception('Failed to load all borrowings');
    } catch (e) {
      throw Exception('Error loading all borrowings: $e');
    }
  }

  Future<List<BorrowRequest>> getAllBorrowingsWithStatus({
    String? status,
  }) async {
    // Check if token is available before making the request
    if (_token == null || _token!.isEmpty) {
      debugPrint(
        'BorrowService: ERROR - No token available for getAllBorrowingsWithStatus',
      );
      throw Exception('Authentication required. Please login again.');
    }

    try {
      debugPrint('BorrowService: Getting all borrowings with status: $status');
      debugPrint(
        'BorrowService: Token status: present (${_token!.substring(0, _token!.length > 20 ? 20 : _token!.length)}...)',
      );

      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse(
        '$_baseUrl/borrow/requests/all/',
      ).replace(queryParameters: queryParams);
      debugPrint('BorrowService: Full URL: $uri');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 401) {
        debugPrint(
          'BorrowService: 401 Unauthorized - Token may be expired or invalid',
        );
        throw Exception('Authentication failed. Please login again.');
      }

      debugPrint('BorrowService: Response status: ${response.statusCode}');
      debugPrint('BorrowService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((item) => BorrowRequest.fromJson(item))
              .toList();
        } else {
          throw Exception(data['message'] ?? 'Failed to load borrowings');
        }
      } else {
        throw Exception('Failed to load borrowings: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('BorrowService: Error getting all borrowings: $e');
      rethrow;
    }
  }

  Future<List<BorrowRequest>> getAllBorrowingsWithFilters({
    String? status,
    String? search,
  }) async {
    // Check if token is available before making the request
    if (_token == null || _token!.isEmpty) {
      debugPrint(
        'BorrowService: ERROR - No token available for getAllBorrowingsWithFilters',
      );
      throw Exception('Authentication required. Please login again.');
    }

    try {
      debugPrint('BorrowService: Getting borrowings with filters:');
      debugPrint('  - status: $status');
      debugPrint('  - search: $search');
      debugPrint(
        'BorrowService: Token status: present (${_token!.substring(0, _token!.length > 20 ? 20 : _token!.length)}...)',
      );

      final queryParams = <String, String>{};

      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final uri = Uri.parse(
        '$_baseUrl/borrow/requests/all/',
      ).replace(queryParameters: queryParams);

      debugPrint('BorrowService: Full URL: $uri');

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 401) {
        debugPrint(
          'BorrowService: 401 Unauthorized - Token may be expired or invalid',
        );
        throw Exception('Authentication failed. Please login again.');
      }

      debugPrint('BorrowService: Response status: ${response.statusCode}');
      debugPrint('BorrowService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final borrowings = (data['data'] as List).map((item) {
            // Debug: Log status fields for first item
            if (data['data'].indexOf(item) == 0) {
              debugPrint('DEBUG: First borrowing item status fields:');
              debugPrint('  - status: ${item['status']}');
              debugPrint('  - borrow_status: ${item['borrow_status']}');
              debugPrint(
                '  - delivery_request: ${item['delivery_request'] != null ? "EXISTS" : "NULL"}',
              );
              if (item['delivery_request'] != null) {
                debugPrint(
                  '  - delivery_request.status: ${item['delivery_request']['status']}',
                );
              }
            }
            return BorrowRequest.fromJson(item);
          }).toList();

          return borrowings;
        } else {
          throw Exception(data['message'] ?? 'Failed to load borrowings');
        }
      } else {
        throw Exception('Failed to load borrowings: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('BorrowService: Error getting borrowings with filters: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getDeliveryManagers() async {
    try {
      debugPrint('BorrowService: Getting delivery managers...');

      final response = await http.get(
        Uri.parse('$_baseUrl/borrow/delivery-managers/'),
        headers: _headers,
      );

      debugPrint('BorrowService: Response status: ${response.statusCode}');
      debugPrint('BorrowService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      throw Exception('Failed to load delivery managers');
    } catch (e) {
      throw Exception('Error loading delivery managers: $e');
    }
  }

  Future<void> approveRequest(int requestId, {int? deliveryManagerId}) async {
    try {
      final body = <String, dynamic>{'action': 'approve'};
      if (deliveryManagerId != null) {
        body['delivery_manager_id'] = deliveryManagerId;
      }

      final response = await http.patch(
        Uri.parse('$_baseUrl/borrow/requests/$requestId/approve/'),
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to approve request');
      }
    } catch (e) {
      throw Exception('Error approving request: $e');
    }
  }

  Future<void> rejectRequest(int requestId, String reason) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/borrow/requests/$requestId/reject/'),
        headers: _headers,
        body: json.encode({'action': 'reject', 'reason': reason}),
      );

      if (response.statusCode != 200) {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to reject request');
      }
    } catch (e) {
      throw Exception('Error rejecting request: $e');
    }
  }

  Future<void> sendReminder(int requestId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/borrow/requests/$requestId/send-reminder/'),
        headers: _headers,
      );

      if (response.statusCode != 200) {
        final data = json.decode(response.body);
        throw Exception(data['message'] ?? 'Failed to send reminder');
      }
    } catch (e) {
      throw Exception('Error sending reminder: $e');
    }
  }

  Future<BorrowRequest?> requestBorrow({
    required String bookId,
    required int durationDays,
    required String deliveryAddress,
    String? notes,
  }) async {
    try {
      debugPrint('=== BORROW REQUEST DEBUG ===');
      debugPrint('URL: $_baseUrl/borrow/requests/');
      debugPrint('Headers: $_headers');
      debugPrint(
        'Body: ${json.encode({'book_id': bookId, 'borrow_period_days': durationDays, 'delivery_address': deliveryAddress, 'additional_notes': notes})}',
      );

      final response = await http.post(
        Uri.parse('$_baseUrl/borrow/requests/'),
        headers: _headers,
        body: json.encode({
          'book_id': bookId,
          'borrow_period_days': durationDays,
          'delivery_address': deliveryAddress,
          'additional_notes': notes,
        }),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 201 && data['success'] == true) {
        return BorrowRequest.fromJson(data['data']);
      } else {
        // Handle error response - extract meaningful error message
        String errorMessage =
            data['message'] ?? 'Failed to create borrow request';

        // Try to parse errors - prioritize actual error messages over generic ones
        if (data['errors'] != null) {
          try {
            debugPrint(
              'BorrowService: Parsing errors - type: ${data['errors'].runtimeType}',
            );

            if (data['errors'] is Map) {
              // If errors is already a map, extract non_field_errors
              final errors = data['errors'] as Map<String, dynamic>;
              debugPrint(
                'BorrowService: Errors map keys: ${errors.keys.toList()}',
              );

              if (errors.containsKey('non_field_errors')) {
                final nonFieldErrors = errors['non_field_errors'];
                debugPrint(
                  'BorrowService: non_field_errors type: ${nonFieldErrors.runtimeType}, value: $nonFieldErrors',
                );

                if (nonFieldErrors is List && nonFieldErrors.isNotEmpty) {
                  final firstError = nonFieldErrors[0];
                  debugPrint(
                    'BorrowService: First error type: ${firstError.runtimeType}, value: $firstError',
                  );

                  // Handle both string and object formats
                  if (firstError is String) {
                    errorMessage = firstError;
                    debugPrint(
                      'BorrowService: Extracted error message: $errorMessage',
                    );
                  } else {
                    errorMessage = firstError.toString();
                    debugPrint(
                      'BorrowService: Converted error message: $errorMessage',
                    );
                  }
                }
              } else {
                // Try to get first error from any field
                if (errors.isNotEmpty) {
                  final firstKey = errors.keys.first;
                  final firstValue = errors[firstKey];
                  debugPrint(
                    'BorrowService: First error key: $firstKey, value: $firstValue',
                  );

                  if (firstValue is List && firstValue.isNotEmpty) {
                    errorMessage = firstValue[0].toString();
                  } else if (firstValue is String) {
                    errorMessage = firstValue;
                  }
                }
              }
            } else if (data['errors'] is String) {
              // Fallback: Parse the string representation of Python dict
              final errorsString = data['errors'] as String;
              debugPrint(
                'BorrowService: Errors is string, parsing: $errorsString',
              );

              // Extract the actual error message from the string
              // Format: "{'non_field_errors': [ErrorDetail(string='...', code='invalid')]}"
              // ignore: deprecated_member_use
              final match = RegExp(
                r"string='([^']+)'",
              ).firstMatch(errorsString);
              if (match != null) {
                errorMessage = match.group(1)!;
                debugPrint(
                  'BorrowService: Extracted from string: $errorMessage',
                );
              }
            }
          } catch (e, stackTrace) {
            debugPrint('BorrowService: Error parsing error message: $e');
            debugPrint('BorrowService: Stack trace: $stackTrace');
          }
        }

        debugPrint('Error from server: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('=== BORROW REQUEST ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');

      // Preserve the original error message - don't double-wrap
      if (e is Exception) {
        // If it's already an Exception, check if it has a meaningful message
        final errorString = e.toString();
        // If the message doesn't contain "Error creating borrow request", it's already meaningful
        if (!errorString.contains('Error creating borrow request')) {
          // Re-throw the original exception to preserve the message
          rethrow;
        } else {
          // Extract just the message part
          final message = errorString
              .replaceFirst('Exception: ', '')
              .replaceFirst('Error creating borrow request: ', '');
          throw Exception(message);
        }
      } else {
        // For other types, wrap with context
        throw Exception('Error creating borrow request: $e');
      }
    }
  }

  Future<List<BorrowRequest>> getCustomerBorrowings({String? status}) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse(
        '$_baseUrl/borrow/my-borrowings/',
      ).replace(queryParameters: queryParams);

      debugPrint('BorrowService: Getting customer borrowings from: $uri');

      final response = await http.get(uri, headers: _headers);

      debugPrint('BorrowService: Response status: ${response.statusCode}');
      debugPrint('BorrowService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return (data['data'] as List)
              .map((item) => BorrowRequest.fromJson(item))
              .toList();
        } else {
          throw Exception(
            data['message'] ?? 'Failed to load customer borrowings',
          );
        }
      } else {
        throw Exception(
          'Failed to load customer borrowings: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('BorrowService: Error getting customer borrowings: $e');
      rethrow;
    }
  }

  Future<BorrowRequest?> getBorrowHistory() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/borrow/my-borrowings/'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'].isNotEmpty) {
          return BorrowRequest.fromJson(data['data'].first);
        }
      }
      return null;
    } catch (e) {
      throw Exception('Error loading borrow history: $e');
    }
  }

  Future<BorrowRequest?> getBorrowRequest(String requestId) async {
    // Check if token is available before making the request
    if (_token == null || _token!.isEmpty) {
      debugPrint(
        'BorrowService: ERROR - No token available for getBorrowRequest',
      );
      throw Exception('Authentication required. Please login again.');
    }

    try {
      debugPrint('BorrowService: Getting borrow request $requestId');
      debugPrint(
        'BorrowService: Token status: present (${_token!.substring(0, _token!.length > 20 ? 20 : _token!.length)}...)',
      );
      debugPrint(
        'BorrowService: Request URL: $_baseUrl/borrow/borrowings/$requestId/',
      );

      final response = await http.get(
        Uri.parse('$_baseUrl/borrow/borrowings/$requestId/'),
        headers: _headers,
      );

      debugPrint('BorrowService: Response status: ${response.statusCode}');

      if (response.statusCode == 401) {
        debugPrint(
          'BorrowService: 401 Unauthorized - Token may be expired or invalid',
        );
        throw Exception('Authentication failed. Please login again.');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('BorrowService: Response data keys: ${data.keys.toList()}');
        debugPrint('BorrowService: Response success: ${data['success']}');

        if (data['success'] == true && data['data'] != null) {
          debugPrint('BorrowService: Parsing BorrowRequest from data...');
          debugPrint('BorrowService: Data keys: ${data['data'].keys.toList()}');
          debugPrint(
            'BorrowService: Status in data: ${data['data']['status']}',
          );
          debugPrint(
            'BorrowService: Delivery person in data: ${data['data']['delivery_person'] != null ? "EXISTS" : "NULL"}',
          );

          final borrowRequest = BorrowRequest.fromJson(data['data']);
          debugPrint(
            'BorrowService: Parsed BorrowRequest - ID: ${borrowRequest.id}, Status: ${borrowRequest.status}',
          );
          debugPrint(
            'BorrowService: Parsed BorrowRequest - Delivery Person: ${borrowRequest.deliveryPerson != null ? "EXISTS" : "NULL"}',
          );

          return borrowRequest;
        }
        debugPrint('BorrowService: ERROR - success is false or data is null');
        debugPrint('BorrowService: Response body: ${response.body}');
        throw Exception(data['message'] ?? 'Failed to load borrow request');
      }

      // Handle other error status codes
      final errorData = json.decode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load borrow request');
    } catch (e) {
      if (e.toString().contains('Authentication failed')) {
        rethrow;
      }
      throw Exception('Error loading borrow request: $e');
    }
  }

  Future<bool> returnBook(String requestId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/borrow/borrowings/$requestId/early-return/'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error returning book: $e');
    }
  }

  Future<bool> renewBook(String requestId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/borrow/borrowings/$requestId/extend/'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error renewing book: $e');
    }
  }

  Future<bool> cancelRequest(String requestId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/borrow/requests/$requestId/cancel/'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error cancelling request: $e');
    }
  }

  Future<bool> confirmBookReturn(String requestId) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/borrow/borrowings/$requestId/confirm-return/'),
        headers: _headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      throw Exception('Error confirming book return: $e');
    }
  }

  Future<BorrowRequest?> confirmPayment({
    required int requestId,
    required String paymentMethod,
    String? cardNumber,
    String? cardholderName,
    int? expiryMonth,
    int? expiryYear,
    String? cvv,
  }) async {
    try {
      debugPrint('=== CONFIRM PAYMENT DEBUG ===');
      debugPrint('URL: $_baseUrl/borrow/confirm-payment/$requestId/');
      debugPrint('Payment Method: $paymentMethod');

      final body = <String, dynamic>{'payment_method': paymentMethod};

      // Add card details if payment method is mastercard
      if (paymentMethod == 'mastercard') {
        if (cardNumber == null ||
            cardholderName == null ||
            expiryMonth == null ||
            expiryYear == null ||
            cvv == null) {
          throw Exception('Card details are required for Mastercard payment');
        }
        body['card_number'] = cardNumber;
        body['cardholder_name'] = cardholderName;
        body['expiry_month'] = expiryMonth;
        body['expiry_year'] = expiryYear;
        body['cvv'] = cvv;
      }

      debugPrint('Request Body: ${json.encode(body)}');

      final response = await http.post(
        Uri.parse('$_baseUrl/borrow/confirm-payment/$requestId/'),
        headers: _headers,
        body: json.encode(body),
      );

      debugPrint('Response Status: ${response.statusCode}');
      debugPrint('Response Body: ${response.body}');

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return BorrowRequest.fromJson(data['data']);
      } else {
        String errorMessage = data['message'] ?? 'Failed to confirm payment';

        // Try to parse errors
        if (data['errors'] != null) {
          if (data['errors'] is Map) {
            final errors = data['errors'] as Map<String, dynamic>;
            if (errors.containsKey('non_field_errors')) {
              final nonFieldErrors = errors['non_field_errors'];
              if (nonFieldErrors is List && nonFieldErrors.isNotEmpty) {
                errorMessage = nonFieldErrors[0].toString();
              }
            } else if (errors.isNotEmpty) {
              final firstKey = errors.keys.first;
              final firstValue = errors[firstKey];
              if (firstValue is List && firstValue.isNotEmpty) {
                errorMessage = firstValue[0].toString();
              } else if (firstValue is String) {
                errorMessage = firstValue;
              }
            }
          }
        }

        debugPrint('Error from server: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e, stackTrace) {
      debugPrint('=== CONFIRM PAYMENT ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (e is Exception) {
        rethrow;
      } else {
        throw Exception('Error confirming payment: $e');
      }
    }
  }
}
