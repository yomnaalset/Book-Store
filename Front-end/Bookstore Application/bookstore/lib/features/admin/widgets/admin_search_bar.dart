import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';

class AdminSearchBar extends StatefulWidget {
  final String? hintText;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final Function()? onClear;
  final TextEditingController? controller;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final double? width;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AdminSearchBar({
    super.key,
    this.hintText = 'Search...',
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.controller,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.width,
    this.margin,
    this.padding,
  });

  @override
  State<AdminSearchBar> createState() => _AdminSearchBarState();
}

class _AdminSearchBarState extends State<AdminSearchBar> {
  late TextEditingController _controller;
  bool _showClearButton = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_onTextChanged);
    _showClearButton = _controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (_showClearButton != hasText) {
      setState(() {
        _showClearButton = hasText;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _onClear() {
    _controller.clear();
    widget.onClear?.call();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      margin: widget.margin ?? const EdgeInsets.all(AppDimensions.spacingM),
      padding: widget.padding,
      child: TextField(
        controller: _controller,
        enabled: widget.enabled,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: AppDimensions.fontSizeM,
          ),
          prefixIcon:
              widget.prefixIcon ??
              const Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: _buildSuffixIcon(),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            borderSide: const BorderSide(
              color: AppColors.borderLight,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingM,
            vertical: AppDimensions.spacingS,
          ),
        ),
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: AppDimensions.fontSizeM,
        ),
      ),
    );
  }

  Widget? _buildSuffixIcon() {
    if (widget.suffixIcon != null) {
      return widget.suffixIcon;
    }

    if (_showClearButton) {
      return IconButton(
        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
        onPressed: _onClear,
        tooltip: 'Clear search',
      );
    }

    return null;
  }
}

// Specialized search bars for different admin sections
class BookSearchBar extends AdminSearchBar {
  const BookSearchBar({
    super.key,
    super.hintText = 'Search books by title, author, ISBN...',
    super.onChanged,
    super.onSubmitted,
    super.onClear,
    super.controller,
    super.enabled,
    super.width,
    super.margin,
    super.padding,
  });
}

class UserSearchBar extends AdminSearchBar {
  const UserSearchBar({
    super.key,
    super.hintText = 'Search users by name, email...',
    super.onChanged,
    super.onSubmitted,
    super.onClear,
    super.controller,
    super.enabled,
    super.width,
    super.margin,
    super.padding,
  });
}

class OrderSearchBar extends AdminSearchBar {
  const OrderSearchBar({
    super.key,
    super.hintText = 'Search orders by ID, customer...',
    super.onChanged,
    super.onSubmitted,
    super.onClear,
    super.controller,
    super.enabled,
    super.width,
    super.margin,
    super.padding,
  });
}

class DeliverySearchBar extends AdminSearchBar {
  const DeliverySearchBar({
    super.key,
    super.hintText = 'Search deliveries by order ID, address...',
    super.onChanged,
    super.onSubmitted,
    super.onClear,
    super.controller,
    super.enabled,
    super.width,
    super.margin,
    super.padding,
  });
}

class ComplaintSearchBar extends AdminSearchBar {
  const ComplaintSearchBar({
    super.key,
    super.hintText = 'Search complaints by title, user...',
    super.onChanged,
    super.onSubmitted,
    super.onClear,
    super.controller,
    super.enabled,
    super.width,
    super.margin,
    super.padding,
  });
}
