import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/public_ad.dart';
import '../../../../core/services/api_config.dart';

class PublicAdService {
  static String get _baseUrl => ApiConfig.getAndroidEmulatorUrl();
  static const String _adsEndpoint = 'ads/public/';

  /// Fetch all public advertisements
  static Future<List<PublicAd>> getPublicAds() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_adsEndpoint'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = json.decode(response.body);
        return jsonData.map((json) => PublicAd.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load advertisements: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching advertisements: $e');
    }
  }

  /// Fetch a specific advertisement by ID
  static Future<PublicAd> getPublicAdById(int adId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_adsEndpoint$adId/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = json.decode(response.body);
        return PublicAd.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        throw Exception('Advertisement not found');
      } else {
        throw Exception('Failed to load advertisement: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching advertisement: $e');
    }
  }

  /// Get active advertisements only
  static Future<List<PublicAd>> getActiveAds() async {
    try {
      final allAds = await getPublicAds();
      return allAds.where((ad) => ad.isVisible).toList();
    } catch (e) {
      throw Exception('Error fetching active advertisements: $e');
    }
  }

  /// Get advertisements by type
  static Future<List<PublicAd>> getAdsByType(String adType) async {
    try {
      final allAds = await getPublicAds();
      return allAds.where((ad) => ad.adType == adType).toList();
    } catch (e) {
      throw Exception('Error fetching advertisements by type: $e');
    }
  }

  /// Get discount code advertisements
  static Future<List<PublicAd>> getDiscountCodeAds() async {
    try {
      return await getAdsByType(PublicAd.adTypeDiscountCode);
    } catch (e) {
      throw Exception('Error fetching discount code advertisements: $e');
    }
  }

  /// Get general advertisements
  static Future<List<PublicAd>> getGeneralAds() async {
    try {
      return await getAdsByType(PublicAd.adTypeGeneral);
    } catch (e) {
      throw Exception('Error fetching general advertisements: $e');
    }
  }
}
