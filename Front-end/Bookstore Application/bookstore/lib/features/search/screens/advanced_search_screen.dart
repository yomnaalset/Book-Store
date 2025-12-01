import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Search'),
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
              _buildSectionTitle('Search by Book Name'),
              CustomTextField(
                controller: _searchController,
                label: 'Book Title or Name',
                hint: 'Enter book title or name',
                prefixIcon: const Icon(Icons.search),
              ),
              const SizedBox(height: AppDimensions.spacingL),

              // Search by Author
              _buildSectionTitle('Search by Author'),
              CustomTextField(
                controller: _authorController,
                label: 'Author Name',
                hint: 'Enter author name (partial matches supported)',
                prefixIcon: const Icon(Icons.person),
              ),
              const SizedBox(height: AppDimensions.spacingL),

              // Search by Category
              _buildSectionTitle('Search by Category'),
              CustomTextField(
                controller: _categoryController,
                label: 'Category Name',
                hint: 'Enter category name',
                prefixIcon: const Icon(Icons.category),
              ),
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

              // Sort Options
              _buildSectionTitle('Sort By'),
              _buildSortSelector(),
              const SizedBox(height: AppDimensions.spacingXL),

              // Search Button
              SizedBox(
                width: double.infinity,
                child: CustomButton(
                  text: 'Search Books',
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
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Books')),
            DropdownMenuItem(value: 'available', child: Text('Available Only')),
            DropdownMenuItem(value: 'borrow_only', child: Text('Borrow Only')),
            DropdownMenuItem(
              value: 'purchase_only',
              child: Text('Purchase Only'),
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
            DropdownMenuItem(value: 'relevance', child: Text('Most Relevant')),
            DropdownMenuItem(value: 'newest', child: Text('Newest First')),
            DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
            DropdownMenuItem(
              value: 'price_low',
              child: Text('Price: Low to High'),
            ),
            DropdownMenuItem(
              value: 'price_high',
              child: Text('Price: High to Low'),
            ),
            DropdownMenuItem(value: 'rating', child: Text('Highest Rated')),
            DropdownMenuItem(
              value: 'most_borrowed',
              child: Text('Most Borrowed'),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
