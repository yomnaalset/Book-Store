import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/constants/app_dimensions.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/common/custom_button.dart';
import '../../../providers/books_provider.dart';
import '../../../providers/categories_provider.dart';

class FilterBottomSheet extends StatefulWidget {
  const FilterBottomSheet({super.key});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String _selectedSortBy = 'newest';
  String _selectedCategory = 'all';
  String _selectedPriceRange = 'all';
  String _selectedRating = 'all';
  String _selectedAvailability = 'all';
  bool _isNewOnly = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),

          // Title
          Text(
            'Filter & Sort Books',
            style: TextStyle(
              fontSize: AppDimensions.fontSizeXL,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.headlineSmall?.color,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),

          // Sort By Section
          _buildSectionTitle('Sort By'),
          _buildSortSelector(),
          const SizedBox(height: AppDimensions.spacingL),

          // Category Filter
          _buildSectionTitle('Category'),
          _buildCategorySelector(),
          const SizedBox(height: AppDimensions.spacingL),

          // Price Range Filter
          _buildSectionTitle('Price Range'),
          _buildPriceRangeSelector(),
          const SizedBox(height: AppDimensions.spacingL),

          // Rating Filter
          _buildSectionTitle('Minimum Rating'),
          _buildRatingSelector(),
          const SizedBox(height: AppDimensions.spacingL),

          // Availability Filter
          _buildSectionTitle('Availability'),
          _buildAvailabilitySelector(),
          const SizedBox(height: AppDimensions.spacingL),

          // New Books Only Toggle
          _buildNewBooksToggle(),
          const SizedBox(height: AppDimensions.spacingL),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Clear All',
                  onPressed: _clearAllFilters,
                  type: ButtonType.secondary,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: CustomButton(
                  text: 'Apply Filters',
                  onPressed: _applyFilters,
                  type: ButtonType.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingL),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Text(
        title,
        style: TextStyle(
          fontSize: AppDimensions.fontSizeM,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildSortSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).cardColor,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSortBy,
          isExpanded: true,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          items: const [
            DropdownMenuItem(value: 'newest', child: Text('Newest First')),
            DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
            DropdownMenuItem(
              value: 'most_borrowed',
              child: Text('Most Borrowed'),
            ),
            DropdownMenuItem(
              value: 'price_low',
              child: Text('Price: Low to High'),
            ),
            DropdownMenuItem(
              value: 'price_high',
              child: Text('Price: High to Low'),
            ),
            DropdownMenuItem(value: 'rating', child: Text('Highest Rated')),
            DropdownMenuItem(value: 'title', child: Text('Title A-Z')),
            DropdownMenuItem(value: 'author', child: Text('Author A-Z')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedSortBy = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Consumer<CategoriesProvider>(
      builder: (context, categoriesProvider, child) {
        if (categoriesProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final categories = categoriesProvider.categories;
        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).cardColor,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              isExpanded: true,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              items: [
                const DropdownMenuItem(
                  value: 'all',
                  child: Text('All Categories'),
                ),
                ...categories.map(
                  (category) => DropdownMenuItem(
                    value: category.id.toString(),
                    child: Text(category.name),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).cardColor,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPriceRange,
          isExpanded: true,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Prices')),
            DropdownMenuItem(value: '0-10', child: Text('\$0 - \$10')),
            DropdownMenuItem(value: '10-25', child: Text('\$10 - \$25')),
            DropdownMenuItem(value: '25-50', child: Text('\$25 - \$50')),
            DropdownMenuItem(value: '50-100', child: Text('\$50 - \$100')),
            DropdownMenuItem(value: '100+', child: Text('\$100+')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedPriceRange = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildRatingSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).cardColor,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRating,
          isExpanded: true,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Ratings')),
            DropdownMenuItem(value: '4', child: Text('4+ Stars')),
            DropdownMenuItem(value: '3', child: Text('3+ Stars')),
            DropdownMenuItem(value: '2', child: Text('2+ Stars')),
            DropdownMenuItem(value: '1', child: Text('1+ Stars')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedRating = value!;
            });
          },
        ),
      ),
    );
  }

  Widget _buildAvailabilitySelector() {
    return Builder(
      builder: (context) {
        final localizations = AppLocalizations.of(context);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingM),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).cardColor,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedAvailability,
              isExpanded: true,
              dropdownColor: Theme.of(context).cardColor,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              items: [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(localizations.allBooks),
                ),
                DropdownMenuItem(
                  value: 'available',
                  child: Text(localizations.availableOnly),
                ),
                DropdownMenuItem(
                  value: 'borrow_only',
                  child: Text(localizations.borrowOnlyFilter),
                ),
                DropdownMenuItem(
                  value: 'purchase_only',
                  child: Text(localizations.purchaseOnly),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAvailability = value!;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewBooksToggle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'New Books Only',
            style: TextStyle(
              fontSize: AppDimensions.fontSizeM,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
        Switch(
          value: _isNewOnly,
          onChanged: (value) {
            setState(() {
              _isNewOnly = value;
            });
          },
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }

  void _clearAllFilters() {
    setState(() {
      _selectedSortBy = 'newest';
      _selectedCategory = 'all';
      _selectedPriceRange = 'all';
      _selectedRating = 'all';
      _selectedAvailability = 'all';
      _isNewOnly = false;
    });
  }

  void _applyFilters() {
    final booksProvider = Provider.of<BooksProvider>(context, listen: false);

    // Parse price range
    double? minPrice;
    double? maxPrice;
    if (_selectedPriceRange != 'all') {
      final parts = _selectedPriceRange.split('-');
      if (parts.length == 2) {
        minPrice = double.tryParse(parts[0]);
        maxPrice = double.tryParse(parts[1]);
      } else if (_selectedPriceRange == '100+') {
        minPrice = 100.0;
      }
    }

    // Parse rating
    double? minRating;
    if (_selectedRating != 'all') {
      minRating = double.tryParse(_selectedRating);
    }

    // Parse availability
    bool? availableToBorrow;
    if (_selectedAvailability == 'borrow_only') {
      availableToBorrow = true;
    } else if (_selectedAvailability == 'purchase_only') {
      availableToBorrow = false;
    }

    // Parse category
    int? categoryId;
    if (_selectedCategory != 'all') {
      categoryId = int.tryParse(_selectedCategory);
    }

    // Apply filters
    booksProvider.getBooks(
      search: null,
      categoryId: categoryId,
      minRating: minRating,
      minPrice: minPrice,
      maxPrice: maxPrice,
      availableToBorrow: availableToBorrow,
      newOnly: _isNewOnly,
      sortBy: _selectedSortBy,
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filters applied successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }
}
