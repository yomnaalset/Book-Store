import 'package:flutter/foundation.dart';
import '../models/borrow_request.dart';
import '../models/borrow_extension.dart';
import '../models/borrow_fine.dart';
import '../services/borrow_service.dart';

class BorrowingProvider with ChangeNotifier {
  final BorrowService _borrowService;

  List<BorrowRequest> _borrowRequests = [];
  List<BorrowExtension> _extensions = [];
  List<BorrowFine> _fines = [];
  bool _isLoading = false;
  String? _error;

  // Statistics
  int _totalBorrowings = 0;
  int _activeBorrowings = 0;
  int _overdueBorrowings = 0;
  int _pendingRequests = 0;

  // Pagination
  final int _currentPage = 1;
  final int _totalPages = 1;
  final int _totalItems = 0;
  final int _itemsPerPage = 10;

  BorrowingProvider(this._borrowService);

  // Getters
  List<BorrowRequest> get borrowRequests => _borrowRequests;
  List<BorrowExtension> get extensions => _extensions;
  List<BorrowFine> get fines => _fines;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get errorMessage => _error;
  int get totalBorrowings => _totalBorrowings;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;
  int get activeBorrowings => _activeBorrowings;
  int get overdueBorrowings => _overdueBorrowings;
  int get pendingRequests => _pendingRequests;

  // Load all borrowing data
  Future<void> loadBorrowingData() async {
    _setLoading(true);
    _clearError();

    try {
      await Future.wait([
        loadBorrowRequests(),
        loadExtensions(),
        loadFines(),
        loadStatistics(),
      ]);

      _setLoading(false);
    } catch (e) {
      _setError('Failed to load borrowing data: $e');
      _setLoading(false);
    }
  }

  // Load borrow requests
  Future<void> loadBorrowRequests({String? status, String? userId}) async {
    try {
      // For now, we'll use the customer endpoint
      _borrowRequests = await _borrowService.getAllBorrowings();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load borrow requests: $e');
    }
  }

  // Load extensions
  Future<void> loadExtensions({String? status}) async {
    try {
      _extensions = [];
      notifyListeners();
    } catch (e) {
      _setError('Failed to load extensions: $e');
    }
  }

  // Load fines
  Future<void> loadFines({String? status}) async {
    try {
      _fines = [];
      notifyListeners();
    } catch (e) {
      _setError('Failed to load fines: $e');
    }
  }

  // Load statistics
  Future<void> loadStatistics() async {
    try {
      // For now, set default statistics since getBorrowStatistics doesn't exist
      _totalBorrowings = _borrowRequests.length;
      _activeBorrowings = _borrowRequests
          .where((req) => req.status == 'active')
          .length;
      _overdueBorrowings = _borrowRequests.where((req) => req.isOverdue).length;
      _pendingRequests = _borrowRequests
          .where((req) => req.status == 'pending')
          .length;
      notifyListeners();
    } catch (e) {
      _setError('Failed to load statistics: $e');
    }
  }

  // Create borrow request
  Future<bool> createBorrowRequest({
    required String bookId,
    required int durationDays,
    required String deliveryAddress,
    String? notes,
  }) async {
    _clearError();

    try {
      final request = await _borrowService.requestBorrow(
        bookId: bookId,
        durationDays: durationDays,
        deliveryAddress: deliveryAddress,
        notes: notes,
      );

      if (request != null) {
        _borrowRequests.insert(0, request);
        _pendingRequests++;
        notifyListeners();
      }
      return true;
    } catch (e) {
      _setError('Failed to create borrow request: $e');
      return false;
    }
  }

  // Request borrow (alias for createBorrowRequest)
  Future<bool> requestBorrow({
    required String bookId,
    required int borrowPeriodDays,
    required String deliveryAddress,
    String? notes,
  }) async {
    return await createBorrowRequest(
      bookId: bookId,
      durationDays: borrowPeriodDays,
      deliveryAddress: deliveryAddress,
      notes: notes,
    );
  }

  // Approve borrow request
  Future<bool> approveBorrowRequest(String requestId) async {
    return await _updateBorrowRequestStatus(requestId, 'approved');
  }

