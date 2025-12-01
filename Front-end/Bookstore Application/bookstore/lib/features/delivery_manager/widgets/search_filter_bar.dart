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
  String? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );
    _selectedFilter = widget.initialFilterValue;
  }

  @override
  void dispose() {
    _searchController.dispose();
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
            decoration: InputDecoration(
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        widget.onSearchChanged('');
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
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              filled: true,
              fillColor: theme.colorScheme.surface,
            ),
            onChanged: (value) {
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
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
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
