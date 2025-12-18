import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/common/custom_button.dart';
import '../../../core/widgets/common/custom_text_field.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _authorController = TextEditingController();
  final _categoryController = TextEditingController();

  String _selectedSortBy = 'relevance';
  String _selectedPriceRange = 'all';
  String _selectedRating = 'all';
  String _selectedAvailability = 'all';

  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSearchQuery();
    });
  }

  void _initializeSearchQuery() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && args['searchQuery'] != null) {
      _searchController.text = args['searchQuery'] as String;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _authorController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.advancedSearch),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search by Name
              _buildSectionTitle(localizations.searchByBookName),
              CustomTextField(
                controller: _searchController,
                label: localizations.bookTitleOrName,
                hint: localizations.enterBookTitleOrName,
                prefixIcon: const Icon(Icons.search),
              ),
              const SizedBox(height: AppDimensions.spacingL),

              // Search by Author
              _buildSectionTitle(localizations.searchByAuthor),
              CustomTextField(
                controller: _authorController,
                label: localizations.authorNameLabel,
                hint: localizations.enterAuthorName,
                prefixIcon: const Icon(Icons.person),
              ),
              const SizedBox(height: AppDimensions.spacingL),

              // Search by Category
              _buildSectionTitle(localizations.searchByCategory),
              CustomTextField(
                controller: _categoryController,
                label: localizations.categoryNameLabel,
                hint: localizations.enterCategoryName,
                prefixIcon: const Icon(Icons.category),
              ),
              const SizedBox(height: AppDimensions.spacingL),

              // Price Range Filter
              _buildSectionTitle(localizations.priceRange),
              _buildPriceRangeSelector(),
              const SizedBox(height: AppDimensions.spacingL),

              // Rating Filter
              _buildSectionTitle(localizations.minimumRating),
              _buildRatingSelector(),
              const SizedBox(height: AppDimensions.spacingL),

              // Availability Filter
              _buildSectionTitle(localizations.availabilityFilter),
              _buildAvailabilitySelector(),
              const SizedBox(height: AppDimensions.spacingL),

              // Sort Options
              _buildSectionTitle(localizations.sortByLabel),
              _buildSortSelector(),
              const SizedBox(height: AppDimensions.spacingXL),

              // Search Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: localizations.searchBooks,
                  onPressed: _performSearch,
                  isLoading: _isSearching,
                ),
              ),

              const SizedBox(height: AppDimensions.spacingXL),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.bodyLarge?.color,
      ),
    );
  }

  Widget _buildPriceRangeSelector() {
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
          value: _selectedPriceRange,
          isExpanded: true,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text(localizations.allPrices),
            ),
            DropdownMenuItem(
              value: '0-10',
              child: Text(localizations.priceRange010),
            ),
            DropdownMenuItem(
              value: '10-25',
              child: Text(localizations.priceRange1025),
            ),
            DropdownMenuItem(
              value: '25-50',
              child: Text(localizations.priceRange2550),
            ),
            DropdownMenuItem(
              value: '50-100',
              child: Text(localizations.priceRange50100),
            ),
            DropdownMenuItem(
              value: '100+',
              child: Text(localizations.priceRange100Plus),
            ),
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
          value: _selectedRating,
          isExpanded: true,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          items: [
            DropdownMenuItem(
              value: 'all',
              child: Text(localizations.allRatings),
            ),
            DropdownMenuItem(
              value: '4',
              child: Text(localizations.rating4Plus),
            ),
            DropdownMenuItem(
              value: '3',
              child: Text(localizations.rating3Plus),
            ),
            DropdownMenuItem(
              value: '2',
              child: Text(localizations.rating2Plus),
            ),
            DropdownMenuItem(
              value: '1',
              child: Text(localizations.rating1Plus),
            ),
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
            DropdownMenuItem(value: 'all', child: Text(localizations.allBooks)),
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
  }

  Widget _buildSortSelector() {
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
          value: _selectedSortBy,
          isExpanded: true,
          dropdownColor: Theme.of(context).cardColor,
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          items: [
            DropdownMenuItem(
              value: 'relevance',
              child: Text(localizations.mostRelevant),
            ),
            DropdownMenuItem(
              value: 'newest',
              child: Text(localizations.newestFirstSort),
            ),
            DropdownMenuItem(
              value: 'oldest',
              child: Text(localizations.oldestFirstSort),
            ),
            DropdownMenuItem(
              value: 'price_low',
              child: Text(localizations.priceLowToHighSort),
            ),
            DropdownMenuItem(
              value: 'price_high',
              child: Text(localizations.priceHighToLowSort),
            ),
            DropdownMenuItem(
              value: 'rating',
              child: Text(localizations.highestRatedSort),
            ),
            DropdownMenuItem(
              value: 'most_borrowed',
              child: Text(localizations.mostBorrowedSort),
            ),
            DropdownMenuItem(
              value: 'title',
              child: Text(localizations.titleAZ),
            ),
            DropdownMenuItem(
              value: 'author',
              child: Text(localizations.authorAZ),
            ),
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

  Future<void> _performSearch() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Navigate to Search Results page with search parameters
      Navigator.pushNamed(
        context,
        '/search-results',
        arguments: {
          'searchQuery': _searchController.text.trim(),
          'authorQuery': _authorController.text.trim().isNotEmpty
              ? _authorController.text.trim()
              : null,
          'categoryQuery': _categoryController.text.trim().isNotEmpty
              ? _categoryController.text.trim()
              : null,
          'priceRange': _selectedPriceRange,
          'rating': _selectedRating,
          'availability': _selectedAvailability,
          'sortBy': _selectedSortBy,
        },
      );

      setState(() {
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
      });

      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.searchFailedError(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
