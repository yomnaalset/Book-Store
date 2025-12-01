import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/review.dart';
import '../providers/reviews_provider.dart';
import 'rating_widget.dart';

class ReviewForm extends StatefulWidget {
  final int bookId;
  final Review? existingReview;
  final VoidCallback? onSubmitted;

  const ReviewForm({
    super.key,
    required this.bookId,
    this.existingReview,
    this.onSubmitted,
  });

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  double _rating = 0.0;
  bool _isSubmitting = false;
  String? _ratingError;

  @override
  void initState() {
    super.initState();
    if (widget.existingReview != null) {
      _rating = widget.existingReview!.rating?.toDouble() ?? 0.0;
      _commentController.text = widget.existingReview!.comment ?? '';
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingReview != null
                    ? 'Edit Review'
                    : 'Write a Review',
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeXL,
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingL),

              // Rating Section
              Text(
                'Rating *',
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeM,
                  fontWeight: FontWeight.w600,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingS),
              RatingWidget(
                initialRating: _rating.toInt(),
                isEditable: true,
                onRatingChanged: (rating) {
                  setState(() {
                    _rating = rating.toDouble();
                    _ratingError = null; // Clear error when rating is selected
                  });
                },
                size: 32,
              ),
              if (_ratingError != null) ...[
                const SizedBox(height: AppDimensions.spacingS),
                Text(
                  _ratingError!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: AppDimensions.fontSizeS,
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.spacingL),

              // Comment Section
              Text(
                'Comment',
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeM,
                  fontWeight: FontWeight.w600,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingS),
              TextFormField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Share your thoughts about this book...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(AppDimensions.paddingM),
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please write a comment';
                  }
                  if (value.trim().length < 10) {
                    return 'Comment must be at least 10 characters long';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacingL),

              // Submit Button
              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: widget.existingReview != null
                          ? 'Update Review'
                          : 'Submit Review',
                      onPressed: _isSubmitting ? null : _submitReview,
                      type: ButtonType.primary,
                    ),
                  ),
                  if (widget.existingReview != null) ...[
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: CustomButton(
                        text: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                        type: ButtonType.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate rating
    if (_rating == 0) {
      setState(() {
        _ratingError = 'Please select a rating';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _ratingError = null; // Clear any previous rating error
    });

    try {
      final reviewsProvider = Provider.of<ReviewsProvider>(
        context,
        listen: false,
      );

      if (widget.existingReview != null) {
        // Update existing review
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await reviewsProvider.updateReview(
          widget.existingReview!.id,
          _rating.toInt(),
          _commentController.text.trim(),
          authProvider.token,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review updated successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Create new review
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await reviewsProvider.addReview(
          widget.bookId,
          _rating.toInt(),
          _commentController.text.trim(),
          authProvider.token,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review submitted successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }

      widget.onSubmitted?.call();
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
        _ratingError = null; // Clear rating error when submission completes
      });
    }
  }
}
