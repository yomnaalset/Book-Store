import 'package:flutter/foundation.dart';
import '../models/return_request.dart';
import '../services/return_request_service.dart';

class ReturnRequestProvider with ChangeNotifier {
  final ReturnRequestService _service = ReturnRequestService();

  List<ReturnRequest> _returnRequests = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ReturnRequest> get returnRequests => _returnRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setToken(String? token) {
    _service.setToken(token);
  }

  Future<bool> createReturnRequest(int borrowId, {String? notes}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final returnRequest = await _service.createReturnRequest(
        borrowId,
        notes: notes,
      );
      _returnRequests.add(returnRequest);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Approve return request only (Step 2)
  /// Uses return request ID (not borrow request ID)
  Future<bool> approveReturnRequestOnly(int returnId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final returnRequest = await _service.approveReturnRequestById(returnId);
      final index = _returnRequests.indexWhere((r) => r.id == returnRequest.id);
      if (index != -1) {
        _returnRequests[index] = returnRequest;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Approve return request by return ID (new endpoint)
  Future<bool> approveReturnRequestById(int returnId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final returnRequest = await _service.approveReturnRequestById(returnId);
      final index = _returnRequests.indexWhere((r) => r.id == returnRequest.id);
      if (index != -1) {
        _returnRequests[index] = returnRequest;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Assign delivery manager to return request (new endpoint)
  Future<bool> assignDeliveryManagerToReturnRequest(
    int returnId,
    int deliveryManagerId,
  ) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final returnRequest = await _service.assignDeliveryManagerToReturnRequest(
        returnId,
        deliveryManagerId,
      );
      final index = _returnRequests.indexWhere((r) => r.id == returnRequest.id);
      if (index != -1) {
        _returnRequests[index] = returnRequest;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Assign delivery manager to return request (Step 3)
  /// Uses return request ID
  Future<bool> assignReturnDeliveryManager(
    int returnId,
    int deliveryManagerId,
  ) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final returnRequest = await _service.assignDeliveryManagerToReturnRequest(
        returnId,
        deliveryManagerId,
      );
      final index = _returnRequests.indexWhere((r) => r.id == returnRequest.id);
      if (index != -1) {
        _returnRequests[index] = returnRequest;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Approve return request and assign delivery manager in one step
  Future<bool> approveReturnRequest(
    int returnId,
    int deliveryManagerId, {
    String? notes,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // First approve the return request
      var returnRequest = await _service.approveReturnRequestById(returnId);

      // Then assign delivery manager
      returnRequest = await _service.assignDeliveryManagerToReturnRequest(
        returnId,
        deliveryManagerId,
      );

      final index = _returnRequests.indexWhere((r) => r.id == returnRequest.id);
      if (index != -1) {
        _returnRequests[index] = returnRequest;
      } else {
        _returnRequests.add(returnRequest);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableDeliveryManagers() async {
    try {
      return await _service.getAvailableDeliveryManagers();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<bool> acceptReturnRequest(int returnId, {String? notes}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final returnRequest = await _service.acceptReturnRequest(
        returnId,
        notes: notes,
      );
      final index = _returnRequests.indexWhere((r) => r.id == returnRequest.id);
      if (index != -1) {
        _returnRequests[index] = returnRequest;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Mark book as collected (starts return process)
  /// This is equivalent to starting the return process
  /// Returns the updated ReturnRequest object
  Future<ReturnRequest?> markBookCollected(int returnId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final returnRequest = await _service.startReturnProcess(returnId);
      final index = _returnRequests.indexWhere((r) => r.id == returnRequest.id);
      if (index != -1) {
        _returnRequests[index] = returnRequest;
      }

      _isLoading = false;
      notifyListeners();
      return returnRequest;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> completeReturn(int returnId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final returnRequest = await _service.completeReturn(returnId);
      final index = _returnRequests.indexWhere((r) => r.id == returnRequest.id);
      if (index != -1) {
        _returnRequests[index] = returnRequest;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadReturnRequests({String? status, String? search}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _returnRequests = await _service.getReturnRequests(
        status: status,
        search: search,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<ReturnRequest?> getReturnRequestById(int returnId) async {
    try {
      return await _service.getReturnRequestById(returnId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  /// Pay fine for a return request
  /// Uses the return request ID (not borrow request ID)
  Future<ReturnRequest?> payFine(
    int returnRequestId,
    String paymentMethod,
  ) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final returnRequest = await _service.payFine(
        returnRequestId,
        paymentMethod,
      );

      // Update the return request in the list
      final index = _returnRequests.indexWhere((r) => r.id == returnRequest.id);
      if (index != -1) {
        _returnRequests[index] = returnRequest;
      } else {
        _returnRequests.add(returnRequest);
      }

      _isLoading = false;
      notifyListeners();
      return returnRequest;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getOutstandingFines() async {
    try {
      return await _service.getOutstandingFines();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return [];
    }
  }

  /// Update delivery manager location
  Future<bool> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
    double? accuracy,
    double? speed,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      await _service.updateLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
        accuracy: accuracy,
        speed: speed,
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
}
