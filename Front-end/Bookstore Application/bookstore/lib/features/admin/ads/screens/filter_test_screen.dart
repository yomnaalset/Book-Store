import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ads_provider.dart';
import '../../../../core/constants/app_colors.dart';

class FilterTestScreen extends StatefulWidget {
  const FilterTestScreen({super.key});

  @override
  State<FilterTestScreen> createState() => _FilterTestScreenState();
}

class _FilterTestScreenState extends State<FilterTestScreen> {
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filter Test'),
        backgroundColor: AppColors.uranianBlue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status Filter: ${_selectedStatus ?? 'None'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Simple filter buttons
            Wrap(
              spacing: 8,
              children: [
                _buildFilterButton('Active', 'active'),
                _buildFilterButton('Inactive', 'inactive'),
                _buildFilterButton('Scheduled', 'scheduled'),
                _buildFilterButton('Expired', 'expired'),
                _buildFilterButton('Clear', null),
              ],
            ),

            const SizedBox(height: 20),

            // Test API call
            ElevatedButton(
              onPressed: _testApiCall,
              child: const Text('Test API Call'),
            ),

            const SizedBox(height: 20),

            // Results
            Expanded(
              child: Consumer<AdsProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null) {
                    return Center(child: Text('Error: ${provider.error}'));
                  }

                  return ListView.builder(
                    itemCount: provider.ads.length,
                    itemBuilder: (context, index) {
                      final ad = provider.ads[index];
                      return Card(
                        child: ListTile(
                          title: Text(ad.title),
                          subtitle: Text('Status: ${ad.status}'),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getStatusColor(ad.status),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              ad.status,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, String? status) {
    final isSelected = _selectedStatus == status;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedStatus = status;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? AppColors.uranianBlue : Colors.grey,
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
        return Colors.grey;
      case 'scheduled':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Future<void> _testApiCall() async {
    try {
      final provider = context.read<AdsProvider>();
      await provider.loadAds(page: 1, limit: 10, status: _selectedStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
