import 'package:flutter/foundation.dart';
import '../models/complaint.dart';
import '../services/manager_api_service.dart';

class ComplaintsProvider with ChangeNotifier {
  final ManagerApiService _apiService;

  List<Complaint> _complaints = [];
  bool _isLoading = false;
  String? _error;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  ComplaintsProvider(this._apiService);

  // Getters
  List<Complaint> get complaints => _complaints;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  // Get complaints
  Future<void> getComplaints({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final response = await _apiService.getComplaints(
        page: page,
        limit: limit,
        search: search,
        status: status,
      );

      _complaints = response.results;
      _currentPage = response.currentPage;
      _totalPages = response.totalPages;
      _totalItems = response.totalItems;
      _itemsPerPage = limit;

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load complaints: $e');
      _setLoading(false);
    }
  }

  // Get complaint details
  Future<Complaint?> getComplaintDetails(int id) async {
    _clearError();

    try {
      return await _apiService.getComplaint(id);
    } catch (e) {
      _setError('Failed to load complaint details: $e');
      return null;
    }
  }

  // Update complaint status
  Future<bool> updateComplaintStatus(int id, String status) async {
    _clearError();

    try {
      await _apiService.updateComplaintStatus(id, status);

      // Update local data
      final index = _complaints.indexWhere((c) => c.id == id);
      if (index != -1) {
        _complaints[index] = _complaints[index].copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to update complaint status: $e');
      return false;
    }
  }

  // Assign complaint
  Future<bool> assignComplaint(int id, int assignedToId) async {
    _clearError();

    try {
      await _apiService.assignComplaint(id, assignedToId);

      // Update local data
      final index = _complaints.indexWhere((c) => c.id == id);
      if (index != -1) {
        _complaints[index] = _complaints[index].copyWith(
          assignedToId: assignedToId,
          status: 'assigned',
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to assign complaint: $e');
      return false;
    }
  }

  // Resolve complaint
  Future<bool> resolveComplaint(int id, String resolution) async {
    _clearError();

    try {
      await _apiService.resolveComplaint(id, resolution);

      // Update local data
      final index = _complaints.indexWhere((c) => c.id == id);
      if (index != -1) {
        _complaints[index] = _complaints[index].copyWith(
          status: 'resolved',
          resolution: resolution,
          resolvedAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }

      return true;
    } catch (e) {
      _setError('Failed to resolve complaint: $e');
      return false;
    }
  }

  // Add complaint response
  Future<bool> addComplaintResponse(int id, String response) async {
    _clearError();

    try {
      await _apiService.addComplaintResponse(id, response);
      return true;
    } catch (e) {
      _setError('Failed to add complaint response: $e');
      return false;
    }
  }

  // Get complaint by ID
  Future<Complaint?> getComplaintById(int id) async {
    _clearError();

    try {
      return await _apiService.getComplaint(id);
    } catch (e) {
      _setError('Failed to get complaint: $e');
      return null;
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  // Update the API service with a new token
  void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      // Set the token directly on the existing API service
      _apiService.setToken(token);
    }
  }

  // Clear data
  void clear() {
    _complaints.clear();
    _currentPage = 1;
    _totalPages = 1;
    _totalItems = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}

// Response models for API calls
class ComplaintsResponse {
  final List<Complaint> results;
  final int totalPages;
  final int totalItems;
  final int currentPage;
  final bool hasNext;
  final bool hasPrevious;

  ComplaintsResponse({
    required this.results,
    required this.totalPages,
    required this.totalItems,
    required this.currentPage,
    required this.hasNext,
    required this.hasPrevious,
  });
}
