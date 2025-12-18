import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ad.dart';
import '../../providers/ads_provider.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared/widgets/admin_search_bar.dart';
import '../../../../../shared/widgets/filters_bar.dart';
import '../../../../../shared/widgets/empty_state.dart';
import '../../../../../routes/app_routes.dart';
import '../../../../auth/providers/auth_provider.dart';

class AdsListScreen extends StatefulWidget {
  const AdsListScreen({super.key});

  @override
  State<AdsListScreen> createState() => _AdsListScreenState();
}

class _AdsListScreenState extends State<AdsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus;
  String? _selectedAdType;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('AdsListScreen: Initializing and loading ads...');
      _loadAds();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAds() async {
    debugPrint('DEBUG: AdsListScreen - Loading ads...');
    debugPrint(
      'DEBUG: AdsListScreen - Search query: "${_searchController.text}"',
    );
    debugPrint('DEBUG: AdsListScreen - Status filter: "$_selectedStatus"');

    try {
      final provider = context.read<AdsProvider>();
      final authProvider = context.read<AuthProvider>();

      // Check if user is authenticated
      if (authProvider.token == null) {
        throw Exception(
          'Authentication required. Please log in to access advertisements.',
        );
      }

      // Check if user has library admin permissions
      if (!authProvider.isLibraryAdmin) {
        throw Exception(
          'Access denied. Only library administrators can manage advertisements.',
        );
      }

      // Ensure provider has the current token
      provider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Ads list - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
      );

      debugPrint('AdsListScreen: Provider found, loading ads...');
      debugPrint('DEBUG: Calling loadAds with parameters:');
      debugPrint(
        '  - search: ${_searchController.text.isNotEmpty ? _searchController.text : null}',
      );
      debugPrint('  - status: $_selectedStatus');
      debugPrint('  - adType: $_selectedAdType');
      debugPrint(
        '  - token: ${authProvider.token != null ? 'present' : 'null'}',
      );

      await provider.loadAds(
        search: _searchController.text.isNotEmpty
            ? _searchController.text
            : null,
        status: _selectedStatus,
        adType: _selectedAdType,
        token: authProvider.token,
      );
    } catch (e) {
      debugPrint('Error loading ads: $e');
      // Show error in UI
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${localizations.errorLoadingAdvertisements}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearch(String query) {
    debugPrint('DEBUG: AdsListScreen - Search query: "$query"');
    setState(() {});

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set up debounced search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadAds();
    });
  }

  void _onClearSearch() {
    debugPrint('DEBUG: AdsListScreen - Clearing search');
    _searchController.clear();
    setState(() {});
    _loadAds();
  }

  void _onFilterChanged(String? status) {
    debugPrint('DEBUG: _onFilterChanged called with status: $status');
    setState(() {
      _selectedStatus = status;
    });
    debugPrint('DEBUG: _selectedStatus updated to: $_selectedStatus');
    debugPrint('DEBUG: Calling _loadAds with status filter: $_selectedStatus');
    _loadAds();
  }

  void _onAdTypeFilterChanged(String? adType) {
    setState(() {
      _selectedAdType = adType;
    });
    _loadAds();
  }

  Future<void> _deleteAd(Ad ad) async {
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

    if (confirmed == true) {
      try {
        if (!mounted) return;
        final provider = context.read<AdsProvider>();
        await provider.deleteAd(ad.id);

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(localizations.advertisementDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
          _loadAds();
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${localizations.failedToDeleteAdvertisement}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _navigateToAdForm([Ad? ad]) async {
    await Navigator.of(
      context,
    ).pushNamed(AppRoutes.managerAdsForm, arguments: {'ad': ad});

    // No need to refresh the list since the provider already updates the local list
    // The updateAd method in AdsProvider already updates the _ads list
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.advertisements),
        actions: [
          IconButton(
            onPressed: () => _navigateToAdForm(),
            icon: const Icon(Icons.add),
            tooltip: localizations.addNewAdvertisement,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                AdminSearchBar(
                  hintText: localizations.searchAdvertisements,
                  controller: _searchController,
                  onChanged: _onSearch,
                  onClear: _onClearSearch,
                ),
                const SizedBox(height: 16),
                // Advertisement Type Filter Bar
                FiltersBar(
                  filterOptions: [
                    FilterOption(
                      key: 'general',
                      label: localizations.generalAdvertisement,
                      defaultValue: 'general',
                    ),
                    FilterOption(
                      key: 'discount_code',
                      label: localizations.discountCodeAdvertisement,
                      defaultValue: 'discount_code',
                    ),
                  ],
                  selectedFilters: _selectedAdType != null
                      ? {_selectedAdType!: _selectedAdType}
                      : {},
                  onFilterChanged: (filters) {
                    // Find the selected ad type from the filters
                    String? selectedAdType;
                    for (final key in filters.keys) {
                      if (filters[key] != null) {
                        selectedAdType = key;
                        break;
                      }
                    }
                    _onAdTypeFilterChanged(selectedAdType);
                  },
                  onClearFilters: () {
                    _onAdTypeFilterChanged(null);
                  },
                ),
                const SizedBox(height: 16),
                // Status Filter Bar
                FiltersBar(
                  filterOptions: [
                    FilterOption(
                      key: 'active',
                      label: localizations.advertisementStatusActive,
                      defaultValue: 'active',
                    ),
                    FilterOption(
                      key: 'inactive',
                      label: localizations.advertisementStatusInactive,
                      defaultValue: 'inactive',
                    ),
                    FilterOption(
                      key: 'scheduled',
                      label: localizations.advertisementStatusScheduled,
                      defaultValue: 'scheduled',
                    ),
                    FilterOption(
                      key: 'expired',
                      label: localizations.advertisementStatusExpired,
                      defaultValue: 'expired',
                    ),
                  ],
                  selectedFilters: _selectedStatus != null
                      ? {_selectedStatus!: _selectedStatus}
                      : {},
                  onFilterChanged: (filters) {
                    debugPrint('DEBUG: Status filter changed: $filters');
                    // Find the selected status from the filters
                    String? selectedStatus;
                    for (final key in filters.keys) {
                      if (filters[key] != null) {
                        selectedStatus = key;
                        break;
                      }
                    }
                    debugPrint('DEBUG: Selected status: $selectedStatus');
                    _onFilterChanged(selectedStatus);
                  },
                  onClearFilters: () {
                    debugPrint('DEBUG: Clearing status filter');
                    _onFilterChanged(null);
                  },
                ),
              ],
            ),
          ),

          // Ads List
          Expanded(
            child: Consumer<AdsProvider>(
              builder: (context, provider, child) {
                debugPrint('AdsListScreen: Consumer builder called');
                if (provider.isLoading && provider.ads.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.ads.isEmpty) {
                  // Check if it's a permission error
                  final isPermissionError =
                      provider.error!.contains('Access denied') ||
                      provider.error!.contains('Only library administrators');

                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPermissionError ? Icons.lock : Icons.error,
                          size: 64,
                          color: isPermissionError ? Colors.orange : Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isPermissionError
                              ? localizations.accessRestricted
                              : localizations.errorLoadingAdvertisementsTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isPermissionError
                                ? Colors.orange
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            isPermissionError
                                ? localizations.onlyLibraryAdminsManageAds
                                : provider.error!,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!isPermissionError)
                          ElevatedButton(
                            onPressed: () {
                              provider.clearError();
                              _loadAds();
                            },
                            child: Text(localizations.retry),
                          ),
                      ],
                    ),
                  );
                }

                if (provider.ads.isEmpty) {
                  return EmptyState(
                    message: localizations.noAdvertisementsAtMoment,
                    icon: Icons.campaign,
                    actionText: localizations.addAdvertisement,
                    onAction: () => _navigateToAdForm(),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _loadAds,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: provider.ads.length,
                    itemBuilder: (context, index) {
                      final ad = provider.ads[index];
                      return _buildAdCard(ad);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdCard(Ad ad) {
    final isExpired =
        ad.endDate != null && ad.endDate!.isBefore(DateTime.now());

    return GestureDetector(
      onTap: () => _navigateToAdDetails(ad),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        color: isExpired
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ad.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (isExpired)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        AppLocalizations.of(context).advertisementStatusExpired,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Ad Type Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ad.isDiscountCodeAd ? Colors.green : Colors.blue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getAdTypeDisplayName(ad),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Content
              if (ad.content != null && ad.content!.isNotEmpty) ...[
                Text(
                  ad.content!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),
              ],

              // Discount Code (if available)
              if (ad.hasDiscountCode) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.greenAccent.withValues(alpha: 0.6)
                          : Colors.green.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.local_offer,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.greenAccent[400]
                            : Colors.green[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${AppLocalizations.of(context).discountCodeLabel}: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.greenAccent[400]
                              : Colors.green[700],
                        ),
                      ),
                      Text(
                        ad.discountCode!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.greenAccent[400]
                              : Colors.green[700],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Image (if available)
              if (ad.imageUrl != null && ad.imageUrl!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: NetworkImage(ad.imageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Start Date
              if (ad.startDate != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${AppLocalizations.of(context).startLabelColon}: ${_formatDate(ad.startDate!)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // End Date
              if (ad.endDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.event,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${AppLocalizations.of(context).endLabelColon}: ${_formatDate(ad.endDate!)}',
                      style: TextStyle(
                        color: isExpired
                            ? Colors.red
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: isExpired
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],

              // Budget (not available in current model)
              // if (ad.cost != null) ...[
              //   const SizedBox(height: 8),
              //   Row(
              //     children: [
              //       const Icon(Icons.attach_money, size: 20, color: Colors.grey),
              //       const SizedBox(width: 8),
              //       Text(
              //         'Budget: \$${ad.cost!.toStringAsFixed(2)}',
              //         style: const TextStyle(color: Colors.grey),
              //       ),
              //     ],
              //   ),
              // ],
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToAdForm(ad),
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(AppLocalizations.of(context).edit),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _deleteAd(ad),
                      icon: const Icon(Icons.delete, size: 18),
                      label: Text(AppLocalizations.of(context).delete),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAdDetails(Ad ad) {
    Navigator.pushNamed(
      context,
      AppRoutes.managerAdsDetails,
      arguments: {'ad': ad},
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getAdTypeDisplayName(Ad ad) {
    final localizations = AppLocalizations.of(context);
    if (ad.isDiscountCodeAd) {
      return localizations.discountCodeAdvertisement;
    }
    return localizations.generalAdvertisement;
  }
}
