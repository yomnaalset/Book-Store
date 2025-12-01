import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../routes/app_routes.dart';
import '../models/borrow_request.dart';
import '../models/book.dart';

class RequestSubmittedSuccessScreen extends StatelessWidget {
  final BorrowRequest borrowRequest;
  final Book book;

  const RequestSubmittedSuccessScreen({
    super.key,
    required this.borrowRequest,
    required this.book,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success Icon
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 60,
                ),
              ),

              const SizedBox(height: AppDimensions.spacingXL),

              // Success Title
              const Text(
                'Request Submitted Successfully!',
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimensions.spacingM),

              // Success Message
              Text(
                'Your borrowing request for "${book.title}" has been submitted and is now pending review by the library manager.',
                style: const TextStyle(
                  fontSize: AppDimensions.fontSizeM,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppDimensions.spacingXL),

              // Book Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingM),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          book.coverImageUrl ?? '',
                          width: 60,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 60,
                              height: 90,
                              color: AppColors.surface,
                              child: const Icon(Icons.book),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeM,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingS),
                            if (book.author != null)
                              Text(
                                'by ${book.author}',
                                style: const TextStyle(
                                  fontSize: AppDimensions.fontSizeS,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            const SizedBox(height: AppDimensions.spacingS),
                            Text(
                              'Request ID: #${borrowRequest.id}',
                              style: const TextStyle(
                                fontSize: AppDimensions.fontSizeS,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppDimensions.spacingXL),

              // Next Steps Info
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingM),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What\'s Next?',
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeM,
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                    SizedBox(height: AppDimensions.spacingS),
                    Text(
                      '• You will receive a notification when your request is reviewed\n'
                      '• The library manager will approve or reject your request\n'
                      '• Once approved, a delivery manager will be assigned\n'
                      '• You can track your request status in "My Borrowings"',
                      style: TextStyle(
                        fontSize: AppDimensions.fontSizeS,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.spacingXXL),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'View My Borrowings',
                  onPressed: () {
                    // Navigate to borrow status screen
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.borrowStatus,
                      (route) => route.isFirst,
                    );
                  },
                ),
              ),

              const SizedBox(height: AppDimensions.spacingM),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.spacingM,
                    ),
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: AppDimensions.fontSizeM,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
