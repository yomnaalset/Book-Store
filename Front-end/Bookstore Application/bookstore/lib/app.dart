import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/localization/app_localizations.dart';
import 'core/services/api_config.dart';
import 'core/services/theme_service.dart';
import 'core/services/location_service.dart';
import 'core/translations.dart';
import 'core/utils/performance.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/profile/providers/profile_provider.dart';
import 'features/profile/providers/language_preference_provider.dart';
import 'features/profile/services/profile_service.dart';
import 'features/profile/services/language_preference_service.dart';
import 'features/books/providers/books_provider.dart';
import 'features/books/providers/authors_provider.dart' as books_authors;
import 'features/books/providers/categories_provider.dart' as books_categories;
import 'features/books/services/books_service.dart';
import 'features/cart/providers/cart_provider.dart';
import 'features/cart/services/cart_service.dart';
import 'features/favorites/providers/favorites_provider.dart';
import 'features/favorites/services/favorites_service.dart';
import 'features/reviews/providers/reviews_provider.dart';
import 'features/borrow/providers/borrow_provider.dart';
import 'features/borrow/providers/borrowing_provider.dart';
import 'features/borrow/providers/return_request_provider.dart';
import 'features/borrow/services/borrow_service.dart';
import 'features/orders/providers/orders_provider.dart';
import 'features/orders/services/orders_service.dart';
import 'features/notifications/providers/notifications_provider.dart';
import 'features/notifications/services/notifications_api_service.dart';
import 'features/admin/providers/library_manager/books_provider.dart'
    as admin_books_provider;
import 'features/admin/providers/library_manager/authors_provider.dart'
    as admin_authors;
import 'features/admin/providers/categories_provider.dart' as admin_categories;
import 'features/admin/providers/complaints_provider.dart';
import 'features/complaints/providers/customer_complaints_provider.dart';
import 'features/complaints/services/customer_complaints_api_service.dart';
import 'features/admin/providers/reports_provider.dart';
import 'features/admin/providers/delivery_provider.dart';
import 'features/delivery_manager/providers/delivery_tasks_provider.dart';
import 'features/delivery_manager/providers/notifications_provider.dart';
import 'features/delivery_manager/providers/delivery_status_provider.dart';
import 'features/delivery_manager/providers/borrowing_delivery_provider.dart';
import 'features/delivery/providers/delivery_settings_provider.dart';
import 'features/delivery/services/delivery_service.dart';
import 'features/admin/ads/providers/ads_provider.dart';
import 'features/admin/ads/services/ads_service.dart';
import 'features/admin/discounts/providers/discounts_provider.dart';
import 'features/admin/orders/providers/orders_provider.dart'
    as admin_orders_provider;
import 'features/admin/providers/notifications_provider.dart'
    as admin_notifications_provider;
import 'features/admin/providers/manager_settings_provider.dart';
import 'features/admin/providers/library_manager/library_provider.dart';
import 'features/admin/providers/admin_borrowing_provider.dart';
import 'features/admin/services/manager_api_service.dart';
import 'features/profile/providers/user_settings_provider.dart';
import 'features/help_support/providers/help_support_provider.dart';
import 'features/help_support/services/help_support_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/api_client.dart';
import 'routes/app_routes.dart';

class BookstoreApp extends StatefulWidget {
  const BookstoreApp({super.key});

  @override
  State<BookstoreApp> createState() => _BookstoreAppState();
}

