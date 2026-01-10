import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  Map<String, String>? _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('ar', 'SA'),
  ];

  // Load translations from JSON file
  Future<bool> load() async {
    try {
      String jsonString;
      if (locale.languageCode == 'ar') {
        jsonString = await rootBundle.loadString(
          'assets/translations/strings_ar.json',
        );
      } else {
        jsonString = await rootBundle.loadString(
          'assets/translations/strings_en.json',
        );
      }

      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = jsonMap.map(
        (key, value) => MapEntry(key, value.toString()),
      );
      return true;
    } catch (e) {
      debugPrint('Error loading translations: $e');
      // Fallback to empty map if loading fails
      _localizedStrings = {};
      return false;
    }
  }

  String get(String key) {
    return _localizedStrings?[key] ??
        key; // Return key if translation not found
  }

  String get appName => get('app_name');
  String get welcome => get('welcome');
  String get loading => get('loading');
  String get error => get('error');
  String get success => get('success');
  String get cancel => get('cancel');
  String get save => get('save');
  String get delete => get('delete');
  String get edit => get('edit');
  String get add => get('add');
  String get remove => get('remove');
  String get update => get('update');
  String get create => get('create');
  String get search => get('search');
  String get filter => get('filter');
  String get clear => get('clear');
  String get refresh => get('refresh');
  String get retry => get('retry');
  String get confirm => get('confirm');
  String get back => get('back');
  String get next => get('next');
  String get done => get('done');
  String get skip => get('skip');
  String get close => get('close');
  String get open => get('open');
  String get view => get('view');
  String get hide => get('hide');
  String get show => get('show');
  String get select => get('select');
  String get deselect => get('deselect');
  String get all => get('all');
  String get none => get('none');
  String get yes => get('yes');
  String get no => get('no');
  String get ok => get('ok');

  // User Roles
  String get purchaseOrders => get('purchase_orders');
  String get borrowRequests => get('borrow_requests');
  String get returnRequests => get('return_requests');
  String get noPurchaseOrders => get('no_purchase_orders');
  String get noPurchaseOrdersDescription =>
      get('no_purchase_orders_description');
  String get noBorrowRequests => get('no_borrow_requests');
  String get noBorrowRequestsDescription =>
      get('no_borrow_requests_description');
  String get noReturnRequests => get('no_return_requests');
  String get noReturnRequestsDescription =>
      get('no_return_requests_description');
  String get customer => get('customer');
  String get libraryManager => get('library_manager');
  String get deliveryManager => get('delivery_manager');
  String get admin => get('admin');

  // Status
  String get active => get('active');
  String get inactive => get('inactive');
  String get pending => get('pending');
  String get approved => get('approved');
  String get rejected => get('rejected');
  String get completed => get('completed');
  String get cancelled => get('cancelled');
  String get expired => get('expired');
  String get available => get('available');
  String get unavailable => get('unavailable');
  String get notFound => get('not_found');
  String get requestPrefix => get('request_prefix');
  String get online => get('online');
  String get offline => get('offline');
  String get busy => get('busy');

  // Time
  String get now => get('now');
  String get today => get('today');
  String get yesterday => get('yesterday');
  String get tomorrow => get('tomorrow');
  String get thisWeek => get('this_week');
  String get thisMonth => get('this_month');
  String get thisYear => get('this_year');
  String get weeksAgo => get('weeks_ago');
  String get monthsAgo => get('months_ago');
  String get yearsAgo => get('years_ago');

  // Validation Messages
  String get requiredField => get('required_field');
  String get invalidEmail => get('invalid_email');
  String get invalidPhone => get('invalid_phone');
  String get passwordTooShort => get('password_too_short');
  String get passwordsDontMatch => get('passwords_dont_match');
  String get invalidOtp => get('invalid_otp');
  String get networkError => get('network_error');
  String get serverError => get('server_error');
  String get unknownError => get('unknown_error');

  // Success Messages
  String get savedSuccessfully => get('saved_successfully');
  String get updatedSuccessfully => get('updated_successfully');
  String get deletedSuccessfully => get('deleted_successfully');
  String get createdSuccessfully => get('created_successfully');
  String get loggedInSuccessfully => get('logged_in_successfully');
  String get loggedOutSuccessfully => get('logged_out_successfully');
  String get registeredSuccessfully => get('registered_successfully');

  // Feature Names
  String get books => get('books');
  String get orders => get('orders');
  String get deliveries => get('deliveries');
  String get borrowings => get('borrowings');
  String get reviews => get('reviews');
  String get notifications => get('notifications');
  String get settings => get('settings');
  String get profile => get('profile');
  String get dashboard => get('dashboard');
  String get library => get('library');
  String get categories => get('categories');
  String get authors => get('authors');
  String get complaints => get('complaints');
  String get reports => get('reports');
  String get advertisements => get('advertisements');
  String get discounts => get('discounts');
  String get messages => get('messages');
  String get tasks => get('tasks');
  String get allRequests => get('all_requests');
  String get availability => get('availability');

  // Navigation
  String get home => get('home');
  String get menu => get('menu');
  String get more => get('more');
  String get about => get('about');
  String get help => get('help');
  String get support => get('support');
  String get contact => get('contact');

  // Empty State Messages
  String get noDataFound => get('no_data_found');
  String get noItemsFound => get('no_items_found');
  String get noResultsFound => get('no_results_found');
  String get noBooksFound => get('no_books_found');
  String get noOrdersFound => get('no_orders_found');
  String get noNotificationsFound => get('no_notifications_found');

  // Placeholder Text
  String get searchHint => get('search_hint');
  String get emailHint => get('email_hint');
  String get passwordHint => get('password_hint');
  String get nameHint => get('name_hint');
  String get phoneHint => get('phone_hint');
  String get addressHint => get('address_hint');

  // Dialog Titles
  String get chooseLanguage => get('choose_language');
  String get signOut => get('sign_out');
  String get logout => get('logout');
  String get selectLanguage => get('select_language');

  // Dialog Messages
  String get signOutConfirmation => get('sign_out_confirmation');
  String get logoutConfirmation => get('logout_confirmation');
  String get languageChanged => get('language_changed');
  String get failedToChangeLanguage => get('failed_to_change_language');

  // App Info
  String get bookstoreApp => get('bookstore_app');
  String get appVersion => get('app_version');
  String get appDescription => get('app_description');

  // Additional translations
  String get myOrders => get('my_orders');
  String get favorites => get('favorites');
  String get complaintDetails => get('complaint_details');
  String get addComplaint => get('add_complaint');
  String get editComplaint => get('edit_complaint');
  String get complaintTitle => get('complaint_title');
  String get complaintMessage => get('complaint_message');
  String get submit => get('submit');
  String get adminReply => get('admin_reply');
  String get noReplyYet => get('no_reply_yet');
  String get failedToLoadComplaint => get('failed_to_load_complaint');
  String get errorLoadingComplaint => get('error_loading_complaint');
  String get account => get('account');
  String get changePassword => get('change_password');
  String get updateYourPassword => get('update_your_password');
  String get appearance => get('appearance');
  String get darkMode => get('dark_mode');
  String get enabled => get('enabled');
  String get disabled => get('disabled');
  String get darkModeEnabled => get('dark_mode_enabled');
  String get lightModeEnabled => get('light_mode_enabled');
  String get language => get('language');
  String get appLanguage => get('app_language');
  String get preferences => get('preferences');
  String get notificationSettings => get('notification_settings');
  String get manageYourNotificationPreferences =>
      get('manage_your_notification_preferences');
  String get accountActions => get('account_actions');
  String get adminActions => get('admin_actions');
  String get signOutSubtitle => get('sign_out_subtitle');
  String get status => get('status');
  String get complaintUpdatedSuccessfully =>
      get('complaint_updated_successfully');
  String get complaintSubmittedSuccessfully =>
      get('complaint_submitted_successfully');
  String get failedToUpdateComplaint => get('failed_to_update_complaint');
  String get failedToSubmitComplaint => get('failed_to_submit_complaint');
  String get complaintInformation => get('complaint_information');
  String get submitted => get('submitted');
  String get complaintId => get('complaint_id');
  String get adminResponses => get('admin_responses');
  String get noAdminResponsesYet => get('no_admin_responses_yet');
  String get goBack => get('go_back');
  String get complaintNotFound => get('complaint_not_found');

  // Cart & Checkout
  String get shoppingCart => get('shopping_cart');
  String get clearAll => get('clear_all');
  String get cart => get('cart');
  String get checkout => get('checkout');
  String get total => get('total');
  String get subtotal => get('subtotal');
  String get discount => get('discount');
  String get tax => get('tax');
  String get delivery => get('delivery');
  String get grandTotal => get('grand_total');
  String get proceedToCheckout => get('proceed_to_checkout');
  String get emptyCart => get('empty_cart');
  String get emptyCartDescription => get('empty_cart_description');
  String get quantity => get('quantity');
  String get price => get('price');
  String get removeItem => get('remove_item');
  String get addToCart => get('add_to_cart');
  String get confirmClearCart => get('confirm_clear_cart');
  String get itemRemoved => get('item_removed');
  String get itemAddedToCart => get('item_added_to_cart');
  String get cartCleared => get('cart_cleared');
  String get continueShopping => get('continue_shopping');

  // Favorites
  String get myFavorites => get('my_favorites');
  String get clearAllFavorites => get('clear_all_favorites');
  String get emptyFavorites => get('empty_favorites');
  String get emptyFavoritesDescription => get('empty_favorites_description');
  String get addToFavorites => get('add_to_favorites');
  String get removeFromFavorites => get('remove_from_favorites');
  String get confirmClearFavorites => get('confirm_clear_favorites');
  String get itemAddedToFavorites => get('item_added_to_favorites');
  String get itemRemovedFromFavorites => get('item_removed_from_favorites');
  String get favoritesCleared => get('favorites_cleared');

  // Orders
  String get orderDetails => get('order_details');
  String get borrowOrderDetails => get('borrow_order_details');
  String get orderDetail => get('order_detail');
  String get orderNumber => get('order_number');
  String get orderDate => get('order_date');
  String get orderStatus => get('order_status');
  String get orderItems => get('order_items');
  String get deliveryAddress => get('delivery_address');
  String get billingAddress => get('billing_address');
  String get paymentMethod => get('payment_method');
  String get trackOrder => get('track_order');
  String get cancelOrder => get('cancel_order');
  String get noOrdersDescription => get('no_orders_description');
  String get confirmCancelOrder => get('confirm_cancel_order');
  String get orderCancelled => get('order_cancelled');
  String get processing => get('processing');
  String get shipped => get('shipped');
  String get delivered => get('delivered');
  String get returned => get('returned');
  String get refunded => get('refunded');

  // Borrow
  String get borrowStatus => get('borrow_status');
  String get borrowRequest => get('borrow_request');
  String get noBorrowingsDescription => get('no_borrowings_description');
  String get borrowPeriod => get('borrow_period');
  String get returnDate => get('return_date');
  String get dueDate => get('due_date');
  String get extendBorrow => get('extend_borrow');
  String get returnBook => get('return_book');
  String get requestBorrow => get('request_borrow');
  String get borrowRequestSubmitted => get('borrow_request_submitted');
  String get borrowNow => get('borrow_now');
  String get cannotBorrowBook => get('cannot_borrow_book');
  String get youAlreadyHavePendingBorrowRequest => get('you_already_have_pending_borrow_request');
  String get youHaveUnreturnedBooks => get('you_have_unreturned_books');
  String get viewBorrowings => get('view_borrowings');
  String get failedToCheckBorrowingStatus => get('failed_to_check_borrowing_status');

  // Password
  String get changePasswordTitle => get('change_password_title');
  String get passwordChanged => get('password_changed');
  String get currentPassword => get('current_password');
  String get newPassword => get('new_password');
  String get confirmPassword => get('confirm_password');
  String get passwordMismatch => get('password_mismatch');
  String get invalidCurrentPassword => get('invalid_current_password');

  // Notifications
  String get notificationSettingsTitle => get('notification_settings_title');
  String get noNotificationsDescription => get('no_notifications_description');
  String get markAllRead => get('mark_all_read');
  String get deleteAll => get('delete_all');

  // Books
  String get bookDetail => get('book_detail');
  String get bookTitle => get('book_title');
  String get author => get('author');
  String get category => get('category');
  String get description => get('description');
  String get isbn => get('isbn');
  String get publisher => get('publisher');
  String get publicationDate => get('publication_date');
  String get pages => get('pages');
  String get languageBook => get('language_book');
  String get format => get('format');
  String get stock => get('stock');
  String get inStock => get('in_stock');
  String get outOfStock => get('out_of_stock');
  String get rating => get('rating');
  String get reviewsCount => get('reviews_count');
  String get writeReview => get('write_review');
  String get relatedBooks => get('related_books');
  String get similarBooks => get('similar_books');
  String get buyNow => get('buy_now');

  // Search & Filter
  String get searchResults => get('search_results');
  String get noSearchResults => get('no_search_results');
  String get filterResults => get('filter_results');
  String get sortBy => get('sort_by');
  String get priceLowToHigh => get('price_low_to_high');
  String get priceHighToLow => get('price_high_to_low');
  String get newestFirst => get('newest_first');
  String get oldestFirst => get('oldest_first');
  String get mostPopular => get('most_popular');
  String get highestRated => get('highest_rated');
  String get apply => get('apply');
  String get reset => get('reset');

  // Confirmations
  String get confirmRemoveItem => get('confirm_remove_item');

  // Help & Support
  String get helpSupport => get('help_support');

  // Book Details
  String get bookDetails => get('book_details');
  String get failedToLoadBookDetails => get('failed_to_load_book_details');
  String get errorOccurred => get('error_occurred');
  String get addedToCartPlaceholder => get('added_to_cart_placeholder');
  String get noDescriptionAvailable => get('no_description_available');
  String get specifications => get('specifications');
  String get reviewsAndRatings => get('reviews_and_ratings');
  String get addToCartButton => get('add_to_cart_button');
  String get borrowButton => get('borrow_button');
  String get outOfStockMessage => get('out_of_stock_message');
  String get inStockMessage => get('in_stock_message');
  String get selectQuantity => get('select_quantity');
  String get totalPrice => get('total_price');
  String get bookInformation => get('book_information');
  String get authorName => get('author_name');
  String get publisherName => get('publisher_name');
  String get publicationYear => get('publication_year');
  String get isbnNumber => get('isbn_number');
  String get numberOfPages => get('number_of_pages');
  String get bookFormat => get('book_format');
  String get bookLanguage => get('book_language');
  String get bookCategory => get('book_category');
  String get priceLabel => get('price_label');
  String get discountLabel => get('discount_label');
  String get finalPrice => get('final_price');
  String get free => get('free');
  String get readMore => get('read_more');
  String get readLess => get('read_less');
  String get writeAReview => get('write_a_review');
  String get noReviewsYet => get('no_reviews_yet');
  String get beTheFirstToReview => get('be_the_first_to_review');
  String get loadingBookDetails => get('loading_book_details');
  String get unableToLoadBook => get('unable_to_load_book');

  // Change Password
  String get changeYourPassword => get('change_your_password');
  String get enterCurrentAndNewPassword =>
      get('enter_current_and_new_password');
  String get currentPasswordLabel => get('current_password_label');
  String get currentPasswordHint => get('current_password_hint');
  String get pleaseEnterCurrentPassword => get('please_enter_current_password');
  String get newPasswordLabel => get('new_password_label');
  String get newPasswordHint => get('new_password_hint');
  String get pleaseEnterNewPassword => get('please_enter_new_password');
  String get confirmNewPasswordLabel => get('confirm_new_password_label');
  String get confirmNewPasswordHint => get('confirm_new_password_hint');
  String get pleaseConfirmNewPassword => get('please_confirm_new_password');
  String get passwordsDoNotMatch => get('passwords_do_not_match');
  String get passwordTooWeak => get('password_too_weak');
  String get passwordChangedSuccessfully =>
      get('password_changed_successfully');
  String get failedToChangePassword => get('failed_to_change_password');
  String get pleaseLogInToChangePassword =>
      get('please_log_in_to_change_password');
  String get noAuthenticationToken => get('no_authentication_token');
  String get confirmNewPassword => get('confirm_new_password');

  // Checkout Screen
  String get delivering => get('delivering');
  String get invoice => get('invoice');
  String get deliveryInformation => get('delivery_information');
  String get editProfile => get('edit_profile');
  String get noDeliveryInfoFound => get('no_delivery_info_found');
  String get deliveryInfoReadonly => get('delivery_info_readonly');
  String get addressLabel => get('address_label');
  String get cityLabel => get('city_label');
  String get zipCodeLabel => get('zip_code_label');
  String get countryLabel => get('country_label');
  String get pleaseEnterAddress => get('please_enter_address');
  String get pleaseEnterCity => get('please_enter_city');
  String get pleaseEnterZip => get('please_enter_zip');
  String get pleaseEnterCountry => get('please_enter_country');
  String get cardDetails => get('card_details');
  String get cardNumber => get('card_number');
  String get cardholderName => get('cardholder_name');
  String get expiryDate => get('expiry_date');
  String get cvv => get('cvv');
  String get required => get('required');
  String get mastercard => get('mastercard');
  String get cashPayment => get('cash_payment');
  String get fillAllCardDetails => get('fill_all_card_details');
  String get orderSummary => get('order_summary');
  String get continueButton => get('continue_button');
  String get placeOrder => get('place_order');
  String get orderPlaced => get('order_placed');
  String get orderPlacedSuccessfully => get('order_placed_successfully');
  String get viewOrders => get('view_orders');
  String get orderFailed => get('order_failed');
  String get failedToPlaceOrder => get('failed_to_place_order');

  // Borrow Request Screen
  String get addressRequired => get('address_required');
  String get addressRequiredMessage => get('address_required_message');
  String get failedToLoadBookDetailsShort =>
      get('failed_to_load_book_details_short');
  String get loadingYourAddress => get('loading_your_address');
  String get borrowDuration => get('borrow_duration');
  String get enterDeliveryAddress => get('enter_delivery_address');
  String get deliveryAddressRequired => get('delivery_address_required');
  String get editAddressFromProfile => get('edit_address_from_profile');
  String get additionalNotesOptional => get('additional_notes_optional');
  String get anySpecialRequests => get('any_special_requests');
  String get submitRequest => get('submit_request');
  String availableCopies(int count) =>
      get('available_copies').replaceAll('{count}', count.toString());
  String byAuthor(String author) =>
      get('by_author').replaceAll('{author}', author);
  String get days => get('days');

  // Borrow Status Detail Screen
  String get authenticationRequired => get('authentication_required');
  String get borrowRequestNotFound => get('borrow_request_not_found');
  String failedToLoadBorrowRequest(String error) =>
      get('failed_to_load_borrow_request').replaceAll('{error}', error);
  String requestNumber(int id) =>
      get('request_number').replaceAll('{id}', id.toString());
  String get orderStatusLabel => get('order_status_label');
  String get orderInformation => get('order_information');
  String get requestDate => get('request_date');
  String get deliveryDate => get('delivery_date');
  String durationDays(int days) =>
      get('duration_days').replaceAll('{days}', days.toString());
  String overdueByDays(int days) =>
      get('overdue_by_days').replaceAll('{days}', days.toString());
  String get viewDeliveryManagerLocation =>
      get('view_delivery_manager_location');
  String get requestInformationNotAvailable =>
      get('request_information_not_available');
  String get deliveryManagerInfoNotAvailable =>
      get('delivery_manager_info_not_available');
  String get locationTrackingAvailable => get('location_tracking_available');
  String get deliveryManagerLocationNotAvailable =>
      get('delivery_manager_location_not_available');
  String get failedToGetLocation => get('failed_to_get_location');
  String couldNotOpenMaps(String error) =>
      get('could_not_open_maps').replaceAll('{error}', error);
  String errorOpeningMaps(String error) =>
      get('error_opening_maps').replaceAll('{error}', error);
  String get creatingReturnRequest => get('creating_return_request');
  String get returnRequestCreatedSuccessfully =>
      get('return_request_created_successfully');
  String get failedToCreateReturnRequest =>
      get('failed_to_create_return_request');

  // Borrow Order Detail Screen
  String get currentStatus => get('current_status');
  String get orderNumberLabel => get('order_number_label');
  String get orderDateLabel => get('order_date_label');
  String get lastUpdated => get('last_updated');
  String get additionalNotes => get('additional_notes');
  String get noNotesYet => get('no_notes_yet');
  String get addNote => get('add_note');
  String get paymentInformation => get('payment_information');
  String get paymentStatus => get('payment_status');
  String get transactionId => get('transaction_id');
  String get amount => get('amount');
  String get notProvided => get('not_provided');
  String get notAvailable => get('not_available');
  String get customerInformation => get('customer_information');
  String get nameLabel => get('name_label');
  String get emailLabel => get('email_label');
  String get phoneLabel => get('phone_label');

  // Help & Support Screen
  String get helpSupportTitle => get('help_support_title');
  String get howCanWeHelp => get('how_can_we_help');
  String get findAnswers => get('find_answers');
  String get quickHelp => get('quick_help');
  String get frequentlyAskedQuestions => get('frequently_asked_questions');
  String findAnswersCommon(int count) =>
      get('find_answers_common').replaceAll('{count}', count.toString());
  String get userGuide => get('user_guide');
  String learnHowToUse(int count) =>
      get('learn_how_to_use').replaceAll('{count}', count.toString());
  String get troubleshooting => get('troubleshooting');
  String fixCommonIssues(int count) =>
      get('fix_common_issues').replaceAll('{count}', count.toString());
  String get contactSupportAdmin => get('contact_support_admin');
  String get noSupportContacts => get('no_support_contacts');
  String get contactInfoNotAvailable => get('contact_info_not_available');
  String get appInformation => get('app_information');
  String get version => get('version');
  String get lastUpdatedLabel => get('last_updated_label');
  String get developer => get('developer');
  String get feedback => get('feedback');
  String get rateTheApp => get('rate_the_app');
  String get rateUsOnStore => get('rate_us_on_store');
  String get sendFeedback => get('send_feedback');
  String get shareThoughts => get('share_thoughts');
  String get reportABug => get('report_a_bug');
  String get helpUsImprove => get('help_us_improve');
  String get legal => get('legal');
  String get termsOfService => get('terms_of_service');
  String get readTerms => get('read_terms');
  String get privacyPolicy => get('privacy_policy');
  String get learnDataProtection => get('learn_data_protection');
  String get errorLoadingHelpContent => get('error_loading_help_content');
  String get liveChat => get('live_chat');
  String get liveChatNotAvailable => get('live_chat_not_available');
  String contactUrl(String url) => get('contact_url').replaceAll('{url}', url);
  String get emailSupport => get('email_support');
  String get sendUsEmail => get('send_us_email');
  String emailLabelWithValue(String email) =>
      get('email_label').replaceAll('{email}', email);
  String get phoneSupport => get('phone_support');
  String get callUsAssistance => get('call_us_assistance');
  String phoneLabelWithValue(String phone) =>
      get('phone_label').replaceAll('{phone}', phone);
  String get rateAppNotImplemented => get('rate_app_not_implemented');
  String get sendFeedbackNotImplemented => get('send_feedback_not_implemented');
  String get reportBugNotImplemented => get('report_bug_not_implemented');
  String get termsNotAvailable => get('terms_not_available');
  String get privacyNotAvailable => get('privacy_not_available');

  // Home App Bar
  String get bookstore => get('bookstore');
  String get guestUser => get('guest_user');
  String get userLabel => get('user');
  String get myProfile => get('my_profile');
  String get profileFeatureComingSoon => get('profile_feature_coming_soon');
  String get myOrdersMenu => get('my_orders_menu');
  String get ordersFeatureComingSoon => get('orders_feature_coming_soon');
  String get libraryManagement => get('library_management');
  String get libraryManagementComingSoon =>
      get('library_management_coming_soon');
  String get deliveryManagement => get('delivery_management');
  String get deliveryManagementComingSoon =>
      get('delivery_management_coming_soon');
  String get languageMenu => get('language_menu');
  String get languageChangedToEnglish => get('language_changed_to_english');
  String get languageChangedToArabic => get('language_changed_to_arabic');
  String get settingsFeatureComingSoon => get('settings_feature_coming_soon');
  String get logoutFunctionalityComingSoon =>
      get('logout_functionality_coming_soon');

  // Search
  String get searchResultsTitle => get('search_results_title');
  String get searchFailed => get('search_failed');
  String get noResultsFoundSearch => get('no_results_found_search');
  String get noBooksMatchingCriteria => get('no_books_matching_criteria');
  String get backToSearch => get('back_to_search');
  String searchResultsCount(int count) =>
      get('search_results_count').replaceAll('{count}', count.toString());
  String byAuthorPrefix(String author) =>
      get('by_author_prefix').replaceAll('{author}', author);
  String priceLabelPrefix(String price) =>
      get('price_label_prefix').replaceAll(r'${price}', price);
  String get availableStatus => get('available_status');
  String get unavailableStatus => get('unavailable_status');
  String get advancedSearch => get('advanced_search');
  String get searchByBookName => get('search_by_book_name');
  String get bookTitleOrName => get('book_title_or_name');
  String get enterBookTitleOrName => get('enter_book_title_or_name');
  String get searchByAuthor => get('search_by_author');
  String get authorNameLabel => get('author_name_label');
  String get enterAuthorName => get('enter_author_name');
  String get searchByCategory => get('search_by_category');
  String get categoryNameLabel => get('category_name_label');
  String get enterCategoryName => get('enter_category_name');
  String get priceRange => get('price_range');
  String get minimumRating => get('minimum_rating');
  String get availabilityFilter => get('availability_filter');
  String get sortByLabel => get('sort_by_label');
  String get searchBooks => get('search_books');
  String get allPrices => get('all_prices');
  String get priceRange010 => get('price_range_0_10');
  String get priceRange1025 => get('price_range_10_25');
  String get priceRange2550 => get('price_range_25_50');
  String get priceRange50100 => get('price_range_50_100');
  String get priceRange100Plus => get('price_range_100_plus');
  String get allRatings => get('all_ratings');
  String get rating4Plus => get('rating_4_plus');
  String get rating3Plus => get('rating_3_plus');
  String get rating2Plus => get('rating_2_plus');
  String get rating1Plus => get('rating_1_plus');
  String get allBooks => get('all_books');
  String get availableOnly => get('available_only');
  String get borrowOnlyFilter => get('borrow_only_filter');
  String get purchaseOnly => get('purchase_only');
  String get mostRelevant => get('most_relevant');
  String get newestFirstSort => get('newest_first_sort');
  String get oldestFirstSort => get('oldest_first_sort');
  String get priceLowToHighSort => get('price_low_to_high_sort');
  String get priceHighToLowSort => get('price_high_to_low_sort');
  String get highestRatedSort => get('highest_rated_sort');
  String get mostBorrowedSort => get('most_borrowed_sort');
  String get titleAZ => get('title_a_z');
  String get authorAZ => get('author_a_z');
  String searchFailedError(String error) =>
      get('search_failed_error').replaceAll('{error}', error);

  // Auth
  String get cannotConnectToServer => get('cannot_connect_to_server');
  String networkErrorLabel(String error) =>
      get('network_error_label').replaceAll('{error}', error);
  String get emailLabelLogin => get('email_label_login');
  String get passwordLabelLogin => get('password_label_login');
  String get loginButton => get('login_button');
  String get forgotPasswordQuestion => get('forgot_password_question');
  String get dontHaveAccount => get('dont_have_account');
  String get registerLink => get('register_link');
  String get loginFailed => get('login_failed');
  String get invalidCredentialsProvided => get('invalid_credentials_provided');
  String get locationUpdatedSuccessfully =>
      get('location_updated_successfully');
  String get searchPurchaseRequests => get('search_purchase_requests');
  String get searchBorrowRequests => get('search_borrow_requests');
  String get purchaseOrder => get('purchase_order');
  String get orderCustomerLabel => get('order_customer_label');
  String get orderAddressLabel => get('order_address_label');
  String get orderItemsLabel => get('order_items_label');
  String get orderTotalLabel => get('order_total_label');
  String get orderCreatedLabel => get('order_created_label');
  String get borrowingRequest => get('borrowing_request');
  String get returnRequest => get('return_request');
  String get noMatchingBorrowRequests => get('no_matching_borrow_requests');
  String get tryAdjustingSearchOrFilter =>
      get('try_adjusting_search_or_filter');
  String get noAddress => get('no_address');
  String get noBookTitleAvailable => get('no_book_title_available');
  String get booksToDeliver => get('books_to_deliver');
  String get searchCategories => get('search_categories');
  String get createdLabel => get('created_label');
  String get createCategory => get('create_category');
  String get editCategory => get('edit_category');
  String get categoryInformation => get('category_information');
  String get categoryName => get('category_name');
  String get categoryNameRequired => get('category_name_required');
  String get categoryNameMinLength => get('category_name_min_length');
  String get enterCategoryDescription => get('enter_category_description');
  String get categoryStatus => get('category_status');
  String get categoryActiveDescription => get('category_active_description');
  String get categoryInactiveDescription =>
      get('category_inactive_description');
  String get updateCategory => get('update_category');
  String get deleteCategory => get('delete_category');
  String deleteCategoryConfirmation(String name) =>
      get('delete_category_confirmation').replaceAll('{name}', name);
  String get categoryDeletedSuccessfully =>
      get('category_deleted_successfully');
  String get categoryCreatedSuccessfully =>
      get('category_created_successfully');
  String get categoryUpdatedSuccessfully =>
      get('category_updated_successfully');
  String get failedToCreateCategory => get('failed_to_create_category');
  String get failedToUpdateCategory => get('failed_to_update_category');
  String get failedToDeleteCategory => get('failed_to_delete_category');
  String get noCategories => get('no_categories');
  String get noCategoriesFound => get('no_categories_found');
  String get addCategory => get('add_category');
  String cannotDeleteCategoryWithBooks(String name) =>
      get('cannot_delete_category_with_books').replaceAll('{name}', name);
  String get failedToSaveCategory => get('failed_to_save_category');
  String get invalidDataPleaseCheckInput =>
      get('invalid_data_please_check_input');
  String get searchDiscounts => get('search_discounts');
  String get discountType => get('discount_type');
  String get invoiceDiscounts => get('invoice_discounts');
  String get bookDiscounts => get('book_discounts');
  String get noDiscounts => get('no_discounts');
  String get noDiscountsFound => get('no_discounts_found');
  String get noDiscountsFoundFilter => get('no_discounts_found_filter');
  String get createDiscount => get('create_discount');
  String get editDiscount => get('edit_discount');
  String get deleteDiscount => get('delete_discount');
  String deleteDiscountConfirmation(String code) =>
      get('delete_discount_confirmation').replaceAll('{code}', code);
  String get discountDeletedSuccessfully =>
      get('discount_deleted_successfully');
  String get showDetails => get('show_details');
  String get discountInformation => get('discount_information');
  String get hasDiscount => get('has_discount');
  String get discountCode => get('discount_code');
  String get enterDiscountCode => get('enter_discount_code');
  String get discountCodeRequired => get('discount_code_required');
  String get discountCodeMinLength => get('discount_code_min_length');
  String get selectDiscountType => get('select_discount_type');
  String get invoiceDiscount => get('invoice_discount');
  String get bookDiscount => get('book_discount');
  String get pleaseSelectDiscountType => get('please_select_discount_type');
  String get bookSelection => get('book_selection');
  String get selectBook => get('select_book');
  String get changeBook => get('change_book');
  String get discountValue => get('discount_value');
  String get discountPercentage => get('discount_percentage');
  String get enterPercentage => get('enter_percentage');
  String get percentageRequired => get('percentage_required');
  String get percentageRange => get('percentage_range');
  String get pleaseEnterValidNumber => get('please_enter_valid_number');
  String get priceAfterDiscount => get('price_after_discount');
  String get enterFinalPrice => get('enter_final_price');
  String get discountedPriceRequired => get('discounted_price_required');
  String get priceMustBeGreaterThanZero =>
      get('price_must_be_greater_than_zero');
  String get discountedPriceMustBeLess => get('discounted_price_must_be_less');
  String get maxUsesPerCustomer => get('max_uses_per_customer');
  String get enterMaxUses => get('enter_max_uses');
  String get maxUsesRequired => get('max_uses_required');
  String get validPositiveNumber => get('valid_positive_number');
  String get validityAndStatus => get('validity_and_status');
  String get startDate => get('start_date');
  String get endDate => get('end_date');
  String get enableThisDiscount => get('enable_this_discount');
  String discountValidFromTo(String startDate, String endDate) => get(
    'discount_valid_from_to',
  ).replaceAll('{startDate}', startDate).replaceAll('{endDate}', endDate);
  String get discountCreatedInactive => get('discount_created_inactive');
  String get createInactiveDiscount => get('create_inactive_discount');
  String get bookDiscountCreatedSuccessfully =>
      get('book_discount_created_successfully');
  String get bookDiscountUpdatedSuccessfully =>
      get('book_discount_updated_successfully');
  String get discountCreatedSuccessfully =>
      get('discount_created_successfully');
  String get discountUpdatedSuccessfully =>
      get('discount_updated_successfully');
  String get codeAlreadyExists => get('code_already_exists');
  String get discountCodeAlreadyExistsMessage =>
      get('discount_code_already_exists_message');
  String discountCodeAlreadyExistsTry(String alternatives) => get(
    'discount_code_already_exists_try',
  ).replaceAll('{alternatives}', alternatives);
  String get pleaseCheckInputAndTryAgain =>
      get('please_check_input_and_try_again');
  String get discountDetails => get('discount_details');
  String get refreshData => get('refresh_data');
  String get fixedPrice => get('fixed_price');
  String get percentage => get('percentage');
  String get unknown => get('unknown');
  String get createdDate => get('created_date');
  String get expirationDate => get('expiration_date');
  String get daysUntilExpiry => get('days_until_expiry');
  String get daysRemaining => get('days_remaining');
  String expiredDaysAgo(int days) =>
      get('expired_days_ago').replaceAll('{days}', days.toString());
  String get expiresToday => get('expires_today');
  String get backToList => get('back_to_list');
  String get errorLoadingDiscountDetails =>
      get('error_loading_discount_details');
  String get failedToLoadFreshData => get('failed_to_load_fresh_data');
  String get pleaseSelectBookForDiscount =>
      get('please_select_book_for_discount');
  String get book => get('book');
  String get start => get('start');
  String get end => get('end');
  String get maxUses => get('max_uses');
  String percentageOff(int value) =>
      get('percentage_off').replaceAll('{value}', value.toString());
  String get original => get('original');
  String get registerTitle => get('register_title');
  String get userType => get('user_type');
  String get firstNameLabel => get('first_name_label');
  String get enterFirstName => get('enter_first_name');
  String get lastNameLabel => get('last_name_label');
  String get enterLastName => get('enter_last_name');
  String get phoneOptional => get('phone_optional');
  String get confirmPasswordLabel => get('confirm_password_label');
  String get confirmPasswordHint => get('confirm_password_hint');
  String get registerButton => get('register_button');
  String get alreadyHaveAccount => get('already_have_account');
  String get loginLink => get('login_link');
  String get registrationSuccessful => get('registration_successful');
  String get registrationFailed => get('registration_failed');
  String get forgotPasswordTitle => get('forgot_password_title');
  String get checkYourEmail => get('check_your_email');
  String get forgotPasswordQuestionTitle =>
      get('forgot_password_question_title');
  String get passwordResetLinkSent => get('password_reset_link_sent');
  String get enterEmailForReset => get('enter_email_for_reset');
  String get sendResetLink => get('send_reset_link');
  String get passwordResetLinkSentTitle =>
      get('password_reset_link_sent_title');
  String get checkEmailInstructions => get('check_email_instructions');
  String get backToLogin => get('back_to_login');
  String get failedToSendResetLink => get('failed_to_send_reset_link');

  // Categories
  String get booksInCategory => get('books_in_category');
  String get purchaseBooks => get('purchase_books');
  String get searchBooksHint => get('search_books_hint');
  String get filterAll => get('filter_all');
  String get filterNewBooks => get('filter_new_books');
  String get filterHighestRated => get('filter_highest_rated');
  String get pleaseLogInToViewBooks => get('please_log_in_to_view_books');
  String get needToBeLoggedIn => get('need_to_be_logged_in');
  String get goToLogin => get('go_to_login');
  String get noBooksFoundCategory => get('no_books_found_category');
  String noBooksMatchSearch(String query) =>
      get('no_books_match_search').replaceAll('{query}', query);
  String get noBooksInCategory => get('no_books_in_category');
  String get noBooksAvailable => get('no_books_available');
  String get unknownAuthor => get('unknown_author');

  // Authors
  String get browseByAuthor => get('browse_by_author');
  String booksByAuthor(String author) =>
      get('books_by_author').replaceAll('{author}', author);
  String get errorLoadingAuthors => get('error_loading_authors');
  String get noAuthorsFound => get('no_authors_found');
  String get authorsWillAppearHere => get('authors_will_appear_here');
  String get searchAuthorsHint => get('search_authors_hint');
  String searchBooksByAuthor(String author) =>
      get('search_books_by_author').replaceAll('{author}', author);
  String get noBooksFoundAuthor => get('no_books_found_author');
  String noBooksMatchAuthorSearch(String query) =>
      get('no_books_match_author_search').replaceAll('{query}', query);
  String get authorNoBooksYet => get('author_no_books_yet');
  String get viewBooks => get('view_books');
  String get noDescriptionAvailableBook => get('no_description_available_book');
  String get searchBooksDialog => get('search_books_dialog');
  String searchInBooksByAuthor(String author) =>
      get('search_in_books_by_author').replaceAll('{author}', author);
  String get searchButton => get('search_button');

  // Notifications
  String get errorLoadingNotifications => get('error_loading_notifications');
  String get noNotifications => get('no_notifications');
  String get noNotificationsYet => get('no_notifications_yet');
  String get refreshButton => get('refresh_button');
  String get notificationTypeSuccess => get('notification_type_success');
  String get notificationTypeWarning => get('notification_type_warning');
  String get notificationTypeError => get('notification_type_error');
  String get notificationTypeOrder => get('notification_type_order');
  String get notificationTypeBorrow => get('notification_type_borrow');
  String get notificationTypeDelivery => get('notification_type_delivery');
  String get notificationTypeInfo => get('notification_type_info');
  String get justNow => get('just_now');
  String get allNotificationsMarkedRead => get('all_notifications_marked_read');
  String get deleteNotification => get('delete_notification');
  String get confirmDeleteNotification => get('confirm_delete_notification');
  String get deleteButton => get('delete_button');
  String get notificationDeletedSuccessfully =>
      get('notification_deleted_successfully');

  // Borrow Status
  String get unknownBook => get('unknown_book');
  String get requestDateLabel => get('request_date_label');
  String get dueDateLabel => get('due_date_label');
  String get durationLabel => get('duration_label');
  String get deliveryManagerLabel => get('delivery_manager_label');
  String get assigned => get('assigned');
  String get orderStatusTitle => get('order_status_title');
  String get approvedStatus => get('approved_status');
  String get deliveredStatus => get('delivered_status');
  String get returnedStatus => get('returned_status');
  String get noBorrowRequestsFound => get('no_borrow_requests_found');
  String get borrowHistoryWillAppear => get('borrow_history_will_appear');

  // Orders
  String orderNumberPrefix(String number) =>
      get('order_number_prefix').replaceAll('{number}', number);
  String totalPrefix(String amount) =>
      get('total_prefix').replaceAll(r'${amount}', amount);
  String statusPrefix(String status) =>
      get('status_prefix').replaceAll('{status}', status);
  String get noOrdersFoundOrders => get('no_orders_found_orders');
  String get ordersWillAppearHere => get('orders_will_appear_here');
  String get browseBooks => get('browse_books');
  String get failedToLoadOrders => get('failed_to_load_orders');
  String get tryAgain => get('try_again');

  // Book Detail
  String get bookDetailsTitle => get('book_details_title');
  String byAuthorUnknown(String author) =>
      get('by_author_unknown').replaceAll('{author}', author);
  String saveAmount(String amount) =>
      get('save_amount').replaceAll(r'${amount}', amount);
  String get priceNotSet => get('price_not_set');
  String get descriptionTab => get('description_tab');
  String get detailsTab => get('details_tab');
  String get reviewsTab => get('reviews_tab');
  String get thisBookOnSale => get('this_book_on_sale');
  String get quantityLabel => get('quantity_label');
  String get addToCartButtonDetail => get('add_to_cart_button_detail');
  String get borrowBookButton => get('borrow_book_button');
  String get outOfStockStatus => get('out_of_stock_status');
  String get limitedStock => get('limited_stock');
  String get inStockStatus => get('in_stock_status');
  String get availableForBorrowing => get('available_for_borrowing');
  String get notAvailableStatus => get('not_available_status');
  String get addedToFavoritesMessage => get('added_to_favorites_message');
  String get removedFromFavoritesMessage =>
      get('removed_from_favorites_message');

  // Profile
  String get personalInformation => get('personal_information');
  String get firstNameField => get('first_name_field');
  String get lastNameField => get('last_name_field');
  String get dateOfBirth => get('date_of_birth');
  String get dateFormatHint => get('date_format_hint');
  String get invalidDateFormat => get('invalid_date_format');
  String get selectDate => get('select_date');
  String get changeEmail => get('change_email');
  String get emailField => get('email_field');
  String get newEmail => get('new_email');
  String get confirmNewEmail => get('confirm_new_email');
  String get pleaseConfirmNewEmail => get('please_confirm_new_email');
  String get emailsDoNotMatch => get('emails_do_not_match');
  String get currentPasswordField => get('current_password_field');
  String get currentPasswordRequired => get('current_password_required');
  String get phoneNumber => get('phone_number');
  String get pleaseEnterValidPhone => get('please_enter_valid_phone');
  String get numberOfBooks => get('number_of_books');
  String get noItemsAvailable => get('no_items_available');
  String get orderDelivered => get('order_delivered');
  String get deliveryConfirmed => get('delivery_confirmed');
  String orderDeliveredMessage(String orderNumber) =>
      get('order_delivered_message').replaceAll('{orderNumber}', orderNumber);
  String get orderDeliveredMessageGeneric =>
      get('order_delivered_message_generic');
  String orderConfirmedMessage(String orderNumber, String confirmedBy) =>
      get('order_confirmed_message')
          .replaceAll('{orderNumber}', orderNumber)
          .replaceAll('{confirmedBy}', confirmedBy);
  String orderConfirmedMessageSimple(String orderNumber) => get(
    'order_confirmed_message_simple',
  ).replaceAll('{orderNumber}', orderNumber);
  String get orderConfirmedMessageGeneric =>
      get('order_confirmed_message_generic');
  String get cancellationReason => get('cancellation_reason');
  String get noCancellationReasonProvided =>
      get('no_cancellation_reason_provided');
  String get noDeliveryManagerAssigned => get('no_delivery_manager_assigned');
  String get orderNotAcceptedYetMessage =>
      get('order_not_accepted_yet_message');
  String get managerName => get('manager_name');
  String get assignedAt => get('assigned_at');
  String get startedAt => get('started_at');
  String get completedAt => get('completed_at');
  String get assignedBy => get('assigned_by');
  String get enterNotesPlaceholder => get('enter_notes_placeholder');
  String get pleaseEnterSomeNotes => get('please_enter_some_notes');
  String get addingNotes => get('adding_notes');
  String get noteAddedSuccessfully => get('note_added_successfully');
  String get failedToAddNotes => get('failed_to_add_notes');
  String get paymentMethodCash => get('payment_method_cash');
  String get paymentMethodCard => get('payment_method_card');
  String get paymentMethodCashOnDelivery =>
      get('payment_method_cash_on_delivery');
  String get paymentStatusPaid => get('payment_status_paid');
  String get paymentStatusUnpaid => get('payment_status_unpaid');
  String get paymentStatusPending => get('payment_status_pending');
  String get deliveryStatusAssigned => get('delivery_status_assigned');
  String get deliveryStatusInProgress => get('delivery_status_in_progress');
  String get deliveryStatusCompleted => get('delivery_status_completed');
  String get deliveryStatusCancelled => get('delivery_status_cancelled');
  String get editNote => get('edit_note');
  String get deleteNote => get('delete_note');
  String get confirmDeleteNote => get('confirm_delete_note');
  String get enterNoteContent => get('enter_note_content');
  String get pleaseEnterNoteContent => get('please_enter_note_content');
  String get updatingNote => get('updating_note');
  String get noteUpdatedSuccessfully => get('note_updated_successfully');
  String get deletingNote => get('deleting_note');
  String get noteDeletedSuccessfully => get('note_deleted_successfully');
  String get failedToDeleteNote => get('failed_to_delete_note');
  String get failedToUpdateNote => get('failed_to_update_note');

  // Admin Dashboard
  String get managerDashboard => get('manager_dashboard');
  String get quickActions => get('quick_actions');
  String get recentActivity => get('recent_activity');
  String welcomeManager(String name) =>
      get('welcome_manager').replaceAll('{name}', name);
  String get tapToViewProfile => get('tap_to_view_profile');
  String get personalProfile => get('personal_profile');
  String get announcements => get('announcements');
  String get newBorrowingRequest => get('new_borrowing_request');
  String get newOrderPlaced => get('new_order_placed');
  String get newAuthorAdded => get('new_author_added');
  String get bookInventoryUpdated => get('book_inventory_updated');
  String get newDiscountCodeCreated => get('new_discount_code_created');
  String signOutFailed(String error) =>
      get('sign_out_failed').replaceAll('{error}', error);
  String get systemOverview => get('system_overview');
  String get activeUsers => get('active_users');
  String get pendingOrders => get('pending_orders');
  String get revenue => get('revenue');
  String get newUserRegistered => get('new_user_registered');
  String get newBookAdded => get('new_book_added');
  String get newComplaintReceived => get('new_complaint_received');
  String get resetToDefaults => get('reset_to_defaults');
  String get resetToDefaultsConfirmation =>
      get('reset_to_defaults_confirmation');
  String get settingsResetToDefaults => get('settings_reset_to_defaults');
  String get errorResettingSettings => get('error_resetting_settings');
  String get errorLoadingSettings => get('error_loading_settings');
  String get settingsSavedSuccessfully => get('settings_saved_successfully');
  String get errorSavingSettings => get('error_saving_settings');
  String get assignmentNotFound => get('assignment_not_found');
  String get assignmentAcceptedSuccessfully =>
      get('assignment_accepted_successfully');
  String get errorAcceptingAssignment => get('error_accepting_assignment');
  String get rejectAssignment => get('reject_assignment');
  String get rejectAssignmentConfirmation =>
      get('reject_assignment_confirmation');
  String get rejectAssignmentButton => get('reject_assignment_button');
  String get errorRejectingAssignment => get('error_rejecting_assignment');
  String get failedToRejectAssignment => get('failed_to_reject_assignment');
  String failedToUpdateDeliveryAssignmentStatus(String statusCode) => get(
    'failed_to_update_delivery_assignment_status',
  ).replaceAll('{statusCode}', statusCode);
  String get deliveryStartedSuccessfully =>
      get('delivery_started_successfully');
  String get failedToStartDelivery => get('failed_to_start_delivery');
  String get errorStartingDelivery => get('error_starting_delivery');
  String get completeDelivery => get('complete_delivery');
  String get completeDeliveryConfirmation =>
      get('complete_delivery_confirmation');
  String get markAsDelivered => get('mark_as_delivered');
  String get orderMarkedDelivered => get('order_marked_delivered');
  String get failedToCompleteDelivery => get('failed_to_complete_delivery');
  String get errorCompletingDelivery => get('error_completing_delivery');
  String get deliveryTracking => get('delivery_tracking');
  String get deliveryTrackingInfo => get('delivery_tracking_info');
  String get startDelivery => get('start_delivery');
  String get updatingLocation => get('updating_location');
  String get updateCurrentLocation => get('update_current_location');
  String deliveryInProgressStatus(String status) =>
      get('delivery_in_progress_status').replaceAll('{status}', status);
  String get acceptDeliveryRequest => get('accept_delivery_request');
  String get acceptDeliveryRequestMessage =>
      get('accept_delivery_request_message');
  String get rejectDeliveryRequest => get('reject_delivery_request');
  String get rejectDeliveryRequestMessage =>
      get('reject_delivery_request_message');
  String requestAcceptedStatus(String status) =>
      get('request_accepted_status').replaceAll('{status}', status);
  String get requestRejectedSuccessfully =>
      get('request_rejected_successfully');
  String deliveryStartedStatus(String status) =>
      get('delivery_started_status').replaceAll('{status}', status);
  String deliveryCompletedStatus(String status) =>
      get('delivery_completed_status').replaceAll('{status}', status);
  String get startDeliveryConfirmation => get('start_delivery_confirmation');
  String get completeDeliveryMessage => get('complete_delivery_message');
  String get trackDelivery => get('track_delivery');
  String get viewDeliveryLocation => get('view_delivery_location');
  String get qty => get('qty');
  String get by => get('by');
  String get borrowed => get('borrowed');
  String get addressInformation => get('address_information');
  String get addressField => get('address_field');
  String get cityField => get('city_field');
  String get zipCodeField => get('zip_code_field');
  String get countryField => get('country_field');
  String get cancelButton => get('cancel_button');
  String get saveChanges => get('save_changes');
  String get camera => get('camera');
  String get gallery => get('gallery');
  String errorPickingImage(String error) =>
      get('error_picking_image').replaceAll('{error}', error);
  String get authenticationTokenNotAvailable =>
      get('authentication_token_not_available');
  String get profilePictureUpdatedSuccessfully =>
      get('profile_picture_updated_successfully');
  String get failedToUploadProfilePicture =>
      get('failed_to_upload_profile_picture');
  String errorUploadingProfilePicture(String error) =>
      get('error_uploading_profile_picture').replaceAll('{error}', error);
  String get userDataNotAvailable => get('user_data_not_available');
  String get noChangesDetected => get('no_changes_detected');
  String get pleaseEnterNewEmailAddress =>
      get('please_enter_new_email_address');
  String get pleaseConfirmNewEmailAddress =>
      get('please_confirm_new_email_address');
  String get emailAddressesDoNotMatch => get('email_addresses_do_not_match');
  String get pleaseEnterCurrentPasswordField =>
      get('please_enter_current_password_field');
  String get emailChangedSuccessfully => get('email_changed_successfully');
  String get failedToChangeEmail => get('failed_to_change_email');
  String get dateOfBirthUpdated => get('date_of_birth_updated');
  String get phoneNumberUpdated => get('phone_number_updated');
  String get emailAddressUpdated => get('email_address_updated');
  String get firstNameUpdated => get('first_name_updated');
  String get lastNameUpdated => get('last_name_updated');
  String get addressUpdated => get('address_updated');
  String get cityUpdated => get('city_updated');
  String get zipCodeUpdated => get('zip_code_updated');
  String get countryUpdated => get('country_updated');
  String get profileUpdatedSuccessfully => get('profile_updated_successfully');
  String profileUpdatedFields(int count) =>
      get('profile_updated_fields').replaceAll('{count}', count.toString());
  String profileUpdatedSuccessfullyFields(int count) => get(
    'profile_updated_successfully_fields',
  ).replaceAll('{count}', count.toString());
  String get emailSameNoChanges => get('email_same_no_changes');
  String get phoneNumberUpdatedSuccessfully =>
      get('phone_number_updated_successfully');
  String get firstNameUpdatedSuccessfully =>
      get('first_name_updated_successfully');
  String get lastNameUpdatedSuccessfully =>
      get('last_name_updated_successfully');
  String get addressUpdatedSuccessfully => get('address_updated_successfully');
  String get cityUpdatedSuccessfully => get('city_updated_successfully');
  String get zipCodeUpdatedSuccessfully => get('zip_code_updated_successfully');
  String get countryUpdatedSuccessfully => get('country_updated_successfully');
  String get failedToUpdateProfile => get('failed_to_update_profile');
  String errorUpdatingProfile(String error) =>
      get('error_updating_profile').replaceAll('{error}', error);
  String get streetAddress => get('street_address');
  String get stateProvince => get('state_province');
  String get zipPostalCode => get('zip_postal_code');
  String get saving => get('saving');
  String get accountOptions => get('account_options');
  String get verifyPassword => get('verify_password');
  String get verifyPasswordMessage => get('verify_password_message');
  String get verify => get('verify');
  String get searchAuthors => get('search_authors');
  String get noAuthors => get('no_authors');
  String get addAuthor => get('add_author');
  String get editAuthor => get('edit_author');
  String get authorInformation => get('author_information');
  String get authorNameRequired => get('author_name_required');
  String get authorNameMinLength => get('author_name_min_length');
  String get biography => get('biography');
  String get enterAuthorBiography => get('enter_author_biography');
  String get nationality => get('nationality');
  String get enterAuthorNationality => get('enter_author_nationality');
  String get authorPhoto => get('author_photo');
  String get orEnterImageUrl => get('or_enter_image_url');
  String get enterImageUrl => get('enter_image_url');
  String get birthDate => get('birth_date');
  String get selectBirthDate => get('select_birth_date');
  String get clearBirthDate => get('clear_birth_date');
  String get deathDate => get('death_date');
  String get selectDeathDate => get('select_death_date');
  String get clearDeathDate => get('clear_death_date');
  String get updateAuthor => get('update_author');
  String get deleteAuthor => get('delete_author');
  String deleteAuthorConfirmation(String name) =>
      get('delete_author_confirmation').replaceAll('{name}', name);
  String get authorDeletedSuccessfully => get('author_deleted_successfully');
  String get authorCreatedSuccessfully => get('author_created_successfully');
  String get authorUpdatedSuccessfully => get('author_updated_successfully');
  String get failedToCreateAuthor => get('failed_to_create_author');
  String get failedToUpdateAuthor => get('failed_to_update_author');
  String get failedToDeleteAuthor => get('failed_to_delete_author');
  String get failedToSaveAuthor => get('failed_to_save_author');
  String get onlyLibraryAdminsCanDeleteAuthors =>
      get('only_library_admins_can_delete_authors');
  String get cannotDeleteAuthorWithBooks =>
      get('cannot_delete_author_with_books');
  String get born => get('born');
  String get hasPhoto => get('has_photo');
  String get added => get('added');
  String get returnRequestDetails => get('return_request_details');
  String get requestNumberLabel => get('request_number_label');
  String get borrowedBook => get('borrowed_book');
  String get actions => get('actions');
  String get acceptRequest => get('accept_request');
  String get assignDeliveryManager => get('assign_delivery_manager');
  String get unknownUser => get('unknown_user');
  String get notSet => get('not_set');
  String get requestedLabel => get('requested_label');
  String get expectedReturnLabel => get('expected_return_label');
  String get bookLabel => get('book_label');
  String get requested => get('requested');
  String get searchReturnRequests => get('search_return_requests');
  String returnRequestNumber(String id) =>
      get('return_request_number').replaceAll('{id}', id);
  String get expectedReturnDate => get('expected_return_date');
  String get requestInformation => get('request_information');
  String get requestId => get('request_id');
  String get requestedAt => get('requested_at');
  String get acceptedAt => get('accepted_at');
  String get acceptReturnRequest => get('accept_return_request');
  String get startReturn => get('start_return');
  String get bookReturnedComplete => get('book_returned_complete');
  String get completeReturn => get('complete_return');
  String get completeReturnConfirmation => get('complete_return_confirmation');
  String get returnRequestAcceptedSuccessfully =>
      get('return_request_accepted_successfully');
  String get returnProcessStartedSuccessfully =>
      get('return_process_started_successfully');
  String get returnCompletedSuccessfully =>
      get('return_completed_successfully');
  String get failedToLoadReturnRequest => get('failed_to_load_return_request');
  String get failedToAcceptReturnRequest =>
      get('failed_to_accept_return_request');
  String get failedToStartReturnProcess =>
      get('failed_to_start_return_process');
  String get failedToCompleteReturn => get('failed_to_complete_return');
  String get noMatchingReturnRequests => get('no_matching_return_requests');
  String get tryAdjustingSearchOrFilterReturn =>
      get('try_adjusting_search_or_filter_return');
  String get refreshRequests => get('refresh_requests');
  String get addNewAdvertisement => get('add_new_advertisement');
  String get searchAdvertisements => get('search_advertisements');
  String get generalAdvertisement => get('general_advertisement');
  String get discountCodeAdvertisement => get('discount_code_advertisement');
  String get advertisementStatusActive => get('advertisement_status_active');
  String get advertisementStatusInactive =>
      get('advertisement_status_inactive');
  String get advertisementStatusScheduled =>
      get('advertisement_status_scheduled');
  String get advertisementStatusExpired => get('advertisement_status_expired');
  String get deleteAdvertisement => get('delete_advertisement');
  String get deleteAdvertisementConfirmation =>
      get('delete_advertisement_confirmation');
  String get advertisementDeletedSuccessfully =>
      get('advertisement_deleted_successfully');
  String get failedToDeleteAdvertisement =>
      get('failed_to_delete_advertisement');
  String get errorLoadingAdvertisements => get('error_loading_advertisements');
  String get accessRestricted => get('access_restricted');
  String get errorLoadingAdvertisementsTitle =>
      get('error_loading_advertisements_title');
  String get onlyLibraryAdminsManageAds =>
      get('only_library_admins_manage_ads');
  String get noAdvertisementsAtMoment => get('no_advertisements_at_moment');
  String get addAdvertisement => get('add_advertisement');
  String get startLabel => get('start_label');
  String get endLabel => get('end_label');
  String get createAdvertisement => get('create_advertisement');
  String get editAdvertisement => get('edit_advertisement');
  String get titleLabel => get('title_label');
  String get enterAdvertisementTitle => get('enter_advertisement_title');
  String get titleRequired => get('title_required');
  String get titleMinLength => get('title_min_length');
  String get contentLabel => get('content_label');
  String get enterAdvertisementContent => get('enter_advertisement_content');
  String get contentRequired => get('content_required');
  String get contentMinLength => get('content_min_length');
  String get imageUrlOptional => get('image_url_optional');
  String get adTypeLabel => get('ad_type_label');
  String get discountCodeRequiredForDiscountAds =>
      get('discount_code_required_for_discount_ads');
  String get selectDiscountCode => get('select_discount_code');
  String get noActiveDiscountCodesFound =>
      get('no_active_discount_codes_found');
  String get noActiveDiscountCodesInfo => get('no_active_discount_codes_info');
  String get statusLabel => get('status_label');
  String get startDateLabel => get('start_date_label');
  String get selectStartDate => get('select_start_date');
  String get startDateRequired => get('start_date_required');
  String get pleaseSelectStartDate => get('please_select_start_date');
  String get endDateLabel => get('end_date_label');
  String get selectEndDate => get('select_end_date');
  String get endDateRequired => get('end_date_required');
  String get pleaseSelectEndDate => get('please_select_end_date');
  String get endDateAfterStartDate => get('end_date_after_start_date');
  String get updateAdvertisement => get('update_advertisement');
  String get advertisementCreatedSuccessfully =>
      get('advertisement_created_successfully');
  String get advertisementUpdatedSuccessfully =>
      get('advertisement_updated_successfully');
  String get authenticationRequiredLoadDiscountCodes =>
      get('authentication_required_load_discount_codes');
  String get onlyLibraryAdminsAccessDiscountCodes =>
      get('only_library_admins_access_discount_codes');
  String get noActiveDiscountCodesCreateFirst =>
      get('no_active_discount_codes_create_first');
  String get failedToLoadDiscountCodes => get('failed_to_load_discount_codes');
  String get noReturnRequestsAtMoment => get('no_return_requests_at_moment');
  String get deliveryManagerInformationNotAvailable =>
      get('delivery_manager_information_not_available');
  String get startLabelColon => get('start_label_colon');
  String get endLabelColon => get('end_label_colon');
  String get advertisementDetails => get('advertisement_details');
  String get noDescriptionProvided => get('no_description_provided');
  String get advertisementInformation => get('advertisement_information');
  String get typeLabel => get('type_label');
  String get copyDiscountCode => get('copy_discount_code');
  String get copied => get('copied');
  String get imageNotAvailable => get('image_not_available');
  String get codeLabel => get('code_label');
  String get discountCodeLabel => get('discount_code_label');
  String get selectDiscountCodeHint => get('select_discount_code_hint');
  String get expires => get('expires');
  String get failedToDeleteAdvertisementColon =>
      get('failed_to_delete_advertisement_colon');
  String get errorColon => get('error_colon');

  // Cart
  String byAuthorCart(String author) =>
      get('by_author_cart').replaceAll('{author}', author);
  String get removeItemFromCart => get('remove_item_from_cart');
  String get proceedToCheckoutButton => get('proceed_to_checkout_button');
  String get discountApplied => get('discount_applied');
  String get editDiscountCode => get('edit_discount_code');
  String get removeDiscountCode => get('remove_discount_code');
  String youSaved(String amount) =>
      get('you_saved').replaceAll(r'${amount}', amount);
  String get applyButton => get('apply_button');
  String get subtotalLabel => get('subtotal_label');
  String get savingsLabel => get('savings_label');
  String get taxLabel => get('tax_label');
  String get deliveryLabel => get('delivery_label');
  String get totalLabel => get('total_label');
  String get removeItemDialog => get('remove_item_dialog');
  String removeItemFromCartConfirm(String title) =>
      get('remove_item_from_cart_confirm').replaceAll('{title}', title);
  String get removeButton => get('remove_button');
  String get editDiscountCodeDialog => get('edit_discount_code_dialog');
  String get enterNewDiscountCode => get('enter_new_discount_code');
  String get enterDiscountCodeHint => get('enter_discount_code_hint');
  String get applyButtonDialog => get('apply_button_dialog');
  String get discountCodeUpdatedSuccessfully =>
      get('discount_code_updated_successfully');
  String get failedToApplyNewDiscountCode =>
      get('failed_to_apply_new_discount_code');
  String get pleaseEnterDiscountCode => get('please_enter_discount_code');
  String get discountCodeAppliedSuccessfully =>
      get('discount_code_applied_successfully');
  String get failedToApplyDiscountCode => get('failed_to_apply_discount_code');
  String get cartIssues => get('cart_issues');
  String get pleaseLoginToProceed => get('please_login_to_proceed');
  String get loginLabel => get('login_label');

  // Offers Section
  String get specialOffers => get('special_offers');
  String get viewAll => get('view_all');
  String get noSpecialOffersAvailable => get('no_special_offers_available');
  String get shopNow => get('shop_now');
  String get limitedTime => get('limited_time');
  String get limited => get('limited');
  String get addOffersInAdminPanel => get('add_offers_in_admin_panel');

  // Complaints
  String get complaintDetailsLabel => get('complaint_details_label');
  String get complaintType => get('complaint_type');
  String get selectComplaintType => get('select_complaint_type');
  String get complaintTypeApp => get('complaint_type_app');
  String get complaintTypeDelivery => get('complaint_type_delivery');
  String get describeYourComplaint => get('describe_your_complaint');
  String get provideComplaintDetails => get('provide_complaint_details');
  String get pleaseEnterComplaintDetails =>
      get('please_enter_complaint_details');
  String get pleaseSelectComplaintType => get('please_select_complaint_type');
  String get provideMoreDetails => get('provide_more_details');
  String get updateComplaintButton => get('update_complaint_button');
  String get submitComplaintButton => get('submit_complaint_button');
  String get noComplaintsYet => get('no_complaints_yet');
  String get searchComplaints => get('search_complaints');
  String get inProgress => get('in_progress');
  String get closed => get('closed');
  String get noComplaints => get('no_complaints');
  String get noComplaintsFound => get('no_complaints_found');
  String complaintNumber(int id) =>
      get('complaint_number').replaceAll('{id}', id.toString());
  String statusUpdatedTo(String status) =>
      get('status_updated_to').replaceAll('{status}', status);
  String get refreshComplaintDetails => get('refresh_complaint_details');
  String get markAsOpen => get('mark_as_open');
  String get markAsReplied => get('mark_as_replied');
  String get markResolved => get('mark_resolved');
  String get replyToComplaint => get('reply_to_complaint');
  String get yourResponse => get('your_response');
  String get typeYourReply => get('type_your_reply');
  String get sending => get('sending');
  String get sendReply => get('send_reply');
  String get pleaseEnterResponse => get('please_enter_response');
  String get replySentSuccessfully => get('reply_sent_successfully');
  String errorSendingReply(String error) =>
      get('error_sending_reply').replaceAll('{error}', error);
  String get created => get('created');
  String get updated => get('updated');
  String get replied => get('replied');
  String get searchOrders => get('search_orders');
  String get allStatuses => get('all_statuses');
  String get pendingAssignment => get('pending_assignment');
  String get inDelivery => get('in_delivery');
  String get noOrders => get('no_orders');
  String get viewDetails => get('view_details');
  String get updateStatus => get('update_status');
  String errorLoadingNotificationsWithError(String error) =>
      '${get('error_loading_notifications')}: $error';
  String get tapToSubmitComplaint => get('tap_to_submit_complaint');

  // Library Management
  String get libraryDetails => get('library_details');
  String errorLoadingLibraryData(String error) =>
      get('error_loading_library_data').replaceAll('{error}', error);
  String get noLibraryData => get('no_library_data');
  String get noLibraryDataAvailable => get('no_library_data_available');
  String get basicInformation => get('basic_information');
  String get logo => get('logo');
  String get libraryStatistics => get('library_statistics');
  String get totalBooks => get('total_books');
  String get totalRequests => get('total_requests');
  String get pendingRequests => get('pending_requests');
  String get availableBooks => get('available_books');
  String get borrowedBooks => get('borrowed_books');
  String get totalMembers => get('total_members');
  String get activeMembers => get('active_members');
  String get libraryInformation => get('library_information');
  String get createdAt => get('created_at');
  String get updatedAt => get('updated_at');
  String get createdBy => get('created_by');
  String get lastUpdatedBy => get('last_updated_by');
  String get deleteLibrary => get('delete_library');
  String get areYouSureDeleteLibrary => get('are_you_sure_delete_library');
  String get libraryDeletedSuccessfully => get('library_deleted_successfully');
  String failedToDeleteLibrary(String error) =>
      get('failed_to_delete_library').replaceAll('{error}', error);
  String errorDeletingLibrary(String error) =>
      get('error_deleting_library').replaceAll('{error}', error);
  String get editLibraryInformation => get('edit_library_information');
  String get createLibrary => get('create_library');
  String get editLibrary => get('edit_library');
  String get libraryName => get('library_name');
  String get libraryNameRequired => get('library_name_required');
  String get enterLibraryName => get('enter_library_name');
  String get detailsRequired => get('details_required');
  String get enterLibraryDetails => get('enter_library_details');
  String get libraryLogo => get('library_logo');
  String get noLogoSelected => get('no_logo_selected');
  String get change => get('change');
  String get updateLibrary => get('update_library');
  String get libraryCreatedSuccessfully => get('library_created_successfully');
  String get libraryUpdatedSuccessfully => get('library_updated_successfully');
  String errorTakingPicture(String error) =>
      get('error_taking_picture').replaceAll('{error}', error);
  String get pleaseLogInLibrary => get('please_log_in_library');
  String get noLibraryFound => get('no_library_found');
  String get createYourFirstLibrary => get('create_your_first_library');
  String get noLibraryInformation => get('no_library_information');
  String get setUpLibraryInformation => get('set_up_library_information');
  String get setUpLibrary => get('set_up_library');

  // Book Management
  String get searchBooksPlaceholder => get('search_books_placeholder');
  String get searchBooksAuthorsPlaceholder =>
      get('search_books_authors_placeholder');
  String get searchAuthorsPlaceholder => get('search_authors_placeholder');
  String get searchDiscountedBooksPlaceholder =>
      get('search_discounted_books_placeholder');
  String get searchNotificationsPlaceholder =>
      get('search_notifications_placeholder');

  // Borrow Requests Screen
  String get borrowingManagement => get('borrowing_management');

  String get searchBorrowingRequests => get('search_borrowing_requests');
  String get customerLabel => get('customer_label');
  String get approve => get('approve');
  String get reject => get('reject');
  String get noMatchingRequests => get('no_matching_requests');
  String get noMatchingRequestsMessage => get('no_matching_requests_message');
  String get noBorrowingRequests => get('no_borrowing_requests');
  String get noBorrowingRequestsMessage => get('no_borrowing_requests_message');
  String get errorLoadingRequests => get('error_loading_requests');
  String get requestDetails => get('request_details');
  String get requestStatus => get('request_status');
  String get sendingDate => get('sending_date');
  String get fullName => get('full_name');
  String get email => get('email');
  String get fullNameRequired => get('full_name_required');
  String get validPhoneNumber => get('valid_phone_number');
  String get emailRequired => get('email_required');
  String get validEmail => get('valid_email');
  String get duration => get('duration');
  String get requestAction => get('request_action');
  String get whatActionForRequest => get('what_action_for_request');
  String get refreshRequestDetails => get('refresh_request_details');
  String get errorLoadingRequestDetails => get('error_loading_request_details');
  String get requestNotFound => get('request_not_found');
  String get unknownCustomer => get('unknown_customer');
  String get userId => get('user_id');
  String get bookId => get('book_id');
  String get expectedReturn => get('expected_return');
  String get noPendingBorrowRequestsFound =>
      get('no_pending_borrow_requests_found');
  String get noApprovedBorrowRequestsFound =>
      get('no_approved_borrow_requests_found');
  String get noActiveBorrowingsFound => get('no_active_borrowings_found');
  String get noRejectedRequestsFound => get('no_rejected_requests_found');
  String get pleaseEnterValidPhoneNumber =>
      get('please_enter_valid_phone_number');
  String get pleaseEnterValidEmailAddress =>
      get('please_enter_valid_email_address');
  String get deliveryCity => get('delivery_city');
  String get returnRequestLabel => get('return_request_label');
  String get statusPendingApproval => get('status_pending_approval');
  String get returnRequestInitiatedMessage =>
      get('return_request_initiated_message');
  String get fine => get('fine');
  String get approveReturnRequest => get('approve_return_request');
  String get assignedDeliveryManager => get('assigned_delivery_manager');
  String get returnRequestApprovedSuccessfully =>
      get('return_request_approved_successfully');
  String get failedToApproveReturnRequest =>
      get('failed_to_approve_return_request');
  String get noDeliveryManagersAvailable =>
      get('no_delivery_managers_available');
  String get selectDeliveryManager => get('select_delivery_manager');
  String get selectDeliveryManagerToAssignReturnRequest =>
      get('select_delivery_manager_to_assign_return_request');
  String get assignManager => get('assign_manager');
  String get deliveryManagerAssignedSuccessfully =>
      get('delivery_manager_assigned_successfully');
  String get failedToAssignDeliveryManager =>
      get('failed_to_assign_delivery_manager');
  String get locationTrackingOnlyAvailableDuringActiveDelivery =>
      get('location_tracking_only_available_during_active_delivery');
  String get authenticationRequiredPleaseLogInAgain =>
      get('authentication_required_please_log_in_again');
  String get deliveryManagerLocationNotAvailableAtTheMoment =>
      get('delivery_manager_location_not_available_at_the_moment');
  String get couldNotOpenMapsPleaseCheckYourInternetConnection =>
      get('could_not_open_maps_please_check_your_internet_connection');
  String get administration => get('administration');
  String get requestIsPendingApproval => get('request_is_pending_approval');
  String get requestHasBeenApproved => get('request_has_been_approved');
  String get requestHasBeenRejected => get('request_has_been_rejected');
  String get bookIsCurrentlyBorrowed => get('book_is_currently_borrowed');
  String get bookHasBeenDelivered => get('book_has_been_delivered');
  String get bookHasBeenReturned => get('book_has_been_returned');
  String get returnRequestPendingApproval =>
      get('return_request_pending_approval');
  String get returnRequestApprovedAssignDeliveryManager =>
      get('return_request_approved_assign_delivery_manager');
  String get returnAssignedToDeliveryManager =>
      get('return_assigned_to_delivery_manager');
  String get bookIsOverdue => get('book_is_overdue');
  String get approvalDate => get('approval_date');
  String get notes => get('notes');
  String get rejectionReason => get('rejection_reason');
  String get fineAmount => get('fine_amount');
  String get fineDetails => get('fine_details');
  String get daysOverdue => get('days_overdue');
  String get penaltyInformation => get('penalty_information');
  String get noPenaltyForThisOrder => get('no_penalty_for_this_order');
  String get penaltyApplied => get('penalty_applied');
  String get penaltyAmountLabel => get('penalty_amount_label');
  String get penaltyReasonLabel => get('penalty_reason_label');
  String get exceededBorrowingPeriod => get('exceeded_borrowing_period');
  String get notSelected => get('not_selected');
  String get paymentMethodLabel => get('payment_method_label');
  String get paymentStatusLabel => get('payment_status_label');
  String get selectPaymentMethod => get('select_payment_method');
  String get deliveryManagerWillCollectCash =>
      get('delivery_manager_will_collect_cash');
  String get redirectedToCompleteOnlinePayment =>
      get('redirected_to_complete_online_payment');
  String get cashPaymentSelected => get('cash_payment_selected');
  String get oopsSomethingWentWrong => get('oops_something_went_wrong');
  String get errorSelectingPaymentMethod =>
      get('error_selecting_payment_method');
  String get failedToSelectPaymentMethod =>
      get('failed_to_select_payment_method');
  String get requestTimelineLabel => get('request_timeline_label');
  String get customerInformationUpdatedSuccessfully =>
      get('customer_information_updated_successfully');
  String get failedToUpdateCustomerInformation =>
      get('failed_to_update_customer_information');
  String get deliveryManagerInformationUpdatedSuccessfully =>
      get('delivery_manager_information_updated_successfully');
  String get failedToUpdateDeliveryManagerInformation =>
      get('failed_to_update_delivery_manager_information');
  String get na => get('na');
  String get orderManagement => get('order_management');
  String get refreshOrders => get('refresh_orders');
  String get rejectOrder => get('reject_order');
  String get approveOrder => get('approve_order');
  String get orderAction => get('order_action');
  String get whatActionForOrder => get('what_action_for_order');
  String get chooseDeliveryManager => get('choose_delivery_manager');
  String get approveOrderButton => get('approve_order_button');
  String get orderApprovedSuccessfully => get('order_approved_successfully');
  String get orderRejectedSuccessfully => get('order_rejected_successfully');
  String get failedToApproveOrder => get('failed_to_approve_order');
  String get failedToRejectOrder => get('failed_to_reject_order');
  String get orderCancelledSuccessfully => get('order_cancelled_successfully');
  String get failedToCancelOrder => get('failed_to_cancel_order');
  String get noPendingOrders => get('no_pending_orders');
  String get noConfirmedOrders => get('no_confirmed_orders');
  String get noOrdersInDelivery => get('no_orders_in_delivery');
  String get noDeliveredOrders => get('no_delivered_orders');
  String get noCancelledOrders => get('no_cancelled_orders');
  String get allOrdersProcessed => get('all_orders_processed');
  String get orderedLabel => get('ordered_label');
  String get itemsLabel => get('items_label');
  String get itemsLabelPlural => get('items_label_plural');
  String get pleaseProvideRejectionReason =>
      get('please_provide_rejection_reason');
  String get enterReasonForRejection => get('enter_reason_for_rejection');
  String get pleaseProvideReasonForRejecting =>
      get('please_provide_reason_for_rejecting');
  String selectDeliveryManagerToAssignOrder(int orderId) => get(
    'select_delivery_manager_to_assign_order',
  ).replaceAll('{orderId}', orderId.toString());
  String get deliveryTrackingFeatureComingSoon =>
      get('delivery_tracking_feature_coming_soon');
  String errorLoadingDeliveryManagers(String error) =>
      get('error_loading_delivery_managers').replaceAll('{error}', error);
  String errorApprovingOrder(String error) =>
      get('error_approving_order').replaceAll('{error}', error);
  String errorRejectingOrder(String error) =>
      get('error_rejecting_order').replaceAll('{error}', error);
  String errorCancellingOrder(String error) =>
      get('error_cancelling_order').replaceAll('{error}', error);
  String get confirmed => get('confirmed');
  String get deliveryRequests => get('delivery_requests');
  String get searchDeliveryRequests => get('search_delivery_requests');
  String get deliveryMonitoringNoLongerAvailable =>
      get('delivery_monitoring_no_longer_available');
  String get sessionExpiredPleaseLogInAgain =>
      get('session_expired_please_log_in_again');
  String errorLoadingDeliveryData(String error) =>
      get('error_loading_delivery_data').replaceAll('{error}', error);
  String get noDeliveryRequests => get('no_delivery_requests');
  String get thereAreNoDeliveryRequests =>
      get('there_are_no_delivery_requests');
  String get authenticationFailedPleaseLogInAgain =>
      get('authentication_failed_please_log_in_again');
  String get noDeliveryAssignmentsFound => get('no_delivery_assignments_found');
  String get assignDeliveryAgents => get('assign_delivery_agents');
  String errorLoadingData(String error) =>
      get('error_loading_data').replaceAll('{error}', error);
  String get noDeliveryOrdersFound => get('no_delivery_orders_found');
  String get availableAgents => get('available_agents');
  String agentsAvailableForAssignment(int count) {
    final plural = count == 1 ? '' : 's';
    return get(
      'agents_available_for_assignment',
    ).replaceAll('{count}', count.toString()).replaceAll('{plural}', plural);
  }

  String get noAgentAssigned => get('no_agent_assigned');
  String assignedTo(String agent) =>
      get('assigned_to').replaceAll('{agent}', agent);
  String get assignAgent => get('assign_agent');
  String get reassign => get('reassign');
  String get unassign => get('unassign');
  String get assignDeliveryAgent => get('assign_delivery_agent');
  String get selectAgentToAssign => get('select_agent_to_assign');
  String get agent => get('agent');
  String get reassignDeliveryAgent => get('reassign_delivery_agent');
  String currentlyAssignedTo(String agent) =>
      get('currently_assigned_to').replaceAll('{agent}', agent);
  String get selectNewAgent => get('select_new_agent');
  String get newAgent => get('new_agent');
  String get noOne => get('no_one');
  String agentAssignedSuccessfully(String agent) =>
      get('agent_assigned_successfully').replaceAll('{agent}', agent);
  String errorAssigningAgent(String error) =>
      get('error_assigning_agent').replaceAll('{error}', error);
  String get unassignAgent => get('unassign_agent');
  String areYouSureUnassign(String agent) =>
      get('are_you_sure_unassign').replaceAll('{agent}', agent);
  String get agentUnassignedSuccessfully =>
      get('agent_unassigned_successfully');
  String errorUnassigningAgent(String error) =>
      get('error_unassigning_agent').replaceAll('{error}', error);
  String get noAvailableAgentsToAssign => get('no_available_agents_to_assign');
  String get creationDate => get('creation_date');
  String get deliveryCost => get('delivery_cost');
  String get totalAmount => get('total_amount');
  String get deliveryManagerWillBeAssignedSoon =>
      get('delivery_manager_will_be_assigned_soon');
  String get noDeliveryManagerAssignedYet =>
      get('no_delivery_manager_assigned_yet');
  String get noDeliveryManagerInformationAvailable =>
      get('no_delivery_manager_information_available');
  String get whatActionWouldYouLikeToTakeForThisOrder =>
      get('what_action_would_you_like_to_take_for_this_order');
  String get selectADeliveryManagerForThisRequest =>
      get('select_a_delivery_manager_for_this_request');
  String get addNotes => get('add_notes');
  String get enterNotesAboutThisOrder => get('enter_notes_about_this_order');

  String orderRejectedReason(String reason) =>
      get('order_rejected_reason').replaceAll('{reason}', reason);
  String get failedToGetDeliveryLocation =>
      get('failed_to_get_delivery_location');
  String get allCategories => get('all_categories');
  String get allAuthors => get('all_authors');
  String get noBooks => get('no_books');
  String get addBook => get('add_book');
  String copiesLabel(int available, int total) => get('copies')
      .replaceAll('{available}', available.toString())
      .replaceAll('{total}', total.toString());
  String get pricingAndInventory => get('pricing_and_inventory');
  String get borrowPrice => get('borrow_price');
  String get purchasePrice => get('purchase_price');
  String get totalInventory => get('total_inventory');
  String get defaultBorrowingPeriod => get('default_borrowing_period');
  String get borrowCount => get('borrow_count');
  String get dates => get('dates');
  String get uncategorized => get('uncategorized');
  String get viewReviews => get('view_reviews');
  String get editBook => get('edit_book');
  String get deleteBook => get('delete_book');
  String get areYouSureDeleteBook => get('are_you_sure_delete_book');
  String areYouSureDeleteBookWithTitle(String title) =>
      get('are_you_sure_delete_book_with_title').replaceAll('{title}', title);
  String get bookDeletedSuccessfully => get('book_deleted_successfully');
  String errorDeletingBook(String error) =>
      get('error_deleting_book').replaceAll('{error}', error);
  String get onlyLibraryAdministratorsDelete =>
      get('only_library_administrators_delete');
  String get noPermissionDeleteBooks => get('no_permission_delete_books');
  String get cannotDeleteBookAuthor => get('cannot_delete_book_author');
  String get pleaseLogInBooksManagement =>
      get('please_log_in_books_management');
  String get createLibraryFirstManageBooks =>
      get('create_library_first_manage_books');
  String reviewsFor(String title) =>
      get('reviews_for').replaceAll('{title}', title);
  String get noBookDataProvided => get('no_book_data_provided');
  String errorRefreshingBook(String error) =>
      get('error_refreshing_book').replaceAll('{error}', error);
  String get bookName => get('book_name');
  String get bookNameRequired => get('book_name_required');
  String get enterBookName => get('enter_book_name');
  String get descriptionRequired => get('description_required');
  String get enterBookDescription => get('enter_book_description');
  String get bookPicture => get('book_picture');
  String get classification => get('classification');
  String get selectCategory => get('select_category');
  String get pleaseSelectCategory => get('please_select_category');
  String get pleaseSelectAuthor => get('please_select_author');
  String get pricingAvailability => get('pricing_availability');
  String get totalStock => get('total_stock');
  String get totalStockRequired => get('total_stock_required');
  String get enterTotalStock => get('enter_total_stock');
  String get availableCopiesRequired => get('available_copies_required');
  String get enterAvailableCopies => get('enter_available_copies');
  String get availableCopiesLabel => get('available_copies_label');
  String get numberOfBooksForBorrowing => get('number_of_books_for_borrowing');
  String get enterNumberBorrowing => get('enter_number_borrowing');
  String get availableForPurchase => get('available_for_purchase');
  String get newBook => get('new_book');
  String get bookCanBePurchased => get('book_can_be_purchased');
  String get bookCanBeBorrowed => get('book_can_be_borrowed');
  String get markAsNewArrival => get('mark_as_new_arrival');
  String get updateBook => get('update_book');
  String get createBook => get('create_book');
  String get bookCreatedSuccessfully => get('book_created_successfully');
  String get bookUpdatedSuccessfully => get('book_updated_successfully');
  String failedToCreateBook(String error) =>
      get('failed_to_create_book').replaceAll('{error}', error);
  String failedToUpdateBook(String error) =>
      get('failed_to_update_book').replaceAll('{error}', error);
  String get authenticationRequiredPleaseLogIn =>
      get('authentication_required_please_log_in');
  String get selectCategoryLabel => get('select_category_label');
  String get selectAuthorLabel => get('select_author_label');

  // Admin Notifications
  String get type => get('type');
  String markAllReadWithCount(int count) =>
      get('mark_all_read_with_count').replaceAll('{count}', count.toString());
  String get deleteAllNotifications => get('delete_all_notifications');
  String get areYouSureDeleteNotification =>
      get('are_you_sure_delete_notification');
  String get areYouSureDeleteAllNotifications =>
      get('are_you_sure_delete_all_notifications');
  String get notificationMarkedAsRead => get('notification_marked_as_read');
  String get allNotificationsMarkedAsRead =>
      get('all_notifications_marked_as_read');
  String get allNotificationsDeletedSuccessfully =>
      get('all_notifications_deleted_successfully');
  String get unableToDeleteNotification => get('unable_to_delete_notification');
  String get unableToDeleteNotifications =>
      get('unable_to_delete_notifications');
  String errorLoadingNotificationsAdmin(String error) =>
      get('error_loading_notifications_admin').replaceAll('{error}', error);
  String daysAgo(int days) =>
      get('days_ago').replaceAll('{days}', days.toString());
  String hoursAgo(int hours) =>
      get('hours_ago').replaceAll('{hours}', hours.toString());
  String minutesAgo(int minutes) =>
      get('minutes_ago').replaceAll('{minutes}', minutes.toString());
  String get order => get('notification_type_order');
  String get borrowing => get('borrowing');
  String get markAsRead => get('mark_as_read');
  String get enterPurchasePrice => get('enter_purchase_price');
  String get enterBorrowPrice => get('enter_borrow_price');
  String get enterTotalNumberBooks => get('enter_total_number_books');
  String get enterNumberAvailableCopies => get('enter_number_available_copies');
  String get enterNumberBooksBorrowing => get('enter_number_books_borrowing');
  String get purchasePriceRequired => get('purchase_price_required');
  String get borrowPriceRequired => get('borrow_price_required');
  String get pleaseEnterValidPrice => get('please_enter_valid_price');
  String get pleaseEnterValidStockQuantity =>
      get('please_enter_valid_stock_quantity');
  String get pleaseEnterValidQuantity => get('please_enter_valid_quantity');
  String get quantityRequired => get('quantity_required');
  String failedToDeleteBook(String error) =>
      get('failed_to_delete_book').replaceAll('{error}', error);
  String get underReview => get('under_review');
  String get resolved => get('resolved');
  String get at => get('at');
  String get errorLoadingComplaints => get('error_loading_complaints');
  String get complaint => get('complaint');
  String get passwordRequirements => get('password_requirements');
  String get atLeast8Characters => get('at_least_8_characters');
  String get containsUppercase => get('contains_uppercase');
  String get containsLowercase => get('contains_lowercase');
  String get containsNumber => get('contains_number');
  String get containsSpecial => get('contains_special');
  String get supportLabel => get('support');
  String get aboutLabel => get('about');
  String get appVersionAndInformation => get('app_version_and_information');
  String get useThisCode => get('use_this_code');
  String get validUntil => get('valid_until');
  String get useOffer => get('use_offer');
  String get codeCopiedToClipboard => get('code_copied_to_clipboard');
  String get applyingOffer => get('applying_offer');
  String get discountAppliedLabel => get('discount_applied');
  String youSavedAmount(String amount) =>
      get('you_saved_amount').replaceAll(r'${amount}', amount);
  String get editDiscountCodeTooltip => get('edit_discount_code_tooltip');
  String get removeDiscountCodeTooltip => get('remove_discount_code_tooltip');
  String get englishLanguage => get('english_language');
  String get arabicLanguage => get('arabic_language');
  String get notificationPreferences => get('notification_preferences');
  String get chooseHowToBeNotified => get('choose_how_to_be_notified');
  String get notificationChannels => get('notification_channels');
  String get emailNotifications => get('email_notifications');
  String get receiveNotificationsViaEmail =>
      get('receive_notifications_via_email');
  String get pushNotifications => get('push_notifications');
  String get receivePushNotifications => get('receive_push_notifications');
  String get smsNotifications => get('sms_notifications');
  String get receiveNotificationsViaSms => get('receive_notifications_via_sms');
  String get whatToNotifyMeAbout => get('what_to_notify_me_about');
  String get orderUpdates => get('order_updates');
  String get updatesAboutOrders => get('updates_about_orders');
  String get borrowReminders => get('borrow_reminders');
  String get remindersAboutBorrowedBooks =>
      get('reminders_about_borrowed_books');
  String get deliveryUpdates => get('delivery_updates');
  String get updatesAboutDeliveryStatus => get('updates_about_delivery_status');
  String get saveSettings => get('save_settings');
  String get resetToDefault => get('reset_to_default');
  String get settingsResetToDefault => get('settings_reset_to_default');
  String get notificationSettingsSaved => get('notification_settings_saved');

  // Notification translations
  String get notificationBookDeliveredSuccessfully =>
      get('notification_book_delivered_successfully');
  String get notificationDeliveryStarted =>
      get('notification_delivery_started');
  String get notificationBorrowRequestApproved =>
      get('notification_borrow_request_approved');
  String get notificationBorrowRequestRejected =>
      get('notification_borrow_request_rejected');
  String get notificationComplaintResolved =>
      get('notification_complaint_resolved');
  String get notificationComplaintAnswered =>
      get('notification_complaint_answered');
  String get notificationNewComplaintReceived =>
      get('notification_new_complaint_received');
  String get notificationNewComplaintReceivedMessage =>
      get('notification_new_complaint_received_message');
  String get notificationOrderPlaced => get('notification_order_placed');
  String get notificationOrderShipped => get('notification_order_shipped');
  String get notificationReturnRequest => get('notification_return_request');
  String get notificationReturnProcessStarted =>
      get('notification_return_process_started');
  String get notificationReturnAccepted => get('notification_return_accepted');
  String get notificationNewOrderPendingApproval =>
      get('notification_new_order_pending_approval');
  String get notificationNewPurchaseRequest =>
      get('notification_new_purchase_request');
  String get notificationDeliveryManagerStatusUpdate =>
      get('notification_delivery_manager_status_update');
  String get notificationNewBorrowingRequest =>
      get('notification_new_borrowing_request');
  String get notificationNewBorrowingRequestPaymentConfirmed =>
      get('notification_new_borrowing_request_payment_confirmed');
  String get notificationNewOrderPendingApprovalMessage =>
      get('notification_new_order_pending_approval_message');
  String get notificationNewPurchaseRequestMessage =>
      get('notification_new_purchase_request_message');
  String get notificationDeliveryManagerStatusUpdateMessage =>
      get('notification_delivery_manager_status_update_message');
  String get notificationNewBorrowingRequestMessage =>
      get('notification_new_borrowing_request_message');
  String get notificationNewBorrowingRequestPaymentConfirmedMessage =>
      get('notification_new_borrowing_request_payment_confirmed_message');

  String notificationBookDeliveredMessage(
    String bookTitle,
    String returnDate,
  ) => get(
    'notification_book_delivered_message',
  ).replaceAll('{bookTitle}', bookTitle).replaceAll('{returnDate}', returnDate);
  String notificationBookDeliveredMessageSimple(String bookTitle) => get(
    'notification_book_delivered_message_simple',
  ).replaceAll('{bookTitle}', bookTitle);
  String get notificationBookDeliveredMessageGeneric =>
      get('notification_book_delivered_message_generic');

  String notificationDeliveryStartedMessage(String bookTitle) => get(
    'notification_delivery_started_message',
  ).replaceAll('{bookTitle}', bookTitle);
  String get notificationDeliveryStartedMessageGeneric =>
      get('notification_delivery_started_message_generic');

  String notificationBorrowApprovedMessage(
    String bookTitle,
    String deliveryManager,
  ) => get('notification_borrow_approved_message')
      .replaceAll('{bookTitle}', bookTitle)
      .replaceAll('{deliveryManager}', deliveryManager);
  String notificationBorrowApprovedMessageSimple(String bookTitle) => get(
    'notification_borrow_approved_message_simple',
  ).replaceAll('{bookTitle}', bookTitle);
  String get notificationBorrowApprovedMessageGeneric =>
      get('notification_borrow_approved_message_generic');

  String get notificationComplaintResolvedMessage =>
      get('notification_complaint_resolved_message');
  String get notificationComplaintAnsweredMessage =>
      get('notification_complaint_answered_message');

  String notificationBookReturnedMessage(String bookTitle) => get(
    'notification_book_returned_message',
  ).replaceAll('{bookTitle}', bookTitle);
  String get notificationBookReturnedMessageGeneric =>
      get('notification_book_returned_message_generic');

  String notificationReturnProcessStartedMessage(
    String bookTitle,
    String deliveryManager,
  ) => get('notification_return_process_started_message')
      .replaceAll('{bookTitle}', bookTitle)
      .replaceAll('{deliveryManager}', deliveryManager);
  String notificationReturnProcessStartedMessageSimple(String bookTitle) => get(
    'notification_return_process_started_message_simple',
  ).replaceAll('{bookTitle}', bookTitle);
  String get notificationReturnProcessStartedMessageGeneric =>
      get('notification_return_process_started_message_generic');

  String notificationReturnAcceptedMessage(
    String bookTitle,
    String deliveryManager,
  ) => get('notification_return_accepted_message')
      .replaceAll('{bookTitle}', bookTitle)
      .replaceAll('{deliveryManager}', deliveryManager);
  String notificationReturnAcceptedMessageSimple(String bookTitle) => get(
    'notification_return_accepted_message_simple',
  ).replaceAll('{bookTitle}', bookTitle);
  String get notificationReturnAcceptedMessageGeneric =>
      get('notification_return_accepted_message_generic');

  // Home screen section titles
  String get purchasingBooks => get('purchasing_books');
  String get discountedBooks => get('discounted_books');
  String discountedBooksFound(int count) =>
      get('discounted_books_found').replaceAll('{count}', count.toString());
  String discountOff(int percentage) =>
      get('discount_off').replaceAll('{percentage}', percentage.toString());
  String get saleBadge => get('sale_badge');
  String get newArrivals => get('new_arrivals');
  String get fiction => get('fiction');
  String get nonFiction => get('non_fiction');
  String get science => get('science');
  String get technology => get('technology');
  String get browseCategories => get('browse_categories');
  String get browseAuthors => get('browse_authors');
  String get noDiscountedBooksAvailable => get('no_discounted_books_available');
  String get checkBackLaterForSpecialOffers =>
      get('check_back_later_for_special_offers');
  String get checkBackLaterForNewBooksToBuy =>
      get('check_back_later_for_new_books_to_buy');
  String get noBorrowedBooksFound => get('no_borrowed_books_found');
  String borrowLabel(String price) =>
      get('borrow_label').replaceAll('{price}', price);
  String get borrowPrefix => get('borrow_prefix');
  String get errorLoadingDiscountedBooks =>
      get('error_loading_discounted_books');
  String get noBooksAvailableForPurchase =>
      get('no_books_available_for_purchase');
  String get failedToLoadAdvertisementDetails =>
      get('failed_to_load_advertisement_details');
  String get specialOffer => get('special_offer');
  String discountCodeCopied(String code) =>
      get('discount_code_copied').replaceAll('{code}', code);
  String get failedToCopyDiscountCode => get('failed_to_copy_discount_code');
  String get descriptionLabel => get('description_label');
  String get offerDetails => get('offer_details');
  String get limitedTimeOffer => get('limited_time_offer');
  String get activeAdvertisement => get('active_advertisement');
  String booksCount(int count) =>
      get('books_count').replaceAll('{count}', count.toString());
  String get noCategoriesAvailable => get('no_categories_available');
  String get addCategoriesInAdminPanel => get('add_categories_in_admin_panel');
  String get noAuthorsAvailable => get('no_authors_available');
  String get addAuthorsInAdminPanel => get('add_authors_in_admin_panel');
  String get discountCodeExpired => get('discount_code_expired');
  String get discountCodeInactive => get('discount_code_inactive');
  String get discountCodeAlreadyApplied => get('discount_code_already_applied');
  String get discountCodeUsageLimitExceeded =>
      get('discount_code_usage_limit_exceeded');
  String get invalidDiscountCode => get('invalid_discount_code');
  String get statusPending => get('status_pending');
  String get statusApproved => get('status_approved');
  String get statusDelivered => get('status_delivered');
  String get statusReturned => get('status_returned');
  String get statusRejected => get('status_rejected');
  String get statusOverdue => get('status_overdue');
  String get statusActive => get('status_active');
  String get statusBorrowed => get('status_borrowed');
  String get statusOutForDelivery => get('status_out_for_delivery');
  String get statusCompleted => get('status_completed');
  String get statusProcessing => get('status_processing');
  String get statusShipped => get('status_shipped');
  String get statusCancelled => get('status_cancelled');
  String get statusPendingReview => get('status_pending_review');
  String get statusRejectedByAdmin => get('status_rejected_by_admin');
  String get statusWaitingForDeliveryManager =>
      get('status_waiting_for_delivery_manager');
  String get statusRejectedByDeliveryManager =>
      get('status_rejected_by_delivery_manager');
  String get statusInDelivery => get('status_in_delivery');
  String get statusAssignedToDelivery => get('status_assigned_to_delivery');
  String get statusDeliveryInProgress => get('status_delivery_in_progress');
  String get statusConfirmed => get('status_confirmed');
  String get statusAssigned => get('status_assigned');
  String get statusAccepted => get('status_accepted');
  String get statusInProgress => get('status_in_progress');
  String get statusReturnRequested => get('status_return_requested');
  String get statusReturnApproved => get('status_return_approved');
  String get statusReturnAssigned => get('status_return_assigned');
  String get statusPendingPickup => get('status_pending_pickup');
  String get statusInReturn => get('status_in_return');
  String get statusReturningToLibrary => get('status_returning_to_library');
  String get statusReturnedSuccessfully => get('status_returned_successfully');
  String get statusLateReturn => get('status_late_return');
  String copiesAvailable(int count) =>
      get('copies_available').replaceAll('{count}', count.toString());
  String get authorLabel => get('author_label');
  String get categoryLabel => get('category_label');
  String get searchFavorites => get('search_favorites');
  String get editReview => get('edit_review');
  String get ratingLabel => get('rating_label');
  String get commentLabel => get('comment_label');
  String get shareThoughtsAboutBook => get('share_thoughts_about_book');
  String get submitReview => get('submit_review');
  String get updateReview => get('update_review');
  String get pleaseSelectRating => get('please_select_rating');
  String get pleaseWriteComment => get('please_write_comment');
  String get pleaseProvideRatingOrComment =>
      get('please_provide_rating_or_comment');
  String get itemsPerPage => get('items_per_page');
  String get numberOfItemsToDisplayPerPage =>
      get('number_of_items_to_display_per_page');
  String get autoRefresh => get('auto_refresh');
  String get automaticallyRefreshData => get('automatically_refresh_data');
  String get refreshInterval => get('refresh_interval');
  String get howOftenToRefreshData => get('how_often_to_refresh_data');
  String get pendingReview => get('pending_review');
  String get rejectedByAdmin => get('rejected_by_admin');
  String get waitingForDeliveryManager => get('waiting_for_delivery_manager');
  String get rejectedByDeliveryManager => get('rejected_by_delivery_manager');
  String get assignedToDelivery => get('assigned_to_delivery');
  String get deliveryActions => get('delivery_actions');
  String get approveDelivery => get('approve_delivery');
  String get rejectDelivery => get('reject_delivery');
  String get deliveryApprovedSuccessfully =>
      get('delivery_approved_successfully');
  String get failedToApproveDelivery => get('failed_to_approve_delivery');
  String get enterRejectionReason => get('enter_rejection_reason');
  String get failedToRejectDelivery => get('failed_to_reject_delivery');
  String get errorApprovingDelivery => get('error_approving_delivery');
  String get errorRejectingDelivery => get('error_rejecting_delivery');
  String get deliveryRejected => get('delivery_rejected');
  String get deliveryRejectedSuccessfully =>
      get('delivery_rejected_successfully');
  String deliveryRejectedReason(String reason) =>
      get('delivery_rejected_reason').replaceAll('{reason}', reason);
  String get deliveryCompletedSuccessfully =>
      get('delivery_completed_successfully');
  String get areYouSureMarkDelivered => get('are_you_sure_mark_delivered');
  String get accepted => get('accepted');
  String get commentTooShort => get('comment_too_short');
  String get optional => get('optional');
  String get reviewUpdatedSuccessfully => get('review_updated_successfully');
  String get reviewSubmittedSuccessfully =>
      get('review_submitted_successfully');
  String get beFirstToShare => get('be_first_to_share');
  String get writeFirstReview => get('write_first_review');
  String get writeReviewLink => get('write_review_link');
  String reviewsCountWithNumber(int count) =>
      get('reviews_count').replaceAll('{count}', count.toString());
  String repliesCountWithNumber(int count) =>
      get('replies_count').replaceAll('{count}', count.toString());
  String get reply => get('reply');
  String get addReply => get('add_reply');
  String get replyToReview => get('reply_to_review');
  String get replyConversationHint => get('reply_conversation_hint');
  String get writeYourReply => get('write_your_reply');
  String get yourReply => get('your_reply');
  String get pleaseEnterReply => get('please_enter_reply');
  String get replyAddedSuccessfully => get('reply_added_successfully');
  String get reviewLiked => get('review_liked');
  String get reviewUnliked => get('review_unliked');
  String get replyLiked => get('reply_liked');
  String get replyUnliked => get('reply_unliked');
  String get deleteReview => get('delete_review');
  String get confirmDeleteReview => get('confirm_delete_review');
  String get reviewDeletedSuccessfully => get('review_deleted_successfully');
  String daysAgoWithNumber(int days) =>
      get('days_ago').replaceAll('{days}', days.toString());
  String weeksAgoWithNumber(int weeks) =>
      get('weeks_ago').replaceAll('{weeks}', weeks.toString());
  String monthsAgoWithNumber(int months) =>
      get('months_ago').replaceAll('{months}', months.toString());
  String yearsAgoWithNumber(int years) =>
      get('years_ago').replaceAll('{years}', years.toString());
  String get contactInformation => get('contact_information');
  String get dateOfBirthLabel => get('date_of_birth_label');
  String get pleaseEnterDateFormat => get('please_enter_date_format');
  String get newEmailLabel => get('new_email_label');
  String get confirmNewEmailLabel => get('confirm_new_email_label');
  String get pleaseEnterNewEmail => get('please_enter_new_email');
  String get pleaseEnterCurrentPasswordProfile =>
      get('please_enter_current_password');
  String get dateOfBirthUpdatedSuccessfully =>
      get('date_of_birth_updated_successfully');
  String get emailAddressUpdatedSuccessfully =>
      get('email_address_updated_successfully');

  /// Get localized status label for borrow request status
  String getBorrowStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return statusPending;
      case 'approved':
        return statusApproved;
      case 'delivered':
        return statusDelivered;
      case 'returned':
        return statusReturned;
      case 'rejected':
        return statusRejected;
      case 'overdue':
        return statusOverdue;
      case 'active':
        return statusActive;
      case 'borrowed':
        return statusBorrowed;
      case 'out_for_delivery':
        return statusOutForDelivery;
      case 'completed':
        return statusCompleted;
      case 'assigned_to_delivery':
        return statusAssignedToDelivery;
      case 'confirmed':
        return statusConfirmed;
      case 'in_delivery':
        return statusInDelivery;
      case 'shipped':
        return statusShipped;
      case 'cancelled':
        return statusCancelled;
      default:
        // Fallback: capitalize first letter of each word
        return status
            .split('_')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
    }
  }

  /// Get localized status label for purchase order status
  String getOrderStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return statusPendingReview;
      case 'rejected_by_admin':
        return statusRejectedByAdmin;
      case 'waiting_for_delivery_manager':
        return statusWaitingForDeliveryManager;
      case 'rejected_by_delivery_manager':
        return statusRejectedByDeliveryManager;
      case 'in_delivery':
        return statusInDelivery;
      case 'assigned_to_delivery':
        return statusAssignedToDelivery;
      case 'delivery_in_progress':
        return statusDeliveryInProgress;
      case 'in_progress':
        return statusInProgress;
      case 'processing':
        return statusProcessing;
      case 'shipped':
        return statusShipped;
      case 'delivered':
        return statusDelivered;
      case 'completed':
        return statusCompleted;
      case 'confirmed':
        return statusConfirmed;
      case 'cancelled':
        return statusCancelled;
      case 'returned':
        return statusReturned;
      default:
        // Fallback: capitalize first letter of each word
        return status
            .split('_')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
    }
  }

  /// Get localized status label for return request status
  String getReturnRequestStatusLabel(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return statusPending;
      case 'APPROVED':
        return statusApproved;
      case 'ASSIGNED':
        return statusAssigned;
      case 'ACCEPTED':
        return statusAccepted;
      case 'IN_PROGRESS':
        return statusInProgress;
      case 'COMPLETED':
        return statusCompleted;
      // Legacy status values
      case 'RETURN_REQUESTED':
        return statusReturnRequested;
      case 'RETURN_APPROVED':
        return statusReturnApproved;
      case 'RETURN_ASSIGNED':
        return statusReturnAssigned;
      case 'PENDING_PICKUP':
        return statusPendingPickup;
      case 'IN_RETURN':
        return statusInReturn;
      case 'RETURNING_TO_LIBRARY':
        return statusReturningToLibrary;
      case 'RETURNED_SUCCESSFULLY':
        return statusReturnedSuccessfully;
      case 'LATE_RETURN':
        return statusLateReturn;
      default:
        // Fallback: capitalize first letter of each word
        return status
            .split('_')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');
    }
  }

  // Reports & Analytics getters
  String get reportsAndAnalytics => get('reports_and_analytics');
  String get reportType => get('report_type');
  String get dateRange => get('date_range');
  String get dashboardOverview => get('dashboard_overview');
  String get borrowingReport => get('borrowing_report');
  String get deliveryReport => get('delivery_report');
  String get finesReport => get('fines_report');
  String get bookPopularityReport => get('book_popularity_report');
  String get bookPopularity => get('book_popularity');
  String get authorPopularity => get('author_popularity');
  String dataFor(String start, String end) =>
      get('data_for').replaceAll('{start}', start).replaceAll('{end}', end);
  String get noDashboardData => get('no_dashboard_data');
  String get noDashboardDataAvailable => get('no_dashboard_data_available');
  String get reportDataWillBeDisplayedHere =>
      get('report_data_will_be_displayed_here');
  String get totalUsers => get('total_users');
  String get totalRevenue => get('total_revenue');
  String get totalOrders => get('total_orders');
  String get totalCategories => get('total_categories');
  String get totalAuthors => get('total_authors');
  String get bookRatings => get('book_ratings');
  String get allBorrowRequests => get('all_borrow_requests');
  String get requestsApproved => get('requests_approved');
  String get awaitingApproval => get('awaiting_approval');
  String get pastDueDate => get('past_due_date');
  String get trendThisPeriod => get('trend_this_period');
  String get successfullyReturned => get('successfully_returned');
  String get topBorrowedBooks => get('top_borrowed_books');
  String get rate => get('rate');
  String get customView => get('custom_view');
  String get custom => get('custom');
  String get allDeliveryTasks => get('all_delivery_tasks');
  String get successfullyCompleted => get('successfully_completed');
  String get currentlyBeingDelivered => get('currently_being_delivered');
  String get notCompleted => get('not_completed');
  String get topPerformingAgents => get('top_performing_agents');
  String get top10Agents => get('top_10_agents');
  String get top10PerformingDeliveryAgents =>
      get('top_10_performing_delivery_agents');
  String get completionRate => get('completion_rate');
  String get totalDeliveries => get('total_deliveries');
  String get completedDeliveries => get('completed_deliveries');
  String get pendingDeliveries => get('pending_deliveries');
  String get deliveriesInProgress => get('deliveries_in_progress');
  String get failedDeliveries => get('failed_deliveries');
  String get agentPerformance => get('agent_performance');
  String get awaitingPickup => get('awaiting_pickup');
  String get unknownTitle => get('unknown_title');
  String get unknownAgent => get('unknown_agent');
  String get authorStatistics => get('author_statistics');
  String get totalAuthorsLabel => get('total_authors_label');
  String get allBooksInSystem => get('all_books_in_system');
  String get currentlyAvailable => get('currently_available');
  String get currentlyBorrowed => get('currently_borrowed');
  String get mostBorrowed => get('most_borrowed');
  String get bestSellers => get('best_sellers');
  String get mostRequestedBooks => get('most_requested_books');
  String get bookTrends => get('book_trends');
  String get borrowingGrowth => get('borrowing_growth');
  String get mostBorrowedBooks => get('most_borrowed_books');
  String get lateBookStatistics => get('late_book_statistics');
  String get overdueBooks => get('overdue_books');
  String get avgDays => get('avg_days');
  String get fineCollectionData => get('fine_collection_data');
  String get totalFinesIssued => get('total_fines_issued');
  String get fines => get('fines');
  String get finePaymentStatus => get('fine_payment_status');
  String get paymentRate => get('payment_rate');
  String get paid => get('paid');
  String get historicalFineTrends => get('historical_fine_trends');
  String get trendThisMonth => get('trend_this_month');
  String get detailedStatistics => get('detailed_statistics');
  String get overdueWithFines => get('overdue_with_fines');
  String get unpaidFines => get('unpaid_fines');
  String get paidFines => get('paid_fines');
  String get unpaidAmount => get('unpaid_amount');
  String get recentFines => get('recent_fines');
  String get complaintAboutTheApp => get('complaint_about_the_app');
  String get approvedRequests => get('approved_requests');
  String get lateRequests => get('late_requests');
  String get returnedRequests => get('returned_requests');
  String get periodAnalysis => get('period_analysis');
  String get top10Books => get('top_10_books');
  String get monthly => get('monthly');
  String get searchAllRequests => get('search_all_requests');
  String get noMatchingRequestsFound => get('no_matching_requests_found');
  String get noOrdersCurrentlyAvailable => get('no_orders_currently_available');
  String get purchase => get('purchase');
  String get returnCollection => get('return_collection');
  String get recentNotifications => get('recent_notifications');
  String get urgentNotifications => get('urgent_notifications');
  String get newDeliveryAssignment => get('new_delivery_assignment');
  String get noDeliveryNotifications => get('no_delivery_notifications');
  String get youAreAllCaughtUp => get('you_are_all_caught_up');
  String get urgentNotification => get('urgent_notification');
  String get notification => get('notification');
  String get noMessage => get('no_message');
  String dAgo(int days) => get('d_ago').replaceAll('{days}', days.toString());
  String hAgo(int hours) =>
      get('h_ago').replaceAll('{hours}', hours.toString());
  String mAgo(int minutes) =>
      get('m_ago').replaceAll('{minutes}', minutes.toString());
  String unreadNotificationsCount(int count) => count == 1
      ? get(
          'unread_notifications_count',
        ).replaceAll('{count}', count.toString())
      : get(
          'unread_notifications_count_plural',
        ).replaceAll('{count}', count.toString());
  String get newTaskAssignments => get('new_task_assignments');
  String get getNotifiedWhenNewTasksAssigned =>
      get('get_notified_when_new_tasks_assigned');
  String get taskUpdates => get('task_updates');
  String get getNotifiedAboutTaskStatusChanges =>
      get('get_notified_about_task_status_changes');
  String get appSettings => get('app_settings');
  String get manageLocation => get('manage_location');
  String get setYourDeliveryLocation => get('set_your_delivery_location');
  String logoutFailed(String error) =>
      get('logout_failed').replaceAll('{error}', error);
  String get enterYourNewEmailAddress => get('enter_your_new_email_address');
  String get confirmYourNewEmailAddress =>
      get('confirm_your_new_email_address');
  String get enterYourCurrentPassword => get('enter_your_current_password');
  String get pleaseConfirmYourNewEmail => get('please_confirm_your_new_email');
  String get pleaseEnterAValidPhoneNumber =>
      get('please_enter_a_valid_phone_number');
  String get notificationNewDeliveryAssignment =>
      get('notification_new_delivery_assignment');
  String youHaveBeenAssignedOrderForDelivery(String orderNumber) => get(
    'you_have_been_assigned_order_for_delivery',
  ).replaceAll('{orderNumber}', orderNumber);
  String youHaveBeenAssignedToDeliver(
    String bookTitle,
    String customerName,
    String deliveryAddress,
  ) => get('you_have_been_assigned_to_deliver')
      .replaceAll('{bookTitle}', bookTitle)
      .replaceAll('{customerName}', customerName)
      .replaceAll('{deliveryAddress}', deliveryAddress);
  String get fineInformation => get('fine_information');
  String get confirmCashPayment => get('confirm_cash_payment');
  String confirmCashPaymentMessage(String amount) =>
      get('confirm_cash_payment_message').replaceAll('\${amount}', '\$$amount');
  String get cashPaymentConfirmedSuccessfully =>
      get('cash_payment_confirmed_successfully');
  String get failedToConfirmCashPayment =>
      get('failed_to_confirm_cash_payment');
  String get fineConfirmed => get('fine_confirmed');
  String get increaseFine => get('increase_fine');
  String get confirmFine => get('confirm_fine');
  String get pendingPayment => get('pending_payment');
  String get fineStatusPaid => get('fine_status_paid');
  String get fineStatusUnpaid => get('fine_status_unpaid');
  String get fineStatusPendingCashPayment =>
      get('fine_status_pending_cash_payment');
  String get fineStatusFailed => get('fine_status_failed');
  String get paymentMethodCashDisplay => get('payment_method_cash_display');
  String get paymentMethodMastercardDisplay =>
      get('payment_method_mastercard_display');
  String get returnRequestApprovedAndAssigned =>
      get('return_request_approved_and_assigned');
  String get exceptionFailedToStartReturnProcess =>
      get('exception_failed_to_start_return_process');
  String get sessionExpiredPleaseLoginAgain =>
      get('session_expired_please_login_again');
  String errorLoadingReturnRequest(String error) =>
      get('error_loading_return_request').replaceAll('{error}', error);
  String get couldNotGetCurrentLocation =>
      get('could_not_get_current_location');
  String get failedToUpdateLocation => get('failed_to_update_location');
  String errorUpdatingLocation(String error) =>
      get('error_updating_location').replaceAll('{error}', error);
  String get fineApplied => get('fine_applied');
  String get youCannotBorrowUntilFinePaid =>
      get('you_cannot_borrow_until_fine_paid');
  String get youCannotSubmitBorrowRequestUntilFinePaid =>
      get('you_cannot_submit_borrow_request_until_fine_paid');
  String get youCanSubmitNewBorrowRequests =>
      get('you_can_submit_new_borrow_requests');
  String get unableToCheckFineStatus => get('unable_to_check_fine_status');
  String get notificationNewFineAdded => get('notification_new_fine_added');
  String get notificationNewFineAddedMessage =>
      get('notification_new_fine_added_message');
  String get notificationOrderApproved => get('notification_order_approved');
  String notificationOrderApprovedMessage(String orderNumber) => get(
    'notification_order_approved_message',
  ).replaceAll('{orderNumber}', orderNumber);
  String get locationServicesDisabled => get('location_services_disabled');
  String get locationPermissionsDenied => get('location_permissions_denied');
  String get locationPermissionsPermanentlyDenied =>
      get('location_permissions_permanently_denied');
  String get authenticationRequiredPleaseLoginAgain =>
      get('authentication_required_please_login_again');
  String get endpointNotFound => get('endpoint_not_found');
  String failedToUpdateLocationWithStatus(String statusCode) => get(
    'failed_to_update_location_with_status',
  ).replaceAll('{statusCode}', statusCode);
  String get youDoNotHavePermissionDeliveryManagersOnly =>
      get('you_do_not_have_permission_delivery_managers_only');
  String get youMustBeOnlineToStartDelivery =>
      get('you_must_be_online_to_start_delivery');
  String get youDoNotHavePermissionStartDeliveries =>
      get('you_do_not_have_permission_start_deliveries');
  String get youDoNotHavePermissionStartReturns =>
      get('you_do_not_have_permission_start_returns');
  String get youDoNotHavePermissionCompleteReturns =>
      get('you_do_not_have_permission_complete_returns');
  String get pleaseLogInToUpdateLocation =>
      get('please_log_in_to_update_location');
  String get locationPermissionRequiredToUpdate =>
      get('location_permission_required_to_update');
  String errorCompletingDeliveryWithError(String error) =>
      get('error_completing_delivery_with_error').replaceAll('{error}', error);
  String get currentLocationStatus => get('current_location_status');
  String get noLocationSet => get('no_location_set');
  String get coordinatesLabel => get('coordinates_label');
  String get never => get('never');
  String get updateLocation => get('update_location');
  String get addressOptional => get('address_optional');
  String get enterAddressOrLocationDescription =>
      get('enter_address_or_location_description');
  String get gettingLocation => get('getting_location');
  String get useGpsLocation => get('use_gps_location');
  String get saveAddress => get('save_address');
  String get instructions => get('instructions');
  String get instructionUseGpsLocation => get('instruction_use_gps_location');
  String get instructionEnterAddressManually =>
      get('instruction_enter_address_manually');
  String get instructionLocationHelpsCustomers =>
      get('instruction_location_helps_customers');
  String get instructionAdminsMonitorLocations =>
      get('instruction_admins_monitor_locations');
  String get instructionLocationDataOptimization =>
      get('instruction_location_data_optimization');
  String get pleaseLogInToManageLocation =>
      get('please_log_in_to_manage_location');
  String get failedToLoadLocation => get('failed_to_load_location');
  String errorLoadingLocation(String error) =>
      get('error_loading_location').replaceAll('{error}', error);
  String get failedToGetGpsLocation => get('failed_to_get_gps_location');
  String errorGettingGpsLocation(String error) =>
      get('error_getting_gps_location').replaceAll('{error}', error);
  String errorUpdatingLocationWithError(String error) =>
      get('error_updating_location_with_error').replaceAll('{error}', error);
  String get pleaseEnterAnAddress => get('please_enter_an_address');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => true;
}
