import 'package:flutter/foundation.dart';
import '../models/customer_complaint.dart';
import '../services/customer_complaints_api_service.dart';

class CustomerComplaintsProvider extends ChangeNotifier {
  final CustomerComplaintsApiService _apiService;
  String? _token;

  List<CustomerComplaint> _complaints = [];
  bool _isLoading = false;
  String? _error;

  CustomerComplaintsProvider(this._apiService);

  // Getters
  List<CustomerComplaint> get complaints => _complaints;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Set authentication token
  void setToken(String? token) {
    _token = token;
  }

  // Load customer's complaints
  Future<void> loadComplaints() async {
    if (_token == null || _token!.isEmpty) {
      debugPrint('CustomerComplaintsProvider: No token available');
      return;
    }

    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final complaints = await _apiService.getMyComplaints(token: _token);
      _complaints = complaints;
      _error = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('CustomerComplaintsProvider: Error loading complaints: $e');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // Create a new complaint
  Future<CustomerComplaint?> createComplaint({
    required String message,
    required String complaintType,
  }) async {
    if (_token == null || _token!.isEmpty) {
      _error = 'Authentication required';
      notifyListeners();
      return null;
    }

    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final complaint = await _apiService.createComplaint(
        message: message,
        complaintType: complaintType,
        token: _token,
      );

      // Add to the beginning of the list
      _complaints.insert(0, complaint);
      _error = null;
      notifyListeners();
      return complaint;
    } catch (e) {
      _error = e.toString();
      debugPrint('CustomerComplaintsProvider: Error creating complaint: $e');
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Update a complaint
  Future<CustomerComplaint?> updateComplaint({
    required int id,
    required String message,
    required String complaintType,
  }) async {
    if (_token == null || _token!.isEmpty) {
      _error = 'Authentication required';
      notifyListeners();
      return null;
    }

    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final complaint = await _apiService.updateComplaint(
        id: id,
        message: message,
        complaintType: complaintType,
        token: _token,
      );

      // Update in the list
      final index = _complaints.indexWhere((c) => c.id == id);
      if (index != -1) {
        _complaints[index] = complaint;
      }
      _error = null;
      notifyListeners();
      return complaint;
    } catch (e) {
      _error = e.toString();
      debugPrint('CustomerComplaintsProvider: Error updating complaint: $e');
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Get complaint details
  Future<CustomerComplaint?> getComplaintDetails(int id) async {
    if (_token == null || _token!.isEmpty) {
      _error = 'Authentication required';
      notifyListeners();
      return null;
    }

    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final complaint = await _apiService.getComplaintDetails(
        id: id,
        token: _token,
      );
      _error = null;
      notifyListeners();
      return complaint;
    } catch (e) {
      _error = e.toString();
      debugPrint(
        'CustomerComplaintsProvider: Error getting complaint details: $e',
      );
      notifyListeners();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
