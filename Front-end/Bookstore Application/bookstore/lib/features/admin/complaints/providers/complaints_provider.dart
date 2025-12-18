import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../../models/complaint.dart';
import '../../services/manager_api_service.dart';

class ComplaintsProvider with ChangeNotifier {
  final ManagerApiService _apiService;
  List<Complaint> _complaints = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  ComplaintsProvider(this._apiService);

  List<Complaint> get complaints => _complaints;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  // Get all complaints
  Future<void> getComplaints({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
    String? type,
    String? priority,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Debug: Print authentication status
      developer.log('ComplaintsProvider: Attempting to get complaints...');
      developer.log(
        'ComplaintsProvider: Auth token available: ${_apiService.getAuthToken != null}',
      );
      if (_apiService.getAuthToken != null) {
        final token = _apiService.getAuthToken!();
        developer.log('ComplaintsProvider: Token length: ${token.length}');
        developer.log(
          'ComplaintsProvider: Token preview: ${token.substring(0, token.length > 20 ? 20 : token.length)}...',
        );
      }

      final result = await _apiService.getComplaints(
        page: page,
        limit: limit,
        search: search,
        status: status,
      );

      _complaints = result.results;
      _currentPage = result.currentPage;
      _itemsPerPage = limit;
      _totalItems = result.totalItems;
      _totalPages = result.totalPages;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      developer.log('ComplaintsProvider: Error getting complaints: $e');
      notifyListeners();
      rethrow;
    }
  }

  // Get complaint by ID
  Future<Complaint?> getComplaintById(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final complaint = await _apiService.getComplaint(id);
      _isLoading = false;
      notifyListeners();
      return complaint;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Update complaint status
  Future<void> updateComplaintStatus(int id, String status) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.updateComplaintStatus(id, status);

      // Update complaint status in the list
      final index = _complaints.indexWhere((c) => c.id == id);
      if (index != -1) {
        _complaints[index] = _complaints[index].copyWith(status: status);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Assign complaint to staff member
  Future<void> assignComplaint(int id, int staffId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.assignComplaint(id, staffId);

      // Update complaint status in the list
      final index = _complaints.indexWhere((c) => c.id == id);
      if (index != -1) {
        _complaints[index] = _complaints[index].copyWith(status: 'in_progress');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Add response to complaint
  Future<void> addComplaintResponse(int id, String response) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.addComplaintResponse(id, response);

      // Refresh the complaint to get updated responses
      final updatedComplaint = await _apiService.getComplaint(id);
      if (updatedComplaint != null) {
        final index = _complaints.indexWhere((c) => c.id == id);
        if (index != -1) {
          _complaints[index] = updatedComplaint;
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Resolve complaint
  Future<void> resolveComplaint(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.resolveComplaint(id);

      // Update complaint status in the list
      final index = _complaints.indexWhere((c) => c.id == id);
      if (index != -1) {
        _complaints[index] = _complaints[index].copyWith(status: 'resolved');
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Reset pagination
  void resetPagination() {
    _currentPage = 1;
    _totalPages = 1;
    _totalItems = 0;
    notifyListeners();
  }
}
