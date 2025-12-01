import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_dimensions.dart';

enum TextFieldType { text, email, password, phone, number, multiline }

class CustomTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final String? initialValue;
  final TextFieldType type;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final void Function()? onTap;
  final bool enabled;
  final bool readOnly;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? prefixText;
  final String? suffixText;
  final Color? fillColor;
  final Color? borderColor;
  final double? borderRadius;
  final EdgeInsets? contentPadding;
  final TextStyle? textStyle;
  final TextStyle? labelStyle;
  final TextStyle? hintStyle;
  final bool isRequired;
  final String? helperText;
  final String? errorText;
  final bool autofocus;
  final FocusNode? focusNode;

  const CustomTextField({
    super.key,
    required this.label,
    this.hint,
    this.initialValue,
    this.type = TextFieldType.text,
    this.controller,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled = true,
    this.readOnly = false,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.prefixText,
    this.suffixText,
    this.fillColor,
    this.borderColor,
    this.borderRadius,
    this.contentPadding,
    this.textStyle,
    this.labelStyle,
    this.hintStyle,
    this.isRequired = false,
    this.helperText,
    this.errorText,
    this.autofocus = false,
    this.focusNode,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late TextEditingController _controller;
  late bool _obscureText;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _obscureText = widget.obscureText;
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(CustomTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.obscureText != oldWidget.obscureText) {
      _obscureText = widget.obscureText;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty) ...[
          RichText(
            text: TextSpan(
              text: widget.label,
              style: widget.labelStyle ?? _getLabelStyle(theme),
              children: [
                if (widget.isRequired)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
        ],
        TextFormField(
          controller: _controller,
          focusNode: _focusNode,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          onTap: widget.onTap,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          obscureText: _obscureText,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          textInputAction: widget.textInputAction ?? _getTextInputAction(),
          keyboardType: widget.keyboardType ?? _getKeyboardType(),
          inputFormatters: widget.inputFormatters ?? _getInputFormatters(),
          autofocus: widget.autofocus,
          style: widget.textStyle ?? _getTextStyle(theme),
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helperText,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon,
            suffixIcon: _buildSuffixIcon(),
            prefixText: widget.prefixText,
            suffixText: widget.suffixText,
            filled: true,
            fillColor: widget.fillColor ?? theme.colorScheme.surface,
            contentPadding: widget.contentPadding ?? _getContentPadding(),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? AppDimensions.radiusM,
              ),
              borderSide: BorderSide(
                color: widget.borderColor ?? theme.colorScheme.outline,
                width: AppDimensions.borderWidth,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? AppDimensions.radiusM,
              ),
              borderSide: BorderSide(
                color: widget.borderColor ?? theme.colorScheme.outline,
                width: AppDimensions.borderWidth,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? AppDimensions.radiusM,
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: AppDimensions.borderWidthThick,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? AppDimensions.radiusM,
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: AppDimensions.borderWidthThick,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? AppDimensions.radiusM,
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.error,
                width: AppDimensions.borderWidthThick,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(
                widget.borderRadius ?? AppDimensions.radiusM,
              ),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.5),
                width: AppDimensions.borderWidth,
              ),
            ),
            hintStyle: widget.hintStyle ?? _getHintStyle(theme),
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    final theme = Theme.of(context);

    if (widget.type == TextFieldType.password) {
      return IconButton(
        icon: Icon(
          _obscureText ? Icons.visibility : Icons.visibility_off,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }
    return widget.suffixIcon;
  }

  TextInputAction _getTextInputAction() {
    switch (widget.type) {
      case TextFieldType.email:
        return TextInputAction.next;
      case TextFieldType.password:
        return TextInputAction.done;
      case TextFieldType.multiline:
        return TextInputAction.newline;
      default:
        return TextInputAction.next;
    }
  }

  TextInputType _getKeyboardType() {
    switch (widget.type) {
      case TextFieldType.email:
        return TextInputType.emailAddress;
      case TextFieldType.phone:
        return TextInputType.phone;
      case TextFieldType.number:
        return TextInputType.number;
      case TextFieldType.multiline:
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter> _getInputFormatters() {
    switch (widget.type) {
      case TextFieldType.phone:
        return [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(15),
        ];
      case TextFieldType.number:
        // ignore: deprecated_member_use
        return [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))];
      default:
        return [];
    }
  }

  TextStyle _getTextStyle(ThemeData theme) {
    return TextStyle(
      fontSize: AppDimensions.fontSizeM,
      color: theme.colorScheme.onSurface,
    );
  }

  TextStyle _getLabelStyle(ThemeData theme) {
    return TextStyle(
      fontSize: AppDimensions.fontSizeM,
      fontWeight: FontWeight.w500,
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  TextStyle _getHintStyle(ThemeData theme) {
    return TextStyle(
      fontSize: AppDimensions.fontSizeM,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
    );
  }

  EdgeInsets _getContentPadding() {
    return const EdgeInsets.symmetric(
      horizontal: AppDimensions.paddingM,
      vertical: AppDimensions.paddingM,
    );
  }
}
