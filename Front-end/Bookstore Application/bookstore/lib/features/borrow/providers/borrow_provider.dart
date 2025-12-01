import 'package:flutter/foundation.dart';
import '../models/borrow_request.dart';
import '../models/borrow_extension.dart';
import '../models/borrow_fine.dart';
import '../services/borrow_service.dart';

class BorrowProvider with ChangeNotifier {
  final BorrowService _borrowService;

  List<BorrowRequest> _borrowRequests = [];
  List<BorrowRequest> _activeBorrows = [];
  List<BorrowExtension> _borrowExtensions = [];
  List<BorrowFine> _borrowFines = [];
  bool _isLoading = false;
  String? _errorMessage;

  BorrowProvider(this._borrowService);

  void setToken(String? token) {
    if (token != null) {
      _borrowService.setToken(token);
    }
  }

  // Getters
  List<BorrowRequest> get borrowRequests => _borrowRequests;
  List<BorrowRequest> get activeBorrows => _activeBorrows;
  List<BorrowExtension> get borrowExtensions => _borrowExtensions;
  List<BorrowFine> get borrowFines => _borrowFines;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Get overdue requests
  List<BorrowRequest> get overdueRequests {
    return _borrowRequests
        .where((request) => request.dueDate?.isBefore(DateTime.now()) ?? false)
        .toList();
  }

  // Get pending requests
  List<BorrowRequest> get pendingRequests {
    return _borrowRequests
        .where(
          (request) =>
              request.status.toLowerCase() == 'pending' ||
              request.status.toLowerCase() == 'approved',
        )
        .toList();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  // Request to borrow a book
  Future<bool> requestBorrow({
    required String bookId,
    required int borrowPeriodDays,
    required String deliveryAddress,
    String? notes,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final request = await _borrowService.requestBorrow(
        bookId: bookId,
        durationDays: borrowPeriodDays,
        deliveryAddress: deliveryAddress,
        notes: notes,
      );

      if (request != null) {
        _borrowRequests.insert(0, request);
        _setLoading(false);
        return true;
      } else {
        _setError('Failed to submit borrow request');
        _setLoading(false);
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('=== BORROW PROVIDER ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Load borrow history
  Future<void> loadBorrowHistory() async {
    _setLoading(true);
    _clearError();

    try {
      final borrowings = await _borrowService.getCustomerBorrowings();
      _borrowRequests = borrowings;
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load borrow history: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Get specific borrow request
  Future<BorrowRequest?> getBorrowRequest(String requestId) async {
    try {
      return await _borrowService.getBorrowRequest(requestId);
    } catch (e) {
      _setError('Failed to load borrow request: ${e.toString()}');
      return null;
    }
  }

  // Return a borrowed book
  Future<bool> returnBook(String requestId) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _borrowService.returnBook(requestId);

      if (success) {
        // Update local state
        final index = _borrowRequests.indexWhere(
          (r) => r.id.toString() == requestId,
        );
        if (index != -1) {
          _borrowRequests[index] = _borrowRequests[index].copyWith(
            status: 'returned',
            finalReturnDate: DateTime.now(),
          );
        }
        _setLoading(false);
        return true;
      } else {
        _setError('Failed to return book');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Renew a borrowed book
  Future<bool> renewBook(String requestId, int additionalDays) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _borrowService.renewBook(requestId);

      if (success) {
        // Update local state
        final index = _borrowRequests.indexWhere(
          (r) => r.id.toString() == requestId,
        );
        if (index != -1) {
          final currentRequest = _borrowRequests[index];
          final newDueDate =
              currentRequest.dueDate?.add(Duration(days: additionalDays)) ??
              DateTime.now().add(Duration(days: additionalDays));
          _borrowRequests[index] = currentRequest.copyWith(
            dueDate: newDueDate,
            durationDays:
                newDueDate.difference(currentRequest.requestDate).inDays +
                additionalDays,
          );
        }
        _setLoading(false);
        return true;
      } else {
        _setError('Failed to renew book');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Cancel a pending borrow request
  Future<bool> cancelRequest(String requestId) async {
    _setLoading(true);
    _clearError();

    try {
      final success = await _borrowService.cancelRequest(requestId);

      if (success) {
        // Remove from local state
        _borrowRequests.removeWhere((r) => r.id.toString() == requestId);
        _setLoading(false);
        return true;
      } else {
        _setError('Failed to cancel request');
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Check if user can borrow a specific book
  bool canBorrowBook(String bookId) {
    // Check if user already has a pending or active borrow for this book
    return !_borrowRequests.any(
      (request) =>
          request.book?.id.toString() == bookId &&
          (request.status.toLowerCase() == 'pending' ||
              request.status.toLowerCase() == 'approved' ||
              request.status.toLowerCase() == 'active'),
    );
  }

  // Get borrow request for a specific book
  BorrowRequest? getBorrowRequestForBook(String bookId) {
    try {
      return _borrowRequests.firstWhere(
        (request) =>
            request.book?.id.toString() == bookId &&
            (request.status.toLowerCase() == 'pending' ||
                request.status.toLowerCase() == 'approved' ||
                request.status.toLowerCase() == 'active'),
      );
    } catch (e) {
      return null;
    }
  }

  // Load active borrows
  Future<void> loadActiveBorrows() async {
    _setLoading(true);
    _clearError();

    try {
      _activeBorrows = [];
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load active borrows: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Load borrow extensions
  Future<void> loadBorrowExtensions() async {
    _setLoading(true);
    _clearError();

    try {
      _borrowExtensions = [];
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load borrow extensions: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Load borrow fines
  Future<void> loadBorrowFines() async {
    _setLoading(true);
    _clearError();

    try {
      _borrowFines = [];
      _setLoading(false);
    } catch (e) {
      _setError('Failed to load borrow fines: ${e.toString()}');
      _setLoading(false);
    }
  }

  // Confirm payment for a borrow request
  Future<bool> confirmPayment({
    required int requestId,
    required String paymentMethod,
    String? cardNumber,
    String? cardholderName,
    int? expiryMonth,
    int? expiryYear,
    String? cvv,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final request = await _borrowService.confirmPayment(
        requestId: requestId,
        paymentMethod: paymentMethod,
        cardNumber: cardNumber,
        cardholderName: cardholderName,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        cvv: cvv,
      );

      if (request != null) {
        // Update local state
        final index = _borrowRequests.indexWhere(
          (r) => r.id == requestId,
        );
        if (index != -1) {
          _borrowRequests[index] = request;
        } else {
          _borrowRequests.insert(0, request);
        }
        _setLoading(false);
        return true;
      } else {
        _setError('Failed to confirm payment');
        _setLoading(false);
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('=== CONFIRM PAYMENT PROVIDER ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      _setError('Network error: ${e.toString()}');
      _setLoading(false);
      return false;
    }
  }

  // Clear all data (for logout)
  void clear() {
    _borrowRequests.clear();
    _activeBorrows.clear();
    _borrowExtensions.clear();
    _borrowFines.clear();
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }
}
