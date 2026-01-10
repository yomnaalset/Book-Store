import 'package:flutter/material.dart';
import '../../../orders/models/order.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/api_config.dart';

class CleanOrderItemCard extends StatelessWidget {
  final OrderItem item;

  const CleanOrderItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    // Get book image URL and build full URL
    final String? imageUrl = item.bookImage;
    final String? fullImageUrl = imageUrl != null && imageUrl.isNotEmpty
        ? ApiConfig.buildImageUrl(imageUrl) ?? imageUrl
        : null;
    final String bookTitle = item.bookTitle;
    final String? authorName = item.bookAuthor;

    debugPrint(
      'CleanOrderItemCard: Book "$bookTitle" - imageUrl: $imageUrl, fullImageUrl: $fullImageUrl',
    );

    return Material(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book cover image or placeholder
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: fullImageUrl != null && fullImageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        fullImageUrl,
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                            'CleanOrderItemCard: Error loading book image for "$bookTitle": $error',
                          );
                          return Icon(
                            Icons.book,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            size: 30,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.book,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 30,
                    ),
            ),
            const SizedBox(width: 16),
            // Book details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (authorName != null && authorName.isNotEmpty) ...[
                    Text(
                      '${localizations.by} $authorName',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  const SizedBox(height: 8),
                  // Price information
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        '${localizations.qty}: ${item.quantity}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${localizations.price}: \$${item.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${localizations.total}: \$${item.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  // Borrowed badge
                  if (item.isBorrowed) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange[100]!),
                      ),
                      child: Text(
                        localizations.borrowed,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
