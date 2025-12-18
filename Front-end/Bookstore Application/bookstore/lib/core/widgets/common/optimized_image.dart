import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'loading_indicator.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../services/api_config.dart';

class OptimizedImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget Function(BuildContext, String, dynamic)? errorBuilder;
  final Duration fadeInDuration;
  final Widget? placeholder;
  final String? semanticsLabel;
  final bool memCacheWidth;
  final bool memCacheHeight;

  const OptimizedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.errorBuilder,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.placeholder,
    this.semanticsLabel,
    this.memCacheWidth = true,
    this.memCacheHeight = true,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate memory cache size based on device pixel ratio and dimensions
    // This significantly reduces memory usage for large images
    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final int? memCacheWidthValue = memCacheWidth && width != null
        ? (width! * pixelRatio).round()
        : null;
    final int? memCacheHeightValue = memCacheHeight && height != null
        ? (height! * pixelRatio).round()
        : null;

    // Default error widget
    Widget defaultErrorBuilder(
      BuildContext context,
      String url,
      dynamic error,
    ) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.greyLight,
          borderRadius: borderRadius,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: AppColors.grey,
                size: (width ?? 100) * 0.3,
              ),
              const SizedBox(height: AppDimensions.spacingS),
              const Text(
                'Image not available',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: AppDimensions.fontSizeS,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default placeholder widget
    Widget defaultPlaceholder(BuildContext context, String url) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.greyLight,
          borderRadius: borderRadius,
        ),
        child: const Center(child: LoadingIndicator(size: 20.0)),
      );
    }

    // Build full URL from relative path if needed
    final fullImageUrl = ApiConfig.buildImageUrl(imageUrl) ?? imageUrl;

    final imageWidget = CachedNetworkImage(
      imageUrl: fullImageUrl,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: fadeInDuration,
      memCacheWidth: memCacheWidthValue,
      memCacheHeight: memCacheHeightValue,
      placeholder: (context, url) =>
          placeholder ?? defaultPlaceholder(context, url),
      errorWidget: errorBuilder ?? defaultErrorBuilder,
    );

    // Apply border radius if specified
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    // Apply semantics if specified
    if (semanticsLabel != null) {
      return Semantics(label: semanticsLabel, image: true, child: imageWidget);
    }

    return imageWidget;
  }
}