class _BookstoreAppState extends State<BookstoreApp>
    with WidgetsBindingObserver {
  final TranslationsProvider _translationsProvider = TranslationsProvider();
  final ThemeService _themeService = ThemeService();
  final LocationService _locationService = LocationService();
  String? _lastProcessedToken; // Track the last token we processed

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Handle app lifecycle changes for better performance
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App is in the foreground
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
    } else if (state == AppLifecycleState.inactive) {
      // App is inactive, free up resources
    }
  }

  Future<void> _initializeApp() async {
    // Any initialization that needs to happen before the first frame
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
    );

    // Load theme preference from storage (allows dark mode)
    await _themeService.loadThemePreference();

    // Load saved language preference on startup
    await _translationsProvider.loadSavedLocale();

    // Apply performance optimizations for the app startup
    Performance.scheduleForNextFrame(() {
      // This will run in the next frame when the UI is idle
      // We can pre-cache important assets here
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Translations Provider
        ChangeNotifierProvider.value(value: _translationsProvider),
        // Theme Provider
        ChangeNotifierProvider.value(value: _themeService),
        // Location Service Provider
        ChangeNotifierProvider.value(value: _locationService),
        // Auth Provider
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        // Profile Provider
        ChangeNotifierProvider(
          create: (_) => ProfileProvider(
            ProfileService(baseUrl: ApiConfig.getAndroidEmulatorUrl()),
          ),
        ),

        // Language Preference Provider
        ChangeNotifierProvider(
          create: (_) => LanguagePreferenceProvider(
            languageService: LanguagePreferenceService(
              baseUrl: ApiConfig.getBaseUrl(),
            ),
            translationsProvider: _translationsProvider,
          ),
        ),

        // Books Provider
        ChangeNotifierProvider(
          create: (_) =>
              BooksProvider(BooksService(baseUrl: ApiConfig.getBaseUrl())),
        ),

        // Books Authors Provider
        ChangeNotifierProvider(
          create: (_) => books_authors.AuthorsProvider(
            BooksService(baseUrl: ApiConfig.getBaseUrl()),
          ),
        ),

        // Books Categories Provider
        ChangeNotifierProvider(
          create: (_) => books_categories.CategoriesProvider(
            BooksService(baseUrl: ApiConfig.getBaseUrl()),
          ),
        ),

        // Cart Provider
        ChangeNotifierProvider(
          create: (_) =>
              CartProvider(CartService(baseUrl: ApiConfig.getBaseUrl())),
        ),

        // Favorites Provider
        ChangeNotifierProvider(
          create: (_) => FavoritesProvider(
            FavoritesService(baseUrl: ApiConfig.getBaseUrl()),
          ),
        ),

        // Reviews Provider
        ChangeNotifierProvider(create: (_) => ReviewsProvider()),

        // Borrow Provider
        ChangeNotifierProvider(create: (_) => BorrowProvider(BorrowService())),
        // Borrowing Provider
        ChangeNotifierProvider(
          create: (_) => BorrowingProvider(BorrowService()),
        ),
        // Return Request Provider
        ChangeNotifierProvider(create: (_) => ReturnRequestProvider()),
        // Orders Provider
        ChangeNotifierProvider(
          create: (_) =>
              OrdersProvider(OrdersService(baseUrl: ApiConfig.getBaseUrl())),
        ),

        // Notifications Provider for customers
        ChangeNotifierProvider(
          create: (context) => NotificationsProvider(
            NotificationsApiService(
              baseUrl: ApiConfig.getBaseUrl(),
              getHeaders: () {
                final authProvider = context.read<AuthProvider>();
                return {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer ${authProvider.token ?? ''}',
                };
              },
            ),
          ),
        ),

        // Admin Providers - Create with empty token initially, will be updated by AuthService
        ChangeNotifierProvider(
          create: (context) => admin_books_provider.BooksProvider(
            ManagerApiService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => admin_authors.AuthorsProvider(
            ManagerApiService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => admin_categories.CategoriesProvider(
            ManagerApiService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              OrdersProvider(OrdersService(baseUrl: ApiConfig.getBaseUrl())),
        ),
        ChangeNotifierProvider(
          create: (context) => ComplaintsProvider(
            ManagerApiService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ReportsProvider(
            ManagerApiService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => context.read<AuthProvider>().token ?? '',
              getRefreshToken: () =>
                  context.read<AuthProvider>().refreshToken ?? '',
              onTokenRefreshed: (newToken) {
                // Update the auth provider with the new token
                context.read<AuthProvider>().setToken(newToken);
              },
            ),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => DeliveryProvider(
            ManagerApiService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
        ),
        // Delivery Manager Provider
        ChangeNotifierProxyProvider<AuthProvider, DeliveryTasksProvider>(
          create: (context) => DeliveryTasksProvider(
            DeliveryService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
          update: (context, authProvider, previous) {
            final provider =
                previous ??
                DeliveryTasksProvider(
                  DeliveryService(
                    baseUrl: ApiConfig.getBaseUrl(),
                    headers: {},
                    getAuthToken: () => '',
                  ),
                );

            // Set the token from AuthProvider
            if (authProvider.isAuthenticated && authProvider.token != null) {
              debugPrint('App: Setting token in DeliveryTasksProvider');
              provider.setToken(authProvider.token);
            }
            return provider;
          },
        ),
        // Delivery Status Provider
        ChangeNotifierProxyProvider<AuthProvider, DeliveryStatusProvider>(
          create: (context) => DeliveryStatusProvider(),
          update: (context, authProvider, previous) {
            final provider = previous ?? DeliveryStatusProvider();

            // Set the token from AuthProvider
            if (authProvider.isAuthenticated && authProvider.token != null) {
              debugPrint('App: Setting token in DeliveryStatusProvider');
              provider.setToken(authProvider.token);
            }
            return provider;
          },
        ),
        // Borrowing Delivery Provider
        ChangeNotifierProxyProvider<AuthProvider, BorrowingDeliveryProvider>(
          create: (context) => BorrowingDeliveryProvider(),
          update: (context, authProvider, previous) {
            final provider = previous ?? BorrowingDeliveryProvider();

            // Set the token from AuthProvider
            if (authProvider.isAuthenticated && authProvider.token != null) {
              debugPrint('App: Setting token in BorrowingDeliveryProvider');
              provider.setToken(authProvider.token);
            }
            return provider;
          },
        ),
        // Delivery Notifications Provider
        ChangeNotifierProxyProvider<
          AuthProvider,
          DeliveryNotificationsProvider
        >(
          create: (context) => DeliveryNotificationsProvider(
            DeliveryService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
          update: (context, authProvider, previous) {
            final provider =
                previous ??
                DeliveryNotificationsProvider(
                  DeliveryService(
                    baseUrl: ApiConfig.getBaseUrl(),
                    headers: {},
                    getAuthToken: () => '',
                  ),
                );

            // Set the token from AuthProvider
            if (authProvider.isAuthenticated && authProvider.token != null) {
              debugPrint('App: Setting token in DeliveryNotificationsProvider');
              provider.setToken(authProvider.token);
            }
            return provider;
          },
        ),
        // Delivery Settings Provider
        ChangeNotifierProxyProvider<AuthProvider, DeliverySettingsProvider>(
          create: (context) => DeliverySettingsProvider(
            DeliveryService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
          update: (context, authProvider, previous) {
            final provider =
                previous ??
                DeliverySettingsProvider(
                  DeliveryService(
                    baseUrl: ApiConfig.getBaseUrl(),
                    headers: {},
                    getAuthToken: () => '',
                  ),
                );

            // Set the token from AuthProvider
            if (authProvider.isAuthenticated && authProvider.token != null) {
              debugPrint('App: Setting token in DeliverySettingsProvider');
              provider.setToken(authProvider.token);
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (context) => AdsProvider(
            AdsService(baseUrl: ApiConfig.getBaseUrl(), headers: {}),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => DiscountsProvider(
            ManagerApiService(
              baseUrl: ApiConfig.getAndroidEmulatorUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
        ),
        // Admin Orders Provider
        ChangeNotifierProvider(
          create: (context) => admin_orders_provider.OrdersProvider(
            ManagerApiService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
        ),
        // Admin Notifications Provider
        ChangeNotifierProvider(
          create: (context) =>
              admin_notifications_provider.NotificationsProvider(
                ManagerApiService(
                  baseUrl: ApiConfig.getBaseUrl(),
                  headers: {},
                  getAuthToken: () {
                    final authProvider = context.read<AuthProvider>();
                    return authProvider.token ?? '';
                  },
                  getRefreshToken: () {
                    final authProvider = context.read<AuthProvider>();
                    return authProvider.refreshToken ?? '';
                  },
                  onTokenRefreshed: (newToken) {
                    final authProvider = context.read<AuthProvider>();
                    authProvider.updateToken(newToken);
                  },
                ),
              ),
        ),
        // Manager Settings Provider
        ChangeNotifierProvider(create: (_) => ManagerSettingsProvider()),
        // Library Provider
        ChangeNotifierProvider(
          create: (context) => LibraryProvider(
            ManagerApiService(
              baseUrl: ApiConfig.getBaseUrl(),
              headers: {},
              getAuthToken: () => '',
            ),
          ),
        ),
        // Admin Borrowing Provider
        ChangeNotifierProvider(create: (_) => AdminBorrowingProvider()),
        // User Settings Provider
        ChangeNotifierProvider(create: (_) => UserSettingsProvider()),
        // Help Support Provider
        ChangeNotifierProvider(
          create: (_) => HelpSupportProvider(
            helpSupportService: HelpSupportService(
              baseUrl: ApiConfig.getBaseUrl(),
            ),
          ),
        ),
        // Customer Complaints Provider
        ChangeNotifierProvider(
          create: (_) =>
              CustomerComplaintsProvider(CustomerComplaintsApiService()),
        ),
      ],
      child: Consumer3<TranslationsProvider, ThemeService, AuthProvider>(
        builder: (context, translationsProvider, themeService, authProvider, _) {
          // Debug theme state
          debugPrint('=== APP REBUILDING ===');
          debugPrint('Current ThemeMode: ${themeService.themeMode}');
          debugPrint('Is Dark Mode: ${themeService.isDarkMode}');
          debugPrint('==================');

          // Set up token refresh callback for ApiClient
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ApiClient.onTokenRefresh = () async {
              debugPrint('ApiClient: Token refresh callback triggered');
              final refreshSuccess = await authProvider.refreshAccessToken();
              if (refreshSuccess) {
                return authProvider.token;
              }
              return null;
            };
          });

          // Only update providers when token actually changes to avoid unnecessary calls
          final currentToken = authProvider.token;
          if (currentToken != _lastProcessedToken) {
            _lastProcessedToken = currentToken;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              debugPrint(
                'DEBUG: App calling AuthService with token: ${currentToken != null ? '${currentToken.substring(0, 20)}...' : 'null'}',
              );
              AuthService.updateProvidersWithToken(context, currentToken);

              // Load user's language preference if authenticated
              if (currentToken != null &&
                  authProvider.user?.preferredLanguage != null) {
                final languageProvider =
                    Provider.of<LanguagePreferenceProvider>(
                      context,
                      listen: false,
                    );
                final translationsProvider = Provider.of<TranslationsProvider>(
                  context,
                  listen: false,
                );

                // Update the app's locale based on user's preference
                final userLanguage = authProvider.user!.preferredLanguage!;
                translationsProvider.changeLocale(Locale(userLanguage));

                // Load language preference from server
                languageProvider.loadCurrentLanguagePreference(currentToken);
              }
            });
          }

          return MaterialApp(
            key: ValueKey(
              translationsProvider.currentLocale.languageCode,
            ), // Force rebuild on language change
            title: 'ReadGo',
            debugShowCheckedModeBanner: false,
            // Localization support
            locale: translationsProvider.currentLocale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            // Optimize startup performance and ensure RTL support
            builder: (context, child) {
              if (child == null) return const SizedBox.shrink();

              // Get current locale to determine text direction
              final locale = translationsProvider.currentLocale;
              final isRTL = locale.languageCode == 'ar';

              // Apply text scaling for accessibility while maintaining UI integrity
              // Also ensure proper text direction for RTL languages
              return Directionality(
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                child: MediaQuery(
                  // Limit text scaling for better UI consistency
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(
                      MediaQuery.of(
                        context,
                      ).textScaler.scale(1.0).clamp(0.8, 1.2),
                    ),
                  ),
                  child: child,
                ),
              );
            },
            // Dynamic theme based on user preference
            theme: themeService.getLightTheme(),
            darkTheme: themeService.getDarkTheme(),
            themeMode: themeService.themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
