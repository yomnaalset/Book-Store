import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../../core/constants/app_dimensions.dart';
import '../../../../features/auth/providers/auth_provider.dart';
import '../../../../features/books/providers/books_provider.dart';
import '../../providers/categories_provider.dart';
import '../../providers/authors_provider.dart';
import 'components/general_books_section.dart';
import 'components/borrowed_books_section.dart';
import 'components/purchasing_books_section.dart';
import 'components/categories_section.dart';
import 'components/writers_section.dart';
import 'components/offers_section.dart';
import 'components/advertisements_section.dart';
import 'components/discounted_books_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final booksProvider = Provider.of<BooksProvider>(context, listen: false);
    final categoriesProvider = Provider.of<CategoriesProvider>(
      context,
      listen: false,
    );
    final authorsProvider = Provider.of<AuthorsProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Ensure providers have the current token
    if (authProvider.token != null) {
      booksProvider.setToken(authProvider.token);
      categoriesProvider.setToken(authProvider.token);
      authorsProvider.setToken(authProvider.token);
      debugPrint(
        'DEBUG: Home screen - Updated providers with token: ${authProvider.token!.substring(0, 20)}...',
      );
    } else {
      debugPrint('DEBUG: Home screen - No token available for providers');
    }

    await Future.wait([
      booksProvider.getNewBooks(),
      booksProvider.getMostBorrowedBooks(),
      categoriesProvider.getCategories(),
      authorsProvider.getAuthors(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              _buildAppBar(authProvider),
              const SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Advertisements Section
                    AdvertisementsSection(),

                    SizedBox(height: AppDimensions.spacingL),

                    // General Books Section (for browsing/purchasing)
                    GeneralBooksSection(),

                    SizedBox(height: AppDimensions.spacingL),

                    // Purchasing Books Section (for purchase only)
                    PurchasingBooksSection(),

                    SizedBox(height: AppDimensions.spacingL),

                    // Borrowed Books Section (for borrowing)
                    BorrowedBooksSection(),

                    SizedBox(height: AppDimensions.spacingL),

                    // Discounted Books Section
                    DiscountedBooksSection(),

                    SizedBox(height: AppDimensions.spacingL),

                    // Categories Section
                    CategoriesSection(),

                    SizedBox(height: AppDimensions.spacingL),

                    // Writers Section
                    WritersSection(),

                    SizedBox(height: AppDimensions.spacingL),

                    // Offers Section
                    OffersSection(),

                    SizedBox(height: AppDimensions.spacingXL),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).colorScheme.surface,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            currentIndex: 0, // Home is selected
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long),
                label: 'My Orders',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.library_books),
                label: 'Borrowings',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Favorites',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            onTap: (index) {
              switch (index) {
                case 0:
                  // Already on home
                  break;
                case 1:
                  Navigator.pushNamed(context, '/orders');
                  break;
                case 2:
                  Navigator.pushNamed(context, '/borrow-status');
                  break;
                case 3:
                  Navigator.pushNamed(context, '/favorites');
                  break;
                case 4:
                  Navigator.pushNamed(context, '/profile');
                  break;
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildAppBar(AuthProvider authProvider) {
    return SliverAppBar(
      expandedHeight: 140.0,
      floating: true,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // App Title
                  Text(
                    'E-Library',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Search Bar
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search books, authors...',
                        hintStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) {
                        // Handle search
                      },
                      onTap: () {
                        Navigator.pushNamed(context, '/advanced-search');
                      },
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          Navigator.pushNamed(
                            context,
                            '/advanced-search',
                            arguments: {'searchQuery': value.trim()},
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.notifications_outlined,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
        ),
        IconButton(
          icon: Icon(
            Icons.shopping_cart_outlined,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () => Navigator.pushNamed(context, '/cart'),
        ),
        IconButton(
          icon: Icon(
            Icons.settings_outlined,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }
}
