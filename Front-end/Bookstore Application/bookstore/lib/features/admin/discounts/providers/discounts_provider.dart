import 'package:flutter/widgets.dart';
import '../../models/discount.dart';
import '../../models/book_discount.dart';
import '../../services/manager_api_service.dart';

class DiscountsProvider with ChangeNotifier {
  final ManagerApiService _apiService;
  List<Discount> _discounts = [];
  List<BookDiscount> _bookDiscounts = [];
  bool _isLoading = false;
  String? _error;
  int _totalItems = 0;
  int _currentPage = 1;
  int _itemsPerPage = 10;
  String? _searchQuery;

  DiscountsProvider(this._apiService);

  List<Discount> get discounts => _discounts;
  List<BookDiscount> get bookDiscounts => _bookDiscounts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalItems => _totalItems;
  int get currentPage => _currentPage;
  int get itemsPerPage => _itemsPerPage;
  int get totalPages => (_totalItems / _itemsPerPage).ceil();

  Future<void> getDiscounts({
    int? page,
    int? limit,
    String? search,
    bool? isActive,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (page != null) _currentPage = page;
      if (limit != null) _itemsPerPage = limit;
      if (search != null) _searchQuery = search;

      final response = await _apiService.fetchDiscounts(
        page: _currentPage,
        limit: _itemsPerPage,
        search: _searchQuery,
        isActive: isActive,
      );

      _discounts = response.results;
      _totalItems = response.totalItems;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<Discount> getDiscountById(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final discount = await _apiService.getDiscount(id);
      _isLoading = false;
      notifyListeners();
      return discount;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createDiscount(Discount discount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.createDiscount(discount);
      await getDiscounts(); // Refresh the list
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateDiscount(Discount discount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.updateDiscount(discount);

      // Update the local list
      final index = _discounts.indexWhere((d) => d.id == discount.id);
      if (index != -1) {
        _discounts[index] = discount;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteDiscount(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteDiscount(id);

      // Remove from local list
      _discounts.removeWhere((discount) => discount.id == id.toString());
      _totalItems--;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> toggleDiscountStatus(Discount discount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedDiscount = discount.copyWith(isActive: !discount.isActive);
      await _apiService.updateDiscount(updatedDiscount);

      // Update the local list
      final index = _discounts.indexWhere((d) => d.id == discount.id);
      if (index != -1) {
        _discounts[index] = updatedDiscount;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  void setItemsPerPage(int value) {
    _itemsPerPage = value;
    _currentPage = 1; // Reset to first page when changing items per page
    // Use WidgetsBinding to defer the API call until after the current build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getDiscounts();
    });
  }

  void setCurrentPage(int value) {
    if (value > 0 && value <= totalPages) {
      _currentPage = value;
      // Use WidgetsBinding to defer the API call until after the current build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        getDiscounts();
      });
    }
  }

  void setSearchQuery(String? query) {
    _searchQuery = query;
    _currentPage = 1; // Reset to first page when searching
    // Use WidgetsBinding to defer the API call until after the current build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getDiscounts();
    });
  }

  void clearFilters() {
    _searchQuery = null;
    _currentPage = 1;
    // Use WidgetsBinding to defer the API call until after the current build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getDiscounts();
    });
  }

  // Update the API service with a new token
  void setToken(String? token) {
    debugPrint(
      'DEBUG: DiscountsProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    if (token != null && token.isNotEmpty) {
      // Set the token directly on the existing API service
      _apiService.setToken(token);
      debugPrint('DEBUG: DiscountsProvider token set successfully');
    } else {
      debugPrint('DEBUG: DiscountsProvider token is null or empty');
    }
  }

  // Check if provider has a valid token
  bool get hasValidToken => _apiService.isAuthenticated;

  // Book Discount Methods
  Future<void> getBookDiscounts({
    int? page,
    int? limit,
    String? search,
    bool? isActive,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (page != null) _currentPage = page;
      if (limit != null) _itemsPerPage = limit;
      if (search != null) _searchQuery = search;

      final response = await _apiService.getBookDiscounts(
        page: _currentPage,
        limit: _itemsPerPage,
        search: _searchQuery,
        isActive: isActive,
      );

      _bookDiscounts = response.allDiscounts;
      _totalItems = response.totalCount;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<BookDiscount> getBookDiscountById(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bookDiscount = await _apiService.getBookDiscount(id);
      _isLoading = false;
      notifyListeners();
      return bookDiscount;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createBookDiscount(BookDiscount bookDiscount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.createBookDiscount(bookDiscount);
      await getBookDiscounts(); // Refresh the list
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateBookDiscount(BookDiscount bookDiscount) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.updateBookDiscount(bookDiscount);

      // Update the local list
      final index = _bookDiscounts.indexWhere((d) => d.id == bookDiscount.id);
      if (index != -1) {
        _bookDiscounts[index] = bookDiscount;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBookDiscount(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteBookDiscount(id);

      // Remove from local list
      _bookDiscounts.removeWhere(
        (bookDiscount) => bookDiscount.id == id.toString(),
      );
      _totalItems--;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<List<AvailableBook>> getAvailableBooks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final books = await _apiService.getAvailableBooks();
      _isLoading = false;
      notifyListeners();
      return books;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}
