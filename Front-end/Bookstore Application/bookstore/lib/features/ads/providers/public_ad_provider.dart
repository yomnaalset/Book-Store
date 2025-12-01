import 'package:flutter/foundation.dart';
import '../models/public_ad.dart';
import '../services/public_ad_service.dart';

class PublicAdProvider extends ChangeNotifier {
  List<PublicAd> _ads = [];
  PublicAd? _selectedAd;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<PublicAd> get ads => _ads;
  PublicAd? get selectedAd => _selectedAd;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get active ads only
  List<PublicAd> get activeAds => _ads.where((ad) => ad.isVisible).toList();

  // Get ads by type
  List<PublicAd> get generalAds => _ads.where((ad) => ad.isGeneralAd).toList();
  List<PublicAd> get discountCodeAds =>
      _ads.where((ad) => ad.isDiscountCodeAd).toList();

  // Get ads ending soon (within 7 days)
  List<PublicAd> get adsEndingSoon {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));

    return _ads.where((ad) {
      return ad.isVisible &&
          ad.endDate.isAfter(now) &&
          ad.endDate.isBefore(sevenDaysFromNow);
    }).toList();
  }

  /// Load all public advertisements
  Future<void> loadAds() async {
    _setLoading(true);
    _clearError();

    try {
      _ads = await PublicAdService.getPublicAds();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load advertisements: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load active advertisements only
  Future<void> loadActiveAds() async {
    _setLoading(true);
    _clearError();

    try {
      _ads = await PublicAdService.getActiveAds();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load active advertisements: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load a specific advertisement by ID
  Future<void> loadAdById(int adId) async {
    _setLoading(true);
    _clearError();

    try {
      _selectedAd = await PublicAdService.getPublicAdById(adId);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load advertisement: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load advertisements by type
  Future<void> loadAdsByType(String adType) async {
    _setLoading(true);
    _clearError();

    try {
      _ads = await PublicAdService.getAdsByType(adType);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load advertisements by type: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load discount code advertisements
  Future<void> loadDiscountCodeAds() async {
    _setLoading(true);
    _clearError();

    try {
      _ads = await PublicAdService.getDiscountCodeAds();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load discount code advertisements: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Load general advertisements
  Future<void> loadGeneralAds() async {
    _setLoading(true);
    _clearError();

    try {
      _ads = await PublicAdService.getGeneralAds();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load general advertisements: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Set the selected advertisement
  void selectAd(PublicAd ad) {
    _selectedAd = ad;
    notifyListeners();
  }

  /// Clear the selected advertisement
  void clearSelectedAd() {
    _selectedAd = null;
    notifyListeners();
  }

  /// Refresh advertisements
  Future<void> refreshAds() async {
    await loadAds();
  }

  /// Clear all data
  void clearData() {
    _ads.clear();
    _selectedAd = null;
    _clearError();
    notifyListeners();
  }

  // Private helper methods
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
}
