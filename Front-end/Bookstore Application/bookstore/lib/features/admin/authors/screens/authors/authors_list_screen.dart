import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/library_manager/authors_provider.dart';
import '../../../models/author.dart';
import '../../../widgets/library_manager/admin_search_bar.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../../../../routes/app_routes.dart';
import '../../../../auth/providers/auth_provider.dart';

class AuthorsListScreen extends StatefulWidget {
  const AuthorsListScreen({super.key});

  @override
  State<AuthorsListScreen> createState() => _AuthorsListScreenState();
}

class _AuthorsListScreenState extends State<AuthorsListScreen> {
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadAuthors();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAuthors() async {
    debugPrint('DEBUG: AuthorsListScreen - Loading authors...');
    debugPrint('DEBUG: AuthorsListScreen - Search query: "$_searchQuery"');

    final provider = context.read<AuthorsProvider>();
    final authProvider = context.read<AuthProvider>();

    // Ensure the provider has the latest token
    if (authProvider.token != null) {
      provider.setToken(authProvider.token);
    }

    await provider.loadAuthors(
      search: _searchQuery.isEmpty ? null : _searchQuery,
    );

    debugPrint(
      'DEBUG: AuthorsListScreen - Authors loaded: ${provider.authors.length}',
    );
  }

  void _onSearch(String query) {
    debugPrint('DEBUG: AuthorsListScreen - Search query: "$query"');
    setState(() {
      _searchQuery = query;
    });

    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set up debounced search
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadAuthors();
    });
  }

  void _onSearchImmediate(String query) {
    debugPrint('DEBUG: AuthorsListScreen - Immediate search query: "$query"');
    setState(() {
      _searchQuery = query;
    });
    _loadAuthors();
  }

  void _navigateToAuthorForm([Author? author]) {
    Navigator.pushNamed(
      context,
      AppRoutes.libraryAuthorForm,
      arguments: author != null ? {'author': author} : null,
    ).then((_) => _loadAuthors());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Authors'),
        actions: [
          IconButton(
            onPressed: () => _loadAuthors(),
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
              hintText: 'Search authors...',
              onSubmitted: _onSearchImmediate,
              onChanged: _onSearch,
            ),
          ),

          // Authors List
          Expanded(
            child: Consumer<AuthorsProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.authors.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null && provider.authors.isEmpty) {
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
                          onPressed: _loadAuthors,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.authors.isEmpty) {
                  return EmptyState(
                    title: 'No Authors',
                    message: 'No authors found',
                    icon: Icons.person,
                    actionText: 'Add Author',
                    onAction: () => _navigateToAuthorForm(),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: provider.authors.length,
                  itemBuilder: (context, index) {
                    final author = provider.authors[index];
                    return _buildAuthorCard(author);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAuthorForm(),
        tooltip: 'Add Author',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAuthorCard(Author author) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.purple.withValues(alpha: (0.1)),
          child: const Icon(Icons.person, color: Colors.purple),
        ),
        title: Text(
          author.name,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (author.biography != null) ...[
              const SizedBox(height: 4),
              Text(
                author.biography!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (author.birthDate != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: (0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Born: ${author.birthDate ?? 'Unknown'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (author.photo != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: (0.1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Has Photo',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (author.createdAt != DateTime.now()) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Added: ${_formatDate(author.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _navigateToAuthorForm(author);
                break;
              case 'delete':
                _deleteAuthor(author);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _navigateToAuthorForm(author),
      ),
    );
  }

  Future<void> _deleteAuthor(Author author) async {
    // Check user permissions first
    final authProvider = context.read<AuthProvider>();
    if (authProvider.userRole != 'library_admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only library administrators can delete authors'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Author'),
        content: Text(
          'Are you sure you want to delete "${author.name}"? This action cannot be undone.',
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
      try {
        if (!mounted) return;
        final provider = context.read<AuthorsProvider>();
        final authProvider = context.read<AuthProvider>();

        // Ensure the provider has the latest token
        if (authProvider.token != null) {
          provider.setToken(authProvider.token);
        }

        await provider.deleteAuthor(int.parse(author.id));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Author deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
          // Reload the authors list
          _loadAuthors();
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = e.toString();
          if (errorMessage.contains('Permission denied') ||
              errorMessage.contains('403') ||
              errorMessage.contains('Unauthorized')) {
            errorMessage =
                'You do not have permission to delete authors. Only library administrators can delete authors.';
          } else if (errorMessage.contains('AUTHOR_HAS_BOOKS')) {
            errorMessage =
                'Cannot delete this author because they have books in the library. Please remove or reassign all books first.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMessage'),
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
