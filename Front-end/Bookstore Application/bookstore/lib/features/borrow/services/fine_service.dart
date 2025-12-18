import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/api_config.dart';
import '../models/fine.dart';

/// Service for managing fines in the borrowing system
/// Stage 6: Fine Management
class FineService {
  String? _token;
  static String get _baseUrl => ApiConfig.getBaseUrl();

  void setToken(String token) {
    _token = token;
    debugPrint('FineService: Token set');
  }

  Map<String, String> get _headers {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }

  /// Get customer's fines
  /// Endpoint: GET /api/borrowing/fines/my-fines/
  Future<Map<String, dynamic>> getMyFines({String? status}) async {
    try {
      var uri = Uri.parse('$_baseUrl/borrowing/fines/my-fines/');

      if (status != null) {
        uri = uri.replace(queryParameters: {'status': status});
      }

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final List<dynamic> finesData = data['data'] ?? [];
          final List<Fine> fines = finesData
              .map((json) => Fine.fromJson(json))
              .toList();

          final FineSummary summary = FineSummary.fromJson(
            data['summary'] ?? {},
          );

          return {'fines': fines, 'summary': summary};
        } else {
          throw Exception(data['message'] ?? 'Failed to load fines');
        }
      } else {
        throw Exception('Failed to load fines: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching fines: $e');
    }
  }

  /// Get all fines (admin only)
  /// Endpoint: GET /api/borrowing/fines/all/
  Future<Map<String, dynamic>> getAllFines({String? status}) async {
    try {
      var uri = Uri.parse('$_baseUrl/borrowing/fines/all/');

      if (status != null) {
        uri = uri.replace(queryParameters: {'status': status});
      }

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return {
            'fines': data['data'] ?? [],
            'summary': data['summary'] ?? {},
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to load all fines');
        }
      } else {
        throw Exception('Failed to load all fines: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching all fines: $e');
    }
  }

  /// Mark fine as paid/not paid (Delivery Manager only)
  /// Stage 6: Delivery manager verifies fine payment
  /// Endpoint: POST /api/borrowing/fines/mark-paid/
  Future<Map<String, dynamic>> markFineAsPaid({
    required int borrowRequestId,
    required bool finePaid,
    String? paymentMethod,
    String? paymentNotes,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/borrowing/fines/mark-paid/');

      final body = {
        'borrow_request_id': borrowRequestId,
        'fine_paid': finePaid,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (paymentNotes != null) 'payment_notes': paymentNotes,
      };

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to mark fine payment');
        }
      } else {
        throw Exception('Failed to mark fine payment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error marking fine payment: $e');
    }
  }

  /// Calculate fine amount based on late days
  /// Formula: 5% of borrow price
  double calculateFine(double borrowPrice) {
    return borrowPrice * 0.05;
  }

  /// Check if customer has unpaid fines
  Future<bool> hasUnpaidFines() async {
    try {
      final result = await getMyFines(status: 'unpaid');
      final summary = result['summary'] as FineSummary;
      return summary.hasUnpaidFines;
    } catch (e) {
      return false;
    }
  }

  /// Get total unpaid fines amount
  Future<double> getTotalUnpaidFines() async {
    try {
      final result = await getMyFines(status: 'unpaid');
      final summary = result['summary'] as FineSummary;
      return summary.totalUnpaid;
    } catch (e) {
      return 0.0;
    }
  }

  /// Check if customer can submit new borrow request
  /// Returns false if customer has unpaid fines
  Future<Map<String, dynamic>> canSubmitBorrowRequest() async {
    try {
      final result = await getMyFines();
      final summary = result['summary'] as FineSummary;

      // Note: This method doesn't have access to BuildContext, so we can't use localization here
      // The calling code should translate the message based on the can_submit flag
      return {
        'can_submit': summary.canSubmitRequest,
        'has_unpaid_fines': summary.hasUnpaidFines,
        'total_unpaid': summary.totalUnpaid,
        'message': summary.canSubmitRequest
            ? 'you_can_submit_new_borrow_requests'
            : 'you_cannot_submit_borrow_request_until_fine_paid',
      };
    } catch (e) {
      return {
        'can_submit': true,
        'has_unpaid_fines': false,
        'total_unpaid': 0.0,
        'message': 'unable_to_check_fine_status',
      };
    }
  }

  /// Select payment method for a fine
  /// Endpoint: POST /api/borrowing/fines/select-payment-method/
  Future<Map<String, dynamic>> selectPaymentMethod({
    required int borrowRequestId,
    required String paymentMethod, // 'cash' or 'mastercard'
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/borrowing/fines/select-payment-method/');

      final body = {
        'borrow_request_id': borrowRequestId,
        'payment_method': paymentMethod,
      };

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to select payment method');
        }
      } else {
        throw Exception(
          'Failed to select payment method: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error selecting payment method: $e');
    }
  }

  /// Process MasterCard payment for a fine
  /// Endpoint: POST /api/borrowing/fines/process-payment/
  Future<Map<String, dynamic>> processMasterCardPayment({
    required int borrowRequestId,
    required Map<String, dynamic> cardData,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/borrowing/fines/process-payment/');

      final body = {
        'borrow_request_id': borrowRequestId,
        'payment_method': 'mastercard',
        'card_data': cardData,
      };

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Payment failed');
        }
      } else {
        throw Exception('Payment failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error processing payment: $e');
    }
  }

  /// Confirm cash payment (Delivery Manager only)
  /// Endpoint: POST /api/borrowing/fines/confirm-cash-payment/
  Future<Map<String, dynamic>> confirmCashPayment({
    required int borrowRequestId,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/borrowing/fines/confirm-cash-payment/');

      final body = {'borrow_request_id': borrowRequestId};

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to confirm cash payment');
        }
      } else {
        throw Exception(
          'Failed to confirm cash payment: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error confirming cash payment: $e');
    }
  }

  // =====================================
  // RETURN REQUEST FINE METHODS
  // =====================================

  /// Select payment method for a return request fine
  /// Endpoint: POST /api/returns/fines/{fine_id}/select-payment-method/
  Future<Map<String, dynamic>> selectReturnFinePaymentMethod({
    required int fineId,
    required String paymentMethod, // 'cash' or 'card'
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/returns/fines/$fineId/select-payment-method/',
      );

      final body = {'payment_method': paymentMethod};

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to select payment method');
        }
      } else {
        throw Exception(
          'Failed to select payment method: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error selecting payment method: $e');
    }
  }

  /// Confirm card payment for a return request fine
  /// Endpoint: POST /api/returns/fines/{fine_id}/confirm-card-payment/
  Future<Map<String, dynamic>> confirmReturnFineCardPayment({
    required int fineId,
    required Map<String, dynamic> cardData,
    String? transactionId,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/returns/fines/$fineId/confirm-card-payment/',
      );

      final body = {
        'card_data': cardData,
        if (transactionId != null) 'transaction_id': transactionId,
      };

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Payment failed');
        }
      } else {
        throw Exception('Payment failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error processing payment: $e');
    }
  }

  /// Confirm cash payment for a return request fine (Delivery Manager only)
  /// Endpoint: POST /api/returns/fines/{fine_id}/confirm-cash-payment/
  Future<Map<String, dynamic>> confirmReturnFineCashPayment({
    required int fineId,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/returns/fines/$fineId/confirm-cash-payment/',
      );

      final response = await http.post(
        uri,
        headers: _headers,
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'message': data['message'],
            'data': data['data'],
          };
        } else {
          throw Exception(data['message'] ?? 'Failed to confirm cash payment');
        }
      } else {
        throw Exception(
          'Failed to confirm cash payment: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error confirming cash payment: $e');
    }
  }
}
