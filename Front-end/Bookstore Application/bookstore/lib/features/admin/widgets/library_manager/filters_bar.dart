import 'package:flutter/material.dart';

class FiltersBar extends StatelessWidget {
  final List<String> filterOptions;
  final String? selectedFilter;
  final ValueChanged<String?> onFilterChanged;
  final VoidCallback? onClearFilters;

  const FiltersBar({
    super.key,
    required this.filterOptions,
    this.selectedFilter,
    required this.onFilterChanged,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(context, 'All', null),
                  const SizedBox(width: 8),
                  ...filterOptions.map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(context, filter, filter),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selectedFilter != null)
            IconButton(
              icon: const Icon(Icons.clear, size: 20),
              onPressed: onClearFilters,
              tooltip: 'Clear filters',
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String? value) {
    final isSelected = selectedFilter == value;

    return GestureDetector(
      onTap: () {
        onFilterChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
