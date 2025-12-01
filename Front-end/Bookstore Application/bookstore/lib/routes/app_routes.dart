import 'package:flutter/material.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/books/screens/home/home_screen.dart';
import '../features/books/screens/book_detail_screen.dart';
import '../features/books/screens/categories_screen.dart';
import '../features/books/screens/categories_list_screen.dart';
import '../features/books/screens/authors_screen.dart';
import '../features/books/screens/writers_list_screen.dart';
import '../features/books/screens/writer_books_screen.dart';
import '../features/books/screens/all_borrowed_books_screen.dart';
import '../features/books/screens/all_ads_screen.dart';
import '../features/books/screens/discounted_books_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/cart/screens/cart_screen.dart';
import '../features/cart/screens/checkout_screen.dart';
import '../features/orders/screens/orders_screen.dart';
import '../features/orders/screens/order_detail_screen.dart';
import '../features/favorites/screens/favorites_screen.dart';
import '../features/borrow/screens/borrow_status_screen.dart';
import '../features/borrow/screens/borrow_request_screen.dart';
import '../features/borrow/screens/borrow_status_detail_screen.dart';
import '../features/settings/screens/settings_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/change_password_screen.dart';
import '../features/profile/screens/notification_settings_screen.dart';
import '../features/profile/screens/help_support_screen.dart';
import '../features/search/screens/advanced_search_screen.dart';
import '../features/search/screens/search_results_screen.dart';
import '../features/library_manager/screens/book_management_screen.dart';
import '../features/borrow/screens/borrow_management_screen.dart';
import '../features/admin/screens/dashboard/manager_dashboard_screen.dart';
import '../features/admin/screens/dashboard/admin_dashboard_screen.dart';
import '../features/delivery_manager/screens/dashboard_screen.dart';
import '../features/delivery_manager/screens/profile_details_screen.dart';
import '../features/admin/books/screens/books/books_list_screen.dart';
import '../features/admin/books/screens/books/book_form_screen.dart';
import '../features/admin/books/screens/books/book_admin_detail_screen.dart';
import '../features/admin/categories/screens/categories/categories_list_screen.dart'
    as admin;
import '../features/admin/authors/screens/authors/authors_list_screen.dart';
import '../features/admin/orders/screens/orders/orders_page.dart';
import '../features/admin/orders/screens/orders/order_details_page.dart';
import '../features/admin/borrow/screens/borrowing/borrowing_page.dart';
import '../features/admin/borrow/screens/borrowing/borrowing_details_page.dart';
import '../features/admin/borrow/screens/return_requests/admin_return_requests_list_screen.dart';
import '../features/admin/borrow/screens/return_requests/admin_return_request_detail_screen.dart';
import '../features/orders/models/order.dart';
import '../features/borrow/models/borrow_request.dart';
import '../features/admin/ads/screens/ads/ads_list_screen.dart';
import '../features/admin/ads/screens/ads/ad_form_screen.dart';
import '../features/admin/ads/screens/ads/ad_details_screen.dart';
import '../features/admin/complaints/screens/complaints/complaints_list_screen.dart';
import '../features/admin/reports/screens/reports/reports_screen.dart';
import '../features/admin/screens/settings/manager_settings_screen.dart';
import '../features/admin/screens/notifications/notifications_center_screen.dart';
import '../features/admin/authors/screens/authors/author_form_screen.dart';
import '../features/admin/discounts/screens/discounts/discount_form_screen.dart';
import '../features/admin/discounts/screens/discounts/discounts_list_screen.dart';
import '../features/admin/discounts/screens/discounts/discount_details_screen.dart';
import '../features/admin/discounts/screens/book_selection/book_selection_screen.dart';
import '../features/admin/books/screens/library/library_management_screen.dart';
import '../features/admin/books/screens/library/library_form_screen.dart';
import '../features/admin/books/screens/library/library_details_screen.dart';
import '../features/admin/screens/profile/admin_profile_screen.dart';
import '../features/ads/screens/public_ad_details_screen.dart';
import '../features/admin/ads/screens/filter_test_screen.dart';

class AppRoutes {
  // Authentication routes
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';

