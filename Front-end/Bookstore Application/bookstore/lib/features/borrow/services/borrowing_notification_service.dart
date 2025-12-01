import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/services/api_service.dart';

class BorrowingNotificationService {
  static String get _baseUrl => ApiService.baseUrl;

  /// Send notification to admin about new borrowing request
  static Future<void> notifyAdminNewRequest({
    required String customerName,
    required String bookTitle,
    required String requestId,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'New Borrowing Request',
          'message':
              'New borrowing request from $customerName for "$bookTitle"',
          'notification_type': 'borrow_request',
          'user_type': 'library_admin',
          'data': {
            'request_id': requestId,
            'customer_name': customerName,
            'book_title': bookTitle,
          },
        }),
      );
    } catch (e) {
      debugPrint('Error sending admin notification: $e');
    }
  }

  /// Send notification to customer about request approval
  static Future<void> notifyCustomerApproval({
    required String customerId,
    required String bookTitle,
    required String deliveryManagerName,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Borrowing Request Approved',
          'message':
              'Your request to borrow "$bookTitle" has been approved and assigned to delivery manager $deliveryManagerName.',
          'notification_type': 'borrow_approved',
          'user_id': customerId,
          'data': {
            'book_title': bookTitle,
            'delivery_manager': deliveryManagerName,
          },
        }),
      );
    } catch (e) {
      debugPrint('Error sending customer approval notification: $e');
    }
  }

  /// Send notification to delivery manager about new assignment
  static Future<void> notifyDeliveryManagerAssignment({
    required String deliveryManagerId,
    required String customerName,
    required String bookTitle,
    required String deliveryAddress,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'New Delivery Assignment',
          'message':
              'You have been assigned to deliver "$bookTitle" to $customerName at $deliveryAddress.',
          'notification_type': 'delivery_assignment',
          'user_id': deliveryManagerId,
          'data': {
            'customer_name': customerName,
            'book_title': bookTitle,
            'delivery_address': deliveryAddress,
          },
        }),
      );
    } catch (e) {
      debugPrint('Error sending delivery manager notification: $e');
    }
  }

  /// Send notification to customer about delivery start
  static Future<void> notifyCustomerDeliveryStart({
    required String customerId,
    required String bookTitle,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Book Picked Up',
          'message':
              'Your book "$bookTitle" has been picked up from the library and is on its way to you.',
          'notification_type': 'delivery_started',
          'user_id': customerId,
          'data': {'book_title': bookTitle},
        }),
      );
    } catch (e) {
      debugPrint('Error sending delivery start notification: $e');
    }
  }

  /// Send notification to customer about delivery completion
  static Future<void> notifyCustomerDeliveryComplete({
    required String customerId,
    required String bookTitle,
    required String returnDate,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Book Delivered Successfully',
          'message':
              'Your book "$bookTitle" has been delivered. Return date: $returnDate',
          'notification_type': 'delivery_completed',
          'user_id': customerId,
          'data': {'book_title': bookTitle, 'return_date': returnDate},
        }),
      );
    } catch (e) {
      debugPrint('Error sending delivery complete notification: $e');
    }
  }

  /// Send notification to admin about delivery completion
  static Future<void> notifyAdminDeliveryComplete({
    required String customerName,
    required String bookTitle,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Book Delivered Successfully',
          'message':
              'Book "$bookTitle" has been successfully delivered to $customerName.',
          'notification_type': 'delivery_completed',
          'user_type': 'library_admin',
          'data': {'customer_name': customerName, 'book_title': bookTitle},
        }),
      );
    } catch (e) {
      debugPrint('Error sending admin delivery notification: $e');
    }
  }

  /// Send notification to customer about return reminder
  static Future<void> notifyCustomerReturnReminder({
    required String customerId,
    required String bookTitle,
    required String dueDate,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Return Reminder',
          'message':
              'Reminder: The due date for return of "$bookTitle" is $dueDate.',
          'notification_type': 'return_reminder',
          'user_id': customerId,
          'data': {'book_title': bookTitle, 'due_date': dueDate},
        }),
      );
    } catch (e) {
      debugPrint('Error sending return reminder notification: $e');
    }
  }

  /// Send notification to customer about overdue book
  static Future<void> notifyCustomerOverdue({
    required String customerId,
    required String bookTitle,
    required double fineAmount,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Book Overdue - Fine Applied',
          'message':
              'A penalty of \$${fineAmount.toStringAsFixed(2)} has been imposed due to late return of the book "$bookTitle".',
          'notification_type': 'overdue_fine',
          'user_id': customerId,
          'data': {'book_title': bookTitle, 'fine_amount': fineAmount},
        }),
      );
    } catch (e) {
      debugPrint('Error sending overdue notification: $e');
    }
  }

  /// Send notification to admin about overdue book
  static Future<void> notifyAdminOverdue({
    required String customerName,
    required String bookTitle,
    required int daysOverdue,
    required double fineAmount,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Overdue Book Alert',
          'message':
              'Customer $customerName has been late returning book "$bookTitle" for $daysOverdue days. Fine: \$${fineAmount.toStringAsFixed(2)}',
          'notification_type': 'overdue_alert',
          'user_type': 'library_admin',
          'data': {
            'customer_name': customerName,
            'book_title': bookTitle,
            'days_overdue': daysOverdue,
            'fine_amount': fineAmount,
          },
        }),
      );
    } catch (e) {
      debugPrint('Error sending admin overdue notification: $e');
    }
  }

  /// Send notification to customer about book return confirmation
  static Future<void> notifyCustomerReturnConfirmed({
    required String customerId,
    required String bookTitle,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Book Return Confirmed',
          'message':
              'Return of "$bookTitle" has been confirmed. Thank you for using our library!',
          'notification_type': 'return_confirmed',
          'user_id': customerId,
          'data': {'book_title': bookTitle},
        }),
      );
    } catch (e) {
      debugPrint('Error sending return confirmation notification: $e');
    }
  }

  /// Send notification to admin about book return
  static Future<void> notifyAdminBookReturned({
    required String customerName,
    required String bookTitle,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Book Returned Successfully',
          'message':
              'Book "$bookTitle" has been successfully returned by $customerName',
          'notification_type': 'book_returned',
          'user_type': 'library_admin',
          'data': {'customer_name': customerName, 'book_title': bookTitle},
        }),
      );
    } catch (e) {
      debugPrint('Error sending admin return notification: $e');
    }
  }

  /// Send notification to customer about request rejection
  static Future<void> notifyCustomerRejection({
    required String customerId,
    required String bookTitle,
    required String rejectionReason,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'Borrowing Request Rejected',
          'message':
              'Your borrowing request for "$bookTitle" has been rejected. Reason: $rejectionReason',
          'notification_type': 'borrow_rejected',
          'user_id': customerId,
          'data': {
            'book_title': bookTitle,
            'rejection_reason': rejectionReason,
          },
        }),
      );
    } catch (e) {
      debugPrint('Error sending rejection notification: $e');
    }
  }

  /// Send notification to all delivery managers about new task
  static Future<void> notifyAllDeliveryManagersNewTask({
    required String bookTitle,
    required String customerName,
    required String deliveryAddress,
  }) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/notifications/create/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization':
              'Bearer YOUR_AUTH_TOKEN', // This should come from auth service
        },
        body: jsonEncode({
          'title': 'New Delivery Task Available',
          'message':
              'New Request: Deliver the book "$bookTitle" to $customerName at address $deliveryAddress.',
          'notification_type': 'delivery_task_created',
          'user_type': 'delivery_admin',
          'data': {
            'book_title': bookTitle,
            'customer_name': customerName,
            'delivery_address': deliveryAddress,
          },
        }),
      );
    } catch (e) {
      debugPrint('Error sending delivery managers notification: $e');
    }
  }
}
