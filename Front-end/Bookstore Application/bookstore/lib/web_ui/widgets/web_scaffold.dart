import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../core/services/theme_service.dart';
import '../../features/auth/providers/auth_provider.dart';
import 'web_sidebar.dart';
import 'web_header.dart';
import 'web_constrained_box.dart';

class WebScaffold extends StatelessWidget {
  final Widget child;
  final String title;
  final List<Widget>? actions;
  final bool constrainContent;

  const WebScaffold({
    super.key,
    required this.child,
    required this.title,
    this.actions,
    this.constrainContent = true,
  });

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDark = themeService.isDarkMode;

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          WebSidebar(userRole: authProvider.userRole ?? 'customer'),
          // Main content area
          Expanded(
            child: Column(
              children: [
                // Header
                WebHeader(title: title, actions: actions),
                // Content with optional constraint
                Expanded(
                  child: Container(
                    color: isDark
                        ? AppColors.darkBackground
                        : AppColors.background,
                    child: constrainContent
                        ? WebConstrainedBox(
                            padding: const EdgeInsets.all(24),
                            child: child,
                          )
                        : child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
