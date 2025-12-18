import 'package:flutter/foundation.dart';
import '../../../core/localization/app_localizations.dart';

/// Helper class to translate notification titles and messages
/// Since the backend sends English text, we translate common patterns
class NotificationTranslator {
  /// Translate notification title based on common patterns
  static String translateTitle(String title, AppLocalizations localizations) {
    final titleLower = title.toLowerCase();

    // Book delivery notifications
    if (titleLower.contains('book delivered successfully') ||
        titleLower.contains('delivered successfully')) {
      return localizations.notificationBookDeliveredSuccessfully;
    }

    if (titleLower.contains('delivery started') ||
        titleLower.contains('delivery has started')) {
      return localizations.notificationDeliveryStarted;
    }

    // Borrowing notifications
    if (titleLower.contains('borrowing request approved') ||
        titleLower.contains('borrow request approved')) {
      return localizations.notificationBorrowRequestApproved;
    }

    if (titleLower.contains('borrowing request rejected') ||
        titleLower.contains('borrow request rejected')) {
      return localizations.notificationBorrowRequestRejected;
    }

    // Complaint notifications
    if (titleLower.contains('new complaint received') ||
        titleLower.contains('complaint received')) {
      return localizations.notificationNewComplaintReceived;
    }

    if (titleLower.contains('complaint has been resolved') ||
        titleLower.contains('complaint resolved')) {
      return localizations.notificationComplaintResolved;
    }

    if (titleLower.contains('complaint has been answered') ||
        titleLower.contains('complaint answered')) {
      return localizations.notificationComplaintAnswered;
    }

    // Fine notifications
    if (titleLower.contains('new fine') && titleLower.contains('added')) {
      return localizations.notificationNewFineAdded;
    }

    // Order notifications
    if (titleLower.contains('order approved') ||
        titleLower.contains('order has been approved')) {
      return localizations.notificationOrderApproved;
    }

    if (titleLower.contains('new order') &&
        titleLower.contains('pending approval')) {
      return localizations.notificationNewOrderPendingApproval;
    }

    if (titleLower.contains('new purchase request') ||
        titleLower.contains('new purchase')) {
      return localizations.notificationNewPurchaseRequest;
    }

    if (titleLower.contains('order placed') ||
        titleLower.contains('order has been placed')) {
      return localizations.notificationOrderPlaced;
    }

    if (titleLower.contains('order shipped') ||
        titleLower.contains('order has been shipped')) {
      return localizations.notificationOrderShipped;
    }

    // Delivery Manager Status Update
    if (titleLower.contains('delivery manager') &&
        titleLower.contains('status update')) {
      return localizations.notificationDeliveryManagerStatusUpdate;
    }

    // Borrowing Request notifications
    if (titleLower.contains('new borrowing request') &&
        titleLower.contains('payment confirmed')) {
      return localizations.notificationNewBorrowingRequestPaymentConfirmed;
    }

    if (titleLower.contains('new borrowing request') ||
        (titleLower.contains('borrowing request') &&
            titleLower.contains('new'))) {
      return localizations.notificationNewBorrowingRequest;
    }

    // Return notifications
    if (titleLower.contains('return request') ||
        titleLower.contains('book return')) {
      return localizations.notificationReturnRequest;
    }

    if (titleLower.contains('return process started') ||
        titleLower.contains('return started')) {
      return localizations.notificationReturnProcessStarted;
    }

    if (titleLower.contains('return accepted') ||
        titleLower.contains('return request accepted')) {
      return localizations.notificationReturnAccepted;
    }

    // Order delivered
    if (titleLower.contains('order delivered') ||
        titleLower.contains('order has been delivered')) {
      return localizations.orderDelivered;
    }

    // Delivery confirmed
    if (titleLower.contains('delivery confirmed') ||
        titleLower.contains('delivery has been confirmed')) {
      return localizations.deliveryConfirmed;
    }

    // New Delivery Assignment
    if (titleLower.contains('new delivery assignment') ||
        titleLower.contains('new delivery assigned') ||
        titleLower.contains('delivery assignment')) {
      return localizations.notificationNewDeliveryAssignment;
    }

    // Default: return original title if no pattern matches
    return title;
  }

