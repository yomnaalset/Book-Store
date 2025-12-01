import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../models/author.dart';
import '../../../providers/authors_provider.dart';
import '../../../../auth/providers/auth_provider.dart';

class AuthorsSection extends StatefulWidget {
  const AuthorsSection({super.key});

  @override
  State<AuthorsSection> createState() => _AuthorsSectionState();
}

class _AuthorsSectionState extends State<AuthorsSection> {
  @override
  void initState() {
    super.initState();
    _loadAuthors();
  }

  Future<void> _loadAuthors() async {
    final authorsProvider = Provider.of<AuthorsProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (authProvider.token != null) {
      authorsProvider.setToken(authProvider.token);
      await authorsProvider.getAuthors();
    }
  }

  Widget _buildAuthorCard(BuildContext context, Author author) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/authors');
      },
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            // Author Photo
            Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.uranianBlue.withValues(alpha: 0.1),
                    border: Border.all(
                      color: AppColors.uranianBlue.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: author.imageUrl != null
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: author.imageUrl!,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              size: 40,
                              color: AppColors.uranianBlue,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.uranianBlue,
                        ),
                ),

                // Online Status Indicator
                if (true) // You can add a real online status check here
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: AppColors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Author Name
            Text(
              author.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Author Info
            if (author.biography != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.uranianBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  author.biography!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.uranianBlue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthorsProvider>(
      builder: (context, authorsProvider, child) {
        final authors = authorsProvider.authors.take(8).toList();

        if (authorsProvider.isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (authors.isEmpty) {
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.fairyTaleColor.withValues(alpha: 20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: AppColors.carnationPink,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Featured Authors',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryText,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/authors');
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

              const SizedBox(height: 16),

              // Authors List
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: authors.length,
                  itemBuilder: (context, index) {
                    final author = authors[index];
                    return _buildAuthorCard(context, author);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
