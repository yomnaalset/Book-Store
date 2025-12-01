import 'package:flutter/foundation.dart';
import '../models/ad.dart';
import '../services/ads_service.dart';

class AdsProvider with ChangeNotifier {
  final AdsService _apiService;
  List<Ad> _ads = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalItems = 0;
  int _itemsPerPage = 10;

  AdsProvider(this._apiService);

  List<Ad> get ads => _ads;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalPages => _totalPages;
  int get totalItems => _totalItems;
  int get itemsPerPage => _itemsPerPage;

  // Get all ads
  Future<void> getAds({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
    String? adType,
    String? token,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _apiService.getAdsWithPagination(
        page: page,
        limit: limit,
        search: search,
        status: status,
        adType: adType,
        token: token,
      );

      final List<Ad> ads = result['ads'] as List<Ad>;
      final int totalCount = result['totalCount'] as int;

      debugPrint(
        'DEBUG: AdsProvider received ${ads.length} ads out of $totalCount total',
      );
      _ads = ads;
      _currentPage = page;
      _itemsPerPage = limit;
      _totalItems = totalCount;
      _totalPages = (totalCount / limit).ceil();
      debugPrint(
        'DEBUG: AdsProvider updated _ads list with ${_ads.length} items, total: $_totalItems, pages: $_totalPages',
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Load ads (alias for getAds for consistency)
  Future<void> loadAds({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
    String? adType,
    String? token,
  }) async {
    debugPrint('DEBUG: AdsProvider.loadAds called with:');
    debugPrint('  - page: $page');
    debugPrint('  - limit: $limit');
    debugPrint('  - search: $search');
    debugPrint('  - status: $status');
    debugPrint('  - adType: $adType');
    debugPrint('  - token: ${token != null ? 'present' : 'null'}');

    return getAds(
      page: page,
      limit: limit,
      search: search,
      status: status,
      adType: adType,
      token: token,
    );
  }

  // Get ad by ID
  Future<Ad?> getAdById(int id, {String? token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final ad = await _apiService.getAd(id, token: token);
      _isLoading = false;
      notifyListeners();
      return ad;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Create new ad
  Future<Ad> createAd(Ad adData, {String? token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newAd = await _apiService.createAd(
        adData.toJson(includeId: false),
        token: token,
      );
      _ads.add(newAd);
      _totalItems++;
      _isLoading = false;
      notifyListeners();
      return newAd;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Update ad
  Future<Ad> updateAd(Ad adData, {String? token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedAd = await _apiService.updateAd(
        adData.id,
        adData.toJson(includeId: true),
        token: token,
      );
      final index = _ads.indexWhere((a) => a.id == adData.id);
      if (index != -1) {
        _ads[index] = updatedAd;
      }
      _isLoading = false;
      notifyListeners();
      return updatedAd;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Delete ad
  Future<void> deleteAd(int id, {String? token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.deleteAd(id, token: token);
      _ads.removeWhere((a) => a.id == id);
      _totalItems--;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Publish ad
  Future<void> publishAd(int id, {String? token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.publishAd(id, token: token);

      // Update ad status in the list
      final index = _ads.indexWhere((a) => a.id == id);
      if (index != -1) {
        _ads[index] = _ads[index].copyWith(status: Ad.statusPublished);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Unpublish ad
  Future<void> unpublishAd(int id, {String? token}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.unpublishAd(id, token: token);

      // Update ad status in the list
      final index = _ads.indexWhere((a) => a.id == id);
      if (index != -1) {
        _ads[index] = _ads[index].copyWith(status: Ad.statusUnpublished);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Reset pagination
  void resetPagination() {
    _currentPage = 1;
    _totalPages = 1;
    _totalItems = 0;
    notifyListeners();
  }

  // Get available discount codes for advertisement creation
  Future<List<Map<String, dynamic>>> getAvailableDiscountCodes({
    String? token,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final discountCodes = await _apiService.getAvailableDiscountCodes(
        token: token,
      );
      _isLoading = false;
      notifyListeners();
      return discountCodes;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  // Update the API service with a new token
  void setToken(String? token) {
    debugPrint(
      'DEBUG: AdsProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    if (token != null && token.isNotEmpty) {
      // Set the token directly on the existing API service
      _apiService.setToken(token);
      debugPrint('DEBUG: AdsProvider token set successfully');
    } else {
      debugPrint('DEBUG: AdsProvider token is null or empty');
    }
  }
}
