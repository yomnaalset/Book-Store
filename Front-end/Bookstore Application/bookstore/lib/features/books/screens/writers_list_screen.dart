import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/widgets/common/error_message.dart';
import '../../../core/widgets/common/loading_indicator.dart';
import '../providers/authors_provider.dart';
import '../models/author.dart';

class AllWritersScreen extends StatefulWidget {
  const AllWritersScreen({super.key});

  @override
  State<AllWritersScreen> createState() => _AllWritersScreenState();
}

class _AllWritersScreenState extends State<AllWritersScreen> {
  @override
  void initState() {
    super.initState();
    _loadWriters();
  }

  Future<void> _loadWriters() async {
    try {
      final authorsProvider = Provider.of<AuthorsProvider>(
        context,
        listen: false,
      );
      await authorsProvider.getAuthors();
    } catch (e) {
      debugPrint('Error loading writers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Writers'),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor,
        actions: [
          IconButton(
            onPressed: () {
              _loadWriters();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<AuthorsProvider>(
        builder: (context, authorsProvider, child) {
          if (authorsProvider.isLoading) {
            return const Center(child: LoadingIndicator());
          }

          if (authorsProvider.error != null) {
            return ErrorMessage(
              message: authorsProvider.error!,
              onRetry: () => authorsProvider.getAuthors(),
            );
          }

          final writers = authorsProvider.authors;

          if (writers.isEmpty) {
            return _buildEmptyState();
          }

          return _buildWritersList(writers);
        },
      ),
    );
  }

  Widget _buildWritersList(List<Author> writers) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: AppDimensions.spacingM,
        mainAxisSpacing: AppDimensions.spacingM,
      ),
      itemCount: writers.length,
      itemBuilder: (context, index) {
        final writer = writers[index];
        return _buildWriterCard(writer);
      },
    );
  }

  Widget _buildWriterCard(Author writer) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/writer-books',
          arguments: {'writerId': writer.id, 'writerName': writer.name},
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.uranianBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.person,
                size: 30,
                color: AppColors.uranianBlue,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                writer.name,
                style: TextStyle(
                  fontSize: AppDimensions.fontSizeM,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${writer.booksCount ?? 0} books',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeS,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 80,
              color: AppColors.textHint.withValues(alpha: 128),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              'No writers found',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeL,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'No writers available at the moment',
              style: TextStyle(
                fontSize: AppDimensions.fontSizeM,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
