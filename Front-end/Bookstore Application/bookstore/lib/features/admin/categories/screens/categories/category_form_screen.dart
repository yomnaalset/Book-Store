import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/categories_provider.dart';
import '../../../models/category.dart';
import '../../../../auth/providers/auth_provider.dart';

class CategoryFormScreen extends StatefulWidget {
  final Category? category;

  const CategoryFormScreen({super.key, this.category});

  @override
  State<CategoryFormScreen> createState() => _CategoryFormScreenState();
}

class _CategoryFormScreenState extends State<CategoryFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isActive = true; // Add active status control

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _populateForm();
    }
  }

  void _populateForm() {
    final category = widget.category!;
    _nameController.text = category.name;
    _descriptionController.text = category.description ?? '';
    _isActive =
        category.isActive; // Set the active status from existing category
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<CategoriesProvider>();
      final authProvider = context.read<AuthProvider>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      debugPrint(
        'DEBUG: Category form - User authenticated: ${authProvider.isAuthenticated}',
      );
      debugPrint(
        'DEBUG: Category form - Token available: ${authProvider.token != null}',
      );

      // Ensure the provider has the latest token
      if (authProvider.token != null) {
        provider.setToken(authProvider.token);
        debugPrint(
          'DEBUG: Category form - Updated provider with token: ${authProvider.token!.substring(0, 20)}...',
        );
      } else {
        debugPrint(
          'DEBUG: Category form - No token available from AuthProvider',
        );
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Authentication required. Please log in again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (widget.category == null) {
        final success = await provider.createCategory(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? ''
              : _descriptionController.text.trim(),
          isActive: _isActive,
        );
        if (mounted) {
          if (success) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Category created successfully')),
            );
          } else {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(provider.error ?? 'Failed to create category'),
                backgroundColor: Colors.red,
              ),
            );
            return; // Don't navigate back if creation failed
          }
        }
      } else {
        final success = await provider.updateCategory(
          id: int.parse(widget.category!.id),
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? ''
              : _descriptionController.text.trim(),
          isActive: _isActive,
        );
        if (mounted) {
          if (success) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Category updated successfully')),
            );
          } else {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(provider.error ?? 'Failed to update category'),
                backgroundColor: Colors.red,
              ),
            );
            return; // Don't navigate back if update failed
          }
        }
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to save category';

        // Check for specific error types
        if (e.toString().contains('401')) {
          errorMessage = 'Authentication failed. Please log in again.';
        } else if (e.toString().contains('400')) {
          errorMessage = 'Invalid data. Please check your input.';
        } else if (e.toString().contains('500')) {
          errorMessage = 'Server error. Please try again later.';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.category == null ? 'Create Category' : 'Edit Category',
        ),
        actions: [
          if (widget.category != null)
            IconButton(
              onPressed: _isLoading ? null : () => _deleteCategory(),
              icon: const Icon(Icons.delete),
              color: Colors.red,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.category, color: Colors.blue),
                                SizedBox(width: 12),
                                Text(
                                  'Category Information',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Name Field
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Category Name *',
                                border: OutlineInputBorder(),
                                hintText: 'Enter category name',
                                prefixIcon: Icon(Icons.category),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Category name is required';
                                }
                                if (value.trim().length < 2) {
                                  return 'Category name must be at least 2 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Description Field
                            TextFormField(
                              controller: _descriptionController,
                              decoration: const InputDecoration(
                                labelText: 'Description',
                                border: OutlineInputBorder(),
                                hintText:
                                    'Enter category description (optional)',
                                prefixIcon: Icon(Icons.description),
                              ),
                              maxLines: 3,
                            ),
                            const SizedBox(height: 16),

                            // Active Status Toggle
                            Card(
                              color: _isActive
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.red.withValues(alpha: 0.1),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isActive
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: _isActive
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Category Status',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: _isActive
                                                  ? Colors.green[700]
                                                  : Colors.red[700],
                                            ),
                                          ),
                                          Text(
                                            _isActive
                                                ? 'This category is active and visible to users'
                                                : 'This category is inactive and hidden from users',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _isActive
                                                  ? Colors.green[600]
                                                  : Colors.red[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch(
                                      value: _isActive,
                                      onChanged: (value) {
                                        setState(() {
                                          _isActive = value;
                                        });
                                      },
                                      activeThumbColor: Colors.green,
                                      inactiveThumbColor: Colors.red,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveCategory,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : Text(
                                widget.category == null
                                    ? 'Create Category'
                                    : 'Update Category',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _deleteCategory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Are you sure you want to delete "${widget.category!.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        if (!mounted) return;
        final provider = context.read<CategoriesProvider>();
        await provider.deleteCategory(int.parse(widget.category!.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category deleted successfully')),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
