import 'package:flutter/foundation.dart';
import '../models/category.dart' as app_category;
import '../services/manager_api_service.dart';

class CategoriesProvider with ChangeNotifier {
  final ManagerApiService _apiService;

  List<app_category.Category> _categories = [];
  bool _isLoading = false;
  String? _error;

  // Pagination
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  CategoriesProvider(this._apiService);

  // Getters
  List<app_category.Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  // Get categories
  Future<void> getCategories({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      debugPrint(
        'DEBUG: CategoriesProvider - Loading categories, page: $page, limit: $limit, search: $search',
      );
      debugPrint(
        'DEBUG: CategoriesProvider - Current token status: ${_apiService.getAuthToken?.call().isNotEmpty ?? false}',
      );
      final categories = await _apiService.getCategories(
        page: page,
        limit: limit,
        search: search,
      );

      debugPrint(
        'DEBUG: CategoriesProvider - Loaded ${categories.length} categories from API',
      );
      _categories = categories;
      _currentPage = page;
      _totalPages = 1; // API doesn't return pagination info
      _totalItems = categories.length;
      _itemsPerPage = limit;
      debugPrint('DEBUG: Categories list updated, notifying listeners');

      _setLoading(false);
    } catch (e) {
      debugPrint('DEBUG: Error loading categories: $e');
      _setError('Failed to load categories: $e');
      _setLoading(false);
    }
  }

  // Create category
  Future<bool> createCategory({
    required String name,
    required String description,
    required bool isActive,
  }) async {
    _clearError();

    try {
      debugPrint(
        'DEBUG: CategoriesProvider - Creating category: name=$name, description=$description, isActive=$isActive',
      );
      debugPrint(
        'DEBUG: CategoriesProvider - Current token status: ${_apiService.getAuthToken?.call().isNotEmpty ?? false}',
      );
      final category = app_category.Category(
        id: '0', // Will be set by the API
        name: name,
        description: description,
        isActive: isActive,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdCategory = await _apiService.createCategory(category);
      debugPrint(
        'DEBUG: CategoriesProvider - Category created successfully: ${createdCategory.toJson()}',
      );

      _categories.insert(0, createdCategory);
      notifyListeners();
      debugPrint(
        'DEBUG: CategoriesProvider - Category added to local list, total items: ${_categories.length}',
      );
      return true;
    } catch (e) {
      _setError('Failed to create category: $e');
      return false;
    }
  }

  // Update category
  Future<bool> updateCategory({
    required int id,
    required String name,
    required String description,
    required bool isActive,
  }) async {
    _clearError();

    try {
      debugPrint('DEBUG: Updating category with ID: $id');
      debugPrint(
        'DEBUG: Category data - name: $name, description: $description, isActive: $isActive',
      );

      final existingCategory = _categories.firstWhere(
        (c) => c.id == id.toString(),
      );
      debugPrint(
        'DEBUG: Found existing category: ${existingCategory.toJson()}',
      );

      final updatedCategory = app_category.Category(
        id: id.toString(),
        name: name,
        description: description,
        isActive: isActive,
        createdAt: existingCategory.createdAt,
        updatedAt: DateTime.now(),
      );

      debugPrint('DEBUG: Sending to API: ${updatedCategory.toJson()}');

      // Get the updated category from the API response
      final result = await _apiService.updateCategory(updatedCategory);

      debugPrint('DEBUG: API returned updated category: ${result.toJson()}');

      // Update the local list with the API response data
      final index = _categories.indexWhere((c) => c.id == id.toString());
      if (index != -1) {
        debugPrint(
          'DEBUG: Found category at index $index, updating local list',
        );
        _categories[index] =
            result; // Use the API response, not the local object
        notifyListeners();
        debugPrint('DEBUG: Local list updated, notifying listeners');
      } else {
        debugPrint('DEBUG: Category not found in local list, index: $index');
      }

      return true;
    } catch (e) {
      debugPrint('DEBUG: Error updating category: $e');
      _setError('Failed to update category: $e');
      return false;
    }
  }

  // Delete category
  Future<bool> deleteCategory(int id) async {
    _clearError();

    try {
      await _apiService.deleteCategory(id);

      _categories.removeWhere((c) => c.id == id.toString());
      notifyListeners();
      return true;
    } catch (e) {
      _setError('Failed to delete category: $e');
      return false;
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

  // Clear data
  void clear() {
    _categories.clear();
    _currentPage = 1;
    _totalPages = 1;
    _totalItems = 0;
    _error = null;
    _isLoading = false;
    notifyListeners();
  }

  // Update the API service with a new token
  void setToken(String? token) {
    debugPrint(
      'DEBUG: CategoriesProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    if (token != null && token.isNotEmpty) {
      // Set the token directly on the existing API service
      _apiService.setToken(token);
      debugPrint('DEBUG: CategoriesProvider token set successfully');
    } else {
      debugPrint('DEBUG: CategoriesProvider token is null or empty');
    }
  }
}

// Response models for API calls
class CategoriesResponse {
  final List<app_category.Category> results;
  final int totalPages;
  final int totalItems;

  CategoriesResponse({
    required this.results,
    required this.totalPages,
    required this.totalItems,
  });
}
