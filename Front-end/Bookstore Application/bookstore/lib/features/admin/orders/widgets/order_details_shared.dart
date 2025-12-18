import 'package:flutter/material.dart';
import '../../../orders/models/order.dart';
import '../../../../core/localization/app_localizations.dart';

class OrderDetailsShared {
  Widget buildSectionCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF2C3E50), size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget buildInfoRow(
    String label,
    String value, {
    bool isHighlighted = false,
    Color? textColor,
    FontWeight fontWeight = FontWeight.bold,
  }) {
    final highlightColor = textColor ?? Colors.blue.shade700;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isHighlighted ? highlightColor : Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isHighlighted ? fontWeight : FontWeight.w500,
                fontSize: 16,
                color: isHighlighted ? highlightColor : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCustomerDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF6C757D)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6C757D),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: value == 'Not provided'
                        ? Colors.red[600]
                        : const Color(0xFF495057),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String getPaymentMethodDisplay(String? method, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (method == null) return localizations.notAvailable;

    switch (method.toLowerCase()) {
      case 'card':
        return localizations.paymentMethodCard;
      case 'cash_on_delivery':
      case 'cod':
      case 'cash':
        return localizations.paymentMethodCashOnDelivery;
      default:
        return method;
    }
  }

  String getPaymentStatusDisplay(String? status, BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (status == null) return localizations.paymentStatusPending;

    final lowerStatus = status.toLowerCase();

    // Handle standard payment statuses
    switch (lowerStatus) {
      case 'paid':
        return localizations.paymentStatusPaid;
      case 'unpaid':
        return localizations.paymentStatusUnpaid;
      case 'pending':
        return localizations.paymentStatusPending;
      case 'delivered':
        // For payment status, "delivered" means payment was completed upon delivery
        // Use statusDelivered which is already translated
        return localizations.statusDelivered;
      case 'completed':
        return localizations.paymentStatusPaid;
      default:
        // If it's not a standard payment status, check if it's an order status
        // (sometimes payment status field contains order status values)
        try {
          final orderStatusLabel = localizations.getOrderStatusLabel(status);
          // If getOrderStatusLabel returns a different value, it means it's an order status
          if (orderStatusLabel.toLowerCase() != lowerStatus) {
            return orderStatusLabel;
          }
        } catch (e) {
          // getOrderStatusLabel might throw for invalid statuses, continue to fallback
        }
        // Final fallback: return the status as-is
        return status;
    }
  }

  bool hasEffectiveDiscount(Order order) {
    // Check if there's a significant price difference between subtotal and total amount
    // If the discount amount is explicitly set and greater than 0
    if (order.discountAmount != null && order.discountAmount! > 0) {
      return true;
    }

    // If there's a discount code
    if (order.discountCode != null && order.discountCode!.isNotEmpty) {
      return true;
    }

    // If there's a significant difference between subtotal and total amount (more than 1%)
    if (order.subtotal > 0) {
      final expectedTotal =
          order.subtotal + order.shippingCost + order.taxAmount;
      final difference = expectedTotal - order.totalAmount;
      if (difference > (expectedTotal * 0.01)) {
        // More than 1% difference
        return true;
      }
    }

    return false;
  }
}
