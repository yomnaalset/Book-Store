import 'package:flutter/material.dart';
import '../../constants/app_dimensions.dart';

enum ButtonType { primary, secondary, outline, text, icon }

enum ButtonSize { small, medium, large, extraLarge }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? borderRadius;
  final EdgeInsets? padding;
  final TextStyle? textStyle;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.borderRadius,
    this.padding,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: _getButtonHeight()),
        child: _buildButton(context, isDisabled),
      ),
    );
  }

  Widget _buildButton(BuildContext context, bool isDisabled) {
    final theme = Theme.of(context);

    switch (type) {
      case ButtonType.primary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? theme.colorScheme.primary,
            foregroundColor: textColor ?? theme.colorScheme.onPrimary,
            elevation: isDisabled ? 0 : AppDimensions.elevationS,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? _getBorderRadius(),
              ),
            ),
            padding: padding ?? _getPadding(),
          ),
          child: _buildButtonContent(context),
        );

      case ButtonType.secondary:
        return ElevatedButton(
          onPressed: isDisabled ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? theme.colorScheme.secondary,
            foregroundColor: textColor ?? theme.colorScheme.onSecondary,
            elevation: isDisabled ? 0 : AppDimensions.elevationS,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? _getBorderRadius(),
              ),
            ),
            padding: padding ?? _getPadding(),
          ),
          child: _buildButtonContent(context),
        );

      case ButtonType.outline:
        return OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: textColor ?? theme.colorScheme.primary,
            side: BorderSide(
              color: borderColor ?? theme.colorScheme.primary,
              width: AppDimensions.borderWidth,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? _getBorderRadius(),
              ),
            ),
            padding: padding ?? _getPadding(),
          ),
          child: _buildButtonContent(context),
        );

      case ButtonType.text:
        return TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: textColor ?? theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? _getBorderRadius(),
              ),
            ),
            padding: padding ?? _getPadding(),
          ),
          child: _buildButtonContent(context),
        );

      case ButtonType.icon:
        return IconButton(
          onPressed: isDisabled ? null : onPressed,
          icon: _buildButtonContent(context),
          style: IconButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: textColor ?? theme.colorScheme.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                borderRadius ?? _getBorderRadius(),
              ),
            ),
            padding: padding ?? _getPadding(),
          ),
        );
    }
  }

  Widget _buildButtonContent(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        width: _getIconSize(),
        height: _getIconSize(),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            textColor ?? _getTextColor(context),
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: _getIconSize()),
          if (text.isNotEmpty) ...[
            const SizedBox(width: AppDimensions.spacingS),
            Flexible(
              child: Text(
                text,
                style: textStyle ?? _getTextStyle(context),
                textAlign: TextAlign.center,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ],
      );
    }

    return Text(
      text,
      style: textStyle ?? _getTextStyle(context),
      textAlign: TextAlign.center,
      overflow: TextOverflow.visible,
    );
  }

  double _getButtonHeight() {
    switch (size) {
      case ButtonSize.small:
        return AppDimensions.buttonHeightS;
      case ButtonSize.medium:
        return AppDimensions.buttonHeightM;
      case ButtonSize.large:
        return AppDimensions.buttonHeightL;
      case ButtonSize.extraLarge:
        return AppDimensions.buttonHeightXL;
    }
  }

  double _getBorderRadius() {
    switch (size) {
      case ButtonSize.small:
        return AppDimensions.radiusS;
      case ButtonSize.medium:
        return AppDimensions.radiusM;
      case ButtonSize.large:
        return AppDimensions.radiusL;
      case ButtonSize.extraLarge:
        return AppDimensions.radiusXL;
    }
  }

  EdgeInsets _getPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        );
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        );
      case ButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXL,
          vertical: AppDimensions.paddingL,
        );
      case ButtonSize.extraLarge:
        return const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingXXL,
          vertical: AppDimensions.paddingXL,
        );
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return AppDimensions.iconS;
      case ButtonSize.medium:
        return AppDimensions.iconM;
      case ButtonSize.large:
        return AppDimensions.iconL;
      case ButtonSize.extraLarge:
        return AppDimensions.iconXL;
    }
  }

  Color _getTextColor(BuildContext context) {
    final theme = Theme.of(context);

    switch (type) {
      case ButtonType.primary:
        return theme.colorScheme.onPrimary;
      case ButtonType.secondary:
        return theme.colorScheme.onSecondary;
      case ButtonType.outline:
      case ButtonType.text:
      case ButtonType.icon:
        return theme.colorScheme.primary;
    }
  }

  TextStyle _getTextStyle(BuildContext context) {
    return TextStyle(
      fontSize: _getFontSize(),
      fontWeight: FontWeight.w600,
      color: textColor ?? _getTextColor(context),
      height: 1.2,
    );
  }

  double _getFontSize() {
    switch (size) {
      case ButtonSize.small:
        return AppDimensions.fontSizeS;
      case ButtonSize.medium:
        return AppDimensions.fontSizeM;
      case ButtonSize.large:
        return AppDimensions.fontSizeL;
      case ButtonSize.extraLarge:
        return AppDimensions.fontSizeXL;
    }
  }
}
