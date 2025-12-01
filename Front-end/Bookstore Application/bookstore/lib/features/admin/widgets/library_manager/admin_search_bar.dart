import 'package:flutter/material.dart';

class AdminSearchBar extends StatefulWidget {
  final String? hintText;
  final String? initialValue;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final bool showFilter;
  final VoidCallback? onFilterTap;
  final Widget? leading;
  final Widget? trailing;
  final bool enabled;
  final TextInputType keyboardType;
  final EdgeInsetsGeometry? contentPadding;

  const AdminSearchBar({
    super.key,
    this.hintText,
    this.initialValue,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.showFilter = false,
    this.onFilterTap,
    this.leading,
    this.trailing,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
    this.contentPadding,
  });

  @override
  State<AdminSearchBar> createState() => _AdminSearchBarState();
}

class _AdminSearchBarState extends State<AdminSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();

    // Listen to text changes to update the UI
    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor, width: 1),
      ),
      child: Row(
        children: [
          if (widget.leading != null) ...[
            widget.leading!,
            const SizedBox(width: 8),
          ],

          // Search icon
          Icon(Icons.search, color: theme.hintColor, size: 20),
          const SizedBox(width: 12),

          // Search input
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              keyboardType: widget.keyboardType,
              decoration: InputDecoration(
                hintText: widget.hintText ?? 'Search...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
                contentPadding: widget.contentPadding ?? EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),

          // Clear button
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: theme.hintColor, size: 18),
              onPressed: () {
                _controller.clear();
                widget.onClear?.call();
                widget.onChanged?.call('');
                widget.onSubmitted?.call('');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),

          // Filter button
          if (widget.showFilter) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.filter_list,
                color: theme.primaryColor,
                size: 20,
              ),
              onPressed: widget.onFilterTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],

          if (widget.trailing != null) ...[
            const SizedBox(width: 8),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}
