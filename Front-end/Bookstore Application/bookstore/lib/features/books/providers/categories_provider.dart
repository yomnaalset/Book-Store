import 'package:flutter/foundation.dart' as prefix0;
import 'package:flutter/material.dart';
import '../../../../features/books/models/category.dart';
import '../../../../features/books/services/books_service.dart';

class CategoriesProvider with prefix0.ChangeNotifier {
  final BooksService _apiService;
  List<Category> _categories = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  CategoriesProvider(this._apiService);

  void setToken(String? token) {
    _apiService.setToken(token);
  }

  List<Category> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  Future<void> getCategories({
    int page = 1,
    int limit = 10,
    String? search,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('CategoriesProvider: Loading categories...');
      final result = await _apiService.getCategories(
        page: page,
        limit: limit,
        search: search,
      );
      debugPrint(
        'CategoriesProvider: Categories loaded: ${result.length} categories',
      );

      _categories = result;
      _currentPage = page;
      _itemsPerPage = limit;
      // In a real implementation, these values would come from the API response
      _totalItems = result.length;
      _totalPages = (result.length / limit).ceil();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('CategoriesProvider: Error loading categories: $e');
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Category> createCategory(Category category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newCategory = await _apiService.createCategory(category.toJson());
      if (newCategory != null) {
        _categories.add(newCategory);
        _isLoading = false;
        notifyListeners();
        return newCategory;
      } else {
        throw Exception('Failed to create category');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<Category> updateCategory(Category category) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedCategory = await _apiService.updateCategory(
        category.id.toString(),
        category.toJson(),
      );
      if (updatedCategory != null) {
        final index = _categories.indexWhere((c) => c.id == category.id);
        if (index != -1) {
          _categories[index] = updatedCategory;
        }
        _isLoading = false;
        notifyListeners();
        return updatedCategory;
      } else {
        throw Exception('Failed to update category');
      }
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteCategory(int id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteCategory(id.toString());
      _categories.removeWhere((c) => c.id == id);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
}
