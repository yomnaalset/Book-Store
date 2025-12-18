import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';

class SearchFilterBar extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialFilterValue;
  final List<String> filterOptions;
  final Function(String) onSearchChanged;
  final Function(String?) onFilterChanged;
  final String searchHint;
  final String filterLabel;

  const SearchFilterBar({
    super.key,
    this.initialSearchQuery,
    this.initialFilterValue,
    required this.filterOptions,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.searchHint,
    required this.filterLabel,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  String? _selectedFilter;
  Timer? _debounceTimer;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );
    _focusNode = FocusNode();
    _selectedFilter = widget.initialFilterValue;
    _hasText = _searchController.text.isNotEmpty;

    // Listen to text changes to update clear button visibility without setState
    _searchController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _searchController.text.isNotEmpty;
    if (_hasText != hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
  }

  @override
  void didUpdateWidget(SearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller text only if:
    // 1. initialSearchQuery changed externally
    // 2. Current controller text matches old initialSearchQuery (hasn't been edited locally)
    // This prevents overwriting user input while typing
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      final currentText = _searchController.text;
      final oldInitialText = oldWidget.initialSearchQuery ?? '';
      // Only sync if controller hasn't been edited locally (matches old initial value)
      if (currentText == oldInitialText) {
        _searchController.text = widget.initialSearchQuery ?? '';
        _hasText = _searchController.text.isNotEmpty;
      }
    }
    // Sync filter value if it changed externally
    if (widget.initialFilterValue != oldWidget.initialFilterValue) {
      _selectedFilter = widget.initialFilterValue;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onTextChanged);
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            controller: _searchController,
            focusNode: _focusNode,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _hasText
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _debounceTimer?.cancel();
                        _searchController.clear();
                        widget.onSearchChanged('');
                        // Keep focus after clearing
                        _focusNode.requestFocus();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
            onChanged: (value) {
              // Cancel previous timer
              _debounceTimer?.cancel();

              // Update hasText state for clear button visibility
              final hasText = value.isNotEmpty;
              if (_hasText != hasText) {
                setState(() {
                  _hasText = hasText;
                });
              }

              // Debounce the API call - wait 800ms after user stops typing
              if (value.isNotEmpty) {
                _debounceTimer = Timer(const Duration(milliseconds: 800), () {
                  widget.onSearchChanged(value);
                });
              } else {
                // If empty, search immediately
                widget.onSearchChanged('');
              }
            },
            onSubmitted: (value) {
              // Cancel debounce and search immediately on submit
              _debounceTimer?.cancel();
              widget.onSearchChanged(value);
            },
          ),

          const SizedBox(height: 12),

          // Filter Bar
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedFilter,
                  decoration: InputDecoration(
                    labelText: widget.filterLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary),
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(AppLocalizations.of(context).all),
                    ),
                    ...widget.filterOptions.map((option) {
                      // Use localized status label - try all methods and use the best match
                      final localizations = AppLocalizations.of(context);

                      // Try getReturnRequestStatusLabel first (for return requests)
                      final returnRequestLabel = localizations
                          .getReturnRequestStatusLabel(option);

                      // Try getBorrowStatusLabel (for borrow requests)
                      final borrowLabel = localizations.getBorrowStatusLabel(
                        option,
                      );

                      // Try getOrderStatusLabel (for purchase orders)
                      final orderLabel = localizations.getOrderStatusLabel(
                        option,
                      );

                      // Check if labels are just formatted (default fallback)
                      // The default fallback formats like "Waiting For Delivery Manager" or "Assigned"
                      final formattedFallback = option
                          .split('_')
                          .map((word) {
                            if (word.isEmpty) return word;
                            return word[0].toUpperCase() +
                                word.substring(1).toLowerCase();
                          })
                          .join(' ');

                      // Determine which label to use:
                      // 1. Priority: getReturnRequestStatusLabel (for return requests)
                      // 2. If returnRequestLabel is just formatted, try borrowLabel
                      // 3. If borrowLabel is just formatted, try orderLabel
                      // 4. If all are formatted, use returnRequestLabel as it's most specific
                      String displayText;
                      if (returnRequestLabel.toLowerCase() !=
                              option.toLowerCase() &&
                          returnRequestLabel.toLowerCase() !=
                              formattedFallback.toLowerCase()) {
                        // getReturnRequestStatusLabel found a translation
                        displayText = returnRequestLabel;
                      } else if (borrowLabel.toLowerCase() !=
                              option.toLowerCase() &&
                          borrowLabel.toLowerCase() !=
                              formattedFallback.toLowerCase()) {
                        // getBorrowStatusLabel found a translation
                        displayText = borrowLabel;
                      } else if (orderLabel.toLowerCase() !=
                              option.toLowerCase() &&
                          orderLabel.toLowerCase() !=
                              formattedFallback.toLowerCase()) {
                        // getOrderStatusLabel found a translation
                        displayText = orderLabel;
                      } else {
                        // All methods returned formatted fallback, use returnRequestLabel as it's most specific
                        displayText = returnRequestLabel;
                      }

                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(displayText),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value;
                    });
                    widget.onFilterChanged(value);
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Clear Filters Button
              if (_searchController.text.isNotEmpty || _selectedFilter != null)
                IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _selectedFilter = null;
                    });
                    widget.onSearchChanged('');
                    widget.onFilterChanged(null);
                  },
                  icon: const Icon(Icons.clear_all),
                  tooltip: AppLocalizations.of(context).clear,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
