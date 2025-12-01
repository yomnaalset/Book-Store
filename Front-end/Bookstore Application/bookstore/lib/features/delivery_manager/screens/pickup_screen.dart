import 'package:flutter/material.dart';
import '../../../core/translations.dart';
import '../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';

class PickupScreen extends StatelessWidget {
  final DeliveryTask task;

  const PickupScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.t(context, 'start_pickup')),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Pickup instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('Pickup Instructions', style: TextStyle()),
                    const SizedBox(height: 12),
                    Text(
                      '1. Verify the order number matches: ${task.orderId}',
                      style: const TextStyle(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '2. Check that all books are present and in good condition',
                      style: TextStyle(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '3. Confirm pickup time and add any notes',
                      style: TextStyle(),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '4. Take a photo of the books if required',
                      style: TextStyle(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Pickup confirmed')),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(AppTranslations.t(context, 'confirm')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
