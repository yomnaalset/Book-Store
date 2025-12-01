import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/ad.dart';
import '../../providers/ads_provider.dart';

class AdDetailsScreen extends StatefulWidget {
  final Ad ad;

  const AdDetailsScreen({super.key, required this.ad});

  @override
  State<AdDetailsScreen> createState() => _AdDetailsScreenState();
}

class _AdDetailsScreenState extends State<AdDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertisement Details'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _navigateToEdit(),
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Advertisement',
          ),
          IconButton(
            onPressed: () => _deleteAd(),
            icon: const Icon(Icons.delete),
            color: Theme.of(context).colorScheme.error,
            tooltip: 'Delete Advertisement',
          ),
        ],
      ),
      body: _buildAdDetails(widget.ad),
    );
  }

  Widget _buildAdDetails(Ad ad) {
    final isExpired =
        ad.endDate != null && ad.endDate!.isBefore(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and status
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          ad.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusChip(ad, isExpired),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildAdTypeChip(ad),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Image (if available)
          if (ad.imageUrl != null && ad.imageUrl!.isNotEmpty) ...[
            Card(
              elevation: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  ad.imageUrl!,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 250,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Image not available',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Content
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ad.content ?? 'No description provided',
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Discount Code (if available)
          if (ad.hasDiscountCode) ...[
            Card(
              elevation: 2,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withValues(alpha: 0.15),
                      Colors.green.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.local_offer,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Discount Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.greenAccent[400]
                                : Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.greenAccent.withValues(alpha: 0.5)
                              : Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Code: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              ad.discountCode!,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.greenAccent[400]
                                    : Colors.green[700],
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _copyToClipboard(ad.discountCode!);
                            },
                            icon: Icon(
                              Icons.copy,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.greenAccent[400]
                                  : Colors.green[700],
                            ),
                            tooltip: 'Copy discount code',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Advertisement Information
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Advertisement Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // Start Date
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: 'Start Date',
                    value: _formatDate(ad.startDate ?? DateTime.now()),
                  ),

                  const SizedBox(height: 8),

                  // End Date
                  _buildInfoRow(
                    icon: Icons.event,
                    label: 'End Date',
                    value: ad.endDate != null
                        ? _formatDate(ad.endDate!)
                        : 'Not set',
                    valueColor: isExpired ? Colors.red : null,
                  ),

                  const SizedBox(height: 8),

                  // Ad Type
                  _buildInfoRow(
                    icon: Icons.category,
                    label: 'Type',
                    value: ad.adTypeDisplayName,
                  ),

                  const SizedBox(height: 8),

                  // Status
                  _buildInfoRow(
                    icon: Icons.info,
                    label: 'Status',
                    value: _getStatusDisplayName(ad.status),
                  ),

                  const SizedBox(height: 8),

                  // Created Date
                  _buildInfoRow(
                    icon: Icons.add_circle_outline,
                    label: 'Created',
                    value: _formatDate(ad.createdAt ?? DateTime.now()),
                  ),

                  const SizedBox(height: 8),

                  // Last Updated
                  _buildInfoRow(
                    icon: Icons.update,
                    label: 'Last Updated',
                    value: _formatDate(ad.updatedAt ?? DateTime.now()),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToEdit(),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Advertisement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteAd(),
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(color: Theme.of(context).colorScheme.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          if (ad.hasDiscountCode) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _copyToClipboard(ad.discountCode!);
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Discount Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).brightness == Brightness.dark
                      ? Colors.greenAccent[700]
                      : Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(Ad ad, bool isExpired) {
    Color chipColor;
    String statusText;

    if (isExpired) {
      chipColor = Colors.red;
      statusText = 'Expired';
    } else if (ad.status == 'active') {
      chipColor = Colors.green;
      statusText = 'Active';
    } else if (ad.status == 'scheduled') {
      chipColor = Colors.orange;
      statusText = 'Scheduled';
    } else {
      chipColor = Colors.grey;
      statusText = 'Inactive';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAdTypeChip(Ad ad) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: ad.isDiscountCodeAd ? Colors.purple : Colors.blue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        ad.adTypeDisplayName,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getStatusDisplayName(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Active';
      case 'inactive':
        return 'Inactive';
      case 'scheduled':
        return 'Scheduled';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToEdit() {
    Navigator.pushNamed(
      context,
      '/manager/ads/form',
      arguments: {'ad': widget.ad},
    );
  }

  Future<void> _deleteAd() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Advertisement'),
        content: const Text(
          'Are you sure you want to delete this advertisement? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = Provider.of<AdsProvider>(context, listen: false);
        await provider.deleteAd(widget.ad.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Advertisement deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete advertisement: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
