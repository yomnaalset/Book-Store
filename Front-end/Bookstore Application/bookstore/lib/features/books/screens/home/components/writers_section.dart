import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../providers/authors_provider.dart';
import '../../../../auth/providers/auth_provider.dart';
import '../../../models/author.dart';

class WritersSection extends StatefulWidget {
  const WritersSection({super.key});

  @override
  State<WritersSection> createState() => _WritersSectionState();
}

class _WritersSectionState extends State<WritersSection> {
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.token != null) {
        authorsProvider.setToken(authProvider.token);
        await authorsProvider.getAuthors();
      }
    } catch (e) {
      debugPrint('Error loading writers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthorsProvider>(
      builder: (context, authorsProvider, child) {
        final writers = authorsProvider.authors.take(6).toList();

        if (authorsProvider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (writers.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Browse Writers',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/writers-list');
                    },
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.uranianBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Writers Grid
              if (writers.isEmpty)
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.textHint.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.textHint.withValues(alpha: 0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 32,
                          color: AppColors.textHint,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No writers available',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add writers in admin panel',
                          style: TextStyle(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: writers.length,
                    itemBuilder: (context, index) {
                      final writer = writers[index];
                      return _buildWriterCard(context, writer);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWriterCard(BuildContext context, Author writer) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/writer-books',
          arguments: {'writerId': writer.id, 'writerName': writer.name},
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: AppColors.white, size: 24),
            ),

            const SizedBox(height: 12),

            // Writer Name
            Text(
              writer.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // Book Count
            Text(
              '${writer.booksCount ?? 0} books',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
