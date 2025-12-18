import 'package:flutter/material.dart';
import '../../features/delivery_manager/screens/dashboard_screen.dart';
import '../widgets/web_scaffold.dart';

class DeliveryWebDashboard extends StatelessWidget {
  const DeliveryWebDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const WebScaffold(
      title: 'Delivery Dashboard',
      child: DeliveryManagerDashboardScreen(),
    );
  }
}
