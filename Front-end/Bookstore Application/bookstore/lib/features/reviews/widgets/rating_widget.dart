import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

class RatingWidget extends StatefulWidget {
  final int initialRating;
  final bool isEditable;
  final Function(int)? onRatingChanged;
  final double size;
  final Color? color;

  const RatingWidget({
    super.key,
    this.initialRating = 0,
    this.isEditable = false,
    this.onRatingChanged,
    this.size = 24.0,
    this.color,
  });

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  late int _currentRating;

  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }

  @override
  void didUpdateWidget(RatingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialRating != widget.initialRating) {
      _currentRating = widget.initialRating;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return GestureDetector(
          onTap: widget.isEditable ? () => _onStarTapped(index + 1) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Icon(
              index < _currentRating ? Icons.star : Icons.star_border,
              color: widget.color ?? AppColors.warning,
              size: widget.size,
            ),
          ),
        );
      }),
    );
  }

  void _onStarTapped(int rating) {
    setState(() {
      _currentRating = rating;
    });
    widget.onRatingChanged?.call(rating);
  }
}

class RatingDisplayWidget extends StatelessWidget {
  final double rating;
  final int reviewCount;
  final double size;
  final bool showReviewCount;

  const RatingDisplayWidget({
    super.key,
    required this.rating,
    this.reviewCount = 0,
    this.size = 20.0,
    this.showReviewCount = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(5, (index) {
          if (index < rating.floor()) {
            return Icon(Icons.star, color: AppColors.warning, size: size);
          } else if (index < rating) {
            return Icon(Icons.star_half, color: AppColors.warning, size: size);
          } else {
            return Icon(
              Icons.star_border,
              color: AppColors.warning,
              size: size,
            );
          }
        }),
        if (showReviewCount) ...[
          const SizedBox(width: AppDimensions.spacingXS),
          Text(
            '${rating.toStringAsFixed(1)} ($reviewCount reviews)',
            style: TextStyle(
              fontSize: size * 0.6,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
