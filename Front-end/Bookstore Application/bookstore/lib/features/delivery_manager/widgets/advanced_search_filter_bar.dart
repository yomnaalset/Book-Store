import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';

class AdvancedSearchFilterBar extends StatefulWidget {
  final String? initialSearchQuery;
  final String? initialStatusFilter;
  final String? initialOrderTypeFilter;
  final List<String> statusFilterOptions;
  final List<String> orderTypeFilterOptions;
  final Function(String) onSearchChanged;
  final Function(String?) onStatusFilterChanged;
  final Function(String?) onOrderTypeFilterChanged;
  final String searchHint;

  const AdvancedSearchFilterBar({
    super.key,
    this.initialSearchQuery,
    this.initialStatusFilter,
    this.initialOrderTypeFilter,
    required this.statusFilterOptions,
    required this.orderTypeFilterOptions,
    required this.onSearchChanged,
    required this.onStatusFilterChanged,
    required this.onOrderTypeFilterChanged,
    required this.searchHint,
  });

  @override
  State<AdvancedSearchFilterBar> createState() =>
      _AdvancedSearchFilterBarState();
}

class _AdvancedSearchFilterBarState extends State<AdvancedSearchFilterBar> {
  late TextEditingController _searchController;
  String? _selectedStatusFilter;
  String? _selectedOrderTypeFilter;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: widget.initialSearchQuery ?? '',
    );
    _selectedStatusFilter = widget.initialStatusFilter;
    _selectedOrderTypeFilter = widget.initialOrderTypeFilter;
  }

  @override
  void didUpdateWidget(AdvancedSearchFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync filter values when parent updates them
    if (widget.initialStatusFilter != oldWidget.initialStatusFilter) {
      _selectedStatusFilter = widget.initialStatusFilter;
    }
    if (widget.initialOrderTypeFilter != oldWidget.initialOrderTypeFilter) {
      _selectedOrderTypeFilter = widget.initialOrderTypeFilter;
    }
    // Sync search query if changed externally
    if (widget.initialSearchQuery != oldWidget.initialSearchQuery) {
      final currentText = _searchController.text;
      final oldInitialText = oldWidget.initialSearchQuery ?? '';
      if (currentText == oldInitialText) {
        _searchController.text = widget.initialSearchQuery ?? '';
      }
    }
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

          // Filter Bars
          Row(
            children: [
              // Status Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('status_$_selectedStatusFilter'),
                  initialValue: _selectedStatusFilter,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).status,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(AppLocalizations.of(context).all),
                    ),
                    ...widget.statusFilterOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              _formatStatusText(option, localizations),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusFilter = value;
                    });
                    widget.onStatusFilterChanged(value);
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Order Type Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('type_$_selectedOrderTypeFilter'),
                  initialValue: _selectedOrderTypeFilter,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).type,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(AppLocalizations.of(context).all),
                    ),
                    ...widget.orderTypeFilterOptions.map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Builder(
                          builder: (context) {
                            final localizations = AppLocalizations.of(context);
                            return Text(
                              _formatOrderTypeText(option, localizations),
                            );
                          },
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedOrderTypeFilter = value;
                    });
                    widget.onOrderTypeFilterChanged(value);
                  },
                ),
              ),

              const SizedBox(width: 12),

              // Clear Filters Button
              if (_searchController.text.isNotEmpty ||
                  _selectedStatusFilter != null ||
                  _selectedOrderTypeFilter != null)
                IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _selectedStatusFilter = null;
                      _selectedOrderTypeFilter = null;
                    });
                    widget.onSearchChanged('');
                    widget.onStatusFilterChanged(null);
                    widget.onOrderTypeFilterChanged(null);
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

  String _formatStatusText(String status, AppLocalizations localizations) {
    // Use getOrderStatusLabel for order statuses
    final localizedStatus = localizations.getOrderStatusLabel(status);
    // If the localized status is different from the raw status, use it
    if (localizedStatus.toLowerCase() != status.toLowerCase()) {
      return localizedStatus;
    }
    // Fallback to formatting snake_case to Title Case
    return status
        .split('_')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  String _formatOrderTypeText(
    String orderType,
    AppLocalizations localizations,
  ) {
    switch (orderType.toLowerCase()) {
      case 'purchase':
        return localizations.purchase;
      case 'borrowing':
        return localizations.borrowing;
      case 'return_collection':
        return localizations.returnCollection;
      default:
        return orderType;
    }
  }
}
