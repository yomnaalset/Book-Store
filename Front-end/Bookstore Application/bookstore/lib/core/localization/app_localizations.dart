import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('ar', 'SA'),
  ];

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // General
      'app_name': 'E-Library',
      'welcome': 'Welcome',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'cancel': 'Cancel',
      'save': 'Save',
      'delete': 'Delete',
      'edit': 'Edit',
      'add': 'Add',
      'remove': 'Remove',
      'update': 'Update',
      'create': 'Create',
      'search': 'Search',
      'filter': 'Filter',
      'clear': 'Clear',
      'refresh': 'Refresh',
      'retry': 'Retry',
      'confirm': 'Confirm',
      'back': 'Back',
      'next': 'Next',
      'done': 'Done',
      'close': 'Close',
      'open': 'Open',
      'view': 'View',
      'hide': 'Hide',
      'show': 'Show',
      'select': 'Select',
      'deselect': 'Deselect',
      'all': 'All',
      'none': 'None',
      'yes': 'Yes',
      'no': 'No',
      'ok': 'OK',

      // User Roles
      'customer': 'Customer',
      'library_manager': 'Library Manager',
      'delivery_manager': 'Delivery Manager',
      'purchase_orders': 'Purchase Requests',
      'borrow_requests': 'Borrow Requests',
      'return_requests': 'Return Requests',
      'no_purchase_orders': 'No Purchase Orders',
      'no_purchase_orders_description':
          'No purchase orders are currently available for delivery.',
      'no_borrow_requests': 'No Borrow Requests',
      'no_borrow_requests_description':
          'No borrowing requests are currently available for delivery.',
      'no_return_requests': 'No Return Requests',
      'no_return_requests_description':
          'No return requests are currently available for collection.',
      'admin': 'Admin',

      // Status
      'active': 'Active',
      'inactive': 'Inactive',
      'pending': 'Pending',
      'approved': 'Approved',
      'rejected': 'Rejected',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'expired': 'Expired',
      'available': 'Available',
      'unavailable': 'Unavailable',
      'online': 'Online',
      'offline': 'Offline',
      'busy': 'Busy',

      // Time
      'now': 'Now',
      'today': 'Today',
      'yesterday': 'Yesterday',
      'tomorrow': 'Tomorrow',
      'this_week': 'This Week',
      'this_month': 'This Month',
      'this_year': 'This Year',
      'minutes_ago': 'minutes ago',
      'hours_ago': 'hours ago',
      'days_ago': 'days ago',
      'weeks_ago': 'weeks ago',
      'months_ago': 'months ago',
      'years_ago': 'years ago',

      // Validation Messages
      'required_field': 'This field is required',
      'invalid_email': 'Invalid email address',
      'invalid_phone': 'Invalid phone number',
      'password_too_short': 'Password must be at least 6 characters',
      'passwords_dont_match': 'Passwords don\'t match',
      'invalid_otp': 'Invalid OTP',
      'network_error': 'Network error. Please check your connection.',
      'server_error': 'Server error. Please try again later.',
      'unknown_error': 'An unknown error occurred',

      // Success Messages
      'saved_successfully': 'Saved successfully',
      'updated_successfully': 'Updated successfully',
      'deleted_successfully': 'Deleted successfully',
      'created_successfully': 'Created successfully',
      'logged_in_successfully': 'Logged in successfully',
      'logged_out_successfully': 'Logged out successfully',
      'registered_successfully': 'Registered successfully',

      // Feature Names
      'books': 'Books',
      'orders': 'Orders',
      'deliveries': 'Deliveries',
      'borrowings': 'Borrowings',
      'reviews': 'Reviews',
      'notifications': 'Notifications',
      'settings': 'Settings',
      'profile': 'Profile',
      'dashboard': 'Dashboard',
      'library': 'Library',
      'categories': 'Categories',
      'authors': 'Authors',
      'complaints': 'Complaints',
      'reports': 'Reports',
      'advertisements': 'Advertisements',
      'discounts': 'Discounts',
      'messages': 'Messages',
      'tasks': 'Tasks',
      'all_requests': 'All Requests',
      'availability': 'Availability',

      // Navigation
      'home': 'Home',
      'menu': 'Menu',
      'more': 'More',
      'about': 'About',
      'help': 'Help',
      'support': 'Support',
      'contact': 'Contact',

      // Empty State Messages
      'no_data_found': 'No data found',
      'no_items_found': 'No items found',
      'no_results_found': 'No results found',
      'no_books_found': 'No books found',
      'no_orders_found': 'No orders found',
      'no_notifications_found': 'No notifications found',

      // Placeholder Text
      'search_hint': 'Search...',
      'email_hint': 'Enter your email',
      'password_hint': 'Enter your password',
      'name_hint': 'Enter your name',
      'phone_hint': 'Enter your phone number',
      'address_hint': 'Enter your address',
    },
    'ar': {
      // General
      'app_name': 'المكتبة الإلكترونية',
      'welcome': 'مرحباً',
      'loading': 'جاري التحميل...',
      'error': 'خطأ',
      'success': 'نجح',
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'delete': 'حذف',
      'edit': 'تعديل',
      'add': 'إضافة',
      'remove': 'إزالة',
      'update': 'تحديث',
      'create': 'إنشاء',
      'search': 'بحث',
      'filter': 'تصفية',
      'clear': 'مسح',
      'refresh': 'تحديث',
      'retry': 'إعادة المحاولة',
      'confirm': 'تأكيد',
      'back': 'رجوع',
      'next': 'التالي',
      'done': 'تم',
      'close': 'إغلاق',
      'open': 'فتح',
      'view': 'عرض',
      'hide': 'إخفاء',
      'show': 'إظهار',
      'select': 'اختيار',
      'deselect': 'إلغاء الاختيار',
      'all': 'الكل',
      'none': 'لا شيء',
      'yes': 'نعم',
      'no': 'لا',
      'ok': 'موافق',

      // User Roles
      'customer': 'عميل',
      'library_manager': 'مدير المكتبة',
      'delivery_manager': 'مدير التوصيل',
      'purchase_orders': 'طلبات الشراء',
      'admin': 'مدير',

      // Status
      'active': 'نشط',
      'inactive': 'غير نشط',
      'pending': 'في الانتظار',
      'approved': 'موافق عليه',
      'rejected': 'مرفوض',
      'completed': 'مكتمل',
      'cancelled': 'ملغي',
      'expired': 'منتهي الصلاحية',
      'available': 'متاح',
      'unavailable': 'غير متاح',
      'online': 'متصل',
      'offline': 'غير متصل',
      'busy': 'مشغول',

      // Time
      'now': 'الآن',
      'today': 'اليوم',
      'yesterday': 'أمس',
      'tomorrow': 'غداً',
      'this_week': 'هذا الأسبوع',
      'this_month': 'هذا الشهر',
      'this_year': 'هذا العام',
      'minutes_ago': 'دقائق مضت',
      'hours_ago': 'ساعات مضت',
      'days_ago': 'أيام مضت',
      'weeks_ago': 'أسابيع مضت',
      'months_ago': 'أشهر مضت',
      'years_ago': 'سنوات مضت',

      // Validation Messages
      'required_field': 'هذا الحقل مطلوب',
      'invalid_email': 'عنوان بريد إلكتروني غير صحيح',
      'invalid_phone': 'رقم هاتف غير صحيح',
      'password_too_short': 'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
      'passwords_dont_match': 'كلمات المرور غير متطابقة',
      'invalid_otp': 'رمز غير صحيح',
      'network_error': 'خطأ في الشبكة. يرجى التحقق من الاتصال.',
      'server_error': 'خطأ في الخادم. يرجى المحاولة لاحقاً.',
      'unknown_error': 'حدث خطأ غير معروف',

      // Success Messages
      'saved_successfully': 'تم الحفظ بنجاح',
      'updated_successfully': 'تم التحديث بنجاح',
      'deleted_successfully': 'تم الحذف بنجاح',
      'created_successfully': 'تم الإنشاء بنجاح',
      'logged_in_successfully': 'تم تسجيل الدخول بنجاح',
      'logged_out_successfully': 'تم تسجيل الخروج بنجاح',
      'registered_successfully': 'تم التسجيل بنجاح',

      // Feature Names
      'books': 'الكتب',
      'orders': 'الطلبات',
      'deliveries': 'التوصيلات',
      'borrowings': 'الاستعارات',
      'reviews': 'التقييمات',
      'notifications': 'الإشعارات',
      'settings': 'الإعدادات',
      'profile': 'الملف الشخصي',
      'dashboard': 'لوحة التحكم',
      'library': 'المكتبة',
      'categories': 'الفئات',
      'authors': 'المؤلفون',
      'complaints': 'الشكاوى',
      'reports': 'التقارير',
      'advertisements': 'الإعلانات',
      'discounts': 'الخصومات',
      'messages': 'الرسائل',
      'tasks': 'المهام',
      'all_requests': 'جميع الطلبات',
      'availability': 'التوفر',

      // Navigation
      'home': 'الرئيسية',
      'menu': 'القائمة',
      'more': 'المزيد',
      'about': 'حول',
      'help': 'المساعدة',
      'support': 'الدعم',
      'contact': 'اتصل بنا',

      // Empty State Messages
      'no_data_found': 'لا توجد بيانات',
      'no_items_found': 'لا توجد عناصر',
      'no_results_found': 'لا توجد نتائج',
      'no_books_found': 'لا توجد كتب',
      'no_orders_found': 'لا توجد طلبات',
      'no_notifications_found': 'لا توجد إشعارات',

      // Placeholder Text
      'search_hint': 'بحث...',
      'email_hint': 'أدخل بريدك الإلكتروني',
      'password_hint': 'أدخل كلمة المرور',
      'name_hint': 'أدخل اسمك',
      'phone_hint': 'أدخل رقم هاتفك',
      'address_hint': 'أدخل عنوانك',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
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
  String get minutesAgo => get('minutes_ago');
  String get hoursAgo => get('hours_ago');
  String get daysAgo => get('days_ago');
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
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
