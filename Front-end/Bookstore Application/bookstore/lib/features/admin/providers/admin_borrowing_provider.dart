import 'package:flutter/foundation.dart';
import '../../borrow/models/borrow_request.dart';
import '../../borrow/services/borrow_service.dart';

class AdminBorrowingProvider extends ChangeNotifier {
  final BorrowService _borrowService = BorrowService();

  bool _isLoading = false;
  String? _errorMessage;

  List<BorrowRequest> _pendingRequests = [];
  List<BorrowRequest> _overdueBorrowings = [];
  List<BorrowRequest> _allBorrowings = [];
  List<Map<String, dynamic>> _deliveryManagers = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BorrowRequest> get pendingRequests => _pendingRequests;
  List<BorrowRequest> get overdueBorrowings => _overdueBorrowings;
  List<BorrowRequest> get allBorrowings => _allBorrowings;
  List<Map<String, dynamic>> get deliveryManagers => _deliveryManagers;

  void setToken(String token) {
    _borrowService.setToken(token);
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadPendingRequests() async {
    try {
      _setLoading(true);
      _setError(null);

      final requests = await _borrowService.getPendingRequests();
      _pendingRequests = requests;
    } catch (e) {
      _setError('Failed to load pending requests: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadOverdueBorrowings() async {
    try {
      _setLoading(true);
      _setError(null);

      final borrowings = await _borrowService.getOverdueBorrowings();
      _overdueBorrowings = borrowings;
    } catch (e) {
      _setError('Failed to load overdue borrowings: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAllBorrowings() async {
    try {
      _setLoading(true);
      _setError(null);

      final borrowings = await _borrowService.getAllBorrowings();
      _allBorrowings = borrowings;
    } catch (e) {
      _setError('Failed to load all borrowings: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAllBorrowingsWithStatus({String? status}) async {
    try {
      _setLoading(true);
      _setError(null);

      final borrowings = await _borrowService.getAllBorrowingsWithStatus(
        status: status,
      );
      _allBorrowings = borrowings;
    } catch (e) {
      _setError('Failed to load borrowings: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadAllBorrowingsWithFilters({
    String? status,
    String? search,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final borrowings = await _borrowService.getAllBorrowingsWithFilters(
        status: status,
        search: search,
      );

      _allBorrowings = borrowings;
    } catch (e) {
      _setError('Failed to load borrowings: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadDeliveryManagers() async {
    try {
      _setLoading(true);
      _setError(null);

      final managers = await _borrowService.getDeliveryManagers();
      _deliveryManagers = managers;
    } catch (e) {
      _setError('Failed to load delivery managers: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> approveRequest(int requestId, {int? deliveryManagerId}) async {
    try {
      _setLoading(true);
      _setError(null);

      await _borrowService.approveRequest(
        requestId,
        deliveryManagerId: deliveryManagerId,
      );

      // Reload data
      await loadPendingRequests();
      await loadAllBorrowings();

      return true;
    } catch (e) {
      _setError('Failed to approve request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> rejectRequest(int requestId, String reason) async {
    try {
      _setLoading(true);
      _setError(null);

      await _borrowService.rejectRequest(requestId, reason);

      // Reload data
      await loadPendingRequests();
      await loadAllBorrowings();

      return true;
    } catch (e) {
      _setError('Failed to reject request: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendReminder(int requestId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _borrowService.sendReminder(requestId);

      return true;
    } catch (e) {
      _setError('Failed to send reminder: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
