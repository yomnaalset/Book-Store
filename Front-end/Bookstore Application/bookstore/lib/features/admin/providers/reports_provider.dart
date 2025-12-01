import 'package:flutter/foundation.dart';
import '../models/dashboard_card.dart';
import '../services/manager_api_service.dart';

class ReportsProvider with ChangeNotifier {
  final ManagerApiService _apiService;

  final List<DashboardCard> _reportData = [];
  bool _isLoading = false;
  String? _error;

  // Report filters
  DateTime? _startDate;
  DateTime? _endDate;
  String? _reportType;
  String? _period; // 'daily', 'weekly', 'monthly', 'yearly'

  // Cached data
  Map<String, dynamic> _salesData = {};
  Map<String, dynamic> _userStats = {};
  Map<String, dynamic> _bookStats = {};
  Map<String, dynamic> _orderStats = {};
  Map<String, dynamic> _authorStats = {};
  Map<String, dynamic> _categoryStats = {};
  Map<String, dynamic> _ratingStats = {};
  Map<String, dynamic> _finesStats = {};
  Map<String, dynamic> _deliveryStats = {};
  Map<String, dynamic> _borrowingStats = {};

  ReportsProvider(this._apiService);

  // Getters
  List<DashboardCard> get reportData => _reportData;
  List<DashboardCard> get dashboardCards =>
      _reportData; // Alias for compatibility
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  String? get reportType => _reportType;
  String? get period => _period;
  Map<String, dynamic> get salesData => _salesData;
  Map<String, dynamic> get userStats => _userStats;
  Map<String, dynamic> get bookStats => _bookStats;
  Map<String, dynamic> get orderStats => _orderStats;
  Map<String, dynamic> get authorStats => _authorStats;
  Map<String, dynamic> get categoryStats => _categoryStats;
  Map<String, dynamic> get ratingStats => _ratingStats;
  Map<String, dynamic> get finesStats => _finesStats;
  Map<String, dynamic> get deliveryStats => _deliveryStats;
  Map<String, dynamic> get borrowingStats => _borrowingStats;

  // Load dashboard reports
  Future<void> loadDashboardReports() async {
    _setLoading(true);
    _clearError();

    try {
      // Use the unified dashboard API
      final cards = await _apiService.getDashboardStats();
      _reportData.clear();
      _reportData.addAll(cards);

      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load dashboard reports: $e');
      _setLoading(false);
    }
  }

  // Alias for compatibility with screen
  Future<void> getDashboardStats() async {
    _setLoading(true);
    _clearError();

    try {
      // Use the unified dashboard API
      final cards = await _apiService.getDashboardStats();
      _reportData.clear();
      _reportData.addAll(cards);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load dashboard stats: $e');
      _setLoading(false);
    }
  }