  // Customer routes
  static const String home = '/home';
  static const String bookDetail = '/book-detail';
  static const String profile = '/profile';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String orders = '/orders';
  static const String orderDetail = '/order-detail';
  static const String favorites = '/favorites';
  static const String borrowStatus = '/borrow-status';
  static const String borrowStatusDetail = '/borrow-status-detail';
  static const String borrowRequest = '/borrow-request';
  static const String settings = '/settings';
  static const String notifications = '/notifications';
  static const String changePassword = '/change-password';
  static const String notificationSettings = '/notification-settings';
  static const String helpSupport = '/help-support';
  static const String advancedSearch = '/advanced-search';
  static const String searchResults = '/search-results';
  static const String bookManagement = '/book-management';
  static const String borrowManagement = '/borrow-management';
  static const String categories = '/categories';
  static const String categoriesList = '/categories-list';
  static const String authors = '/authors';
  static const String writersList = '/writers-list';
  static const String writerBooks = '/writer-books';
  static const String allBorrowedBooks = '/all-borrowed-books';
  static const String allAds = '/all-ads';
  static const String allDiscountedBooks = '/all-discounted-books';
  static const String publicAdDetails = '/public-ad-details';
  static const String filterTest = '/filter-test';

  // Library Manager routes
  static const String libraryDashboard = '/library/dashboard';
  static const String libraryBooks = '/library/books';
  static const String libraryBookDetail = '/library/book-detail';
  static const String libraryBookForm = '/library/book-form';
  static const String libraryCategories = '/library/categories';
  static const String libraryCategoryForm = '/library/category-form';
  static const String libraryAuthors = '/library/authors';
  static const String libraryAuthorForm = '/library/author-form';
  static const String libraryOrders = '/library/orders';
  static const String libraryOrderDetail = '/library/order-detail';
  static const String libraryBorrowing = '/library/borrowing';
  static const String libraryBorrowingActive = '/library/borrowing/active';
  static const String libraryBorrowingRequests = '/library/borrowing/requests';
  static const String libraryBorrowingExtensions =
      '/library/borrowing/extensions';
  static const String libraryBorrowingFines = '/library/borrowing/fines';
  static const String libraryDelivery = '/library/delivery';
  static const String libraryDeliveryAssign = '/library/delivery/assign';
  static const String libraryDeliveryTracking = '/library/delivery/tracking';
  static const String libraryDeliveryRequests = '/library/delivery/requests';
  static const String libraryReports = '/library/reports';
  static const String librarySettings = '/library/settings';
  static const String libraryNotifications = '/library/notifications';

  // Admin routes
  static const String adminDashboard = '/admin/dashboard';
  static const String adminBooks = '/admin/books';
  static const String adminBookDetail = '/admin/book-detail';
  static const String adminBookForm = '/admin/book-form';
  static const String adminCategories = '/admin/categories';
  static const String adminCategoryForm = '/admin/category-form';
  static const String adminAuthors = '/admin/authors';
  static const String adminAuthorForm = '/admin/author-form';
  static const String adminOrders = '/admin/orders';
  static const String adminOrderDetail = '/admin/order-detail';
  static const String adminOrdersMain = '/admin/orders-main';
  static const String adminOrderDetails = '/admin/order-details';
  static const String adminUsers = '/admin/users';
  static const String adminUserDetail = '/admin/user-detail';
  static const String adminDiscounts = '/admin/discounts';
  static const String adminDiscountForm = '/admin/discount-form';
  static const String managerDiscountForm = '/manager/discount-form';
  static const String managerDiscountDetails = '/manager/discount-details';
  static const String bookSelection = '/book-selection';
  static const String adminAds = '/admin/ads';
  static const String adminAdForm = '/admin/ad-form';
  static const String adminComplaints = '/admin/complaints';
  static const String adminComplaintDetail = '/admin/complaint-detail';
  static const String adminReports = '/admin/reports';
  static const String adminSettings = '/admin/settings';
  static const String adminNotifications = '/admin/notifications';
  static const String adminReturnRequests = '/admin/return-requests';
  static const String adminReturnRequestDetail = '/admin/return-request-detail';

