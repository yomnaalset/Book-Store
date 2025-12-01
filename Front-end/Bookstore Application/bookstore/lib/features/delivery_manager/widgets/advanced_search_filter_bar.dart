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
                  initialValue: _selectedStatusFilter,
                  decoration: InputDecoration(
                    labelText: 'Status',
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
                        child: Text(_formatStatusText(option)),
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
                  initialValue: _selectedOrderTypeFilter,
                  decoration: InputDecoration(
                    labelText: 'Type',
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
                        child: Text(_formatOrderTypeText(option)),
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

  String _formatStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_delivery':
        return 'In Delivery';
      case 'delivered':
        return 'Delivered';
      case 'returned':
        return 'Returned';
      case 'waiting_for_delivery_manager':
        return 'Waiting for Delivery Manager';
      case 'assigned_to_delivery':
        return 'Assigned to Delivery';
      case 'delivery_in_progress':
        return 'Delivery In Progress';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'rejected_by_delivery_manager':
        return 'Rejected by Delivery Manager';
      case 'rejected_by_admin':
        return 'Rejected by Admin';
      default:
        // Format snake_case to Title Case
        return status
            .split('_')
            .map(
              (word) => word.isEmpty
                  ? ''
                  : word[0].toUpperCase() + word.substring(1).toLowerCase(),
            )
            .join(' ');
    }
  }

  String _formatOrderTypeText(String orderType) {
    switch (orderType.toLowerCase()) {
      case 'purchase':
        return 'Purchase';
      case 'borrowing':
        return 'Borrowing';
      case 'return_collection':
        return 'Return Collection';
      default:
        return orderType;
    }
  }
}
