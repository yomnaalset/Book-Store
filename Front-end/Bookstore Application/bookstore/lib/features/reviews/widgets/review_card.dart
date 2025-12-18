import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/extensions/theme_extensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/review.dart';
import '../models/reply.dart';
import '../providers/reviews_provider.dart';
import 'rating_widget.dart';

class ReviewCard extends StatefulWidget {
  final Review review;
  final bool showActions;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ReviewCard({
    super.key,
    required this.review,
    this.showActions = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and rating
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    widget.review.userName?.substring(0, 1).toUpperCase() ??
                        'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.review.userName ?? 'Anonymous',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppDimensions.fontSizeM,
                        ),
                      ),
                      if (widget.review.createdAt != null)
                        Text(
                          _formatDate(widget.review.createdAt!),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppDimensions.fontSizeS,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.showActions)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          widget.onEdit?.call();
                          break;
                        case 'delete':
                          widget.onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit, size: 16),
                              const SizedBox(width: 8),
                              Text(localizations.edit),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.delete,
                                size: 16,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                localizations.delete,
                                style: const TextStyle(color: AppColors.error),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingM),

            // Rating
            if (widget.review.rating != null)
              RatingDisplayWidget(
                rating: widget.review.rating!.toDouble(),
                size: 16.0,
                showReviewCount: false,
              ),
            const SizedBox(height: AppDimensions.spacingS),

            // Comment
            if (widget.review.comment != null &&
                widget.review.comment!.isNotEmpty)
              Text(
                widget.review.comment!,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeM,
                  color: context.textColor,
                  height: 1.4,
                ),
              ),

            const SizedBox(height: AppDimensions.spacingM),

            // Actions (like, reply)
            Row(
              children: [
                Consumer<ReviewsProvider>(
                  builder: (context, reviewsProvider, child) {
                    return GestureDetector(
                      onTap: () => _toggleLike(context, reviewsProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacingS,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.review.isLiked == true
                              ? AppColors.primary.withValues(alpha: 0.1)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusS,
                          ),
                          border: Border.all(
                            color: widget.review.isLiked == true
                                ? AppColors.primary
                                : AppColors.border.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.review.isLiked == true
                                  ? Icons.thumb_up
                                  : Icons.thumb_up_outlined,
                              size: 16,
                              color: widget.review.isLiked == true
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.review.likesCount ?? 0}',
                              style: TextStyle(
                                fontSize: AppDimensions.fontSizeS,
                                fontWeight: FontWeight.w500,
                                color: widget.review.isLiked == true
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: AppDimensions.spacingM),
                GestureDetector(
                  onTap: () => _showReplyDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingS,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusS,
                      ),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.reply_outlined,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              localizations.reply,
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeS,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),

            // Replies section
            if (widget.review.replies != null &&
                widget.review.replies!.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingM),
              Container(
                margin: const EdgeInsets.only(left: AppDimensions.spacingL),
                padding: const EdgeInsets.all(AppDimensions.spacingM),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (context) {
                        final localizations = AppLocalizations.of(context);
                        return Row(
                          children: [
                            Text(
                              localizations.repliesCountWithNumber(
                                widget.review.replies!.length,
                              ),
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeS,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => _showReplyDialog(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.spacingS,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radiusS,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add,
                                      size: 12,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      localizations.addReply,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacingS),
                    ...widget.review.replies!.map(
                      (reply) => _buildReplyItem(reply),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    final localizations = AppLocalizations.of(context);

    if (difference.inDays == 0) {
      return localizations.today;
    } else if (difference.inDays == 1) {
      return localizations.yesterday;
    } else if (difference.inDays < 7) {
      return localizations.daysAgoWithNumber(difference.inDays);
    } else if (difference.inDays < 30) {
      return localizations.weeksAgoWithNumber((difference.inDays / 7).floor());
    } else if (difference.inDays < 365) {
      return localizations.monthsAgoWithNumber(
        (difference.inDays / 30).floor(),
      );
    } else {
      return localizations.yearsAgoWithNumber(
        (difference.inDays / 365).floor(),
      );
    }
  }

  void _toggleLike(
    BuildContext context,
    ReviewsProvider reviewsProvider,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context);

    try {
      await reviewsProvider.likeReview(widget.review.id, authProvider.token);

      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              widget.review.isLiked == true
                  ? localizations.reviewUnliked
                  : localizations.reviewLiked,
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showReplyDialog(BuildContext context) {
    final TextEditingController replyController = TextEditingController();
    final localizations = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.reply, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(localizations.replyToReview),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingS),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      localizations.replyConversationHint,
                      style: const TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            TextField(
              controller: replyController,
              decoration: InputDecoration(
                hintText: localizations.writeYourReply,
                border: const OutlineInputBorder(),
                labelText: localizations.yourReply,
              ),
              maxLines: 4,
              minLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(localizations.pleaseEnterReply),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              final reviewsProvider = Provider.of<ReviewsProvider>(
                context,
                listen: false,
              );
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );

              try {
                await reviewsProvider.addReply(
                  widget.review.id,
                  replyController.text.trim(),
                  authProvider.token,
                );

                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(localizations.replyAddedSuccessfully),
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text(localizations.reply),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(Reply reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(
                  reply.userName?.substring(0, 1).toUpperCase() ?? 'U',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reply.userName ?? 'Anonymous',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppDimensions.fontSizeS,
                      ),
                    ),
                    if (reply.createdAt != null)
                      Text(
                        _formatDate(reply.createdAt!),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingS),
          Text(
            reply.content,
            style: TextStyle(
              fontSize: AppDimensions.fontSizeS,
              color: context.textColor,
              height: 1.3,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
          // Reply like button
          Consumer<ReviewsProvider>(
            builder: (context, reviewsProvider, child) {
              return GestureDetector(
                onTap: () => _toggleReplyLike(context, reviewsProvider, reply),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingS,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: reply.isLiked == true
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                    border: Border.all(
                      color: reply.isLiked == true
                          ? AppColors.primary
                          : AppColors.border.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        reply.isLiked == true
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        size: 12,
                        color: reply.isLiked == true
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '${reply.likesCount ?? 0}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: reply.isLiked == true
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _toggleReplyLike(
    BuildContext context,
    ReviewsProvider reviewsProvider,
    Reply reply,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final localizations = AppLocalizations.of(context);

    try {
      await reviewsProvider.likeReply(reply.id, authProvider.token);

      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              reply.isLiked == true
                  ? localizations.replyUnliked
                  : localizations.replyLiked,
            ),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
