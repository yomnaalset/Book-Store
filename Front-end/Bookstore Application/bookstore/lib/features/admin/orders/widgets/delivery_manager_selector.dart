import 'package:flutter/material.dart';

class DeliveryManagerSelector extends StatelessWidget {
  final List<Map<String, dynamic>> deliveryManagers;
  final String? selectedManagerId;
  final ValueChanged<String?> onChanged;
  final bool isLoading;

  const DeliveryManagerSelector({
    super.key,
    required this.deliveryManagers,
    this.selectedManagerId,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (deliveryManagers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No delivery managers available at the moment',
                style: TextStyle(color: Colors.orange[700]),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Delivery Manager',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selectedManagerId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: deliveryManagers.map((manager) {
            final status = manager['status'] as String;
            final isAvailable = status == 'online' || status == 'available';

            return DropdownMenuItem<String>(
              value: manager['id'] as String,
              enabled: isAvailable,
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _getStatusColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          manager['name'] as String,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isAvailable ? null : Colors.grey,
                          ),
                        ),
                        Text(
                          '${manager['vehicle']} • ${manager['rating']}★',
                          style: TextStyle(
                            fontSize: 12,
                            color: isAvailable ? Colors.grey[600] : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isAvailable)
                    const Text(
                      'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a delivery manager';
            }
            return null;
          },
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    // Handle legacy 'busy' status by treating it as 'online'
    final normalizedStatus = status.toLowerCase() == 'busy'
        ? 'online'
        : status.toLowerCase();

    switch (normalizedStatus) {
      case 'online':
      case 'available':
        return Colors.green;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
