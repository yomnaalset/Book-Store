import 'package:flutter/foundation.dart';
import '../../../admin/models/category.dart' as book_category;
import '../../services/manager_api_service.dart';

class CategoriesProvider extends ChangeNotifier {
  ManagerApiService _apiService;

  CategoriesProvider(this._apiService);

  // State
  List<book_category.Category> _categories = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  // Getters
  List<book_category.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  // Methods
  Future<void> loadCategories({int page = 1, String? search}) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final categories = await _apiService.getCategories(
        page: page,
        search: search,
      );
      _categories = categories;
      _currentPage = page;
      // Note: The API service doesn't return pagination info, so we'll use defaults
      _totalPages = 1;
      _totalItems = categories.length;
      _itemsPerPage = 10;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<book_category.Category?> createCategory(
    book_category.Category category,
  ) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final newCategory = await _apiService.createCategory(category);
      _categories.insert(0, newCategory);
      _totalItems++;
      notifyListeners();
      return newCategory;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<book_category.Category?> updateCategory(
    book_category.Category category,
  ) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final updatedCategory = await _apiService.updateCategory(category);
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = updatedCategory;
        notifyListeners();
      }
      return updatedCategory;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteCategory(int id) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteCategory(id);
      _categories.removeWhere((category) => category.id == id.toString());
      _totalItems--;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
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

  // Update the API service with a new token
  void setToken(String? token) {
    if (token != null && token.isNotEmpty) {
      // Create a new API service instance with the updated token
      _apiService = ManagerApiService(
        baseUrl: _apiService.baseUrl,
        headers: _apiService.headers,
        getAuthToken: () => token,
      );
    }
  }
}
