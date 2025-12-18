class AppStrings {
  // App Information
  static const String appName = 'ReadGo';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Digital Library Management System';

  // Common Actions
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String add = 'Add';
  static const String remove = 'Remove';
  static const String update = 'Update';
  static const String create = 'Create';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String clear = 'Clear';
  static const String refresh = 'Refresh';
  static const String retry = 'Retry';
  static const String confirm = 'Confirm';
  static const String back = 'Back';
  static const String next = 'Next';
  static const String done = 'Done';
  static const String close = 'Close';
  static const String open = 'Open';
  static const String view = 'View';
  static const String hide = 'Hide';
  static const String show = 'Show';
  static const String select = 'Select';
  static const String deselect = 'Deselect';
  static const String all = 'All';
  static const String none = 'None';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String ok = 'OK';
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String warning = 'Warning';
  static const String info = 'Info';

  // User Roles
  static const String customer = 'Customer';
  static const String libraryManager = 'Library Manager';
  static const String deliveryManager = 'Delivery Manager';
  static const String admin = 'Admin';

  // Status
  static const String active = 'Active';
  static const String inactive = 'Inactive';
  static const String pending = 'Pending';
  static const String approved = 'Approved';
  static const String rejected = 'Rejected';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
  static const String expired = 'Expired';
  static const String available = 'Available';
  static const String unavailable = 'Unavailable';
  static const String online = 'Online';
  static const String offline = 'Offline';
  static const String busy = 'Busy';

  // Time
  static const String now = 'Now';
  static const String today = 'Today';
  static const String yesterday = 'Yesterday';
  static const String tomorrow = 'Tomorrow';
  static const String thisWeek = 'This Week';
  static const String thisMonth = 'This Month';
  static const String thisYear = 'This Year';
  static const String minutesAgo = 'minutes ago';
  static const String hoursAgo = 'hours ago';
  static const String daysAgo = 'days ago';
  static const String weeksAgo = 'weeks ago';
  static const String monthsAgo = 'months ago';
  static const String yearsAgo = 'years ago';

  // Validation Messages
  static const String requiredField = 'This field is required';
  static const String invalidEmail = 'Invalid email address';
  static const String invalidPhone = 'Invalid phone number';
  static const String passwordTooShort =
      'Password must be at least 6 characters';
  static const String passwordsDontMatch = 'Passwords don\'t match';
  static const String invalidOtp = 'Invalid OTP';
  static const String invalidUrl = 'Invalid URL';
  static const String invalidDate = 'Invalid date';
  static const String invalidNumber = 'Invalid number';
  static const String invalidAmount = 'Invalid amount';
  static const String invalidQuantity = 'Invalid quantity';
  static const String invalidRating = 'Invalid rating';
  static const String invalidLength = 'Invalid length';
  static const String invalidFormat = 'Invalid format';

  // Error Messages
  static const String networkError =
      'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String unknownError = 'An unknown error occurred';
  static const String connectionTimeout = 'Connection timeout';
  static const String noInternetConnection = 'No internet connection';
  static const String requestFailed = 'Request failed';
  static const String dataNotFound = 'Data not found';
  static const String accessDenied = 'Access denied';
  static const String sessionExpired = 'Session expired';
  static const String invalidCredentials = 'Invalid credentials';
  static const String accountNotFound = 'Account not found';
  static const String accountSuspended = 'Account suspended';
  static const String accountDeleted = 'Account deleted';

  // Success Messages
  static const String savedSuccessfully = 'Saved successfully';
  static const String updatedSuccessfully = 'Updated successfully';
  static const String deletedSuccessfully = 'Deleted successfully';
  static const String createdSuccessfully = 'Created successfully';
  static const String sentSuccessfully = 'Sent successfully';
  static const String uploadedSuccessfully = 'Uploaded successfully';
  static const String downloadedSuccessfully = 'Downloaded successfully';
  static const String copiedSuccessfully = 'Copied successfully';
  static const String sharedSuccessfully = 'Shared successfully';
  static const String loggedInSuccessfully = 'Logged in successfully';
  static const String loggedOutSuccessfully = 'Logged out successfully';
  static const String registeredSuccessfully = 'Registered successfully';
  static const String passwordChangedSuccessfully =
      'Password changed successfully';
  static const String profileUpdatedSuccessfully =
      'Profile updated successfully';

  // Confirmation Messages
  static const String confirmDelete =
      'Are you sure you want to delete this item?';
  static const String confirmLogout = 'Are you sure you want to logout?';
  static const String confirmCancel = 'Are you sure you want to cancel?';
  static const String confirmSave = 'Are you sure you want to save changes?';
  static const String confirmDiscard =
      'Are you sure you want to discard changes?';
  static const String confirmReset = 'Are you sure you want to reset?';
  static const String confirmClear = 'Are you sure you want to clear?';
  static const String confirmRemove = 'Are you sure you want to remove?';
  static const String confirmUpdate = 'Are you sure you want to update?';
  static const String confirmCreate = 'Are you sure you want to create?';

  // Placeholder Text
  static const String searchHint = 'Search...';
  static const String emailHint = 'Enter your email';
  static const String passwordHint = 'Enter your password';
  static const String nameHint = 'Enter your name';
  static const String phoneHint = 'Enter your phone number';
  static const String addressHint = 'Enter your address';
  static const String descriptionHint = 'Enter description';
  static const String notesHint = 'Enter notes';
  static const String commentHint = 'Enter comment';
  static const String reviewHint = 'Enter review';
  static const String ratingHint = 'Enter rating';
  static const String quantityHint = 'Enter quantity';
  static const String priceHint = 'Enter price';
  static const String amountHint = 'Enter amount';
  static const String dateHint = 'Select date';
  static const String timeHint = 'Select time';
  static const String categoryHint = 'Select category';
  static const String statusHint = 'Select status';
  static const String typeHint = 'Select type';
  static const String priorityHint = 'Select priority';

  // Empty State Messages
  static const String noDataFound = 'No data found';
  static const String noItemsFound = 'No items found';
  static const String noResultsFound = 'No results found';
  static const String noBooksFound = 'No books found';
  static const String noOrdersFound = 'No orders found';
  static const String noNotificationsFound = 'No notifications found';
  static const String noMessagesFound = 'No messages found';
  static const String noReviewsFound = 'No reviews found';
  static const String noCategoriesFound = 'No categories found';
  static const String noAuthorsFound = 'No authors found';
  static const String noLibrariesFound = 'No libraries found';
  static const String noDeliveriesFound = 'No deliveries found';
  static const String noBorrowingsFound = 'No borrowings found';
  static const String noComplaintsFound = 'No complaints found';
  static const String noReportsFound = 'No reports found';
  static const String noAdsFound = 'No advertisements found';
  static const String noDiscountsFound = 'No discounts found';

  // Feature Names
  static const String books = 'Books';
  static const String orders = 'Orders';
  static const String deliveries = 'Deliveries';
  static const String borrowings = 'Borrowings';
  static const String reviews = 'Reviews';
  static const String notifications = 'Notifications';
  static const String settings = 'Settings';
  static const String profile = 'Profile';
  static const String dashboard = 'Dashboard';
  static const String library = 'Library';
  static const String categories = 'Categories';
  static const String authors = 'Authors';
  static const String complaints = 'Complaints';
  static const String reports = 'Reports';
  static const String advertisements = 'Advertisements';
  static const String discounts = 'Discounts';
  static const String messages = 'Messages';
  static const String tasks = 'Tasks';
  static const String availability = 'Availability';

  // Navigation
  static const String home = 'Home';
  static const String menu = 'Menu';
  static const String more = 'More';
  static const String about = 'About';
  static const String help = 'Help';
  static const String support = 'Support';
  static const String contact = 'Contact';
  static const String privacy = 'Privacy';
  static const String terms = 'Terms';
  static const String faq = 'FAQ';
  static const String feedback = 'Feedback';
  static const String rate = 'Rate';
  static const String share = 'Share';
  static const String copy = 'Copy';
  static const String paste = 'Paste';
  static const String cut = 'Cut';
  static const String undo = 'Undo';
  static const String redo = 'Redo';
  static const String selectAll = 'Select All';
  static const String deselectAll = 'Deselect All';
}
