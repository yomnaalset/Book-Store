import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../models/library.dart';
import '../../services/manager_api_service.dart';

class LibraryProvider extends ChangeNotifier {
  ManagerApiService _apiService;

  LibraryProvider(this._apiService);

  // State
  Library? _library;
  bool _isLoading = false;
  String? _error;

  // Getters
  Library? get library => _library;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated =>
      _apiService.getAuthToken?.call().isNotEmpty ?? false;

  // Load library data
  Future<void> getLibrary() async {
    _setLoading(true);
    _error = null;

    try {
      if (kDebugMode) {
        debugPrint('LibraryProvider: Loading library data...');
      }

      // Check if we have a valid token before making the API call
      final token = _apiService.getAuthToken?.call();
      if (kDebugMode) {
        debugPrint(
          'LibraryProvider: Token check - token: ${token != null ? 'Present (${token.length} chars)' : 'Null'}',
        );
      }

      if (token == null || token.isEmpty) {
        throw Exception('Authentication required. Please log in first.');
      }

      _library = await _apiService.getLibrary();
      if (kDebugMode) {
        debugPrint('LibraryProvider: Library data loaded successfully');
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LibraryProvider: Error loading library: $e');
      }
      _error = e.toString();
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  // Update library
  Future<bool> updateLibrary(
    Library library, {
    File? logoFile,
    Uint8List? logoBytes,
    bool removeLogo = false,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final updatedLibrary = await _apiService.updateLibrary(
        library,
        logoFile: logoFile,
        logoBytes: logoBytes,
        removeLogo: removeLogo,
      );
      _library = updatedLibrary;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Create library
  Future<bool> createLibrary(
    Library library, {
    File? logoFile,
    Uint8List? logoBytes,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final createdLibrary = await _apiService.createLibrary(
        library,
        logoFile: logoFile,
        logoBytes: logoBytes,
      );
      _library = createdLibrary;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete library
  Future<bool> deleteLibrary() async {
    if (_library == null) return false;

    _setLoading(true);
    _error = null;

    try {
      final success = await _apiService.deleteLibrary();
      if (success) {
        _library = null;
      }
      notifyListeners();
      return success;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void reset() {
    _library = null;
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  // Update the API service with a new token
  void setToken(String? token) {
    if (kDebugMode) {
      debugPrint(
        'LibraryProvider: Setting token: ${token != null ? 'Present' : 'Null'}',
      );
    }
    if (token != null && token.isNotEmpty) {
      // Create a new API service instance with the updated token
      _apiService = ManagerApiService(
        baseUrl: _apiService.baseUrl,
        headers: _apiService.headers,
        getAuthToken: () => token,
      );
      if (kDebugMode) {
        debugPrint('LibraryProvider: API service updated with new token');
      }
    }
  }
}
