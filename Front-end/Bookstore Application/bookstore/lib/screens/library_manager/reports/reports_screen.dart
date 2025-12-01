import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../features/admin/providers/reports_provider.dart';
import '../../../features/admin/models/dashboard_card.dart';
import '../../../features/admin/widgets/library_manager/empty_state.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ReportsProvider>();
      await provider.loadDashboardReports();
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

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<ReportsProvider>();

      switch (_selectedReportType) {
        case 'borrowing':
          await provider.generateCustomReport(
            reportType: 'borrowing',
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
        case 'delivery':
          await provider.generateCustomReport(
            reportType: 'delivery',
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
        case 'fines':
          await provider.generateCustomReport(
            reportType: 'fines',
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
        case 'books':
          await provider.generateCustomReport(
            reportType: 'books',
            startDate: _startDate,
            endDate: _endDate,
          );
          break;
        case 'authors':
          await provider.generateCustomReport(
            reportType: 'authors',
            startDate: _startDate,
            endDate: _endDate,
          );
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

  Future<void> _selectDateRange() async {
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
      _loadReport();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            onPressed: () => _loadDashboardStats(),
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
              color: Colors.grey[100],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                // Report Type Selection
                Row(
                  children: [
                    const Text(
                      'Report Type:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedReportType,
                        isExpanded: true,
                        underline: Container(
                          height: 1,
                          color: Colors.grey[300],
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'dashboard',
                            child: Text('Dashboard Overview'),
                          ),
                          DropdownMenuItem(
                            value: 'borrowing',
                            child: Text('Borrowing Report'),
                          ),
                          DropdownMenuItem(
                            value: 'delivery',
                            child: Text('Delivery Report'),
                          ),
                          DropdownMenuItem(
                            value: 'fines',
                            child: Text('Fines Report'),
                          ),
                          DropdownMenuItem(
                            value: 'books',
                            child: Text('Book Popularity'),
                          ),
                          DropdownMenuItem(
                            value: 'authors',
                            child: Text('Author Popularity'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedReportType = value;
                            });
                            if (value != 'dashboard') {
                              _loadReport();
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
                    const Text(
                      'Date Range:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _selectDateRange,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
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
                : Consumer<ReportsProvider>(
                    builder: (context, provider, child) {
                      if (provider.error != null) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error: ${provider.error}',
                                style: const TextStyle(color: Colors.red),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadDashboardStats,
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
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardView(ReportsProvider provider) {
    if (provider.reportData.isEmpty) {
      return EmptyState(
        title: 'No Data',
        message: 'No dashboard data available',
        icon: Icons.analytics,
        actionText: 'Refresh',
        onAction: _loadDashboardStats,
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
              childAspectRatio: 1.5,
            ),
            itemCount: provider.reportData.length,
            itemBuilder: (context, index) {
              final stat = provider.reportData[index];
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report Header
          Row(
            children: [
              Icon(
                _getReportIcon(_selectedReportType),
                color: Colors.blue,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                '${_getReportTitle(_selectedReportType)} Report',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data for ${_formatDate(_startDate)} to ${_formatDate(_endDate)}',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Report Content based on type
          _buildReportContent(provider),
        ],
      ),
    );
  }

  Widget _buildReportContent(ReportsProvider provider) {
    switch (_selectedReportType) {
      case 'authors':
        return _buildAuthorReport(provider);
      case 'books':
        return _buildBookReport(provider);
      case 'borrowing':
        return _buildBorrowingReport(provider);
      case 'delivery':
        return _buildDeliveryReport(provider);
      case 'fines':
        return _buildFinesReport(provider);
      default:
        return const Center(child: Text('Report data will be displayed here'));
    }
  }

  Widget _buildAuthorReport(ReportsProvider provider) {
    final authorStats = provider.authorStats;
    final totalAuthors = authorStats['total_authors'] ?? 0;
    final authorTrend = authorStats['author_trend']?.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Author Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Total Authors: $totalAuthors',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (authorTrend != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Trend: $authorTrend',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookReport(ReportsProvider provider) {
    final bookStats = provider.bookStats;
    final totalBooks = bookStats['total_books'] ?? 0;
    final availableBooks = bookStats['available_books'] ?? 0;
    final bookTrend = bookStats['book_trend']?.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Book Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.book, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Total Books: $totalBooks',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Available Books: $availableBooks',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (bookTrend != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.trending_up, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Trend: $bookTrend',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBorrowingReport(ReportsProvider provider) {
    final borrowingStats = provider.borrowingStats;
    final totalRequests = borrowingStats['total_requests'] ?? 0;
    final approvedRequests = borrowingStats['approved_requests'] ?? 0;
    final pendingRequests = borrowingStats['pending_requests'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Borrowing Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.library_books, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Total Requests: $totalRequests',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Approved Requests: $approvedRequests',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.pending, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Pending Requests: $pendingRequests',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryReport(ReportsProvider provider) {
    final deliveryStats = provider.deliveryStats;
    final totalDeliveries = deliveryStats['total_deliveries'] ?? 0;
    final completedDeliveries = deliveryStats['completed_deliveries'] ?? 0;
    final pendingDeliveries = deliveryStats['pending_deliveries'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delivery Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Total Deliveries: $totalDeliveries',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Completed Deliveries: $completedDeliveries',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.pending, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Pending Deliveries: $pendingDeliveries',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinesReport(ReportsProvider provider) {
    final finesStats = provider.finesStats;
    final totalFines = (finesStats['total_fines'] as num?)?.toDouble() ?? 0.0;
    final paidFines = (finesStats['paid_fines'] as num?)?.toDouble() ?? 0.0;
    final unpaidFines = (finesStats['unpaid_fines'] as num?)?.toDouble() ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fines Statistics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.money_off, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'Total Fines: \$${totalFines.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Paid Fines: \$${paidFines.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Unpaid Fines: \$${unpaidFines.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
        return Icons.people;
      case 'revenue':
        return Icons.attach_money;
      case 'overdue books':
        return Icons.warning;
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
        return Colors.purple;
      case 'revenue':
        return Colors.green;
      case 'overdue books':
        return Colors.red;
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
        return 'Borrowing';
      case 'delivery':
        return 'Delivery';
      case 'fines':
        return 'Fines';
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