  // Manager specific routes
  static const String managerDashboard = '/manager/dashboard';
  static const String managerBooks = '/manager/books';
  static const String managerBooksCreate = '/manager/books/create';
  static const String managerBookDetails = '/manager/books/details';
  static const String managerCategories = '/manager/categories';
  static const String managerAuthors = '/manager/authors';
  static const String managerOrders = '/manager/orders';
  static const String managerOrderDetails = '/manager/order-details';
  static const String managerBorrows = '/manager/borrows';
  static const String managerBorrowDetails = '/manager/borrow-details';
  static const String managerAds = '/manager/ads';
  static const String managerAdsForm = '/manager/ads/form';
  static const String managerAdsDetails = '/manager/ads/details';
  static const String managerComplaints = '/manager/complaints';
  static const String managerNotifications = '/manager/notifications';
  static const String managerReports = '/manager/reports';
  static const String managerSettings = '/manager/settings';
  static const String managerProfile = '/manager/profile';
  static const String managerLibrary = '/manager/library';
  static const String managerLibraryForm = '/manager/library/form';
  static const String managerLibraryDetails = '/manager/library/details';

  // Delivery Manager routes
  static const String deliveryDashboard = '/delivery/dashboard';
  static const String deliveryTasks = '/delivery/tasks';
  static const String deliveryTaskDetail = '/delivery/task-detail';
  static const String deliveryAvailability = '/delivery/availability';
  static const String deliveryPickup = '/delivery/pickup';
  static const String deliveryHandover = '/delivery/handover';
  static const String deliveryMessages = '/delivery/messages';
  static const String deliveryNotifications = '/delivery/notifications';
  static const String deliverySettings = '/delivery/settings';
  static const String deliveryProfile = '/delivery/profile';

  // Route generators
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final String? routeName = settings.name;
    debugPrint('DEBUG: Route requested: $routeName');

