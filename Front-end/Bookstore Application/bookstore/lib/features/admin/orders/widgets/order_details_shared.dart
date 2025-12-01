import 'package:flutter/material.dart';
import '../../../orders/models/order.dart';

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

  String getPaymentMethodDisplay(String? method) {
    if (method == null) return 'Not specified';

    switch (method.toLowerCase()) {
      case 'card':
        return 'Credit/Debit Card';
      case 'cash_on_delivery':
      case 'cod':
      case 'cash':
        return 'Cash on Delivery';
      default:
        return method;
    }
  }

  String getPaymentStatusDisplay(String? status) {
    if (status == null) return 'Pending';

    switch (status.toLowerCase()) {
      case 'paid':
        return 'Paid';
      case 'unpaid':
        return 'Unpaid';
      case 'pending':
        return 'Pending';
      default:
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
