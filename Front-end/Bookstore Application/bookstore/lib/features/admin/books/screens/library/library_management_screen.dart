import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/constants/app_colors.dart' as app_colors;
import '../../../providers/library_manager/library_provider.dart'
    as library_provider;
import '../../../../../../routes/app_routes.dart';

class LibraryManagementScreen extends StatefulWidget {
  const LibraryManagementScreen({super.key});

  @override
  State<LibraryManagementScreen> createState() =>
      _LibraryManagementScreenState();
}

class _LibraryManagementScreenState extends State<LibraryManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<library_provider.LibraryProvider>().getLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Management'),
        backgroundColor: app_colors.AppColors.primary,
        foregroundColor: app_colors.AppColors.white,
        elevation: 0,
      ),
      body: Consumer<library_provider.LibraryProvider>(
        builder: (context, libraryProvider, child) {
          if (libraryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (libraryProvider.error != null) {
            // Check if it's an authentication error
            final isAuthError =
                libraryProvider.error!.contains('Authentication required') ||
                libraryProvider.error!.contains('401') ||
                libraryProvider.error!.contains('token');

            // Check if it's a "no library found" error (which is a valid state)
            final isNoLibraryError = libraryProvider.error!.contains(
              'NO_LIBRARY_FOUND',
            );

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isAuthError
                        ? Icons.lock
                        : isNoLibraryError
                        ? Icons.library_books
                        : Icons.error,
                    size: 64,
                    color: isNoLibraryError
                        ? app_colors.AppColors.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isAuthError
                        ? 'Authentication Required'
                        : isNoLibraryError
                        ? 'No Library Found'
                        : 'Error: ${libraryProvider.error}',
                    style: TextStyle(
                      color: isNoLibraryError
                          ? app_colors.AppColors.primary
                          : Theme.of(context).colorScheme.error,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isAuthError) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Please log in to access library management.',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (isNoLibraryError) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Create your first library to get started',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (isNoLibraryError)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.managerLibraryForm,
                        );
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create Library'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        if (isAuthError) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.login,
                            (route) => false,
                          );
                        } else {
                          libraryProvider.getLibrary();
                        }
                      },
                      child: Text(isAuthError ? 'Go to Login' : 'Retry'),
                    ),
                ],
              ),
            );
          }

          final library = libraryProvider.library;
          if (library == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.library_books,
                    size: 64,
                    color: app_colors.AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Library Information',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set up your library information to get started',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => _navigateToForm(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: app_colors.AppColors.primary,
                      foregroundColor: app_colors.AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: const Text('Set Up Library'),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Library Header
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: app_colors.AppColors.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: library.hasLogo && library.logoUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        library.logoUrl!,
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.library_books,
                                                size: 40,
                                                color: app_colors
                                                    .AppColors
                                                    .primary,
                                              );
                                            },
                                      ),
                                    )
                                  : const Icon(
                                      Icons.library_books,
                                      size: 40,
                                      color: app_colors.AppColors.primary,
                                    ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    library.name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    library.details,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodySmall?.color,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildInfoCard(
                              'Status',
                              library.isActive ? 'Active' : 'Inactive',
                              Icons.check_circle,
                            ),
                            _buildInfoCard(
                              'Created',
                              library.createdAt.toString().split(' ')[0],
                              Icons.calendar_today,
                            ),
                            _buildInfoCard(
                              'Updated',
                              library.updatedAt.toString().split(' ')[0],
                              Icons.update,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToDetails(context),
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Details'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: app_colors.AppColors.primary,
                          foregroundColor: app_colors.AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showDeleteConfirmation(context),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: app_colors.AppColors.primary, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToDetails(BuildContext context) {
    Navigator.pushNamed(context, AppRoutes.managerLibraryDetails);
  }

  void _navigateToForm(BuildContext context) {
    final library = context.read<library_provider.LibraryProvider>().library;
    Navigator.pushNamed(
      context,
      AppRoutes.managerLibraryForm,
      arguments: library != null ? {'library': library} : null,
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Library'),
          content: const Text(
            'Are you sure you want to delete this library? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteLibrary(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteLibrary(BuildContext context) async {
    final provider = context.read<library_provider.LibraryProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final success = await provider.deleteLibrary();

      if (mounted) {
        if (success) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Library deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to delete library: ${provider.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting library: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
