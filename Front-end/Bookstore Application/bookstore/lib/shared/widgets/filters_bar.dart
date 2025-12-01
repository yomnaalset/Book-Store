import 'package:flutter/material.dart';

class FiltersBar extends StatelessWidget {
  final List<FilterOption> filterOptions;
  final Map<String, dynamic> selectedFilters;
  final ValueChanged<Map<String, dynamic>> onFilterChanged;
  final VoidCallback? onClearFilters;

  const FiltersBar({
    super.key,
    required this.filterOptions,
    required this.selectedFilters,
    required this.onFilterChanged,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: filterOptions.map((option) {
                  final isSelected =
                      selectedFilters.containsKey(option.key) &&
                      selectedFilters[option.key] != null;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(option.label),
                      selected: isSelected,
                      onSelected: (selected) {
                        debugPrint(
                          'DEBUG: FilterChip ${option.key} selected: $selected',
                        );
                        final newFilters = Map<String, dynamic>.from(
                          selectedFilters,
                        );
                        if (selected) {
                          // Clear other filters first (single selection)
                          newFilters.clear();
                          newFilters[option.key] = option.defaultValue;
                        } else {
                          newFilters.remove(option.key);
                        }
                        debugPrint('DEBUG: New filters: $newFilters');
                        onFilterChanged(newFilters);
                      },
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      checkmarkColor: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (selectedFilters.isNotEmpty && onClearFilters != null)
            TextButton(
              onPressed: onClearFilters,
              child: Text(
                'Clear',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
        ],
      ),
    );
  }
}

class FilterOption {
  final String key;
  final String label;
  final dynamic defaultValue;

  const FilterOption({
    required this.key,
    required this.label,
    required this.defaultValue,
  });
}
