import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/review.dart';
import '../providers/reviews_provider.dart';
import 'review_card.dart';
import 'review_form.dart';

class ReviewsList extends StatefulWidget {
  final String bookId;
  final VoidCallback? onReviewsUpdated;

  const ReviewsList({super.key, required this.bookId, this.onReviewsUpdated});

  @override
  State<ReviewsList> createState() => _ReviewsListState();
}

class _ReviewsListState extends State<ReviewsList> {
  bool _isInitialLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReviews();
    });
  }

  Future<void> _loadReviews({bool notifyParent = false}) async {
    final reviewsProvider = Provider.of<ReviewsProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await reviewsProvider.loadReviews(
      int.parse(widget.bookId),
      authProvider.token,
    );

    // Only notify parent if this is not the initial load and notifyParent is true
    if (!_isInitialLoad && notifyParent && widget.onReviewsUpdated != null) {
      widget.onReviewsUpdated!();
    }

    _isInitialLoad = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ReviewsProvider, AuthProvider>(
      builder: (context, reviewsProvider, authProvider, child) {
        if (reviewsProvider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(AppDimensions.paddingXL),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (reviewsProvider.reviews.isEmpty) {
          return _buildEmptyState();
        }

        // Get current user ID from AuthProvider
        final currentUserId = authProvider.user?.id;

        return Column(
          children: [
            // Reviews header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Text(
                        localizations.reviewsCountWithNumber(
                          reviewsProvider.reviews.length,
                        ),
                        style: TextStyle(
                          fontSize: AppDimensions.fontSizeL,
                          fontWeight: FontWeight.bold,
                          color: context.textColor,
                        ),
                      );
                    },
                  ),
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return TextButton(
                        onPressed: () => _showAddReviewDialog(),
                        child: Text(localizations.writeReviewLink),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),

            // Reviews list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviewsProvider.reviews.length,
              itemBuilder: (context, index) {
                final review = reviewsProvider.reviews[index];
                final isCurrentUserReview =
                    currentUserId != null &&
                    (review.userId == currentUserId ||
                        review.userId.toString() == currentUserId.toString());

                return ReviewCard(
                  review: review,
                  showActions: isCurrentUserReview,
                  onEdit: isCurrentUserReview
                      ? () => _showEditReviewDialog(review)
                      : null,
                  onDelete: isCurrentUserReview
                      ? () => _showDeleteReviewDialog(review)
                      : null,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.rate_review_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.noReviewsYet,
                  style: const TextStyle(
                    fontSize: AppDimensions.fontSizeL,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(
                  localizations.beFirstToShare,
                  style: const TextStyle(
                    fontSize: AppDimensions.fontSizeM,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return ElevatedButton.icon(
                  onPressed: () => _showAddReviewDialog(),
                  icon: const Icon(Icons.rate_review),
                  label: Text(localizations.writeFirstReview),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReviewDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReviewForm(
          bookId: int.parse(widget.bookId),
          onSubmitted: () {
            _loadReviews(notifyParent: true);
          },
        ),
      ),
    );
  }

  void _showEditReviewDialog(Review review) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusL),
        ),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ReviewForm(
          bookId: int.parse(widget.bookId),
          existingReview: review,
          onSubmitted: () {
            _loadReviews(notifyParent: true);
          },
        ),
      ),
    );
  }

  void _showDeleteReviewDialog(Review review) {
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteReview),
        content: Text(localizations.confirmDeleteReview),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteReview(review);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReview(Review review) async {
    try {
      final reviewsProvider = Provider.of<ReviewsProvider>(
        context,
        listen: false,
      );
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await reviewsProvider.deleteReview(review.id, authProvider.token);

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.reviewDeletedSuccessfully),
            backgroundColor: AppColors.success,
          ),
        );

        _loadReviews(notifyParent: true);
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
    }
  }
}
