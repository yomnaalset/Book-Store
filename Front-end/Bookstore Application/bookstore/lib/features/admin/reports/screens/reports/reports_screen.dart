import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../models/dashboard_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../../auth/providers/auth_provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _selectedReportType = 'dashboard';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  bool _hasLoadedInitialData = false;

  @override
  void initState() {
    super.initState();
    // Don't load data in initState, let the Consumer handle it
  }

  Future<void> _loadDashboardStats(ReportsProvider provider) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Ensure provider has the current token
      if (authProvider.token != null) {
        provider.setToken(authProvider.token);
        debugPrint(
          'DEBUG: Reports - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
        );
      } else {
        debugPrint('DEBUG: Reports - No token available from AuthProvider');
        return;
      }

      await provider.getDashboardStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadReport(ReportsProvider provider) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Ensure provider has the current token
      if (authProvider.token != null) {
        provider.setToken(authProvider.token);
        debugPrint(
          'DEBUG: Reports - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
        );
      } else {
        debugPrint('DEBUG: Reports - No token available from AuthProvider');
        return;
      }

      switch (_selectedReportType) {
        case 'dashboard':
          await provider.getDashboardStats();
          break;
        case 'borrowing':
          await provider.getBorrowingReport(
            period: 'custom',
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
        case 'delivery':
          await provider.getDeliveryReport(period: 'custom');
          break;
        case 'fines':
          await provider.getFineReport(
            period: 'custom',
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
        case 'books':
          await provider.getBookPopularityReport(period: 'custom');
          break;
        case 'authors':
          await provider.getAuthorPopularityReport(period: 'custom');
          break;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateRange(ReportsProvider provider) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReport(provider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportsProvider>(
      builder: (context, provider, child) {
        // Load initial data if not already loaded
        if (!_hasLoadedInitialData) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _hasLoadedInitialData = true;
              _loadDashboardStats(provider);
            }
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Reports & Analytics'),
            actions: [
              IconButton(
                onPressed: () => _loadDashboardStats(provider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body: Column(
            children: [
              // Report Type Selection and Date Range
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Report Type Selection
                    Row(
                      children: [
                        Text(
                          'Report Type:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _selectedReportType,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                              filled: true,
                              fillColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              labelStyle: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            dropdownColor: Theme.of(
                              context,
                            ).scaffoldBackgroundColor,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            iconEnabledColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                            items: [
                              DropdownMenuItem(
                                value: 'dashboard',
                                child: Text(
                                  'Dashboard Overview',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'borrowing',
                                child: Text(
                                  'Borrowing Report',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'delivery',
                                child: Text(
                                  'Delivery Report',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'fines',
                                child: Text(
                                  'Fines Report',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'books',
                                child: Text(
                                  'Book Popularity',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'authors',
                                child: Text(
                                  'Author Popularity',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedReportType = value;
                                });
                                if (value != 'dashboard') {
                                  _loadReport(provider);
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date Range Selection
                    Row(
                      children: [
                        Text(
                          'Date Range:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _selectDateRange(provider),
                            icon: Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            label: Text(
                              '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              backgroundColor: Theme.of(
                                context,
                              ).scaffoldBackgroundColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Report Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildReportContent(provider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportContent(ReportsProvider provider) {
    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: ${provider.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadDashboardStats(provider),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_selectedReportType == 'dashboard') {
      return _buildDashboardView(provider);
    } else {
      return _buildReportView(provider);
    }
  }

  Widget _buildDashboardView(ReportsProvider provider) {
    if (provider.dashboardCards.isEmpty) {
      return const EmptyState(
        title: 'No Dashboard Data',
        message: 'No dashboard data available',
        icon: Icons.analytics,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // Dashboard Cards Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
            ),
            itemCount: provider.dashboardCards.length,
            itemBuilder: (context, index) {
              final stat = provider.dashboardCards[index];
              return _buildDashboardCard(stat);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(DashboardCard stat) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  _getStatIcon(stat.title),
                  color: _getStatColor(stat.title),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stat.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              stat.value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            if (stat.trendValue != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    stat.trendValue! > 0
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: stat.trendValue! > 0 ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${stat.trendValue!.abs().toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: stat.trendValue! > 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportView(ReportsProvider provider) {
    // Display specific report data based on type
    if (_selectedReportType == 'dashboard') {
      return _buildDashboardReport(provider);
    } else if (_selectedReportType == 'authors') {
      return _buildAuthorPopularityReport(provider);
    } else if (_selectedReportType == 'books') {
      return _buildBookPopularityReport(provider);
    } else if (_selectedReportType == 'fines') {
      return _buildFinesReport(provider);
    } else if (_selectedReportType == 'delivery') {
      return _buildDeliveryReport(provider);
    } else if (_selectedReportType == 'borrowing') {
      return _buildBorrowingReport(provider);
    }

    // For other report types, show placeholder
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _getReportIcon(_selectedReportType),
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '${_getReportTitle(_selectedReportType)} Report',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Data for ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Report data will be displayed here',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardReport(ReportsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          const Row(
            children: [
              Icon(Icons.dashboard, size: 32, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                'Dashboard Overview',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data for ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // Dashboard Cards Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: provider.dashboardCards
                .map((card) => _buildDashboardCard(card))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget buildDashboardCard(DashboardCard card) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(card.icon, color: card.color, size: 24),
                const Spacer(),
                if (card.trend != null)
                  Icon(
                    card.trend == 'up'
                        ? Icons.trending_up
                        : card.trend == 'down'
                        ? Icons.trending_down
                        : Icons.trending_flat,
                    color: card.trend == 'up'
                        ? Colors.green
                        : card.trend == 'down'
                        ? Colors.red
                        : Colors.grey,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              card.value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: card.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              card.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            if (card.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                card.subtitle!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorPopularityReport(ReportsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          const Row(
            children: [
              Icon(Icons.person, size: 32, color: Colors.indigo),
              SizedBox(width: 12),
              Text(
                'Author Popularity Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data for ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // Basic Author Statistics
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Author Statistics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Total Authors
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Authors:',
                        style: TextStyle(fontSize: 16),
                      ),
                      Text(
                        '${provider.authorStats['total_authors'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookPopularityReport(ReportsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          const Row(
            children: [
              Icon(Icons.book, size: 32, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                'Book Popularity Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data for ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // 6 Cards Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              // Total Books Card
              _buildBookStatCard(
                title: 'Total Books',
                value: '${provider.bookStats['total_books'] ?? 0}',
                subtitle: 'All books in system',
                icon: Icons.library_books,
                color: Colors.blue,
                trend: provider.bookStats['book_trend'],
                trendValue: (provider.bookStats['book_trend_value'] as num?)
                    ?.toDouble(),
              ),

              // Available Books Card
              _buildBookStatCard(
                title: 'Available Books',
                value: '${provider.bookStats['available_books'] ?? 0}',
                subtitle: 'Currently available',
                icon: Icons.check_circle,
                color: Colors.green,
              ),

              // Borrowed Books Card
              _buildBookStatCard(
                title: 'Borrowed Books',
                value: '${provider.bookStats['borrowed_books'] ?? 0}',
                subtitle: 'Currently borrowed',
                icon: Icons.book_online,
                color: Colors.orange,
              ),

              // Most Borrowed Books Card
              _buildBookStatCard(
                title: 'Most Borrowed',
                value:
                    '${(provider.bookStats['most_borrowed_books'] as List?)?.length ?? 0}',
                subtitle: 'Top borrowed books',
                icon: Icons.trending_up,
                color: Colors.purple,
              ),

              // Best Sellers Card
              _buildBookStatCard(
                title: 'Best Sellers',
                value:
                    '${(provider.bookStats['best_sellers'] as List?)?.length ?? 0}',
                subtitle: 'Most requested books',
                icon: Icons.star,
                color: Colors.amber,
              ),

              // Book Trends Card
              _buildBookStatCard(
                title: 'Book Trends',
                value:
                    '${provider.bookStats['borrowing_trend_value']?.toStringAsFixed(1) ?? '0.0'}%',
                subtitle: 'Borrowing growth',
                icon: Icons.trending_up,
                color: Colors.teal,
                trend: provider.bookStats['borrowing_trend'],
                trendValue:
                    (provider.bookStats['borrowing_trend_value'] as num?)
                        ?.toDouble(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Most Borrowed Books List
          if ((provider.bookStats['most_borrowed_books'] as List?)
                  ?.isNotEmpty ==
              true)
            _buildBookListSection(
              title: 'Most Borrowed Books',
              books: provider.bookStats['most_borrowed_books'],
              type: 'borrowed',
            ),

          const SizedBox(height: 16),

          // Best Sellers List
          if ((provider.bookStats['best_sellers'] as List?)?.isNotEmpty == true)
            _buildBookListSection(
              title: 'Best Sellers',
              books: provider.bookStats['best_sellers'],
              type: 'sellers',
            ),
        ],
      ),
    );
  }

  Widget _buildBookStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? trend,
    double? trendValue,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                if (trend != null)
                  Icon(
                    trend == 'up'
                        ? Icons.trending_up
                        : trend == 'down'
                        ? Icons.trending_down
                        : Icons.trending_flat,
                    color: trend == 'up'
                        ? Colors.green
                        : trend == 'down'
                        ? Colors.red
                        : Colors.grey,
                    size: 14,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookListSection({
    required String title,
    required List<dynamic> books,
    required String type,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...books
                .take(5)
                .map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book['title'] ?? 'Unknown Title',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                book['author'] ?? 'Unknown Author',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${book[type == 'borrowed' ? 'borrow_count' : 'request_count'] ?? 0}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinesReport(ReportsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          const Row(
            children: [
              Icon(Icons.money_off, size: 32, color: Colors.red),
              SizedBox(width: 12),
              Text(
                'Fines Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data for ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // 4 Cards Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 19,
            mainAxisSpacing: 19,
            childAspectRatio: 1.5,
            children: [
              // Late Book Statistics Card
              _buildFineStatCard(
                title: 'Late Book Statistics',
                value: '${provider.finesStats['total_overdue_books'] ?? 0}',
                subtitle: 'Overdue books',
                icon: Icons.warning,
                color: Colors.orange,
                additionalInfo:
                    '${provider.finesStats['avg_days_overdue'] ?? 0} avg days',
              ),

              // Fine Collection Data Card
              _buildFineStatCard(
                title: 'Fine Collection Data',
                value:
                    '\$${provider.finesStats['total_fine_amount']?.toStringAsFixed(2) ?? '0.00'}',
                subtitle: 'Total fines issued',
                icon: Icons.attach_money,
                color: Colors.red,
                additionalInfo:
                    '${provider.finesStats['total_fines_issued'] ?? 0} fines',
              ),

              // Fine Payment Status Card
              _buildFineStatCard(
                title: 'Fine Payment Status',
                value:
                    '${provider.finesStats['payment_rate']?.toStringAsFixed(1) ?? '0.0'}%',
                subtitle: 'Payment rate',
                icon: Icons.payment,
                color: Colors.green,
                additionalInfo:
                    '\$${provider.finesStats['total_paid_amount']?.toStringAsFixed(2) ?? '0.00'} paid',
              ),

              // Historical Fine Trends Card
              _buildFineStatCard(
                title: 'Historical Fine Trends',
                value:
                    '${provider.finesStats['fine_trend_value']?.toStringAsFixed(1) ?? '0.0'}%',
                subtitle: 'Trend this month',
                icon: Icons.trending_up,
                color: Colors.purple,
                trend: provider.finesStats['fine_trend'],
                trendValue: (provider.finesStats['fine_trend_value'] as num?)
                    ?.toDouble(),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Detailed Statistics
          _buildFinesDetailSection(provider),

          const SizedBox(height: 16),

          // Recent Fines List
          if ((provider.finesStats['recent_fines'] as List?)?.isNotEmpty ==
              true)
            _buildRecentFinesSection(provider),
        ],
      ),
    );
  }

  Widget _buildFineStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? additionalInfo,
    String? trend,
    double? trendValue,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 14),
                const Spacer(),
                if (trend != null)
                  Icon(
                    trend == 'up'
                        ? Icons.trending_up
                        : trend == 'down'
                        ? Icons.trending_down
                        : Icons.trending_flat,
                    color: trend == 'up'
                        ? Colors.green
                        : trend == 'down'
                        ? Colors.red
                        : Colors.grey,
                    size: 8,
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (additionalInfo != null) ...[
              const SizedBox(height: 1),
              Text(
                additionalInfo,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinesDetailSection(ReportsProvider provider) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Row 1
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Overdue with Fines',
                    '${provider.finesStats['overdue_books_with_fines'] ?? 0}',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    'Unpaid Fines',
                    '${provider.finesStats['unpaid_fines'] ?? 0}',
                    Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 2
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    'Paid Fines',
                    '${provider.finesStats['paid_fines'] ?? 0}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    'Unpaid Amount',
                    '\$${provider.finesStats['total_unpaid_amount']?.toStringAsFixed(2) ?? '0.00'}',
                    Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentFinesSection(ReportsProvider provider) {
    final recentFines = provider.finesStats['recent_fines'] as List? ?? [];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Fines',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...recentFines
                .take(5)
                .map(
                  (fine) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fine['book_title'] ?? 'Unknown Book',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                fine['customer_name'] ?? 'Unknown Customer',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: fine['status'] == 'paid'
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '\$${fine['amount']?.toStringAsFixed(2) ?? '0.00'}',
                            style: TextStyle(
                              color: fine['status'] == 'paid'
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryReport(ReportsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          const Row(
            children: [
              Icon(Icons.local_shipping, size: 32, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                'Delivery Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data for ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // 6 Cards Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              // Total Deliveries Card
              _buildDeliveryStatCard(
                title: 'Total Deliveries',
                value: '${provider.deliveryStats['total_deliveries'] ?? 0}',
                subtitle: 'All delivery tasks',
                icon: Icons.local_shipping,
                color: Colors.blue,
              ),

              // Completed Deliveries Card
              _buildDeliveryStatCard(
                title: 'Completed Deliveries',
                value: '${provider.deliveryStats['completed_deliveries'] ?? 0}',
                subtitle: 'Successfully completed',
                icon: Icons.check_circle,
                color: Colors.green,
                additionalInfo:
                    '${provider.deliveryStats['overall_completion_rate']?.toStringAsFixed(1) ?? '0.0'}% rate',
              ),

              // Pending Deliveries Card
              _buildDeliveryStatCard(
                title: 'Pending Deliveries',
                value: '${provider.deliveryStats['pending_deliveries'] ?? 0}',
                subtitle: 'Awaiting pickup',
                icon: Icons.schedule,
                color: Colors.orange,
              ),

              // Deliveries in Progress Card
              _buildDeliveryStatCard(
                title: 'Deliveries in Progress',
                value:
                    '${provider.deliveryStats['in_progress_deliveries'] ?? 0}',
                subtitle: 'Currently being delivered',
                icon: Icons.delivery_dining,
                color: Colors.purple,
              ),

              // Failed Deliveries Card
              _buildDeliveryStatCard(
                title: 'Failed Deliveries',
                value: '${provider.deliveryStats['failed_deliveries'] ?? 0}',
                subtitle: 'Not completed',
                icon: Icons.error,
                color: Colors.red,
              ),

              // Agent Performance Card
              _buildDeliveryStatCard(
                title: 'Agent Performance',
                value: '${provider.deliveryStats['top_agents_count'] ?? 0}',
                subtitle: 'Top performing agents',
                icon: Icons.people,
                color: Colors.teal,
                additionalInfo: 'Top 10 agents',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Agent Performance Details
          if ((provider.deliveryStats['agent_performance'] as List?)
                  ?.isNotEmpty ==
              true)
            _buildAgentPerformanceSection(provider),
        ],
      ),
    );
  }

  Widget _buildDeliveryStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? additionalInfo,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (additionalInfo != null) ...[
              const SizedBox(height: 2),
              Text(
                additionalInfo,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAgentPerformanceSection(ReportsProvider provider) {
    final agentPerformance =
        provider.deliveryStats['agent_performance'] as List? ?? [];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top 10 Performing Delivery Agents',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Agent Performance List
            ...agentPerformance
                .take(10)
                .map(
                  (agent) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        // Agent Name
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                agent['agent_name'] ?? 'Unknown Agent',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${agent['delivery_count'] ?? 0} deliveries',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Completion Rate
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${agent['completion_rate']?.toStringAsFixed(1) ?? '0.0'}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: (agent['completion_rate'] ?? 0) >= 80
                                      ? Colors.green
                                      : (agent['completion_rate'] ?? 0) >= 60
                                      ? Colors.orange
                                      : Colors.red,
                                ),
                              ),
                              const Text(
                                'completion rate',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Completed Count
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${agent['completed_count'] ?? 0}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildBorrowingReport(ReportsProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          const Row(
            children: [
              Icon(Icons.library_books, size: 32, color: Colors.indigo),
              SizedBox(width: 12),
              Text(
                'Borrowing Report',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data for ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // 7 Cards Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              // Total Requests Card
              _buildBorrowingStatCard(
                title: 'Total Requests',
                value: '${provider.borrowingStats['total_requests'] ?? 0}',
                subtitle: 'All borrow requests',
                icon: Icons.library_books,
                color: Colors.indigo,
              ),

              // Approved Requests Card
              _buildBorrowingStatCard(
                title: 'Approved Requests',
                value: '${provider.borrowingStats['approved_requests'] ?? 0}',
                subtitle: 'Requests approved',
                icon: Icons.check_circle,
                color: Colors.green,
                additionalInfo:
                    '${(provider.borrowingStats['approval_rate'] ?? 0.0).toStringAsFixed(1)}% rate',
              ),

              // Pending Requests Card
              _buildBorrowingStatCard(
                title: 'Pending Requests',
                value: '${provider.borrowingStats['pending_requests'] ?? 0}',
                subtitle: 'Awaiting approval',
                icon: Icons.schedule,
                color: Colors.orange,
              ),

              // Late Requests Card
              _buildBorrowingStatCard(
                title: 'Late Requests',
                value: '${provider.borrowingStats['late_requests'] ?? 0}',
                subtitle: 'Past due date',
                icon: Icons.warning,
                color: Colors.red,
              ),

              // Returned Requests Card
              _buildBorrowingStatCard(
                title: 'Returned Requests',
                value: '${provider.borrowingStats['returned_requests'] ?? 0}',
                subtitle: 'Successfully returned',
                icon: Icons.assignment_turned_in,
                color: Colors.teal,
                additionalInfo:
                    '${(provider.borrowingStats['return_rate'] ?? 0.0).toStringAsFixed(1)}% rate',
              ),

              // Period Analysis Card
              _buildBorrowingStatCard(
                title: 'Period Analysis',
                value:
                    '${(provider.borrowingStats['trend_value'] ?? 0.0).toStringAsFixed(1)}%',
                subtitle: 'Trend this period',
                icon: Icons.trending_up,
                color: Colors.purple,
                trend: provider.borrowingStats['trend'],
                trendValue:
                    (provider.borrowingStats['trend_value'] as num?)
                        ?.toDouble() ??
                    0.0,
                additionalInfo:
                    '${provider.borrowingStats['period'] ?? 'monthly'} view',
              ),

              // Most Borrowed Books Card
              _buildBorrowingStatCard(
                title: 'Most Borrowed Books',
                value: '${provider.borrowingStats['top_books_count'] ?? 0}',
                subtitle: 'Top borrowed books',
                icon: Icons.star,
                color: Colors.amber,
                additionalInfo: 'Top 10 books',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Most Borrowed Books List
          if ((provider.borrowingStats['most_borrowed_books'] as List?)
                  ?.isNotEmpty ==
              true)
            _buildMostBorrowedBooksSection(provider),
        ],
      ),
    );
  }

  Widget _buildBorrowingStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? additionalInfo,
    String? trend,
    double? trendValue,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                if (trend != null)
                  Icon(
                    trend == 'up'
                        ? Icons.trending_up
                        : trend == 'down'
                        ? Icons.trending_down
                        : Icons.trending_flat,
                    color: trend == 'up'
                        ? Colors.green
                        : trend == 'down'
                        ? Colors.red
                        : Colors.grey,
                    size: 14,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (additionalInfo != null) ...[
              const SizedBox(height: 2),
              Text(
                additionalInfo,
                style: TextStyle(
                  fontSize: 9,
                  color: color.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMostBorrowedBooksSection(ReportsProvider provider) {
    final mostBorrowedBooks =
        provider.borrowingStats['most_borrowed_books'] as List? ?? [];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Most Borrowed Books',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Most Borrowed Books List
            ...mostBorrowedBooks
                .take(10)
                .map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        // Book Title and Author
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book['title'] ?? 'Unknown Book',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                book['author'] ?? 'Unknown Author',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Borrow Count
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${book['borrow_count'] ?? 0}',
                            style: TextStyle(
                              color: Colors.indigo.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  IconData _getStatIcon(String title) {
    switch (title.toLowerCase()) {
      case 'total books':
        return Icons.book;
      case 'active borrowings':
        return Icons.library_books;
      case 'pending requests':
        return Icons.pending;
      case 'total customers':
      case 'total users':
        return Icons.people;
      case 'revenue':
      case 'total revenue':
        return Icons.attach_money;
      case 'overdue books':
        return Icons.warning;
      case 'total authors':
        return Icons.person;
      case 'total categories':
        return Icons.category;
      case 'book ratings':
        return Icons.star;
      case 'total orders':
        return Icons.shopping_cart;
      default:
        return Icons.analytics;
    }
  }

  Color _getStatColor(String title) {
    switch (title.toLowerCase()) {
      case 'total books':
        return Colors.blue;
      case 'active borrowings':
        return Colors.green;
      case 'pending requests':
        return Colors.orange;
      case 'total customers':
      case 'total users':
        return Colors.purple;
      case 'revenue':
      case 'total revenue':
        return Colors.green;
      case 'overdue books':
        return Colors.red;
      case 'total authors':
        return Colors.indigo;
      case 'total categories':
        return Colors.teal;
      case 'book ratings':
        return Colors.amber;
      case 'total orders':
        return Colors.cyan;
      default:
        return Colors.grey;
    }
  }

  IconData _getReportIcon(String reportType) {
    switch (reportType) {
      case 'borrowing':
        return Icons.library_books;
      case 'delivery':
        return Icons.local_shipping;
      case 'fines':
        return Icons.money_off;
      case 'books':
        return Icons.book;
      case 'authors':
        return Icons.person;
      default:
        return Icons.analytics;
    }
  }

  String _getReportTitle(String reportType) {
    switch (reportType) {
      case 'borrowing':
        return 'Borrowing Report';
      case 'delivery':
        return 'Delivery Report';
      case 'fines':
        return 'Fines Report';
      case 'books':
        return 'Book Popularity';
      case 'authors':
        return 'Author Popularity';
      default:
        return 'Report';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
