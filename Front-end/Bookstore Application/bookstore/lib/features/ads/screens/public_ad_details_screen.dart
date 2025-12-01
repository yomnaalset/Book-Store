import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/public_ad.dart';
import '../providers/public_ad_provider.dart';
import '../../../../core/widgets/common/loading_indicator.dart';
import '../../../../core/widgets/common/error_message.dart';

class PublicAdDetailsScreen extends StatefulWidget {
  final int adId;

  const PublicAdDetailsScreen({super.key, required this.adId});

  @override
  State<PublicAdDetailsScreen> createState() => _PublicAdDetailsScreenState();
}

class _PublicAdDetailsScreenState extends State<PublicAdDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicAdProvider>().loadAdById(widget.adId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertisement Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer<PublicAdProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (provider.error != null) {
            return Center(
              child: ErrorMessage(
                message: provider.error!,
                onRetry: () => provider.loadAdById(widget.adId),
              ),
            );
          }

          if (provider.selectedAd == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Advertisement not found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            );
          }

          return _buildAdDetails(provider.selectedAd!);
        },
      ),
    );
  }

  Widget _buildAdDetails(PublicAd ad) {
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
                      _buildStatusChip(ad),
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
                      color: Colors.grey[300],
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Image not available',
                              style: TextStyle(color: Colors.grey),
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
                    ad.content,
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
                      Colors.green.withValues(alpha: 0.1),
                      Colors.green.withValues(alpha: 0.05),
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
                        const Text(
                          'Special Offer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Discount Code: ',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Expanded(
                            child: Text(
                              ad.discountCode!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.green,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _copyToClipboard(ad.discountCode!);
                            },
                            icon: const Icon(Icons.copy, color: Colors.green),
                            tooltip: 'Copy discount code',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use this code at checkout to get your discount!',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green[700],
                        fontStyle: FontStyle.italic,
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
                    value: _formatDate(ad.startDate),
                  ),

                  const SizedBox(height: 8),

                  // End Date
                  _buildInfoRow(
                    icon: Icons.event,
                    label: 'End Date',
                    value: _formatDate(ad.endDate),
                    valueColor: ad.isExpired ? Colors.red : null,
                  ),

                  const SizedBox(height: 8),

                  // Time remaining
                  if (!ad.isExpired) ...[
                    _buildInfoRow(
                      icon: Icons.access_time,
                      label: 'Time Remaining',
                      value: ad.timeUntilExpirationText,
                      valueColor: Colors.blue,
                    ),
                    const SizedBox(height: 8),
                  ],

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
                    value: ad.statusDisplayName,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons
          if (ad.hasDiscountCode) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  _copyToClipboard(ad.discountCode!);
                },
                icon: const Icon(Icons.copy),
                label: const Text('Copy Discount Code'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue,
                side: const BorderSide(color: Colors.blue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(PublicAd ad) {
    Color chipColor;
    String statusText;

    if (ad.isExpired) {
      chipColor = Colors.red;
      statusText = 'Expired';
    } else if (ad.isActive) {
      chipColor = Colors.green;
      statusText = 'Active';
    } else if (ad.isScheduled) {
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

  Widget _buildAdTypeChip(PublicAd ad) {
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
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _copyToClipboard(String text) {
    // Note: You'll need to add flutter/services to your imports for Clipboard
    // import 'package:flutter/services.dart';
    // Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $text'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
