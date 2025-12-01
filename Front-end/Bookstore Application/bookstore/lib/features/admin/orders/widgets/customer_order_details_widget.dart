import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../orders/models/order.dart';
import 'clean_order_item_card.dart';
import 'order_details_shared.dart';
import '../providers/orders_provider.dart';
import 'delivery_location_map_widget.dart';

class CustomerOrderDetailsWidget extends StatefulWidget {
  final Order order;
  final OrderDetailsShared shared;

  const CustomerOrderDetailsWidget({
    super.key,
    required this.order,
    required this.shared,
  });

  @override
  State<CustomerOrderDetailsWidget> createState() =>
      _CustomerOrderDetailsWidgetState();
}

class _CustomerOrderDetailsWidgetState
    extends State<CustomerOrderDetailsWidget> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1 - Order Details
          widget.shared.buildSectionCard(
            context: context,
            title: 'Order Details',
            icon: Icons.shopping_cart,
            children: [
              widget.shared.buildInfoRow(
                'Order Number',
                '#ORD-${widget.order.id.toString().padLeft(4, '0')}',
              ),
              widget.shared.buildInfoRow(
                'Creation Date',
                widget.shared.formatDate(widget.order.createdAt),
              ),
              widget.shared.buildInfoRow('Current Status', widget.order.statusDisplay),
              widget.shared.buildInfoRow('Number of Books', '${widget.order.items.length}'),
              widget.shared.buildInfoRow(
                'Subtotal',
                '\$${widget.order.subtotal.toStringAsFixed(2)}',
              ),
              if (widget.shared.hasEffectiveDiscount(widget.order)) ...[
                widget.shared.buildInfoRow(
                  'Discount',
                  '-\$${(widget.order.subtotal - widget.order.totalAmount).toStringAsFixed(2)}',
                  isHighlighted: true,
                  textColor: Colors.red,
                ),
              ],
              if (widget.order.shippingCost > 0) ...[
                widget.shared.buildInfoRow(
                  'Delivery Cost',
                  '\$${widget.order.shippingCost.toStringAsFixed(2)}',
                ),
              ],
              // Always show tax if it exists (even if 0, as it might be calculated)
              widget.shared.buildInfoRow(
                'Tax',
                '\$${widget.order.taxAmount.toStringAsFixed(2)}',
              ),
              widget.shared.buildInfoRow(
                'Total Amount',
                '\$${widget.order.totalAmount.toStringAsFixed(2)}',
                isHighlighted: true,
                fontWeight: FontWeight.bold,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Section 2 - Customer Information
          widget.shared.buildSectionCard(
            context: context,
            title: 'Customer Information',
            icon: Icons.person,
            children: [
              widget.shared.buildInfoRow('Full Name', widget.order.customerName),
              widget.shared.buildInfoRow(
                'Phone Number',
                widget.order.customerPhone.isNotEmpty
                    ? widget.order.customerPhone
                    : 'Not provided',
              ),
              widget.shared.buildInfoRow('Email', widget.order.customerEmail),
              if (widget.order.shippingAddress != null) ...[
                widget.shared.buildInfoRow(
                  'Address',
                  widget.order.shippingAddressText ?? 'No address',
                ),
              ],
              if (widget.order.deliveryCity != null) ...[
                widget.shared.buildInfoRow('City', widget.order.deliveryCity!),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Section 3 - Payment Information
          widget.shared.buildSectionCard(
            context: context,
            title: 'Payment Information',
            icon: Icons.payment,
            children: [
              widget.shared.buildInfoRow(
                'Payment Method',
                widget.shared.getPaymentMethodDisplay(widget.order.paymentMethod),
              ),
              widget.shared.buildInfoRow(
                'Payment Status',
                widget.shared.getPaymentStatusDisplay(widget.order.paymentStatus),
              ),
              widget.shared.buildInfoRow(
                'Discount Applied',
                widget.shared.hasEffectiveDiscount(widget.order) ? 'Yes' : 'No',
                isHighlighted: widget.shared.hasEffectiveDiscount(widget.order),
                textColor: widget.shared.hasEffectiveDiscount(widget.order)
                    ? Colors.green
                    : null,
              ),
              if (widget.shared.hasEffectiveDiscount(widget.order)) ...[
                if (widget.order.discountCode != null &&
                    widget.order.discountCode!.isNotEmpty) ...[
                  widget.shared.buildInfoRow(
                    'Discount Code',
                    widget.order.discountCode!,
                    isHighlighted: true,
                    textColor: Colors.green,
                  ),
                ],
                widget.shared.buildInfoRow(
                  'Discount Amount',
                  '\$${(widget.order.subtotal - widget.order.totalAmount).toStringAsFixed(2)}',
                  isHighlighted: true,
                  textColor: Colors.green,
                ),
                if (widget.order.subtotal > 0) ...[
                  widget.shared.buildInfoRow(
                    'Savings Percentage',
                    '${(((widget.order.subtotal - widget.order.totalAmount) / widget.order.subtotal) * 100).toStringAsFixed(1)}%',
                    isHighlighted: true,
                    textColor: Colors.green,
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Order Items Section
          widget.shared.buildSectionCard(
            context: context,
            title: 'Order Items',
            icon: Icons.inventory,
            children: [
              ...widget.order.items.map((item) => CleanOrderItemCard(item: item)),
            ],
          ),
          const SizedBox(height: 16),

          // View Delivery Location Button (when status is "in_delivery")
          if (widget.order.isInDelivery && !widget.order.isCancelled)
            _buildViewDeliveryLocationButton(),
        ],
      ),
    );
  }

  Widget _buildViewDeliveryLocationButton() {
    return widget.shared.buildSectionCard(
      context: context,
      title: 'Delivery Tracking',
      icon: Icons.location_on,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _viewDeliveryLocation,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.map, color: Colors.white),
            label: const Text('View Delivery Location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _viewDeliveryLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<OrdersProvider>();
      final locationData = await provider.getOrderDeliveryLocation(
        int.parse(widget.order.id),
      );

      if (mounted) {
        if (locationData != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeliveryLocationMapWidget(
                order: widget.order,
                locationData: locationData,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.error ?? 'Failed to get delivery location'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
