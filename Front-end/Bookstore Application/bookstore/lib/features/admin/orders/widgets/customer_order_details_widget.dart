import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../orders/models/order.dart';
import 'clean_order_item_card.dart';
import 'order_details_shared.dart';
import '../providers/orders_provider.dart';
import '../../../../core/localization/app_localizations.dart';

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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1 - Order Details
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return widget.shared.buildSectionCard(
                context: context,
                title: localizations.orderDetails,
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
                  Builder(
                    builder: (context) {
                      final localizations = AppLocalizations.of(context);
                      return widget.shared.buildInfoRow(
                        'Current Status',
                        localizations.getOrderStatusLabel(widget.order.status),
                      );
                    },
                  ),
                  widget.shared.buildInfoRow(
                    'Number of Books',
                    '${widget.order.items.fold(0, (sum, item) => sum + item.quantity)}',
                  ),
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
              );
            },
          ),
          const SizedBox(height: 16),

          // Section 2 - Payment Information
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return widget.shared.buildSectionCard(
                context: context,
                title: localizations.paymentInformation,
                icon: Icons.payment,
                children: [
                  widget.shared.buildInfoRow(
                    'Payment Method',
                    widget.shared.getPaymentMethodDisplay(
                      widget.order.paymentMethod,
                      context,
                    ),
                  ),
                  widget.shared.buildInfoRow(
                    'Payment Status',
                    widget.shared.getPaymentStatusDisplay(
                      widget.order.paymentStatus,
                      context,
                    ),
                  ),
                  widget.shared.buildInfoRow(
                    'Discount Applied',
                    widget.shared.hasEffectiveDiscount(widget.order)
                        ? 'Yes'
                        : 'No',
                    isHighlighted: widget.shared.hasEffectiveDiscount(
                      widget.order,
                    ),
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
              );
            },
          ),
          const SizedBox(height: 16),

          // Order Items Section
          Builder(
            builder: (context) {
              final localizations = AppLocalizations.of(context);
              return widget.shared.buildSectionCard(
                context: context,
                title: localizations.orderItems,
                icon: Icons.inventory,
                children: [
                  ...widget.order.items.map(
                    (item) => CleanOrderItemCard(item: item),
                  ),
                ],
              );
            },
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
            label: Builder(
              builder: (context) {
                final localizations = AppLocalizations.of(context);
                return Text(localizations.viewDeliveryLocation);
              },
            ),
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
          final location = locationData['location'] as Map<String, dynamic>?;
          final latitude = location?['latitude'] as double?;
          final longitude = location?['longitude'] as double?;

          if (latitude != null && longitude != null) {
            await _launchGoogleMaps(latitude, longitude);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Delivery manager location is not available at the moment.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                provider.error ?? 'Failed to get delivery location',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Launch Google Maps with the given coordinates
  Future<void> _launchGoogleMaps(double latitude, double longitude) async {
    try {
      // Try multiple URL schemes in order of preference
      final urls = [
        // Google Maps app (Android) - navigation mode
        Uri.parse('google.navigation:q=$latitude,$longitude'),
        // Google Maps app (Android/iOS) - search mode
        Uri.parse('comgooglemaps://?q=$latitude,$longitude'),
        // Geo scheme (Android) - opens default maps app
        Uri.parse('geo:$latitude,$longitude'),
        // Google Maps web URL (always works as fallback)
        Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        ),
      ];

      bool launched = false;
      for (final url in urls) {
        try {
          // Try to launch directly - canLaunchUrl can be unreliable
          await launchUrl(url, mode: LaunchMode.externalApplication);
          launched = true;
          break;
        } catch (e) {
          // Try next URL if this one fails
          debugPrint('Failed to launch URL $url: $e');
          continue;
        }
      }

      if (!launched) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to open maps application.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
