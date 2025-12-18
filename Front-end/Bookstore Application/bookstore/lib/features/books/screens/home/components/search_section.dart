import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../../core/constants/app_colors.dart';
import '../../../../../../core/localization/app_localizations.dart';

class SearchSection extends StatefulWidget {
  const SearchSection({super.key});

  @override
  State<SearchSection> createState() => _SearchSectionState();
}

class _SearchSectionState extends State<SearchSection> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main Search Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: localizations.searchBooksAuthorsPlaceholder,
                    hintStyle: const TextStyle(
                      color: AppColors.hintText,
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.uranianBlue,
                      size: 24,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Voice Search Button
                        IconButton(
                          onPressed: _startVoiceSearch,
                          icon: const Icon(
                            Icons.mic_outlined,
                            color: AppColors.uranianBlue,
                            size: 22,
                          ),
                          tooltip: 'Voice Search',
                        ),
                        const SizedBox(width: 8),
                        // Camera Search Button
                        IconButton(
                          onPressed: _startImageSearch,
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            color: AppColors.uranianBlue,
                            size: 22,
                          ),
                          tooltip: 'Search by Image',
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.primaryText,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Search Field
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: localizations.searchBooksAuthorsPlaceholder,
                  hintStyle: const TextStyle(
                    color: AppColors.hintText,
                    fontSize: 16,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.uranianBlue,
                    size: 24,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.primaryText,
                ),
                onChanged: (value) {
                  // Handle search input
                  if (value.isNotEmpty) {
                    _onSearch(value);
                  }
                },
              );
            },
          ),

          const SizedBox(height: 12),

          // Quick Search Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final localizations = AppLocalizations.of(context);
                    return Row(
                      children: [
                        _buildQuickFilterChip(
                          'all_books',
                          localizations.allBooks,
                          true,
                        ),
                        _buildQuickFilterChip(
                          'new_arrivals',
                          localizations.newArrivals,
                          false,
                        ),
                        _buildQuickFilterChip(
                          'most_popular',
                          localizations.mostPopular,
                          false,
                        ),
                        _buildQuickFilterChip(
                          'fiction',
                          localizations.fiction,
                          false,
                        ),
                        _buildQuickFilterChip(
                          'non_fiction',
                          localizations.nonFiction,
                          false,
                        ),
                        _buildQuickFilterChip(
                          'science',
                          localizations.science,
                          false,
                        ),
                        _buildQuickFilterChip(
                          'technology',
                          localizations.technology,
                          false,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterChip(String key, String label, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.uranianBlue,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          _showSnackBar('Filter "$label" selected');
        },
        backgroundColor: AppColors.white,
        selectedColor: AppColors.uranianBlue,
        checkmarkColor: AppColors.white,
        side: const BorderSide(color: AppColors.uranianBlue, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  void _onSearch(String query) {
    if (query.isNotEmpty) {
      // Navigate to advanced search with the query
      Navigator.pushNamed(
        context,
        '/advanced-search',
        arguments: {'searchQuery': query},
      );
    }
  }

  void _startVoiceSearch() {
    _showSnackBar('Voice search feature coming soon!');
  }

  void _startImageSearch() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Search by Image',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Take a photo or upload an image of a book cover',
                    style: TextStyle(color: AppColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _pickImageFromCamera();
                          },
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.uranianBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _pickImageFromGallery();
                          },
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.uranianBlue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        _showSnackBar('Image captured! Search functionality coming soon.');
      }
    } catch (e) {
      _showSnackBar('Error capturing image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        _showSnackBar('Image selected! Search functionality coming soon.');
      }
    } catch (e) {
      _showSnackBar('Error selecting image: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.uranianBlue,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