    if (routeName == AppRoutes.splash) {
      return MaterialPageRoute(
        builder: (_) => const SplashScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.login) {
      return MaterialPageRoute(
        builder: (_) => const LoginScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.register) {
      return MaterialPageRoute(
        builder: (_) => const RegisterScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.forgotPassword) {
      return MaterialPageRoute(
        builder: (_) => const ForgotPasswordScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.onboarding) {
      return MaterialPageRoute(
        builder: (_) => const OnboardingScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.home) {
      return MaterialPageRoute(
        builder: (_) => const HomeScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.bookDetail) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => BookDetailScreen(book: args?['book']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.profile) {
      return MaterialPageRoute(
        builder: (_) => const ProfileScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.cart) {
      return MaterialPageRoute(
        builder: (_) => const CartScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.checkout) {
      return MaterialPageRoute(
        builder: (_) => const CheckoutScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.orders) {
      return MaterialPageRoute(
        builder: (_) => const OrdersScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.orderDetail) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: args?['orderId'] ?? ''),
        settings: settings,
      );
    } else if (routeName == AppRoutes.favorites) {
      return MaterialPageRoute(
        builder: (_) => const FavoritesScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.borrowStatus) {
      return MaterialPageRoute(
        builder: (_) => const BorrowStatusScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.borrowStatusDetail) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => BorrowStatusDetailScreen(
          borrowRequestId: args?['borrowRequestId'] ?? 0,
        ),
        settings: settings,
      );
    } else if (routeName == AppRoutes.borrowRequest) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => BorrowRequestScreen(book: args?['book']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.settings) {
      return MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.notifications) {
      return MaterialPageRoute(
        builder: (_) => const NotificationsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.changePassword) {
      return MaterialPageRoute(
        builder: (_) => const ChangePasswordScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.notificationSettings) {
      return MaterialPageRoute(
        builder: (_) => const NotificationSettingsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.helpSupport) {
      return MaterialPageRoute(
        builder: (_) => const HelpSupportScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.advancedSearch) {
      return MaterialPageRoute(
        builder: (_) => const AdvancedSearchScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.searchResults) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          searchQuery: args?['searchQuery'] ?? '',
          authorQuery: args?['authorQuery'],
          categoryQuery: args?['categoryQuery'],
          priceRange: args?['priceRange'] ?? 'all',
          rating: args?['rating'] ?? 'all',
          availability: args?['availability'] ?? 'all',
          sortBy: args?['sortBy'] ?? 'relevance',
        ),
        settings: settings,
      );
    } else if (routeName == AppRoutes.bookManagement) {
      return MaterialPageRoute(
        builder: (_) => const BookManagementScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.borrowManagement) {
      return MaterialPageRoute(
        builder: (_) => const BorrowManagementScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.categories) {
      return MaterialPageRoute(
        builder: (_) => const CategoriesScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.categoriesList) {
      return MaterialPageRoute(
        builder: (_) => const AllCategoriesScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.authors) {
      return MaterialPageRoute(
        builder: (_) => const AuthorsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.writersList) {
      return MaterialPageRoute(
        builder: (_) => const AllWritersScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.writerBooks) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => WriterBooksScreen(
          writerId: args?['writerId'],
          writerName: args?['writerName'],
        ),
        settings: settings,
      );
    } else if (routeName == AppRoutes.allBorrowedBooks) {
      return MaterialPageRoute(
        builder: (_) => const AllBorrowedBooksScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.allAds) {
      return MaterialPageRoute(
        builder: (_) => const AllAdsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.allDiscountedBooks) {
      return MaterialPageRoute(
        builder: (_) => const DiscountedBooksScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.publicAdDetails) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => PublicAdDetailsScreen(adId: args?['adId'] ?? 0),
        settings: settings,
      );
    } else if (routeName == AppRoutes.filterTest) {
      return MaterialPageRoute(
        builder: (_) => const FilterTestScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.libraryDashboard) {
      return MaterialPageRoute(
        builder: (_) => const ManagerDashboardScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.adminDashboard) {
      return MaterialPageRoute(
        builder: (_) => const AdminDashboardScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.deliveryDashboard) {
      return MaterialPageRoute(
        builder: (_) => const DeliveryManagerDashboardScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.deliveryProfile) {
      return MaterialPageRoute(
        builder: (_) => const ProfileDetailsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerBooks) {
      return MaterialPageRoute(
        builder: (_) => const BooksListScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerBooksCreate) {
      return MaterialPageRoute(
        builder: (_) => const BookFormScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerBookDetails) {
      return MaterialPageRoute(
        builder: (_) => const BookAdminDetailScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerCategories) {
      return MaterialPageRoute(
        builder: (_) => const admin.CategoriesListScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerAuthors) {
      return MaterialPageRoute(
        builder: (_) => const AuthorsListScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerOrders) {
      return MaterialPageRoute(
        builder: (_) => const OrdersPage(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerOrderDetails) {
      final order = settings.arguments as Order;
      return MaterialPageRoute(
        builder: (_) => OrderDetailsPage(order: order),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerBorrows) {
      return MaterialPageRoute(
        builder: (_) => const BorrowingPage(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerBorrowDetails) {
      final request = settings.arguments as BorrowRequest;
      return MaterialPageRoute(
        builder: (_) => BorrowingDetailsPage(request: request),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerAds) {
      return MaterialPageRoute(
        builder: (_) => const AdsListScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerComplaints) {
      return MaterialPageRoute(
        builder: (_) => const ComplaintsListScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerReports) {
      return MaterialPageRoute(
        builder: (_) => const ReportsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerSettings) {
      return MaterialPageRoute(
        builder: (_) => const ManagerSettingsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerProfile) {
      return MaterialPageRoute(
        builder: (_) => const AdminProfileScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerNotifications) {
      return MaterialPageRoute(
        builder: (_) => const NotificationsCenterScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerLibrary) {
      return MaterialPageRoute(
        builder: (_) => const LibraryManagementScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerLibraryForm) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => LibraryFormScreen(library: args?['library']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerLibraryDetails) {
      return MaterialPageRoute(
        builder: (_) => const LibraryDetailsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.libraryBookForm) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => BookFormScreen(book: args?['book']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.libraryAuthorForm) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AuthorFormScreen(author: args?['author']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerDiscountForm) {
      Map<String, dynamic>? args;
      if (settings.arguments is Map) {
        args = Map<String, dynamic>.from(settings.arguments as Map);
      }
      debugPrint('DEBUG: Creating DiscountFormScreen with args: $args');
      return MaterialPageRoute(
        builder: (_) => DiscountFormScreen(
          discount: args?['discount'],
          bookDiscount: args?['bookDiscount'],
        ),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerDiscountDetails) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => DiscountDetailsScreen(discount: args?['discount']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.adminDiscounts) {
      return MaterialPageRoute(
        builder: (_) => const DiscountsListScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.bookSelection) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) =>
            BookSelectionScreen(onBookSelected: args?['onBookSelected']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.adminAds) {
      return MaterialPageRoute(
        builder: (_) => const AdsListScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.adminAdForm) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AdFormScreen(ad: args?['ad']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerAds) {
      return MaterialPageRoute(
        builder: (_) => const AdsListScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerAdsForm) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AdFormScreen(ad: args?['ad']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.managerAdsDetails) {
      final args = settings.arguments as Map<String, dynamic>?;
      return MaterialPageRoute(
        builder: (_) => AdDetailsScreen(ad: args?['ad']),
        settings: settings,
      );
    } else if (routeName == AppRoutes.adminReports) {
      return MaterialPageRoute(
        builder: (_) => const ReportsScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.adminReturnRequests) {
      return MaterialPageRoute(
        builder: (_) => const AdminReturnRequestsListScreen(),
        settings: settings,
      );
    } else if (routeName == AppRoutes.adminReturnRequestDetail) {
      final returnRequestId = settings.arguments as int;
      return MaterialPageRoute(
        builder: (_) => AdminReturnRequestDetailScreen(
          returnRequestId: returnRequestId,
        ),
        settings: settings,
      );
    } else {
      return MaterialPageRoute(
        builder: (_) => const NotFoundScreen(),
        settings: settings,
      );
    }
  }

  // Navigation helpers
  static void pushNamed(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamed(context, routeName, arguments: arguments);
  }

  static void pushReplacementNamed(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushReplacementNamed(context, routeName, arguments: arguments);
  }

  static void pushNamedAndRemoveUntil(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  static void pop(BuildContext context, [dynamic result]) {
    Navigator.pop(context, result);
  }

  static bool canPop(BuildContext context) {
    return Navigator.canPop(context);
  }

  // Route validation
  static bool isValidRoute(String route) {
    return _allRoutes.contains(route);
  }

  static List<String> get _allRoutes => [
    splash,
    login,
    register,
    forgotPassword,
    onboarding,
    home,
    bookDetail,
    profile,
    cart,
    checkout,
    orders,
    orderDetail,
    favorites,
    borrowStatus,
    borrowStatusDetail,
    borrowRequest,
    settings,
    notifications,
    changePassword,
    notificationSettings,
    helpSupport,
    advancedSearch,
    searchResults,
    bookManagement,
    borrowManagement,
    categories,
    authors,
    writersList,
    writerBooks,
    allBorrowedBooks,
    allAds,
    allDiscountedBooks,
    publicAdDetails,
    filterTest,
    libraryDashboard,
    libraryBooks,
    libraryBookDetail,
    libraryBookForm,
    libraryCategories,
    libraryCategoryForm,
    libraryAuthors,
    libraryAuthorForm,
    libraryOrders,
    libraryOrderDetail,
    libraryBorrowing,
    libraryBorrowingActive,
    libraryBorrowingRequests,
    libraryBorrowingExtensions,
    libraryBorrowingFines,
    libraryDelivery,
    libraryDeliveryAssign,
    libraryDeliveryTracking,
    libraryDeliveryRequests,
    libraryReports,
    librarySettings,
    libraryNotifications,
    adminDashboard,
    adminBooks,
    adminBookDetail,
    adminBookForm,
    adminCategories,
    adminCategoryForm,
    adminAuthors,
    adminAuthorForm,
    adminOrders,
    adminOrderDetail,
    adminUsers,
    adminUserDetail,
    adminDiscounts,
    adminDiscountForm,
    adminAds,
    adminAdForm,
    adminComplaints,
    adminComplaintDetail,
    adminReports,
    adminSettings,
    adminNotifications,
    adminReturnRequests,
    adminReturnRequestDetail,
    deliveryDashboard,
    deliveryTasks,
    deliveryTaskDetail,
    deliveryAvailability,
    deliveryPickup,
    deliveryHandover,
    deliveryMessages,
    deliveryNotifications,
    deliverySettings,
    deliveryProfile,
    managerDashboard,
    managerBooks,
    managerBooksCreate,
    managerBookDetails,
    managerCategories,
    managerAuthors,
    managerOrders,
    managerOrderDetails,
    managerBorrows,
    managerBorrowDetails,
    managerDiscountForm,
    managerDiscountDetails,
    bookSelection,
    managerAds,
    managerAdsForm,
    managerAdsDetails,
    managerComplaints,
    managerNotifications,
    managerReports,
    managerSettings,
    managerProfile,
    managerLibrary,
    managerLibraryForm,
    managerLibraryDetails,
  ];
}

// NotFound Screen
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // Get the route name from the current route settings
    final routeName = ModalRoute.of(context)?.settings.name ?? 'Unknown';

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Page Not Found'),
            const SizedBox(height: 16),
            Text('Route: $routeName', style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
