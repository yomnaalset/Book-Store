import 'package:flutter/foundation.dart';
import '../../borrow/models/return_request.dart';
import '../../../core/services/api_client.dart';

class ReturnRequestService {
  String? _token;

  void setToken(String? token) {
    _token = token;
  }

  /// Create a return request for a borrowed book
  /// POST /api/returns/requests/
  Future<ReturnRequest> createReturnRequest(
    int borrowId, {
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{'borrowing_id': borrowId};

      final response = await ApiClient.post(
        '/returns/requests/',
        body: body,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        if (responseData['success'] == true) {
          return ReturnRequest.fromJson(responseData['data']);
        }
        throw Exception(
          responseData['message'] ?? 'Failed to create return request',
        );
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(
          errorData['message'] ?? 'Failed to create return request',
        );
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error creating return request: $e');
      rethrow;
    }
  }

  /// Approve return request - Admin
  /// POST /api/returns/requests/<pk>/approve/
  Future<ReturnRequest> approveReturnRequestById(int returnId) async {
    try {
      final response = await ApiClient.post(
        '/returns/requests/$returnId/approve/',
        body: {},
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        if (responseData['success'] == true) {
          return ReturnRequest.fromJson(responseData['data']);
        }
        throw Exception(
          responseData['message'] ?? 'Failed to approve return request',
        );
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(
          errorData['message'] ?? 'Failed to approve return request',
        );
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error approving return request: $e');
      rethrow;
    }
  }

  /// Assign delivery manager to return request - Admin
  /// POST /api/returns/requests/<pk>/assign/
  Future<ReturnRequest> assignDeliveryManagerToReturnRequest(
    int returnId,
    int deliveryManagerId,
  ) async {
    try {
      final response = await ApiClient.post(
        '/returns/requests/$returnId/assign/',
        body: {'delivery_manager_id': deliveryManagerId},
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        if (responseData['success'] == true) {
          return ReturnRequest.fromJson(responseData['data']);
        }
        throw Exception(
          responseData['message'] ?? 'Failed to assign delivery manager',
        );
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(
          errorData['message'] ?? 'Failed to assign delivery manager',
        );
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error assigning delivery manager: $e');
      rethrow;
    }
  }

  /// Get available delivery managers
  /// GET /api/returns/delivery-managers/
  Future<List<Map<String, dynamic>>> getAvailableDeliveryManagers() async {
    try {
      final response = await ApiClient.get(
        '/returns/delivery-managers/',
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        List<dynamic> managersData;

        if (responseData is Map<String, dynamic>) {
          managersData = responseData['results'] ?? responseData['data'] ?? [];
        } else if (responseData is List) {
          managersData = responseData;
        } else {
          throw Exception('Unexpected response format');
        }

        return managersData.cast<Map<String, dynamic>>();
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(
          errorData['message'] ?? 'Failed to load delivery managers',
        );
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error loading delivery managers: $e');
      rethrow;
    }
  }

  /// Accept a return request (Delivery Manager)
  /// POST /api/returns/requests/<pk>/accept/
  Future<ReturnRequest> acceptReturnRequest(
    int returnId, {
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (notes != null && notes.isNotEmpty) {
        body['notes'] = notes;
      }

      final response = await ApiClient.post(
        '/returns/requests/$returnId/accept/',
        body: body,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        if (responseData['success'] == true) {
          return ReturnRequest.fromJson(responseData['data']);
        }
        throw Exception(
          responseData['message'] ?? 'Failed to accept return request',
        );
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(
          errorData['message'] ?? 'Failed to accept return request',
        );
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error accepting return request: $e');
      rethrow;
    }
  }

  /// Start return process (Delivery Manager)
  /// POST /api/returns/requests/<pk>/start/
  Future<ReturnRequest> startReturnProcess(int returnId) async {
    try {
      final response = await ApiClient.post(
        '/returns/requests/$returnId/start/',
        body: {},
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        if (responseData['success'] == true) {
          return ReturnRequest.fromJson(responseData['data']);
        }
        throw Exception(
          responseData['message'] ?? 'Failed to start return process',
        );
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(
          errorData['message'] ?? 'Failed to start return process',
        );
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error starting return process: $e');
      rethrow;
    }
  }

  /// Complete return (Delivery Manager)
  /// POST /api/returns/requests/<pk>/complete/
  Future<ReturnRequest> completeReturn(int returnId) async {
    try {
      final response = await ApiClient.post(
        '/returns/requests/$returnId/complete/',
        body: {},
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        if (responseData['success'] == true) {
          return ReturnRequest.fromJson(responseData['data']);
        }
        throw Exception(responseData['message'] ?? 'Failed to complete return');
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(errorData['message'] ?? 'Failed to complete return');
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error completing return: $e');
      rethrow;
    }
  }

  /// Get all return requests
  /// GET /api/returns/requests/list/
  /// Supports optional status filtering
  Future<List<ReturnRequest>> getReturnRequests({
    String? status,
    String? search,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (status != null &&
          status.isNotEmpty &&
          status.toLowerCase() != 'all') {
        queryParams['status'] = status;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }

      final response = await ApiClient.get(
        '/returns/requests/list/',
        queryParams: queryParams,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        List<dynamic> returnRequestsData;

        if (responseData is Map<String, dynamic>) {
          returnRequestsData =
              responseData['results'] ?? responseData['data'] ?? [];
        } else if (responseData is List) {
          returnRequestsData = responseData;
        } else {
          throw Exception('Unexpected response format');
        }

        return returnRequestsData
            .map((json) => ReturnRequest.fromJson(json))
            .toList();
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(
          errorData['message'] ?? 'Failed to load return requests',
        );
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error loading return requests: $e');
      rethrow;
    }
  }

  /// Get return request by ID
  /// GET /api/returns/requests/<pk>/
  Future<ReturnRequest> getReturnRequestById(int returnId) async {
    try {
      final response = await ApiClient.get(
        '/returns/requests/$returnId/',
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        if (responseData is Map<String, dynamic> &&
            responseData['data'] != null) {
          return ReturnRequest.fromJson(responseData['data']);
        }
        return ReturnRequest.fromJson(responseData);
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(
          errorData['message'] ?? 'Failed to load return request',
        );
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error loading return request: $e');
      rethrow;
    }
  }

  /// Pay fine for a return request
  /// POST /api/returns/requests/<pk>/pay-fine/
  Future<ReturnRequest> payFine(
    int returnRequestId,
    String paymentMethod,
  ) async {
    try {
      final response = await ApiClient.post(
        '/returns/requests/$returnRequestId/pay-fine/',
        body: {'payment_method': paymentMethod},
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        if (responseData['success'] == true) {
          return ReturnRequest.fromJson(responseData['data']['return_request']);
        }
        throw Exception(responseData['message'] ?? 'Failed to pay fine');
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(errorData['message'] ?? 'Failed to pay fine');
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error paying fine: $e');
      rethrow;
    }
  }

  /// Get outstanding fines for current user (related to return requests)
  /// GET /api/returns/fines/my-fines/
  Future<List<Map<String, dynamic>>> getOutstandingFines() async {
    try {
      final response = await ApiClient.get(
        '/returns/fines/my-fines/',
        queryParams: {'status': 'unpaid'},
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        final responseData = ApiClient.handleResponse(response);
        List<dynamic> finesData;

        if (responseData is Map<String, dynamic>) {
          finesData = responseData['results'] ?? responseData['data'] ?? [];
        } else if (responseData is List) {
          finesData = responseData;
        } else {
          throw Exception('Unexpected response format');
        }

        return finesData.cast<Map<String, dynamic>>();
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(errorData['message'] ?? 'Failed to load fines');
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error loading fines: $e');
      rethrow;
    }
  }

  /// Update delivery manager location
  /// POST /api/delivery-profiles/update_location/
  Future<bool> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
    double? accuracy,
    double? speed,
  }) async {
    try {
      final body = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
      };
      if (address != null && address.isNotEmpty) body['address'] = address;
      // Note: accuracy and speed are not supported by the delivery-profiles endpoint
      // They can be added to LocationHistory if needed via a different endpoint

      final response = await ApiClient.post(
        '/delivery-profiles/update_location/',
        body: body,
        token: _token,
      );

      if (ApiClient.isSuccess(response)) {
        return true;
      } else {
        final errorData = ApiClient.handleResponse(response);
        throw Exception(
          errorData['message'] ??
              errorData['error'] ??
              'Failed to update location',
        );
      }
    } catch (e) {
      debugPrint('ReturnRequestService: Error updating location: $e');
      rethrow;
    }
  }
}
