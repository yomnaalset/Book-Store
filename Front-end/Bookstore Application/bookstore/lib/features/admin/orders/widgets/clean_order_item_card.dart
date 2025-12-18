import 'package:flutter/material.dart';
import '../../../orders/models/order.dart';
import '../../../../core/localization/app_localizations.dart';

class CleanOrderItemCard extends StatelessWidget {
  final OrderItem item;

  const CleanOrderItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    // Get book image URL from either book object or snapshot
    final String? imageUrl = item.book.primaryImageUrl ?? item.bookImage;
    final String bookTitle = item.book.title;
    final String? authorName = item.book.author?.name ?? item.bookAuthor;

    return Material(
      color: Colors.white,
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
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 60,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.book,
                            color: Colors.grey,
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
                  : const Icon(Icons.book, color: Colors.grey, size: 30),
            ),
            const SizedBox(width: 16),
            // Book details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bookTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (authorName != null && authorName.isNotEmpty) ...[
                    Text(
                      '${localizations.by} $authorName',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
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
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${localizations.price}: \$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${localizations.total}: \$${item.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
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
