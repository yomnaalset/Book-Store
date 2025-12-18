import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/ad.dart';
import '../../providers/ads_provider.dart';
import '../../../../../core/localization/app_localizations.dart';

class AdDetailsScreen extends StatefulWidget {
  final Ad ad;

  const AdDetailsScreen({super.key, required this.ad});

  @override
  State<AdDetailsScreen> createState() => _AdDetailsScreenState();
}

class _AdDetailsScreenState extends State<AdDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.advertisementDetails),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _navigateToEdit(),
            icon: const Icon(Icons.edit),
            tooltip: localizations.editAdvertisement,
          ),
          IconButton(
            onPressed: () => _deleteAd(),
            icon: const Icon(Icons.delete),
            color: Theme.of(context).colorScheme.error,
            tooltip: localizations.deleteAdvertisement,
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
      physics: const AlwaysScrollableScrollPhysics(),
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
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context).imageNotAvailable,
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
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
                  Text(
                    AppLocalizations.of(context).descriptionLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ad.content ??
                        AppLocalizations.of(context).noDescriptionProvided,
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
                          AppLocalizations.of(context).discountCodeLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color:
                                Theme.of(context).brightness == Brightness.dark
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
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
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
                            '${AppLocalizations.of(context).codeLabel}: ',
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
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
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
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.greenAccent[400]
                                  : Colors.green[700],
                            ),
                            tooltip: AppLocalizations.of(
                              context,
                            ).copyDiscountCode,
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
                  Text(
                    AppLocalizations.of(context).advertisementInformation,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Start Date
                  _buildInfoRow(
                    icon: Icons.calendar_today,
                    label: AppLocalizations.of(context).startDateLabel,
                    value: _formatDate(ad.startDate ?? DateTime.now()),
                  ),

                  const SizedBox(height: 8),

                  // End Date
                  _buildInfoRow(
                    icon: Icons.event,
                    label: AppLocalizations.of(context).endDateLabel,
                    value: ad.endDate != null
                        ? _formatDate(ad.endDate!)
                        : AppLocalizations.of(context).notSet,
                    valueColor: isExpired ? Colors.red : null,
                  ),

                  const SizedBox(height: 8),

                  // Ad Type
                  _buildInfoRow(
                    icon: Icons.category,
                    label: AppLocalizations.of(context).typeLabel,
                    value: _getAdTypeDisplayName(ad),
                  ),

                  const SizedBox(height: 8),

                  // Status
                  _buildInfoRow(
                    icon: Icons.info,
                    label: AppLocalizations.of(context).statusLabel,
                    value: _getStatusDisplayName(ad.status),
                  ),

                  const SizedBox(height: 8),

                  // Created Date
                  _buildInfoRow(
                    icon: Icons.add_circle_outline,
                    label: AppLocalizations.of(context).createdLabel,
                    value: _formatDate(ad.createdAt ?? DateTime.now()),
                  ),

                  const SizedBox(height: 8),

                  // Last Updated
                  _buildInfoRow(
                    icon: Icons.update,
                    label: AppLocalizations.of(context).lastUpdatedLabel,
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
                  label: Text(AppLocalizations.of(context).editAdvertisement),
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
                  label: Text(AppLocalizations.of(context).delete),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
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
                label: Text(AppLocalizations.of(context).copyDiscountCode),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.dark
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
    final localizations = AppLocalizations.of(context);
    Color chipColor;
    String statusText;

    if (isExpired) {
      chipColor = Colors.red;
      statusText = localizations.advertisementStatusExpired;
    } else if (ad.status == 'active') {
      chipColor = Colors.green;
      statusText = localizations.advertisementStatusActive;
    } else if (ad.status == 'scheduled') {
      chipColor = Colors.orange;
      statusText = localizations.advertisementStatusScheduled;
    } else {
      chipColor = Colors.grey;
      statusText = localizations.advertisementStatusInactive;
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
        _getAdTypeDisplayName(ad),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getAdTypeDisplayName(Ad ad) {
    final localizations = AppLocalizations.of(context);
    if (ad.isDiscountCodeAd) {
      return localizations.discountCodeAdvertisement;
    }
    return localizations.generalAdvertisement;
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
    final localizations = AppLocalizations.of(context);
    switch (status.toLowerCase()) {
      case 'active':
        return localizations.advertisementStatusActive;
      case 'inactive':
        return localizations.advertisementStatusInactive;
      case 'scheduled':
        return localizations.advertisementStatusScheduled;
      case 'expired':
        return localizations.advertisementStatusExpired;
      default:
        return status;
    }
  }

  void _copyToClipboard(String text) {
    final localizations = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${localizations.copied}: $text'),
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
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteAdvertisement),
        content: Text(localizations.deleteAdvertisementConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = Provider.of<AdsProvider>(context, listen: false);
        await provider.deleteAd(widget.ad.id);

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.advertisementDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${localizations.failedToDeleteAdvertisementColon}: $e',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
