import 'package:flutter/foundation.dart';
import '../../borrow/models/borrow_request.dart';
import '../../borrow/services/borrow_service.dart';

class DeliveryProvider extends ChangeNotifier {
  final BorrowService _borrowService = BorrowService();

  bool _isLoading = false;
  String? _errorMessage;

  List<BorrowRequest> _readyForDelivery = [];
  List<BorrowRequest> _myTasks = [];
  final List<BorrowRequest> _completedTasks = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<BorrowRequest> get readyForDelivery => _readyForDelivery;
  List<BorrowRequest> get myTasks => _myTasks;
  List<BorrowRequest> get completedTasks => _completedTasks;

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

  Future<void> loadReadyForDelivery() async {
    try {
      _setLoading(true);
      _setError(null);

      final requests = await _borrowService.getPendingRequests();
      _readyForDelivery = requests
          .where((r) => r.status == 'approved')
          .toList();
    } catch (e) {
      _setError('Failed to load ready for delivery: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMyTasks() async {
    try {
      _setLoading(true);
      _setError(null);

      final requests = await _borrowService.getAllBorrowings();
      _myTasks = requests
          .where(
            (r) =>
                r.status == 'pending_delivery' ||
                r.status == 'return_requested',
          )
          .toList();
    } catch (e) {
      _setError('Failed to load my tasks: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> pickupBook(int requestId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _borrowService.approveRequest(requestId);

      await loadReadyForDelivery();
      await loadMyTasks();

      return true;
    } catch (e) {
      _setError('Failed to pickup book: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> markDelivered(int requestId, String notes) async {
    try {
      _setLoading(true);
      _setError(null);

      // This would call a mark delivered API endpoint
      await Future.delayed(const Duration(seconds: 1)); // Placeholder

      await loadMyTasks();

      return true;
    } catch (e) {
      _setError('Failed to mark as delivered: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> collectForReturn(int requestId, String notes) async {
    try {
      _setLoading(true);
      _setError(null);

      // This would call a collect for return API endpoint
      await Future.delayed(const Duration(seconds: 1)); // Placeholder

      await loadMyTasks();

      return true;
    } catch (e) {
      _setError('Failed to collect for return: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
