import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../models/dashboard_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/localization/app_localizations.dart';

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

  // Helper methods
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getLocalizedDashboardTitle(
    String title,
    AppLocalizations localizations,
  ) {
    switch (title.toLowerCase()) {
      case 'total users':
        return localizations.totalUsers;
      case 'total revenue':
        return localizations.totalRevenue;
      case 'total orders':
        return localizations.totalOrders;
      case 'total books':
        return localizations.totalBooks;
      case 'total categories':
        return localizations.totalCategories;
      case 'total authors':
        return localizations.totalAuthors;
      case 'book ratings':
        return localizations.bookRatings;
      default:
        return title;
    }
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

  String _getReportTitle(String reportType, AppLocalizations localizations) {
    switch (reportType) {
      case 'borrowing':
        return localizations.borrowingReport;
      case 'delivery':
        return localizations.deliveryReport;
      case 'fines':
        return localizations.finesReport;
      case 'books':
        return localizations.bookPopularity;
      case 'authors':
        return localizations.authorPopularity;
      default:
        return localizations.reports;
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

        final localizations = AppLocalizations.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(localizations.reportsAndAnalytics),
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
                          '${localizations.reportType}:',
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
                                  localizations.dashboardOverview,
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
                                  localizations.borrowingReport,
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
                                  localizations.deliveryReport,
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
                                  localizations.finesReport,
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
                                  localizations.bookPopularity,
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
                                  localizations.authorPopularity,
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
                          '${localizations.dateRange}:',
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
    final localizations = AppLocalizations.of(context);
    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${localizations.error}: ${provider.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadDashboardStats(provider),
              child: Text(localizations.retry),
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
    final localizations = AppLocalizations.of(context);
    if (provider.dashboardCards.isEmpty) {
      return EmptyState(
        title: localizations.noDashboardData,
        message: localizations.noDashboardDataAvailable,
        icon: Icons.analytics,
      );
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.dashboardOverview,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
    return Builder(
      builder: (context) {
        final localizations = AppLocalizations.of(context);
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
                        _getLocalizedDashboardTitle(stat.title, localizations),
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
                          color: stat.trendValue! > 0
                              ? Colors.green
                              : Colors.red,
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
      },
    );
  }

  Widget _buildReportView(ReportsProvider provider) {
    final localizations = AppLocalizations.of(context);
    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${localizations.error}: ${provider.error}',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadDashboardStats(provider),
              child: Text(localizations.retry),
            ),
          ],
        ),
      );
    }

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
    } else {
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
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  _getReportTitle(_selectedReportType, localizations),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.dataFor(
                    _formatDate(_startDate),
                    _formatDate(_endDate),
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.reportDataWillBeDisplayedHere,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDashboardReport(ReportsProvider provider) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Row(
                children: [
                  const Icon(Icons.dashboard, size: 32, color: Colors.blue),
                  const SizedBox(width: 12),
                  Text(
                    localizations.dashboardOverview,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                localizations.dataFor(
                  _formatDate(_startDate),
                  _formatDate(_endDate),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              );
            },
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

  Widget _buildAuthorPopularityReport(ReportsProvider provider) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Row(
                children: [
                  const Icon(Icons.person, size: 32, color: Colors.indigo),
                  const SizedBox(width: 12),
                  Text(
                    localizations.authorPopularity,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                localizations.dataFor(
                  _formatDate(_startDate),
                  _formatDate(_endDate),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              );
            },
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
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations.authorStatistics,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Total Authors
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${localizations.totalAuthorsLabel}:',
                            style: const TextStyle(fontSize: 16),
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
                      );
                    },
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
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          Row(
            children: [
              Icon(Icons.book, size: 32, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                localizations.bookPopularityReport,
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
            localizations.dataFor(
              _formatDate(_startDate),
              _formatDate(_endDate),
            ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // 6 Cards Grid
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  // Total Books Card
                  _buildBookStatCard(
                    title: localizations.totalBooks,
                    value: '${provider.bookStats['total_books'] ?? 0}',
                    subtitle: localizations.allBooksInSystem,
                    icon: Icons.library_books,
                    color: Colors.blue,
                    trend: provider.bookStats['book_trend'],
                    trendValue: (provider.bookStats['book_trend_value'] as num?)
                        ?.toDouble(),
                  ),

                  // Available Books Card
                  _buildBookStatCard(
                    title: localizations.availableBooks,
                    value: '${provider.bookStats['available_books'] ?? 0}',
                    subtitle: localizations.currentlyAvailable,
                    icon: Icons.check_circle,
                    color: Colors.green,
                  ),

                  // Borrowed Books Card
                  _buildBookStatCard(
                    title: localizations.borrowedBooks,
                    value: '${provider.bookStats['borrowed_books'] ?? 0}',
                    subtitle: localizations.currentlyBorrowed,
                    icon: Icons.book_online,
                    color: Colors.orange,
                  ),

                  // Most Borrowed Books Card
                  _buildBookStatCard(
                    title: localizations.mostBorrowed,
                    value:
                        '${(provider.bookStats['most_borrowed_books'] as List?)?.length ?? 0}',
                    subtitle: localizations.topBorrowedBooks,
                    icon: Icons.trending_up,
                    color: Colors.purple,
                  ),

                  // Best Sellers Card
                  _buildBookStatCard(
                    title: localizations.bestSellers,
                    value:
                        '${(provider.bookStats['best_sellers'] as List?)?.length ?? 0}',
                    subtitle: localizations.mostRequestedBooks,
                    icon: Icons.star,
                    color: Colors.amber,
                  ),

                  // Book Trends Card
                  _buildBookStatCard(
                    title: localizations.bookTrends,
                    value:
                        '${provider.bookStats['borrowing_trend_value']?.toStringAsFixed(1) ?? '0.0'}%',
                    subtitle: localizations.borrowingGrowth,
                    icon: Icons.trending_up,
                    color: Colors.teal,
                    trend: provider.bookStats['borrowing_trend'],
                    trendValue:
                        (provider.bookStats['borrowing_trend_value'] as num?)
                            ?.toDouble(),
                  ),
                ],
              );
            },
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
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    book['title'] ?? localizations.unknownTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  );
                                },
                              ),
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    book['author'] ??
                                        localizations.unknownAuthor,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  );
                                },
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
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          Row(
            children: [
              Icon(Icons.money_off, size: 32, color: Colors.red),
              SizedBox(width: 12),
              Text(
                localizations.finesReport,
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
            localizations.dataFor(
              _formatDate(_startDate),
              _formatDate(_endDate),
            ),
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
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildFineStatCard(
                    title: localizations.lateBookStatistics,
                    value: '${provider.finesStats['total_overdue_books'] ?? 0}',
                    subtitle: localizations.overdueBooks,
                    icon: Icons.warning,
                    color: Colors.orange,
                    additionalInfo:
                        '${provider.finesStats['avg_days_overdue'] ?? 0} ${localizations.avgDays}',
                  );
                },
              ),

              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildFineStatCard(
                    title: localizations.fineCollectionData,
                    value:
                        '\$${provider.finesStats['total_fine_amount']?.toStringAsFixed(2) ?? '0.00'}',
                    subtitle: localizations.totalFinesIssued,
                    icon: Icons.attach_money,
                    color: Colors.red,
                    additionalInfo:
                        '${provider.finesStats['total_fines_issued'] ?? 0} ${localizations.fines}',
                  );
                },
              ),

              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildFineStatCard(
                    title: localizations.finePaymentStatus,
                    value:
                        '${provider.finesStats['payment_rate']?.toStringAsFixed(1) ?? '0.0'}%',
                    subtitle: localizations.paymentRate,
                    icon: Icons.payment,
                    color: Colors.green,
                    additionalInfo:
                        '\$${provider.finesStats['total_paid_amount']?.toStringAsFixed(2) ?? '0.00'} ${localizations.paid}',
                  );
                },
              ),

              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildFineStatCard(
                    title: localizations.historicalFineTrends,
                    value:
                        '${provider.finesStats['fine_trend_value']?.toStringAsFixed(1) ?? '0.0'}%',
                    subtitle: localizations.trendThisMonth,
                    icon: Icons.trending_up,
                    color: Colors.purple,
                    trend: provider.finesStats['fine_trend'],
                    trendValue:
                        (provider.finesStats['fine_trend_value'] as num?)
                            ?.toDouble(),
                  );
                },
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
    final localizations = AppLocalizations.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.detailedStatistics,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Row 1
            Row(
              children: [
                Expanded(
                  child: _buildDetailItem(
                    localizations.overdueWithFines,
                    '${provider.finesStats['overdue_books_with_fines'] ?? 0}',
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    localizations.unpaidFines,
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
                    localizations.paidFines,
                    '${provider.finesStats['paid_fines'] ?? 0}',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildDetailItem(
                    localizations.unpaidAmount,
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
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    fine['book_title'] ??
                                        localizations.unknownBook,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  );
                                },
                              ),
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    fine['customer_name'] ??
                                        localizations.unknownCustomer,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  );
                                },
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
    final localizations = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          Row(
            children: [
              Icon(Icons.local_shipping, size: 32, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                localizations.deliveryReport,
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
            localizations.dataFor(
              _formatDate(_startDate),
              _formatDate(_endDate),
            ),
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
            childAspectRatio: 1.25,
            children: [
              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildDeliveryStatCard(
                    title: localizations.totalDeliveries,
                    value: '${provider.deliveryStats['total_deliveries'] ?? 0}',
                    subtitle: localizations.allDeliveryTasks,
                    icon: Icons.local_shipping,
                    color: Colors.blue,
                  );
                },
              ),

              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildDeliveryStatCard(
                    title: localizations.completedDeliveries,
                    value:
                        '${provider.deliveryStats['completed_deliveries'] ?? 0}',
                    subtitle: localizations.successfullyCompleted,
                    icon: Icons.check_circle,
                    color: Colors.green,
                    additionalInfo:
                        '${provider.deliveryStats['overall_completion_rate']?.toStringAsFixed(1) ?? '0.0'}% ${localizations.rate}',
                  );
                },
              ),

              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildDeliveryStatCard(
                    title: localizations.pendingDeliveries,
                    value:
                        '${provider.deliveryStats['pending_deliveries'] ?? 0}',
                    subtitle: localizations.awaitingPickup,
                    icon: Icons.schedule,
                    color: Colors.orange,
                  );
                },
              ),

              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildDeliveryStatCard(
                    title: localizations.deliveriesInProgress,
                    value:
                        '${provider.deliveryStats['in_progress_deliveries'] ?? 0}',
                    subtitle: localizations.currentlyBeingDelivered,
                    icon: Icons.delivery_dining,
                    color: Colors.purple,
                  );
                },
              ),

              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildDeliveryStatCard(
                    title: localizations.failedDeliveries,
                    value:
                        '${provider.deliveryStats['failed_deliveries'] ?? 0}',
                    subtitle: localizations.notCompleted,
                    icon: Icons.error,
                    color: Colors.red,
                  );
                },
              ),

              Builder(
                builder: (context) {
                  final localizations = AppLocalizations.of(context);
                  return _buildDeliveryStatCard(
                    title: localizations.agentPerformance,
                    value: '${provider.deliveryStats['top_agents_count'] ?? 0}',
                    subtitle: localizations.topPerformingAgents,
                    icon: Icons.people,
                    color: Colors.teal,
                    additionalInfo: localizations.top10Agents,
                  );
                },
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
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 9,
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
                  fontSize: 8,
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
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.top10PerformingDeliveryAgents,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
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
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    agent['agent_name'] ??
                                        localizations.unknownAgent,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 2),
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    '${agent['delivery_count'] ?? 0} ${localizations.deliveries}',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  );
                                },
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
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    localizations.completionRate,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  );
                                },
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Row(
                children: [
                  const Icon(
                    Icons.library_books,
                    size: 32,
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    localizations.borrowingReport,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return Text(
                localizations.dataFor(
                  _formatDate(_startDate),
                  _formatDate(_endDate),
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // 7 Cards Grid
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.2,
                children: [
                  // Total Requests Card
                  _buildBorrowingStatCard(
                    title: localizations.totalRequests,
                    value: '${provider.borrowingStats['total_requests'] ?? 0}',
                    subtitle: localizations.allBorrowRequests,
                    icon: Icons.library_books,
                    color: Colors.indigo,
                  ),

                  // Approved Requests Card
                  _buildBorrowingStatCard(
                    title: localizations.approvedRequests,
                    value:
                        '${provider.borrowingStats['approved_requests'] ?? 0}',
                    subtitle: localizations.requestsApproved,
                    icon: Icons.check_circle,
                    color: Colors.green,
                    additionalInfo:
                        '${localizations.rate} ${(provider.borrowingStats['approval_rate'] ?? 0.0).toStringAsFixed(1)}%',
                  ),

                  // Pending Requests Card
                  _buildBorrowingStatCard(
                    title: localizations.pendingRequests,
                    value:
                        '${provider.borrowingStats['pending_requests'] ?? 0}',
                    subtitle: localizations.awaitingApproval,
                    icon: Icons.schedule,
                    color: Colors.orange,
                  ),

                  // Late Requests Card
                  _buildBorrowingStatCard(
                    title: localizations.lateRequests,
                    value: '${provider.borrowingStats['late_requests'] ?? 0}',
                    subtitle: localizations.pastDueDate,
                    icon: Icons.warning,
                    color: Colors.red,
                  ),

                  // Returned Requests Card
                  _buildBorrowingStatCard(
                    title: localizations.returnedRequests,
                    value:
                        '${provider.borrowingStats['returned_requests'] ?? 0}',
                    subtitle: localizations.successfullyReturned,
                    icon: Icons.assignment_turned_in,
                    color: Colors.teal,
                    additionalInfo:
                        '${localizations.rate} ${(provider.borrowingStats['return_rate'] ?? 0.0).toStringAsFixed(1)}%',
                  ),

                  // Period Analysis Card
                  _buildBorrowingStatCard(
                    title: localizations.periodAnalysis,
                    value:
                        '${(provider.borrowingStats['trend_value'] ?? 0.0).toStringAsFixed(1)}%',
                    subtitle: localizations.trendThisPeriod,
                    icon: Icons.trending_up,
                    color: Colors.purple,
                    trend: provider.borrowingStats['trend'],
                    trendValue:
                        (provider.borrowingStats['trend_value'] as num?)
                            ?.toDouble() ??
                        0.0,
                    additionalInfo:
                        '${localizations.view} ${provider.borrowingStats['period'] == 'custom' ? localizations.custom : (provider.borrowingStats['period'] ?? localizations.monthly)}',
                  ),

                  // Most Borrowed Books Card
                  _buildBorrowingStatCard(
                    title: localizations.mostBorrowedBooks,
                    value: '${provider.borrowingStats['top_books_count'] ?? 0}',
                    subtitle: localizations.topBorrowedBooks,
                    icon: Icons.star,
                    color: Colors.amber,
                    additionalInfo: localizations.top10Books,
                  ),
                ],
              );
            },
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
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.mostBorrowedBooks,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
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
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    book['title'] ?? localizations.unknownBook,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 2),
                              Builder(
                                builder: (context) {
                                  final localizations = AppLocalizations.of(
                                    context,
                                  );
                                  return Text(
                                    book['author'] ??
                                        localizations.unknownAuthor,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  );
                                },
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
}
