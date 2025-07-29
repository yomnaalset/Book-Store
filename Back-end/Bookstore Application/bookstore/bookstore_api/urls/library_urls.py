from django.urls import path
from bookstore_api.views.library_views import (
    LibraryCreateView, LibraryDetailView, LibraryManagementView, LibraryPublicView,
    LibraryUpdateView, LibraryDeleteView,
    # Book views
    BookCreateView, BookListView, BookDetailView, BookUpdateView, BookDeleteView,
    BookManagementView,
    # Advanced book filtering views
    NewBooksView, BooksByCategoryView, BooksByAuthorView, BooksByPriceRangeView,
    # Category views
    CategoryCreateView, CategoryListView, CategoryDetailView, CategoryUpdateView, 
    CategoryDeleteView, CategoryManagementView, CategoryChoicesView,
    # Author views
    AuthorCreateView, AuthorListView, AuthorDetailView, AuthorWithBooksView,
    AuthorUpdateView, AuthorDeleteView, AuthorManagementView, AuthorChoicesView
)

# Library URLs configuration
library_urls = [
    # Library management endpoints (Library Admin only)
    path('create/', LibraryCreateView.as_view(), name='library_create'),
    path('manage/', LibraryManagementView.as_view(), name='library_management'),
    path('update/', LibraryUpdateView.as_view(), name='library_update'),
    path('delete/', LibraryDeleteView.as_view(), name='library_delete'),
    # Public library endpoints (All users)
    path('info/', LibraryPublicView.as_view(), name='library_public_info'),
    
    # =====================================
    # BOOK MANAGEMENT ENDPOINTS
    # =====================================
    # Book management endpoints (Library Admin only)
    path('books/create/', BookCreateView.as_view(), name='book_create'),
    path('books/manage/', BookManagementView.as_view(), name='book_management'),
    path('books/<int:pk>/update/', BookUpdateView.as_view(), name='book_update'),
    path('books/<int:pk>/delete/', BookDeleteView.as_view(), name='book_delete'),
    # Book access endpoints (All authenticated users)
    path('books/', BookListView.as_view(), name='book_list'),
    path('books/<int:pk>/', BookDetailView.as_view(), name='book_detail'),
    
    # =====================================
    # ADVANCED BOOK FILTERING ENDPOINTS
    # =====================================
    # New books
    path('books/new/', NewBooksView.as_view(), name='new_books'),
    # Books by category
    path('books/category/<int:category_id>/', BooksByCategoryView.as_view(), name='books_by_category'),
    # Books by author
    path('books/author/', BooksByAuthorView.as_view(), name='books_by_author'),
    # Books by price range
    path('books/price-range/', BooksByPriceRangeView.as_view(), name='books_by_price_range'),
    
    # =====================================
    # CATEGORY MANAGEMENT ENDPOINTS
    # =====================================
    # Category management endpoints (Library Admin only)
    path('categories/create/', CategoryCreateView.as_view(), name='category_create'),
    path('categories/manage/', CategoryManagementView.as_view(), name='category_management'),
    path('categories/<int:pk>/update/', CategoryUpdateView.as_view(), name='category_update'),
    path('categories/<int:pk>/delete/', CategoryDeleteView.as_view(), name='category_delete'),
    # Category access endpoints (All authenticated users)
    path('categories/', CategoryListView.as_view(), name='category_list'),
    path('categories/<int:pk>/', CategoryDetailView.as_view(), name='category_detail'),
    path('categories/choices/', CategoryChoicesView.as_view(), name='category_choices'),
    
    # =====================================
    # AUTHOR MANAGEMENT ENDPOINTS
    # =====================================
    # Author management endpoints (Library Admin only)
    path('authors/create/', AuthorCreateView.as_view(), name='author_create'),
    path('authors/manage/', AuthorManagementView.as_view(), name='author_management'),
    path('authors/<int:pk>/update/', AuthorUpdateView.as_view(), name='author_update'),
    path('authors/<int:pk>/delete/', AuthorDeleteView.as_view(), name='author_delete'),
    # Author access endpoints (All authenticated users)
    path('authors/', AuthorListView.as_view(), name='author_list'),
    path('authors/<int:pk>/', AuthorDetailView.as_view(), name='author_detail'),
    path('authors/<int:pk>/books/', AuthorWithBooksView.as_view(), name='author_with_books'),
    path('authors/choices/', AuthorChoicesView.as_view(), name='author_choices'),
] 