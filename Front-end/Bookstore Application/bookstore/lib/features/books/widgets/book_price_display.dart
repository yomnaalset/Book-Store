import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/book.dart';

class BookPriceDisplay extends StatelessWidget {
  final Book book;
  final bool showBorrowPrice;
  final double? fontSize;
  final double? smallFontSize;
  final bool isCompact;

  const BookPriceDisplay({
    super.key,
    required this.book,
    this.showBorrowPrice = true,
    this.fontSize,
    this.smallFontSize,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return _buildCompactPriceDisplay(context);
    }
    return _buildFullPriceDisplay(context);
  }

  Widget _buildCompactPriceDisplay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main price display
        if (book.originalPrice != null &&
            book.originalPrice! > 0 &&
            book.discountedPrice != null &&
            book.discountedPrice! < book.originalPrice!) ...[
          // Original price (crossed out)
          Text(
            '\$${book.originalPrice!.toStringAsFixed(2)}',
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: smallFontSize ?? 8,
            ),
          ),
          const SizedBox(height: 1),
          // Discounted price
          Text(
            '\$${book.discountedPrice!.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
              fontSize: fontSize ?? 9,
            ),
          ),
        ] else if (book.price != null) ...[
          // Regular price
          Text(
            '\$${book.price}',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: fontSize ?? 9,
            ),
          ),
        ],
        // Borrow price
        if (showBorrowPrice && book.borrowPrice != null) ...[
          const SizedBox(height: 1),
          Text(
            'Borrow: \$${book.borrowPrice}',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
              fontSize: smallFontSize ?? 8,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFullPriceDisplay(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (book.originalPrice != null &&
            book.originalPrice! > 0 &&
            book.discountedPrice != null &&
            book.discountedPrice! < book.originalPrice!) ...[
          // Original price (crossed out)
          Text(
            '\$${book.originalPrice!.toStringAsFixed(2)}',
            style: TextStyle(
              decoration: TextDecoration.lineThrough,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: smallFontSize ?? 10,
            ),
          ),
          const SizedBox(height: 2),
          // Discounted price
          Text(
            '\$${book.discountedPrice!.toStringAsFixed(2)}',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.bold,
              fontSize: fontSize ?? 12,
            ),
          ),
          // Savings amount
          if (book.savingsAmount > 0) ...[
            const SizedBox(height: 2),
            Text(
              'Save \$${book.savingsAmount.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppColors.success,
                fontSize: smallFontSize ?? 9,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ] else if (book.price != null) ...[
          // Regular price
          Text(
            '\$${book.price}',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: fontSize ?? 12,
            ),
          ),
        ],
        // Borrow price
        if (showBorrowPrice && book.borrowPrice != null) ...[
          const SizedBox(height: 4),
          Text(
            'Borrow: \$${book.borrowPrice}',
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
              fontSize: smallFontSize ?? 10,
            ),
          ),
        ],
      ],
    );
  }
}