  // Load sales report
  Future<void> loadSalesReport({
    DateTime? startDate,
    DateTime? endDate,
    String? period,
  }) async {
    try {
      _salesData = await _apiService.getSalesReport(
        startDate: startDate ?? _startDate,
        endDate: endDate ?? _endDate,
        period: period ?? _period ?? 'monthly',
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load sales report: $e');
    }
  }

  // Load user report
  Future<void> loadUserReport({DateTime? startDate, DateTime? endDate}) async {
    try {
      _userStats = await _apiService.getUserReport(
        startDate: startDate ?? _startDate,
        endDate: endDate ?? _endDate,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load user report: $e');
    }
  }

  // Load book report
  Future<void> loadBookReport() async {
    try {
      _bookStats = await _apiService.getBookReport();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load book report: $e');
    }
  }

  // Load order report
  Future<void> loadOrderReport({
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    try {
      _orderStats = await _apiService.getOrderReport(
        startDate: startDate ?? _startDate,
        endDate: endDate ?? _endDate,
        status: status,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load order report: $e');
    }
  }

  // Load author report
  Future<void> loadAuthorReport() async {
    try {
      _authorStats = await _apiService.getAuthorReport();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load author report: $e');
    }
  }

  // Load category report
  Future<void> loadCategoryReport() async {
    try {
      _categoryStats = await _apiService.getCategoryReport();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load category report: $e');
    }
  }

  // Load rating report
  Future<void> loadRatingReport() async {
    try {
      _ratingStats = await _apiService.getRatingReport();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load rating report: $e');
    }
  }

  // Load fines report
  Future<void> loadFinesReport() async {
    try {
      _finesStats = await _apiService.getFinesReport();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load fines report: $e');
    }
  }

  // Load delivery report
  Future<void> loadDeliveryReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _deliveryStats = await _apiService.getDeliveryReport(
        startDate: startDate,
        endDate: endDate,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load delivery report: $e');
    }
  }

  // Load borrowing report
  Future<void> loadBorrowingReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _borrowingStats = await _apiService.getBorrowingReport(
        startDate: startDate,
        endDate: endDate,
      );
      notifyListeners();
    } catch (e) {
      _setError('Failed to load borrowing report: $e');
    }
  }

  // Generate custom report
  Future<Map<String, dynamic>> generateCustomReport({
    required String reportType,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? filters,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Load the specific report data based on report type
      switch (reportType) {
        case 'borrowing':
          await loadBorrowingReport(startDate: startDate, endDate: endDate);
          break;
        case 'delivery':
          await loadDeliveryReport(startDate: startDate, endDate: endDate);
          break;
        case 'fines':
          await loadFinesReport();
          break;
        case 'books':
          await loadBookReport();
          break;
        case 'authors':
          await loadAuthorReport();
          break;
        case 'users':
          await loadUserReport(startDate: startDate, endDate: endDate);
          break;
        case 'orders':
          await loadOrderReport(startDate: startDate, endDate: endDate);
          break;
        case 'ratings':
          await loadRatingReport();
          break;
        case 'categories':
          await loadCategoryReport();
          break;
        default:
          // For dashboard, load all reports
          await loadDashboardReports();
      }

      _setLoading(false);
      notifyListeners();

      // Return the appropriate data based on report type
      switch (reportType) {
        case 'borrowing':
          return _borrowingStats;
        case 'delivery':
          return _deliveryStats;
        case 'fines':
          return _finesStats;
        case 'books':
          return _bookStats;
        case 'authors':
          return _authorStats;
        case 'users':
          return _userStats;
        case 'orders':
          return _orderStats;
        case 'ratings':
          return _ratingStats;
        case 'categories':
          return _categoryStats;
        default:
          return {};
      }
    } catch (e) {
      _setError('Failed to generate custom report: $e');
      _setLoading(false);
      return {};
    }
  }

  // Additional report methods for screen compatibility
  Future<void> getDeliveryReport({
    required String period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Load delivery report data
      await loadDeliveryReport(startDate: startDate, endDate: endDate);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load delivery report: $e');
      _setLoading(false);
    }
  }

  Future<void> getFineReport({
    required String period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // For now, load basic order data
      await loadOrderReport(startDate: startDate, endDate: endDate);
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load fines report: $e');
      _setLoading(false);
    }
  }

  Future<void> getBookPopularityReport({required String period}) async {
    _setLoading(true);
    _clearError();

    try {
      await loadBookReport();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load book popularity report: $e');
      _setLoading(false);
    }
  }

  Future<void> getAuthorPopularityReport({required String period}) async {
    _setLoading(true);
    _clearError();

    try {
      // Load only basic author data without performance metrics or book relationships
      await loadAuthorReport();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load author popularity report: $e');
      _setLoading(false);
    }
  }

  Future<void> getFinesReport({required String period}) async {
    _setLoading(true);
    _clearError();

    try {
      await loadFinesReport();
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load fines report: $e');
      _setLoading(false);
    }
  }

  Future<void> getBorrowingReport({
    required String period,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _borrowingStats = await _apiService.getBorrowingReport(
        period: period,
        startDate: startDate,
        endDate: endDate,
      );
      _setLoading(false);
      notifyListeners();
    } catch (e) {
      _setError('Failed to load borrowing report: $e');
      _setLoading(false);
    }
  }

  // Set date range filter
  void setDateRange(DateTime? startDate, DateTime? endDate) {
    _startDate = startDate;
    _endDate = endDate;
    notifyListeners();
  }

  // Set report type filter
  void setReportType(String? reportType) {
    _reportType = reportType;
    notifyListeners();
  }

  // Set period filter
  void setPeriod(String? period) {
    _period = period;
    notifyListeners();
  }

  // Apply filters and reload
  Future<void> applyFilters({
    DateTime? startDate,
    DateTime? endDate,
    String? reportType,
    String? period,
  }) async {
    _startDate = startDate ?? _startDate;
    _endDate = endDate ?? _endDate;
    _reportType = reportType ?? _reportType;
    _period = period ?? _period;

    await loadDashboardReports();
  }

  // Clear filters
  Future<void> clearFilters() async {
    _startDate = null;
    _endDate = null;
    _reportType = null;
    _period = 'monthly';

    await loadDashboardReports();
  }

  // Get revenue trend
  List<Map<String, dynamic>> getRevenueTrend() {
    final trend = _salesData['trend'] as List<dynamic>?;
    return trend?.cast<Map<String, dynamic>>() ?? [];
  }

  // Get top selling books
  List<Map<String, dynamic>> getTopSellingBooks({int limit = 10}) {
    final books = _bookStats['top_selling'] as List<dynamic>?;
    return books?.take(limit).cast<Map<String, dynamic>>().toList() ?? [];
  }

  // Get top borrowing books
  List<Map<String, dynamic>> getTopBorrowingBooks({int limit = 10}) {
    final books = _bookStats['top_borrowing'] as List<dynamic>?;
    return books?.take(limit).cast<Map<String, dynamic>>().toList() ?? [];
  }

  // Get user growth data
  List<Map<String, dynamic>> getUserGrowthData() {
    final growth = _userStats['growth'] as List<dynamic>?;
    return growth?.cast<Map<String, dynamic>>() ?? [];
  }

  // Get order status distribution
  Map<String, int> getOrderStatusDistribution() {
    final distribution =
        _orderStats['status_distribution'] as Map<String, dynamic>?;
    return distribution?.map((key, value) => MapEntry(key, value as int)) ?? {};
  }

  // Refresh all reports
  Future<void> refresh() async {
    await loadDashboardReports();
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

  // Update the API service with a new token
  void setToken(String? token) {
    debugPrint(
      'DEBUG: ReportsProvider setToken called with: ${token != null ? '${token.substring(0, 20)}...' : 'null'}',
    );
    if (token != null && token.isNotEmpty) {
      _apiService.setToken(token);
      debugPrint('DEBUG: ReportsProvider token set successfully');
    } else {
      debugPrint('DEBUG: ReportsProvider token is null or empty');
    }
  }

  // Clear all data
  void clear() {
    _reportData.clear();
    _salesData.clear();
    _userStats.clear();
    _bookStats.clear();
    _orderStats.clear();
    _authorStats.clear();
    _categoryStats.clear();
    _ratingStats.clear();
    _finesStats.clear();
    _deliveryStats.clear();
    _borrowingStats.clear();
    _startDate = null;
    _endDate = null;
    _reportType = null;
    _period = 'monthly';
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
