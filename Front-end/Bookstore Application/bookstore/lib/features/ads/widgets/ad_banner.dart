import 'package:flutter/material.dart';
import '../models/public_ad.dart';
import '../../../../routes/app_routes.dart';

class AdBanner extends StatelessWidget {
  final PublicAd ad;
  final double? height;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;

  const AdBanner({
    super.key,
    required this.ad,
    this.height,
    this.margin,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _navigateToAdDetails(context),
          borderRadius: borderRadius ?? BorderRadius.circular(12),
          child: Container(
            height: height ?? 120,
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.circular(12),
              gradient: _getGradient(),
            ),
            child: Stack(
              children: [
                // Background image (if available)
                if (ad.imageUrl != null && ad.imageUrl!.isNotEmpty)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: borderRadius ?? BorderRadius.circular(12),
                      child: Image.network(
                        ad.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius:
                                  borderRadius ?? BorderRadius.circular(12),
                              gradient: _getGradient(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Gradient overlay for better text readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: borderRadius ?? BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ),

                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and status
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ad.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusChip(),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Content preview
                      Expanded(
                        child: Text(
                          ad.content,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Footer with type and time remaining
                      Row(
                        children: [
                          _buildAdTypeChip(),
                          const Spacer(),
                          if (!ad.isExpired)
                            Text(
                              ad.timeUntilExpirationText,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Click indicator
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.touch_app,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient _getGradient() {
    if (ad.isDiscountCodeAd) {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.purple.withValues(alpha: 0.8),
          Colors.deepPurple.withValues(alpha: 0.8),
        ],
      );
    } else {
      return LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.blue.withValues(alpha: 0.8),
          Colors.blueAccent.withValues(alpha: 0.8),
        ],
      );
    }
  }

  Widget _buildStatusChip() {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildAdTypeChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ad.isDiscountCodeAd ? Colors.purple : Colors.blue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        ad.isDiscountCodeAd ? 'Discount' : 'General',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _navigateToAdDetails(BuildContext context) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.publicAdDetails, arguments: {'adId': ad.id});
  }
}

class AdBannerList extends StatelessWidget {
  final List<PublicAd> ads;
  final double? height;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;
  final bool showOnlyActive;

  const AdBannerList({
    super.key,
    required this.ads,
    this.height,
    this.margin,
    this.borderRadius,
    this.showOnlyActive = true,
  });

  @override
  Widget build(BuildContext context) {
    final filteredAds = showOnlyActive
        ? ads.where((ad) => ad.isVisible).toList()
        : ads;

    if (filteredAds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: filteredAds
          .map(
            (ad) => AdBanner(
              ad: ad,
              height: height,
              margin: margin,
              borderRadius: borderRadius,
            ),
          )
          .toList(),
    );
  }
}

class AdBannerCarousel extends StatefulWidget {
  final List<PublicAd> ads;
  final double height;
  final EdgeInsets? margin;
  final BorderRadius? borderRadius;
  final bool showOnlyActive;
  final Duration autoPlayInterval;

  const AdBannerCarousel({
    super.key,
    required this.ads,
    this.height = 200,
    this.margin,
    this.borderRadius,
    this.showOnlyActive = true,
    this.autoPlayInterval = const Duration(seconds: 5),
  });

  @override
  State<AdBannerCarousel> createState() => _AdBannerCarouselState();
}

class _AdBannerCarouselState extends State<AdBannerCarousel> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Auto-play functionality
    if (widget.ads.length > 1) {
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    Future.delayed(widget.autoPlayInterval, () {
      if (mounted && widget.ads.length > 1) {
        _currentIndex = (_currentIndex + 1) % widget.ads.length;
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        _startAutoPlay();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredAds = widget.showOnlyActive
        ? widget.ads.where((ad) => ad.isVisible).toList()
        : widget.ads;

    if (filteredAds.isEmpty) {
      return const SizedBox.shrink();
    }

    if (filteredAds.length == 1) {
      return AdBanner(
        ad: filteredAds.first,
        height: widget.height,
        margin: widget.margin,
        borderRadius: widget.borderRadius,
      );
    }

    return Container(
      margin:
          widget.margin ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: widget.height,
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: filteredAds.length,
              itemBuilder: (context, index) {
                return AdBanner(
                  ad: filteredAds[index],
                  height: widget.height,
                  margin: EdgeInsets.zero,
                  borderRadius: widget.borderRadius,
                );
              },
            ),
          ),

          // Page indicators
          if (filteredAds.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                filteredAds.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentIndex == index
                        ? Colors.blue
                        : Colors.grey.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
