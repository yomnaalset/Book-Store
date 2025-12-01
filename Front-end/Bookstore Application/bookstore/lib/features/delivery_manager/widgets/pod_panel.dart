import 'package:flutter/material.dart';
import '../../../core/translations.dart';
import '../../../core/constants/app_colors.dart';
import '../models/delivery_task.dart';
import '../../../features/delivery/models/proof_of_delivery.dart'
    as proof_of_delivery;

class PODPanel extends StatefulWidget {
  final DeliveryTask task;
  final Function(proof_of_delivery.ProofOfDelivery)? onPODSubmitted;

  const PODPanel({super.key, required this.task, this.onPODSubmitted});

  @override
  State<PODPanel> createState() => _PODPanelState();
}

class _PODPanelState extends State<PODPanel> {
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _collectionMethod = 'cash';
  @override
  void dispose() {
    _otpController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTranslations.t(context, 'proof_of_delivery'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Customer OTP
            TextField(
              controller: _otpController,
              decoration: InputDecoration(
                labelText: AppTranslations.t(context, 'customer_otp'),
                hintText: 'Enter OTP received by customer',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Collection Method
            Text(
              AppTranslations.t(context, 'collection_method'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _collectionMethod,
              onChanged: (value) {
                setState(() {
                  _collectionMethod = value!;
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(AppTranslations.t(context, 'cash')),
                      value: 'cash',
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(AppTranslations.t(context, 'card')),
                      value: 'card',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Collected Amount
            TextField(
              decoration: InputDecoration(
                labelText: AppTranslations.t(context, 'collected_amount'),
                hintText: '0.00',
                border: const OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {},
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                labelText: AppTranslations.t(context, 'notes'),
                hintText: 'Add any delivery notes...',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(AppTranslations.t(context, 'cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submitPOD,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: AppColors.white,
                    ),
                    child: Text(AppTranslations.t(context, 'submit_proof')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _submitPOD() {
    if (_otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter customer OTP'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final pod = proof_of_delivery.ProofOfDelivery(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      deliveryTaskId: widget.task.id.toString(),
      signature: _otpController.text, // Using OTP as signature for now
      receiverName: widget.task.customerName,
      notes: _notesController.text,
      timestamp: DateTime.now(),
      isComplete: true,
    );

    widget.onPODSubmitted?.call(pod);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppTranslations.t(context, 'success')),
        backgroundColor: AppColors.success,
      ),
    );

    Navigator.pop(context);
  }
}
