import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/library_manager/library_provider.dart';
import '../../../widgets/library_manager/empty_state.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/services/api_config.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLibraryData();
    });
  }

  Future<void> _loadLibraryData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<LibraryProvider>();
      await provider.getLibrary();
    } catch (e) {
      if (mounted) {
        final localizations = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(localizations.errorLoadingLibraryData(e.toString())),
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
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.libraryDetails),
        actions: [
          IconButton(
            onPressed: () => _loadLibraryData(),
            icon: const Icon(Icons.refresh),
            tooltip: localizations.refresh,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Consumer<LibraryProvider>(
              builder: (context, provider, child) {
                if (provider.error != null) {
                  return Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${localizations.error}: ${provider.error}',
                              style: const TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadLibraryData,
                              child: Text(localizations.retry),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }

                if (provider.library == null) {
                  return Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return EmptyState(
                        title: localizations.noLibraryData,
                        message: localizations.noLibraryDataAvailable,
                        icon: Icons.library_books,
                        actionText: localizations.refresh,
                        onAction: _loadLibraryData,
                      );
                    },
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
                                    ApiConfig.buildImageUrl(library.logoUrl!) ?? library.logoUrl!,
                                    height: 64,
                                    width: 64,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      debugPrint('LibraryDetailsScreen: Error loading logo: $error');
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
                        title: localizations.basicInformation,
                        icon: Icons.info,
                        children: [
                          _buildInfoRow(localizations.nameLabel, library.name),
                          _buildInfoRow(
                            localizations.description,
                            library.details,
                          ),
                          _buildInfoRow(
                            localizations.logo,
                            library.hasLogo
                                ? localizations.available
                                : localizations.notSet,
                          ),
                          _buildInfoRow(
                            localizations.status,
                            library.isActive
                                ? localizations.active
                                : localizations.inactive,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Statistics
                      _buildSectionCard(
                        title: localizations.libraryStatistics,
                        icon: Icons.analytics,
                        children: [
                          _buildInfoRow(localizations.totalBooks, '0'),
                          _buildInfoRow(localizations.availableBooks, '0'),
                          _buildInfoRow(localizations.borrowedBooks, '0'),
                          _buildInfoRow(localizations.totalMembers, '0'),
                          _buildInfoRow(localizations.activeMembers, '0'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Library Information
                      _buildSectionCard(
                        title: localizations.libraryInformation,
                        icon: Icons.info_outline,
                        children: [
                          _buildInfoRow(
                            localizations.createdAt,
                            library.createdAt.toString(),
                          ),
                          _buildInfoRow(
                            localizations.updatedAt,
                            library.updatedAt.toString(),
                          ),
                          if (library.createdByName.isNotEmpty)
                            _buildInfoRow(
                              localizations.createdBy,
                              library.createdByName,
                            ),
                          if (library.lastUpdatedByName.isNotEmpty)
                            _buildInfoRow(
                              localizations.lastUpdatedBy,
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
                              label: Text(localizations.deleteLibrary),
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
                              label: Text(localizations.editLibraryInformation),
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
    final localizations = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.deleteLibrary),
          content: Text(localizations.areYouSureDeleteLibrary),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(localizations.cancel),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteLibrary(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(localizations.delete),
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
    final localizations = AppLocalizations.of(context);

    try {
      final success = await provider.deleteLibrary();

      if (mounted) {
        if (success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(localizations.libraryDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate back to library management
          navigator.pop();
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                localizations.failedToDeleteLibrary(
                  provider.error ?? localizations.unknownError,
                ),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(localizations.errorDeletingLibrary(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
