import 'package:flutter/foundation.dart';
import '../../models/library.dart';

class LibraryProvider with ChangeNotifier {
  Library? _library;
  bool _isLoading = false;
  String? _error;

  // Getters
  Library? get library => _library;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Methods
  Future<void> loadLibrary(String libraryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));
      _library = null; // Placeholder
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLibrary(Library library) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));
      _library = library;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createLibrary(Library library) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));
      _library = library;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteLibrary(String libraryId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(seconds: 1));
      _library = null;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> getLibrary(String libraryId) async {
    await loadLibrary(libraryId);
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
