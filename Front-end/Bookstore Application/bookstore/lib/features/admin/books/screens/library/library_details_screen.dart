import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/library_manager/library_provider.dart';
import '../../../widgets/library_manager/empty_state.dart';

class LibraryDetailsScreen extends StatefulWidget {
  const LibraryDetailsScreen({super.key});

  @override
  State<LibraryDetailsScreen> createState() => _LibraryDetailsScreenState();
}

class _LibraryDetailsScreenState extends State<LibraryDetailsScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLibraryData();
  }

  Future<void> _loadLibraryData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<LibraryProvider>();
      await provider.getLibrary();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading library data: ${e.toString()}'),
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
        title: const Text('Library Details'),
        actions: [
          IconButton(
            onPressed: () => _loadLibraryData(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<LibraryProvider>(
              builder: (context, provider, child) {
                if (provider.error != null) {
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
                          onPressed: _loadLibraryData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (provider.library == null) {
                  return EmptyState(
                    title: 'No Library Data',
                    message: 'No library data available',
                    icon: Icons.library_books,
                    actionText: 'Refresh',
                    onAction: _loadLibraryData,
                  );
                }

                final library = provider.library!;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Library Header
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              // Show library logo if available, otherwise show default icon
                              if (library.hasLogo && library.logoUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    library.logoUrl!,
                                    height: 64,
                                    width: 64,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.library_books,
                                        size: 64,
                                        color: Colors.blue,
                                      );
                                    },
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.library_books,
                                  size: 64,
                                  color: Colors.blue,
                                ),
                              const SizedBox(height: 16),
                              Text(
                                library.name,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (library.details.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  library.details,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Basic Information
                      _buildSectionCard(
                        title: 'Basic Information',
                        icon: Icons.info,
                        children: [
                          _buildInfoRow('Name', library.name),
                          _buildInfoRow('Details', library.details),
                          _buildInfoRow(
                            'Logo',
                            library.hasLogo ? 'Available' : 'Not set',
                          ),
                          _buildInfoRow(
                            'Status',
                            library.isActive ? 'Active' : 'Inactive',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Statistics
                      _buildSectionCard(
                        title: 'Library Statistics',
                        icon: Icons.analytics,
                        children: [
                          _buildInfoRow('Total Books', '0'),
                          _buildInfoRow('Available Books', '0'),
                          _buildInfoRow('Borrowed Books', '0'),
                          _buildInfoRow('Total Members', '0'),
                          _buildInfoRow('Active Members', '0'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Library Information
                      _buildSectionCard(
                        title: 'Library Information',
                        icon: Icons.info_outline,
                        children: [
                          _buildInfoRow(
                            'Created At',
                            library.createdAt.toString(),
                          ),
                          _buildInfoRow(
                            'Updated At',
                            library.updatedAt.toString(),
                          ),
                          if (library.createdByName.isNotEmpty)
                            _buildInfoRow('Created By', library.createdByName),
                          if (library.lastUpdatedByName.isNotEmpty)
                            _buildInfoRow(
                              'Last Updated By',
                              library.lastUpdatedByName,
                            ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showDeleteConfirmation(context),
                              icon: const Icon(Icons.delete),
                              label: const Text('Delete Library'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // Navigate to edit form
                                Navigator.pushNamed(
                                  context,
                                  '/manager/library/form',
                                  arguments: {'library': library},
                                );
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Edit Library Information'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue,
                                side: const BorderSide(color: Colors.blue),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
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
    final provider = context.read<LibraryProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

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
          // Navigate back to library management
          navigator.pop();
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
