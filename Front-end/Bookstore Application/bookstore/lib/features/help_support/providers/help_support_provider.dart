import 'package:flutter/foundation.dart';
import '../services/help_support_service.dart';
import '../models/help_support_models.dart';

class HelpSupportProvider extends ChangeNotifier {
  final HelpSupportService _helpSupportService;

  HelpSupportProvider({required HelpSupportService helpSupportService})
    : _helpSupportService = helpSupportService;

  // State variables
  bool _isLoading = false;
  String? _error;
  HelpSupportData? _helpSupportData;
  String? _authToken;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  HelpSupportData? get helpSupportData => _helpSupportData;
  List<FAQ> get faqs => _helpSupportData?.faqs ?? [];
  List<UserGuide> get userGuides => _helpSupportData?.userGuides ?? [];
  List<TroubleshootingGuide> get troubleshootingGuides =>
      _helpSupportData?.troubleshootingGuides ?? [];
  List<SupportContact> get supportContacts =>
      _helpSupportData?.supportContacts ?? [];

  // Set auth token
  void setAuthToken(String token) {
    _authToken = token;
  }

  // Clear auth token
  void clearAuthToken() {
    _authToken = null;
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Set error state
  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  // Clear error
  void _clearError() {
    _error = null;
  }

  // Load all help and support data
  Future<void> loadHelpSupportData({String? token}) async {
    if (token != null) {
      _authToken = token;
    }

    if (_authToken == null) {
      debugPrint('HelpSupportProvider: No auth token available');
      _setError('No authentication token available');
      return;
    }

    debugPrint('HelpSupportProvider: Loading help and support data...');
    _setLoading(true);
    _clearError();

    try {
      final response = await _helpSupportService.getAllHelpSupportData(
        _authToken!,
      );

      if (response['success'] == true && response['data'] != null) {
        _helpSupportData = HelpSupportData.fromJson(response['data']);
        debugPrint(
          'HelpSupportProvider: Help and support data loaded successfully',
        );
        debugPrint('HelpSupportProvider: FAQs: ${faqs.length}');
        debugPrint('HelpSupportProvider: User Guides: ${userGuides.length}');
        debugPrint(
          'HelpSupportProvider: Troubleshooting Guides: ${troubleshootingGuides.length}',
        );
        debugPrint(
          'HelpSupportProvider: Support Contacts: ${supportContacts.length}',
        );
      } else {
        throw Exception(
          response['message'] ?? 'Failed to load help and support data',
        );
      }
    } catch (e) {
      debugPrint(
        'HelpSupportProvider: Error loading help and support data: $e',
      );
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // Load FAQs by category
  Future<List<FAQ>> loadFAQs({String? category}) async {
    if (_authToken == null) {
      debugPrint('HelpSupportProvider: No auth token available for FAQs');
      return [];
    }

    try {
      final response = await _helpSupportService.getFAQs(
        category: category,
        token: _authToken!,
      );

      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((item) => FAQ.fromJson(item))
            .toList();
      } else {
        throw Exception(response['message'] ?? 'Failed to load FAQs');
      }
    } catch (e) {
      debugPrint('HelpSupportProvider: Error loading FAQs: $e');
      return [];
    }
  }

  // Load user guides by section
  Future<List<UserGuide>> loadUserGuides({String? section}) async {
    if (_authToken == null) {
      debugPrint(
        'HelpSupportProvider: No auth token available for user guides',
      );
      return [];
    }

    try {
      final response = await _helpSupportService.getUserGuides(
        section: section,
        token: _authToken!,
      );

      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((item) => UserGuide.fromJson(item))
            .toList();
      } else {
        throw Exception(response['message'] ?? 'Failed to load user guides');
      }
    } catch (e) {
      debugPrint('HelpSupportProvider: Error loading user guides: $e');
      return [];
    }
  }

  // Load troubleshooting guides by category
  Future<List<TroubleshootingGuide>> loadTroubleshootingGuides({
    String? category,
  }) async {
    if (_authToken == null) {
      debugPrint(
        'HelpSupportProvider: No auth token available for troubleshooting guides',
      );
      return [];
    }

    try {
      final response = await _helpSupportService.getTroubleshootingGuides(
        category: category,
        token: _authToken!,
      );

      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((item) => TroubleshootingGuide.fromJson(item))
            .toList();
      } else {
        throw Exception(
          response['message'] ?? 'Failed to load troubleshooting guides',
        );
      }
    } catch (e) {
      debugPrint(
        'HelpSupportProvider: Error loading troubleshooting guides: $e',
      );
      return [];
    }
  }

  // Load support contacts
  Future<List<SupportContact>> loadSupportContacts() async {
    if (_authToken == null) {
      debugPrint(
        'HelpSupportProvider: No auth token available for support contacts',
      );
      return [];
    }

    try {
      final response = await _helpSupportService.getSupportContacts(
        _authToken!,
      );

      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List)
            .map((item) => SupportContact.fromJson(item))
            .toList();
      } else {
        throw Exception(
          response['message'] ?? 'Failed to load support contacts',
        );
      }
    } catch (e) {
      debugPrint('HelpSupportProvider: Error loading support contacts: $e');
      return [];
    }
  }

  // Refresh data
  Future<void> refreshData({String? token}) async {
    await loadHelpSupportData(token: token);
  }

  // Clear data
  void clearData() {
    _helpSupportData = null;
    _error = null;
    notifyListeners();
  }
}
