import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/public_ad_provider.dart';
import '../widgets/ad_banner.dart';
import '../../../../core/widgets/common/loading_indicator.dart';
import '../../../../core/widgets/common/error_message.dart';

class AdDemoScreen extends StatefulWidget {
  const AdDemoScreen({super.key});

  @override
  State<AdDemoScreen> createState() => _AdDemoScreenState();
}

class _AdDemoScreenState extends State<AdDemoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PublicAdProvider>().loadAds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advertisement Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              context.read<PublicAdProvider>().refreshAds();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
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
                onRetry: () => provider.loadAds(),
              ),
            );
          }

          if (provider.ads.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.campaign, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No advertisements available',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Check your internet connection or try again later',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Advertisement Examples',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap on any advertisement to view details',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),

                // Single Ad Banner Example
                const Text(
                  'Single Advertisement Banner',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                AdBanner(ad: provider.ads.first, height: 150),
                const SizedBox(height: 32),

                // Ad Banner List Example
                const Text(
                  'Advertisement List',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                AdBannerList(
                  ads: provider.ads,
                  height: 120,
                  showOnlyActive: true,
                ),
                const SizedBox(height: 32),

                // Ad Banner Carousel Example
                if (provider.ads.length > 1) ...[
                  const Text(
                    'Advertisement Carousel',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  AdBannerCarousel(
                    ads: provider.ads,
                    height: 200,
                    showOnlyActive: true,
                  ),
                  const SizedBox(height: 32),
                ],

                // Discount Code Ads Only
                if (provider.discountCodeAds.isNotEmpty) ...[
                  const Text(
                    'Discount Code Advertisements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  AdBannerList(
                    ads: provider.discountCodeAds,
                    height: 140,
                    showOnlyActive: true,
                  ),
                  const SizedBox(height: 32),
                ],

                // General Ads Only
                if (provider.generalAds.isNotEmpty) ...[
                  const Text(
                    'General Advertisements',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  AdBannerList(
                    ads: provider.generalAds,
                    height: 140,
                    showOnlyActive: true,
                  ),
                  const SizedBox(height: 32),
                ],

                // Ads Ending Soon
                if (provider.adsEndingSoon.isNotEmpty) ...[
                  const Text(
                    'Ending Soon',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  AdBannerList(
                    ads: provider.adsEndingSoon,
                    height: 140,
                    showOnlyActive: false,
                  ),
                  const SizedBox(height: 32),
                ],

                // Statistics
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Advertisement Statistics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildStatRow(
                          'Total Advertisements',
                          provider.ads.length,
                        ),
                        _buildStatRow(
                          'Active Advertisements',
                          provider.activeAds.length,
                        ),
                        _buildStatRow(
                          'General Advertisements',
                          provider.generalAds.length,
                        ),
                        _buildStatRow(
                          'Discount Code Advertisements',
                          provider.discountCodeAds.length,
                        ),
                        _buildStatRow(
                          'Ending Soon',
                          provider.adsEndingSoon.length,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatRow(String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
