import 'package:flutter/foundation.dart';
import '../../models/ad.dart';
import '../../services/manager_api_service.dart';

class AdsProvider extends ChangeNotifier {
  final ManagerApiService _apiService;

  AdsProvider(this._apiService);

  // State
  List<Ad> _ads = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  // Getters
  List<Ad> get ads => _ads;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  // Token management
  void setToken(String? token) {
    debugPrint(
      'DEBUG: AdsProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    if (token != null && token.isNotEmpty) {
      _apiService.setToken(token);
      debugPrint('DEBUG: AdsProvider token set successfully');
    } else {
      debugPrint('DEBUG: AdsProvider token is null or empty');
    }
  }

  // Methods
  Future<void> loadAds({int page = 1, String? search, String? status}) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final ads = await _apiService.getAds(
        page: page,
        search: search,
        status: status,
      );
      _ads = ads;
      _currentPage = page;
      // Note: The API service doesn't return pagination info, so we'll use defaults
      _totalPages = 1;
      _totalItems = ads.length;
      _itemsPerPage = 10;
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading ads: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<Ad?> createAd(Ad ad) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final newAd = await _apiService.createAd(ad);
      _ads.insert(0, newAd);
      _totalItems++;
      notifyListeners();
      return newAd;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Ad?> updateAd(Ad ad) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      final updatedAd = await _apiService.updateAd(ad);
      final index = _ads.indexWhere((a) => a.id == ad.id);
      if (index != -1) {
        _ads[index] = updatedAd;
        notifyListeners();
      }
      return updatedAd;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteAd(int id) async {
    _setLoading(true);
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteAd(id);
      _ads.removeWhere((ad) => ad.id == id.toString());
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
}
