import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/translations.dart';
import '../../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';

class MessagesScreen extends StatelessWidget {
  final DeliveryTask task;

  const MessagesScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.t(context, 'messages')),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Customer contact info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Customer Contact',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Name: ${task.customerName}'),
                    const SizedBox(height: 8),
                    Text('Phone: ${task.customerPhone}'),
                    const SizedBox(height: 8),
                    Text('Email: ${task.customerEmail}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Call button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _callCustomer(context),
                icon: const Icon(Icons.phone),
                label: Text(AppTranslations.t(context, 'call_customer')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _callCustomer(BuildContext context) async {
    final phoneNumber = task.customerPhone;

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer phone number is not available'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Remove any non-digit characters except + for international numbers
    final cleanPhoneNumber = phoneNumber.replaceAll(
      // ignore: deprecated_member_use
      RegExp(r'[^\d+]'),
      '',
    );

    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhoneNumber);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot make phone calls on this device'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching phone call: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
