import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_dimensions.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final bool readOnly;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry? contentPadding;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.prefixIcon,
    this.suffixIcon,
    this.contentPadding,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onTap: onTap,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      minLines: minLines,
      maxLength: maxLength,
      textCapitalization: textCapitalization,
      textAlign: textAlign,
      focusNode: focusNode,
      // Support text direction based on locale (RTL for Arabic, LTR for English)
      textDirection: null, // Let Flutter determine based on locale
      // Enable Unicode input for Arabic and English
      enableSuggestions: true,
      style: TextStyle(
        fontSize: AppDimensions.fontSizeM,
        color: AppColors.textPrimary,
        // Use system font that supports both Arabic and English
        fontFamily: null, // Use system default which supports Unicode
        // Ensure proper rendering of Arabic and English characters
        letterSpacing: 0.0,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        helperText: helperText,
        errorText: errorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingM,
              vertical: AppDimensions.paddingM,
            ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.disabled),
        ),
        filled: true,
        fillColor: enabled
            ? AppColors.surface
            : AppColors.disabled.withValues(alpha: 0.1),
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppDimensions.fontSizeM,
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppDimensions.fontSizeM,
        ),
        helperStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: AppDimensions.fontSizeS,
        ),
        errorStyle: const TextStyle(
          color: AppColors.error,
          fontSize: AppDimensions.fontSizeS,
        ),
      ),
    );
  }
}