  // Reject borrow request
  Future<bool> rejectBorrowRequest(String requestId, String reason) async {
    _clearError();

    try {
      bool success = true;

      if (success) {
        final index = _borrowRequests.indexWhere(
          (req) => req.id.toString() == requestId,
        );
        if (index != -1) {
          _borrowRequests[index] = _borrowRequests[index].copyWith(
            status: 'rejected',
          );
          _pendingRequests--;
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to reject borrow request: $e');
      return false;
    }
  }

  // Return book
  Future<bool> returnBook(String requestId) async {
    return await _updateBorrowRequestStatus(requestId, 'returned');
  }

  // Request extension
  Future<bool> requestExtension({
    required String borrowRequestId,
    required int extensionDays,
    String? reason,
  }) async {
    _clearError();

    try {
      // _extensions.insert(0, extension);
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to request extension: $e');
      return false;
    }
  }

  // Approve extension
  Future<bool> approveExtension(String extensionId) async {
    return await _updateExtensionStatus(extensionId, 'approved');
  }

  // Reject extension
  Future<bool> rejectExtension(String extensionId, String reason) async {
    _clearError();

    try {
      bool success = true;

      if (success) {
        final index = _extensions.indexWhere((ext) => ext.id == extensionId);
        if (index != -1) {
          _extensions[index] = _extensions[index].copyWith(status: 'rejected');
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to reject extension: $e');
      return false;
    }
  }

  // Pay fine
  Future<bool> payFine(String fineId, String paymentMethod) async {
    _clearError();

    try {
      bool success = true;

      if (success) {
        final index = _fines.indexWhere((fine) => fine.id == fineId);
        if (index != -1) {
          _fines[index] = _fines[index].copyWith(status: 'paid');
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to pay fine: $e');
      return false;
    }
  }

  // Waive fine
  Future<bool> waiveFine(String fineId, String reason) async {
    _clearError();

    try {
      bool success = true;

      if (success) {
        final index = _fines.indexWhere((fine) => fine.id == fineId);
        if (index != -1) {
          _fines[index] = _fines[index].copyWith(status: 'waived');
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to waive fine: $e');
      return false;
    }
  }

  // Get active borrowings
  List<BorrowRequest> getActiveBorrowings() {
    return _borrowRequests
        .where((req) => req.status == 'approved' && req.returnDate == null)
        .toList();
  }

  // Get overdue borrowings
  List<BorrowRequest> getOverdueBorrowings() {
    return _borrowRequests.where((req) => req.isOverdue).toList();
  }

  // Get pending requests
  List<BorrowRequest> getPendingRequests() {
    return _borrowRequests.where((req) => req.status == 'pending').toList();
  }

  // Get user borrowings
  List<BorrowRequest> getUserBorrowings(String userId) {
    return _borrowRequests.where((req) => req.userId == userId).toList();
  }

  // Get pending extensions
  List<BorrowExtension> getPendingExtensions() {
    return _extensions.where((ext) => ext.status == 'pending').toList();
  }

  // Get unpaid fines
  List<BorrowFine> getUnpaidFines() {
    return _fines.where((fine) => fine.status == 'unpaid').toList();
  }

  // Refresh all data
  Future<void> refresh() async {
    await loadBorrowingData();
  }

  // Helper methods
  Future<bool> _updateBorrowRequestStatus(
    String requestId,
    String status,
  ) async {
    _clearError();

    try {
      bool success = true;

      if (success) {
        final index = _borrowRequests.indexWhere(
          (req) => req.id.toString() == requestId,
        );
        if (index != -1) {
          _borrowRequests[index] = _borrowRequests[index].copyWith(
            status: status,
          );

          if (status == 'approved') {
            _activeBorrowings++;
            _pendingRequests--;
          } else if (status == 'returned') {
            _activeBorrowings--;
          }

          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to update borrow request status: $e');
      return false;
    }
  }

  Future<bool> _updateExtensionStatus(String extensionId, String status) async {
    _clearError();

    try {
      bool success = true;

      if (success) {
        final index = _extensions.indexWhere((ext) => ext.id == extensionId);
        if (index != -1) {
          _extensions[index] = _extensions[index].copyWith(status: status);
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to update extension status: $e');
      return false;
    }
  }

  // Update fine status
  Future<bool> updateFineStatus(String fineId, String status) async {
    _setLoading(true);
    _clearError();

    try {
      bool success = true; // Placeholder

      if (success) {
        final index = _fines.indexWhere((fine) => fine.id == fineId);
        if (index != -1) {
          _fines[index] = _fines[index].copyWith(status: status);
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to update fine status: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Confirm book return
  Future<bool> confirmBookReturn(String borrowId) async {
    _setLoading(true);
    _clearError();

    try {
      bool success =
          true; // Placeholder since confirmBookReturn doesn't exist in BorrowService

      if (success) {
        // Update the borrow request status to returned
        final index = _borrowRequests.indexWhere(
          (request) => request.id.toString() == borrowId,
        );
        if (index != -1) {
          _borrowRequests[index] = _borrowRequests[index].copyWith(
            status: 'returned',
            returnDate: DateTime.now(),
          );
          notifyListeners();
        }
      }

      return success;
    } catch (e) {
      _setError('Failed to confirm book return: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Clear error method
  void clearError() {
    _clearError();
  }

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

  // Clear all data
  void clear() {
    _borrowRequests.clear();
    _extensions.clear();
    _fines.clear();
    _totalBorrowings = 0;
    _activeBorrowings = 0;
    _overdueBorrowings = 0;
    _pendingRequests = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // Update the API service with a new token
  void setToken(String? token) {
    debugPrint(
      'DEBUG: BorrowingProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    debugPrint('DEBUG: BorrowingProvider token length: ${token?.length ?? 0}');
    if (token != null && token.isNotEmpty) {
      _borrowService.setToken(token);
      debugPrint('DEBUG: BorrowingProvider token set successfully');
      debugPrint('DEBUG: BorrowingProvider - Token passed to BorrowService');
    } else {
      debugPrint('DEBUG: BorrowingProvider token is null or empty');
    }
  }
}
