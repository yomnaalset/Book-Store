import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show debugPrint;
import '../models/ad.dart';
import '../../../../core/services/api_client.dart';

class AdsService {
  final String baseUrl;
  final Map<String, String> headers;
  String? _cachedToken;

  AdsService({
    required this.baseUrl,
    this.headers = const {'Content-Type': 'application/json'},
  });

  Map<String, String> get _headers => {
    ...headers,
    'Accept': 'application/json',
    'Content-Type': 'application/json', // Explicitly ensure Content-Type is set
  };

  Map<String, String> _headersWithAuth(String token) => {
    ..._headers,
    'Authorization': 'Bearer $token',
  };

  // Set the authentication token directly
  void setToken(String? token) {
    _cachedToken = token;
    debugPrint(
      'DEBUG: AdsService setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
  }

  // Check if we have a valid token
  bool get isAuthenticated => _cachedToken != null && _cachedToken!.isNotEmpty;

  // Get all ads with pagination and filtering
  Future<List<Ad>> getAds({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
    String? adType,
    String? token,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/ads/');

      Map<String, String> queryParams = {
        'page': page.toString(),
        'page_size': limit.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (adType != null && adType.isNotEmpty) {
        queryParams['ad_type'] = adType;
      }

      uri = uri.replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: _cachedToken != null
            ? _headersWithAuth(_cachedToken!)
            : _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('DEBUG: Ads API Response: $data');

        // Handle paginated response from Django REST framework
        List<dynamic> adsData;
        if (data is Map && data.containsKey('results')) {
          // Paginated response: {'count': 25, 'results': [ad1, ad2, ...]}
          adsData = data['results'] as List<dynamic>;
          debugPrint(
            'DEBUG: Paginated response - Total count: ${data['count']}, Results: ${adsData.length}',
          );
        } else if (data is List) {
          // Direct array response: [ad1, ad2, ...]
          adsData = data;
          debugPrint(
            'DEBUG: Direct array response - Results: ${adsData.length}',
          );
        } else {
          // Fallback: treat as single item or empty
          adsData = data is List ? data : [];
          debugPrint('DEBUG: Fallback response - Results: ${adsData.length}');
        }

        debugPrint('DEBUG: Parsed ads data: $adsData');
        final List<Ad> ads = adsData.map((json) => Ad.fromJson(json)).toList();
        debugPrint('DEBUG: Converted ads: ${ads.length} ads');
        return ads;
      } else {
        throw Exception('Failed to load ads: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting ads: $e');
      rethrow;
    }
  }

  // Get ads with pagination metadata
  Future<Map<String, dynamic>> getAdsWithPagination({
    int page = 1,
    int limit = 10,
    String? search,
    String? status,
    String? adType,
    String? token,
  }) async {
    try {
      var uri = Uri.parse('$baseUrl/ads/');

      Map<String, String> queryParams = {
        'page': page.toString(),
        'page_size': limit.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      if (adType != null && adType.isNotEmpty) {
        queryParams['ad_type'] = adType;
      }

      uri = uri.replace(queryParameters: queryParams);

      debugPrint('DEBUG: AdsService.getAdsWithPagination - Final URL: $uri');
      debugPrint(
        'DEBUG: AdsService.getAdsWithPagination - Query params: $queryParams',
      );

      final response = await http.get(
        uri,
        headers: _cachedToken != null
            ? _headersWithAuth(_cachedToken!)
            : _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('DEBUG: Ads API Response with pagination: $data');

        // Handle paginated response from Django REST framework
        List<dynamic> adsData;
        int totalCount = 0;
        bool hasNext = false;
        bool hasPrevious = false;

        if (data is Map && data.containsKey('results')) {
          // Paginated response: {'count': 25, 'results': [ad1, ad2, ...], 'next': '...', 'previous': '...'}
          adsData = data['results'] as List<dynamic>;
          totalCount = data['count'] ?? 0;
          hasNext = data['next'] != null;
          hasPrevious = data['previous'] != null;
          debugPrint(
            'DEBUG: Paginated response - Total count: $totalCount, Results: ${adsData.length}, Has next: $hasNext, Has previous: $hasPrevious',
          );
        } else if (data is List) {
          // Direct array response: [ad1, ad2, ...]
          adsData = data;
          totalCount = data.length;
          debugPrint(
            'DEBUG: Direct array response - Results: ${adsData.length}',
          );
        } else {
          // Fallback: treat as single item or empty
          adsData = data is List ? data : [];
          totalCount = adsData.length;
          debugPrint('DEBUG: Fallback response - Results: ${adsData.length}');
        }

        debugPrint('DEBUG: Parsed ads data: $adsData');
        final List<Ad> ads = adsData.map((json) => Ad.fromJson(json)).toList();
        debugPrint('DEBUG: Converted ads: ${ads.length} ads');

        return {
          'ads': ads,
          'totalCount': totalCount,
          'hasNext': hasNext,
          'hasPrevious': hasPrevious,
          'currentPage': page,
          'pageSize': limit,
        };
      } else {
        throw Exception('Failed to load ads: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting ads with pagination: $e');
      rethrow;
    }
  }

  // Get ad by ID
  Future<Ad?> getAd(int id, {String? token}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/ads/$id/'),
        headers: _cachedToken != null
            ? _headersWithAuth(_cachedToken!)
            : _headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return Ad.fromJson(data);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load ad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting ad: $e');
      rethrow;
    }
  }

  // Get advertisement by ID (non-nullable version for details page)
  Future<Ad> getAdvertisementById(int id) async {
    try {
      debugPrint('DEBUG: Fetching advertisement details for ID: $id');
      final response = await http.get(
        Uri.parse('$baseUrl/ads/public/$id/'),
        headers: _headers,
      );

      debugPrint(
        'DEBUG: Advertisement details API Response Status: ${response.statusCode}',
      );
      debugPrint(
        'DEBUG: Advertisement details API Response Body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final ad = Ad.fromJson(data);
        debugPrint('DEBUG: Successfully loaded advertisement: ${ad.title}');
        return ad;
      } else if (response.statusCode == 404) {
        throw Exception('Advertisement not found');
      } else {
        throw Exception(
          'Failed to load advertisement details: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error getting advertisement details: $e');
      rethrow;
    }
  }

  // Create new ad
  Future<Ad> createAd(Map<String, dynamic> adData, {String? token}) async {
    try {
      debugPrint('DEBUG: Creating ad with data: $adData');

      final response = await ApiClient.post(
        '/ads/create/',
        body: adData,
        token: _cachedToken,
      );

      debugPrint('DEBUG: API Response Status: ${response.statusCode}');
      debugPrint('DEBUG: API Response Body: ${response.body}');

      if (response.statusCode == 201) {
        final data = ApiClient.handleResponse(response);
        return Ad.fromJson(data);
      } else {
        throw Exception(
          'Failed to create ad: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error creating ad: $e');
      rethrow;
    }
  }

  // Update ad
  Future<Ad> updateAd(
    int id,
    Map<String, dynamic> adData, {
    String? token,
  }) async {
    try {
      debugPrint('DEBUG: Updating ad $id with data: $adData');
      debugPrint('DEBUG: Request body JSON: ${json.encode(adData)}');

      final response = await ApiClient.put(
        '/ads/$id/update/',
        body: adData,
        token: _cachedToken,
      );

      debugPrint('DEBUG: Update response status: ${response.statusCode}');
      debugPrint('DEBUG: Update response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = ApiClient.handleResponse(response);
        debugPrint('DEBUG: Parsed response data: $data');
        return Ad.fromJson(data);
      } else {
        throw Exception(
          'Failed to update ad: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error updating ad: $e');
      rethrow;
    }
  }

  // Delete ad
  Future<void> deleteAd(int id, {String? token}) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/ads/$id/delete/'),
        headers: _cachedToken != null
            ? _headersWithAuth(_cachedToken!)
            : _headers,
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        throw Exception('Failed to delete ad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting ad: $e');
      rethrow;
    }
  }

  // Publish ad
  Future<void> publishAd(int id, {String? token}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ads/$id/publish/'),
        headers: _cachedToken != null
            ? _headersWithAuth(_cachedToken!)
            : _headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to publish ad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error publishing ad: $e');
      rethrow;
    }
  }

  // Unpublish ad
  Future<void> unpublishAd(int id, {String? token}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/ads/$id/unpublish/'),
        headers: _cachedToken != null
            ? _headersWithAuth(_cachedToken!)
            : _headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to unpublish ad: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error unpublishing ad: $e');
      rethrow;
    }
  }

  // Get public advertisements (no authentication required)
  Future<List<Ad>> getPublicAds({int limit = 10}) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/ads/public/',
      ).replace(queryParameters: {'limit': limit.toString()});

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('DEBUG: Public Ads API Response: $data');

        // Handle both paginated and direct array responses
        List<dynamic> adsData;
        if (data is List) {
          // Direct array response: [ad1, ad2, ...]
          adsData = data;
        } else if (data is Map && data.containsKey('results')) {
          // Paginated response: {'results': [ad1, ad2, ...]}
          adsData = data['results'] as List<dynamic>;
        } else {
          // Fallback: treat as single item or empty
          adsData = data is List ? data : [];
        }

        debugPrint('DEBUG: Parsed public ads data: $adsData');
        final List<Ad> ads = adsData.map((json) => Ad.fromJson(json)).toList();
        debugPrint('DEBUG: Converted public ads: ${ads.length} ads');
        return ads;
      } else {
        throw Exception('Failed to load public ads: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error getting public ads: $e');
      rethrow;
    }
  }

  // Get available discount codes for advertisement creation
  Future<List<Map<String, dynamic>>> getAvailableDiscountCodes({
    String? token,
  }) async {
    try {
      debugPrint('DEBUG: Fetching available discount codes');

      final response = await ApiClient.get(
        '/discounts/active/',
        token: _cachedToken,
      );

      debugPrint(
        'DEBUG: Discount codes API Response Status: ${response.statusCode}',
      );
      debugPrint('DEBUG: Discount codes API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = ApiClient.handleResponse(response);
        debugPrint('DEBUG: Discount codes data: $data');

        // Handle the new active codes endpoint response format
        List<dynamic> codesData;
        if (data is List) {
          // Direct array response: [code1, code2, ...]
          codesData = data;
        } else {
          // Fallback: treat as single item or empty
          codesData = data is List ? data : [];
        }

        // Format codes for dropdown
        final List<Map<String, dynamic>> availableCodes = codesData
            .map(
              (code) => {
                'id': code['id'],
                'code': code['code'],
                'discount_percentage': code['discount_percentage'],
                'expiration_date': code['expiration_date'],
              },
            )
            .toList();

        debugPrint('DEBUG: Available discount codes: ${availableCodes.length}');
        return availableCodes;
      } else {
        throw Exception(
          'Failed to load discount codes: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error getting discount codes: $e');
      rethrow;
    }
  }
}
