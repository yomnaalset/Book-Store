import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../models/category.dart';
import '../../../widgets/library_manager/admin_search_bar.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../../../core/localization/app_localizations.dart';
import 'category_form_screen.dart';

class CategoriesListScreen extends StatefulWidget {
  const CategoriesListScreen({super.key});

  @override
  State<CategoriesListScreen> createState() => _CategoriesListScreenState();
}

class _CategoriesListScreenState extends State<CategoriesListScreen> {
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    debugPrint('DEBUG: CategoriesListScreen - Loading categories...');
    debugPrint('DEBUG: CategoriesListScreen - Search query: "$_searchQuery"');
    final provider = context.read<CategoriesProvider>();
    await provider.getCategories(
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );
    debugPrint(
      'DEBUG: CategoriesListScreen - Categories loaded: ${provider.categories.length}',
    );
  }

  void _onSearch(String query) {
    debugPrint('DEBUG: CategoriesListScreen - Search query: "$query"');
    setState(() {
      _searchQuery = query;
    });

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set up debounced search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadCategories();
    });
  }

  void _onSearchImmediate(String query) {
    debugPrint(
      'DEBUG: CategoriesListScreen - Immediate search query: "$query"',
    );
    setState(() {
      _searchQuery = query;
    });
    _loadCategories();
  }

  void _navigateToCategoryForm([Category? category]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryFormScreen(category: category),
      ),
    ).then((_) => _loadCategories());
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.categories),
        actions: [
          IconButton(
            onPressed: () => _loadCategories(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AdminSearchBar(
              hintText: localizations.searchCategories,
              onSubmitted: _onSearchImmediate,
              onChanged: _onSearch,
            ),
          ),

          // Categories List
          Expanded(
            child: Consumer<CategoriesProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.categories.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.categories.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Error: ${provider.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadCategories,
                          child: Text(localizations.retry),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.categories.isEmpty) {
                  return EmptyState(
                    title: localizations.noCategories,
                    message: localizations.noCategoriesFound,
                    icon: Icons.category,
                    actionText: localizations.addCategory,
                    onAction: () => _navigateToCategoryForm(),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: provider.categories.length,
                  itemBuilder: (context, index) {
                    final category = provider.categories[index];
                    return _buildCategoryCard(category);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCategoryForm(),
        tooltip: localizations.addCategory,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryCard(Category category) {
    final localizations = AppLocalizations.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          child: const Icon(Icons.category, color: Colors.blue),
        ),
        title: Text(
          category.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category.description != null) ...[
              const SizedBox(height: 4),
              Text(
                category.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${localizations.createdLabel} ${_formatDate(category.createdAt)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _navigateToCategoryForm(category);
                break;
              case 'delete':
                _deleteCategory(category);
                break;
            }
          },
          itemBuilder: (context) {
            final localizations = AppLocalizations.of(context);
            return [
              PopupMenuItem(value: 'edit', child: Text(localizations.edit)),
              PopupMenuItem(value: 'delete', child: Text(localizations.delete)),
            ];
          },
        ),
        onTap: () => _navigateToCategoryForm(category),
      ),
    );
  }

  Future<void> _deleteCategory(Category category) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(localizations.deleteCategory),
        content: Text(localizations.deleteCategoryConfirmation(category.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(localizations.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(localizations.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (!mounted) return;
        final provider = context.read<CategoriesProvider>();
        final authProvider = context.read<AuthProvider>();

        // Ensure the provider has the latest token
        if (authProvider.token != null) {
          provider.setToken(authProvider.token);
        }

        final success = await provider.deleteCategory(int.parse(category.id));

        if (mounted) {
          final localizations = AppLocalizations.of(context);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(localizations.categoryDeletedSuccessfully),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  provider.error ?? localizations.failedToDeleteCategory,
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          final localizations = AppLocalizations.of(context);
          String errorMessage = localizations.failedToDeleteCategory;

          // Check if it's a business logic error (category has books)
          if (e.toString().contains('book(s) assigned to it')) {
            errorMessage = localizations.cannotDeleteCategoryWithBooks(
              category.name,
            );
          } else if (e.toString().contains('401')) {
            errorMessage = localizations.authenticationFailedPleaseLogInAgain;
          } else {
            errorMessage = '${localizations.error}: ${e.toString()}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