  /// Translate notification message based on common patterns
  /// This extracts dynamic content (book titles, dates) and translates the template
  static String translateMessage(
    String message,
    AppLocalizations localizations,
  ) {
    final messageLower = message.toLowerCase();

    // Extract book title (usually in quotes or after 'book' or 'for')
    String? bookTitle;
    // Try single quotes first
    final bookTitleMatch1 = RegExp(
      r"'([^']+)'",
      caseSensitive: false,
    ).firstMatch(message);
    // Try double quotes
    final bookTitleMatch2 = RegExp(
      r'"([^"]+)"',
      caseSensitive: false,
    ).firstMatch(message);
    // Try "for 'title'" pattern
    final bookTitleMatch3 = RegExp(
      r"for\s+'([^']+)'",
      caseSensitive: false,
    ).firstMatch(message);
    // Try "book 'title'" pattern
    final bookTitleMatch4 = RegExp(
      r"book\s+'([^']+)'",
      caseSensitive: false,
    ).firstMatch(message);

    if (bookTitleMatch1 != null) {
      bookTitle = bookTitleMatch1.group(1);
    } else if (bookTitleMatch2 != null) {
      bookTitle = bookTitleMatch2.group(1);
    } else if (bookTitleMatch3 != null) {
      bookTitle = bookTitleMatch3.group(1);
    } else if (bookTitleMatch4 != null) {
      bookTitle = bookTitleMatch4.group(1);
    }

    // Extract return date
    String? returnDate;
    final returnDateMatch = RegExp(
      r'return date:\s*(\d{4}-\d{2}-\d{2})',
      caseSensitive: false,
    ).firstMatch(message);
    if (returnDateMatch != null) {
      returnDate = returnDateMatch.group(1);
    }

    // Book delivered successfully
    if (messageLower.contains('has been delivered') &&
        messageLower.contains('loan period starts today')) {
      if (bookTitle != null && returnDate != null) {
        return localizations.notificationBookDeliveredMessage(
          bookTitle,
          returnDate,
        );
      } else if (bookTitle != null) {
        return localizations.notificationBookDeliveredMessageSimple(bookTitle);
      }
      return localizations.notificationBookDeliveredMessageGeneric;
    }

    // Delivery started
    if (messageLower.contains('is now being delivered') ||
        messageLower.contains('being delivered to')) {
      if (bookTitle != null) {
        return localizations.notificationDeliveryStartedMessage(bookTitle);
      }
      return localizations.notificationDeliveryStartedMessageGeneric;
    }

    // Borrow request approved
    if (messageLower.contains('request to borrow') &&
        messageLower.contains('has been approved')) {
      String? deliveryManager;
      final managerMatch = RegExp(
        r'assigned to delivery manager\s+([^.]+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (managerMatch != null) {
        deliveryManager = managerMatch.group(1)?.trim();
      }

      if (bookTitle != null && deliveryManager != null) {
        return localizations.notificationBorrowApprovedMessage(
          bookTitle,
          deliveryManager,
        );
      } else if (bookTitle != null) {
        return localizations.notificationBorrowApprovedMessageSimple(bookTitle);
      }
      return localizations.notificationBorrowApprovedMessageGeneric;
    }

    // New complaint received
    if (messageLower.contains('customer has submitted') &&
        messageLower.contains('new complaint')) {
      return localizations.notificationNewComplaintReceivedMessage;
    }

    if (messageLower.contains('submitted') &&
        messageLower.contains('new complaint')) {
      return localizations.notificationNewComplaintReceivedMessage;
    }

    // Complaint resolved
    if (messageLower.contains('complaint status has been updated') &&
        messageLower.contains('resolved')) {
      return localizations.notificationComplaintResolvedMessage;
    }

    // Complaint answered
    if (messageLower.contains('complaint has been answered')) {
      return localizations.notificationComplaintAnsweredMessage;
    }

    // Book successfully returned
    if (messageLower.contains('has been successfully returned') ||
        messageLower.contains('successfully returned to the library')) {
      if (bookTitle != null) {
        return localizations.notificationBookReturnedMessage(bookTitle);
      }
      return localizations.notificationBookReturnedMessageGeneric;
    }

    // Return process started
    if (messageLower.contains('started the return process') ||
        messageLower.contains('return process for')) {
      String? deliveryManager;
      final managerMatch = RegExp(
        r'delivery manager\s+([^.]+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (managerMatch != null) {
        deliveryManager = managerMatch.group(1)?.trim();
      }

      if (bookTitle != null && deliveryManager != null) {
        return localizations.notificationReturnProcessStartedMessage(
          bookTitle,
          deliveryManager,
        );
      } else if (bookTitle != null) {
        return localizations.notificationReturnProcessStartedMessageSimple(
          bookTitle,
        );
      }
      return localizations.notificationReturnProcessStartedMessageGeneric;
    }

    // Return request accepted
    if (messageLower.contains('accepted your return request') ||
        messageLower.contains('return request for')) {
      String? deliveryManager;
      final managerMatch = RegExp(
        r'delivery manager\s+([^.]+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (managerMatch != null) {
        deliveryManager = managerMatch.group(1)?.trim();
      }

      if (bookTitle != null && deliveryManager != null) {
        return localizations.notificationReturnAcceptedMessage(
          bookTitle,
          deliveryManager,
        );
      } else if (bookTitle != null) {
        return localizations.notificationReturnAcceptedMessageSimple(bookTitle);
      }
      return localizations.notificationReturnAcceptedMessageGeneric;
    }

    // New Order Pending Approval
    if (messageLower.contains('has placed a new order') ||
        messageLower.contains('placed a new order')) {
      String? customerName;
      final customerMatch = RegExp(
        r'customer\s+([^.]+?)\s+has',
        caseSensitive: false,
      ).firstMatch(message);
      if (customerMatch != null) {
        customerName = customerMatch.group(1)?.trim();
      }

      if (customerName != null) {
        return localizations.notificationNewOrderPendingApprovalMessage
            .replaceAll('{customerName}', customerName);
      }
      return localizations.notificationNewOrderPendingApprovalMessage
          .replaceAll('{customerName}', 'Customer');
    }

    // New Fine Added
    if (messageLower.contains('new fine has been added') &&
        (messageLower.contains('late book return') ||
            messageLower.contains('due to late'))) {
      return localizations.notificationNewFineAddedMessage;
    }

    // Order Approved
    if (messageLower.contains('order') &&
        messageLower.contains('has been approved') &&
        messageLower.contains('waiting for delivery manager')) {
      String? orderNumber;
      final orderMatch = RegExp(
        r'#ord-([a-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (orderMatch != null) {
        orderNumber = orderMatch.group(1)?.toUpperCase();
      }

      if (orderNumber != null) {
        return localizations.notificationOrderApprovedMessage(orderNumber);
      }
      return localizations.notificationOrderApprovedMessage('N/A');
    }

    // New Purchase Request
    if (messageLower.contains('new order') && messageLower.contains('ord-')) {
      String? orderNumber;
      final orderMatch = RegExp(
        r'#ord-([a-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (orderMatch != null) {
        orderNumber = orderMatch.group(1)?.toUpperCase();
      }

      if (orderNumber != null) {
        return localizations.notificationNewPurchaseRequestMessage.replaceAll(
          '{orderNumber}',
          orderNumber,
        );
      }
      return localizations.notificationNewPurchaseRequestMessage.replaceAll(
        '{orderNumber}',
        'N/A',
      );
    }

    // Order delivered successfully
    if ((messageLower.contains('order') && messageLower.contains('ord-')) &&
        (messageLower.contains('has been successfully delivered') ||
            messageLower.contains('has been delivered successfully') ||
            messageLower.contains('has been successfully d'))) {
      String? orderNumber;
      final orderMatch = RegExp(
        r'#ord-([a-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (orderMatch != null) {
        orderNumber = orderMatch.group(1)?.toUpperCase();
      }

      if (orderNumber != null) {
        return localizations.orderDeliveredMessage(orderNumber);
      }
      return localizations.orderDeliveredMessageGeneric;
    }

    // Order confirmed
    if ((messageLower.contains('order') && messageLower.contains('ord-')) &&
        (messageLower.contains('has been confirmed') ||
            messageLower.contains('has been confirmed by'))) {
      String? orderNumber;
      String? confirmedBy;
      final orderMatch = RegExp(
        r'#ord-([a-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (orderMatch != null) {
        orderNumber = orderMatch.group(1)?.toUpperCase();
      }

      final confirmedByMatch = RegExp(
        r'confirmed by\s+([^.]+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (confirmedByMatch != null) {
        confirmedBy = confirmedByMatch.group(1)?.trim();
        // Translate "delivery manager" if it appears
        if (confirmedBy?.toLowerCase() == 'delivery manager') {
          confirmedBy = localizations.deliveryManager;
        }
      }

      if (orderNumber != null && confirmedBy != null) {
        return localizations.orderConfirmedMessage(orderNumber, confirmedBy);
      } else if (orderNumber != null) {
        return localizations.orderConfirmedMessageSimple(orderNumber);
      }
      return localizations.orderConfirmedMessageGeneric;
    }

    // Delivery Manager Status Update
    if (messageLower.contains('del status') ||
        (messageLower.contains('status') &&
            messageLower.contains('changed from'))) {
      String? managerName;
      String? oldStatus;
      String? newStatus;

      final managerMatch = RegExp(
        r'([a-z0-9]+)\s+del\s+status',
        caseSensitive: false,
      ).firstMatch(message);
      if (managerMatch != null) {
        managerName = managerMatch.group(1)?.trim();
      }

      final statusMatch = RegExp(
        r'changed from\s+(\w+)\s+to\s+(\w+)',
        caseSensitive: false,
      ).firstMatch(message);
      if (statusMatch != null) {
        oldStatus = statusMatch.group(1)?.trim();
        newStatus = statusMatch.group(2)?.trim();
      }

      if (managerName != null && oldStatus != null && newStatus != null) {
        return localizations.notificationDeliveryManagerStatusUpdateMessage
            .replaceAll('{managerName}', managerName)
            .replaceAll('{oldStatus}', oldStatus)
            .replaceAll('{newStatus}', newStatus);
      } else if (managerName != null) {
        return localizations.notificationDeliveryManagerStatusUpdateMessage
            .replaceAll('{managerName}', managerName)
            .replaceAll('{oldStatus}', 'previous')
            .replaceAll('{newStatus}', 'current');
      }
      return localizations.notificationDeliveryManagerStatusUpdateMessage
          .replaceAll('{managerName}', 'Manager')
          .replaceAll('{oldStatus}', 'previous')
          .replaceAll('{newStatus}', 'current');
    }

    // New Borrowing Request
    if (messageLower.contains('new borrowing request') ||
        messageLower.contains('borrowing request from')) {
      String? customerName;
      String? bookTitle;

      final customerMatch = RegExp(
        r'from\s+([a-z\s]+?)\s+(?:for|has)',
        caseSensitive: false,
      ).firstMatch(message);
      if (customerMatch != null) {
        customerName = customerMatch.group(1)?.trim();
      }

      final bookMatch = RegExp(
        r"for\s+'([^']+)'",
        caseSensitive: false,
      ).firstMatch(message);
      if (bookMatch != null) {
        bookTitle = bookMatch.group(1);
      }

      if (customerName != null && bookTitle != null) {
        return localizations.notificationNewBorrowingRequestMessage
            .replaceAll('{customerName}', customerName)
            .replaceAll('{bookTitle}', bookTitle);
      } else if (customerName != null) {
        return localizations.notificationNewBorrowingRequestMessage
            .replaceAll('{customerName}', customerName)
            .replaceAll(" for '{bookTitle}'", '');
      }
      return localizations.notificationNewBorrowingRequestMessage
          .replaceAll('{customerName}', 'Customer')
          .replaceAll(" for '{bookTitle}'", '');
    }

    // New Borrowing Request - Payment Confirmed
    if (messageLower.contains('has confirmed payment') ||
        (messageLower.contains('confirmed payment') &&
            messageLower.contains('borrowing'))) {
      String? customerName;
      final customerMatch = RegExp(
        r'customer\s+([^.]+?)\s+has',
        caseSensitive: false,
      ).firstMatch(message);
      if (customerMatch != null) {
        customerName = customerMatch.group(1)?.trim();
      }

      if (customerName != null) {
        return localizations
            .notificationNewBorrowingRequestPaymentConfirmedMessage
            .replaceAll('{customerName}', customerName);
      }
      return localizations
          .notificationNewBorrowingRequestPaymentConfirmedMessage
          .replaceAll('{customerName}', 'Customer');
    }

    // New Delivery Assignment - Order assigned
    if (messageLower.contains('you have been assigned order') &&
        messageLower.contains('for delivery') &&
        (messageLower.contains('please review') ||
            messageLower.contains('review and confirm'))) {
      String? orderNumber;
      // Try to match "order #ORD-..." or just "#ORD-..."
      final orderMatch1 = RegExp(
        r'order\s+#ord-([a-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(message);
      final orderMatch2 = RegExp(
        r'#ord-([a-z0-9]+)',
        caseSensitive: false,
      ).firstMatch(message);

      if (orderMatch1 != null) {
        orderNumber = orderMatch1.group(1)?.toUpperCase();
      } else if (orderMatch2 != null) {
        orderNumber = orderMatch2.group(1)?.toUpperCase();
      }

      if (orderNumber != null) {
        return localizations.youHaveBeenAssignedOrderForDelivery(orderNumber);
      }
    }

    // New Delivery Assignment - Book delivery
    // Pattern: "You have been assigned to deliver [book] to [customer] at [address]"
    if (messageLower.contains('you have been assigned to deliver')) {
      String? bookTitle;
      String? customerName;
      String? deliveryAddress;

      // Extract book title (in quotes - handle both single and double quotes, with optional period)
      // Try double quotes first: "book"
      final bookTitleMatch1 = RegExp(
        r'"([^"]+)"',
        caseSensitive: false,
      ).firstMatch(message);
      // Try single quotes with optional period before: .'book' or 'book'
      final bookTitleMatch2 = RegExp(
        r"\.?'([^']+)'",
        caseSensitive: false,
      ).firstMatch(message);
      // Try single quotes without period: 'book'
      final bookTitleMatch3 = RegExp(
        r"'([^']+)'",
        caseSensitive: false,
      ).firstMatch(message);

      if (bookTitleMatch1 != null) {
        bookTitle = bookTitleMatch1.group(1);
      } else if (bookTitleMatch2 != null) {
        bookTitle = bookTitleMatch2.group(1);
      } else if (bookTitleMatch3 != null) {
        bookTitle = bookTitleMatch3.group(1);
      }

      // Use a comprehensive pattern to extract all parts at once
      // Pattern: "deliver [book] to [customer] at [address]"
      // Handle formats like: "deliver .'book' to customer at address"
      // or "deliver 'book' to customer at address" or "deliver "book" to customer at address"
      final fullPattern1 = RegExp(
        r"deliver\s+\.?'([^']+)'\s+to\s+([^\s]+(?:\s+[^\s]+)*?)\s+at\s+(.+)$",
        caseSensitive: false,
      ).firstMatch(message);

      final fullPattern2 = RegExp(
        r'deliver\s+"([^"]+)"\s+to\s+([^\s]+(?:\s+[^\s]+)*?)\s+at\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(message);

      final fullPattern3 = RegExp(
        r"deliver\s+'([^']+)'\s+to\s+([^\s]+(?:\s+[^\s]+)*?)\s+at\s+(.+)$",
        caseSensitive: false,
      ).firstMatch(message);

      RegExpMatch? matchedPattern;
      if (fullPattern1 != null) {
        matchedPattern = fullPattern1;
      } else if (fullPattern2 != null) {
        matchedPattern = fullPattern2;
      } else if (fullPattern3 != null) {
        matchedPattern = fullPattern3;
      }

      if (matchedPattern != null) {
        // Extract from the matched pattern
        final extractedBook = matchedPattern.group(1)?.trim();
        final extractedCustomer = matchedPattern.group(2)?.trim();
        final extractedAddress = matchedPattern.group(3)?.trim();

        if (extractedBook != null &&
            extractedCustomer != null &&
            extractedAddress != null) {
          debugPrint(
            'NotificationTranslator: Successfully extracted - book: $extractedBook, customer: $extractedCustomer, address: $extractedAddress',
          );
          return localizations.youHaveBeenAssignedToDeliver(
            extractedBook,
            extractedCustomer,
            extractedAddress,
          );
        }
      }

      // Fallback: Try to extract customer name and address separately
      // Extract customer name (between "to" and "at")
      // Pattern that captures everything between "to" and "at", handling multiple words
      final customerMatch = RegExp(
        r'to\s+([^\s]+(?:\s+[^\s]+)*?)\s+at',
        caseSensitive: false,
      ).firstMatch(message);

      if (customerMatch != null) {
        customerName = customerMatch.group(1)?.trim();
      }

      // Extract delivery address (after "at")
      final addressMatch = RegExp(
        r'at\s+(.+)$',
        caseSensitive: false,
      ).firstMatch(message);
      if (addressMatch != null) {
        deliveryAddress = addressMatch.group(1)?.trim();
      }

      // Debug: Print extracted values for troubleshooting
      debugPrint(
        'NotificationTranslator: Extracted values - bookTitle: $bookTitle, customerName: $customerName, deliveryAddress: $deliveryAddress',
      );
      debugPrint('NotificationTranslator: Original message: $message');

      // If we have all three parts, return translated message
      if (bookTitle != null &&
          customerName != null &&
          deliveryAddress != null) {
        return localizations.youHaveBeenAssignedToDeliver(
          bookTitle,
          customerName,
          deliveryAddress,
        );
      }

      // If extraction failed, try one more comprehensive pattern
      // This pattern matches the entire structure: "deliver [quote]book[quote] to [name] at [address]"
      final comprehensivePattern = RegExp(
        r"deliver\s+\.?'([^']+)'\s+to\s+([^\s]+(?:\s+[^\s]+)*?)\s+at\s+(.+)$",
        caseSensitive: false,
      ).firstMatch(message);

      if (comprehensivePattern != null) {
        final extractedBook2 = comprehensivePattern.group(1)?.trim();
        final extractedCustomer2 = comprehensivePattern.group(2)?.trim();
        final extractedAddress2 = comprehensivePattern.group(3)?.trim();

        if (extractedBook2 != null &&
            extractedCustomer2 != null &&
            extractedAddress2 != null) {
          return localizations.youHaveBeenAssignedToDeliver(
            extractedBook2,
            extractedCustomer2,
            extractedAddress2,
          );
        }
      }
    }

    // Default: return original message if no pattern matches
    return message;
  }
}
