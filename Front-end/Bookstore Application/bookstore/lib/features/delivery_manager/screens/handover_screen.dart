import 'package:flutter/material.dart';
import '../../../core/translations.dart';
import '../../../../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';

class HandoverScreen extends StatelessWidget {
  final DeliveryTask task;

  const HandoverScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.t(context, 'mark_delivered')),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Delivery instructions
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Instructions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text('1. Verify customer identity'),
                    SizedBox(height: 8),
                    Text('2. Confirm delivery address'),
                    SizedBox(height: 8),
                    Text('3. Collect payment if required'),
                    SizedBox(height: 8),
                    Text('4. Get customer signature or OTP'),
                    SizedBox(height: 8),
                    Text('5. Take delivery photo'),
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
                    const SnackBar(content: Text('Delivery confirmed')),
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
