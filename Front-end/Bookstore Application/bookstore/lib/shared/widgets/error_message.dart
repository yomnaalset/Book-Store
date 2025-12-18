import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/localization/app_localizations.dart';
import 'custom_button.dart';

class ErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final String? retryText;

  const ErrorMessage({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
    this.retryText,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon ?? Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              localizations.oopsSomethingWentWrong,
              style: const TextStyle(
                fontSize: AppDimensions.fontSizeL,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              message,
              style: const TextStyle(
                fontSize: AppDimensions.fontSizeM,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppDimensions.spacingL),
              CustomButton(
                text: retryText ?? localizations.tryAgain,
                onPressed: onRetry,
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.refresh, color: AppColors.white),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InlineErrorMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const InlineErrorMessage({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      margin: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppDimensions.spacingS),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: AppDimensions.fontSizeS,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: AppDimensions.spacingS),
            Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return TextButton(
                  onPressed: onRetry,
                  child: Text(
                    localizations.retry,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: AppDimensions.fontSizeS,
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
