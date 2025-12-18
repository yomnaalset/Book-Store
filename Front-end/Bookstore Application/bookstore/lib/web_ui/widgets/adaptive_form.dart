import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Adaptive form utilities for responsive layouts
class AdaptiveForm {
  /// Creates a responsive form row
  /// Mobile: Returns Column with fields stacked vertically
  /// Web: Returns Row with fields side by side
  static Widget formRow({
    required List<Widget> children,
    double spacing = 16.0,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    if (kIsWeb) {
      // Web: Horizontal layout
      return Row(
        crossAxisAlignment: crossAxisAlignment,
        children: _buildExpandedChildren(children, spacing),
      );
    } else {
      // Mobile: Vertical layout
      return Column(
        crossAxisAlignment: crossAxisAlignment,
        children: _buildSpacedChildren(children, spacing),
      );
    }
  }

  /// Creates a responsive grid for forms
  /// Mobile: Single column
  /// Web: Two columns
  static Widget formGrid({
    required List<Widget> children,
    int webColumns = 2,
    double spacing = 16.0,
  }) {
    if (kIsWeb) {
      // Web: Grid layout
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = webColumns;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: _calculateAspectRatio(
                constraints.maxWidth,
                crossAxisCount,
                spacing,
              ),
            ),
            itemCount: children.length,
            itemBuilder: (context, index) => children[index],
          );
        },
      );
    } else {
      // Mobile: Column layout
      return Column(children: _buildSpacedChildren(children, spacing));
    }
  }

  /// Creates responsive spacing between form fields
  static double get fieldSpacing => kIsWeb ? 16.0 : 12.0;

  /// Creates responsive padding for form containers
  static EdgeInsets get formPadding =>
      kIsWeb ? const EdgeInsets.all(24.0) : const EdgeInsets.all(16.0);

  /// Helper to build expanded children for Row
  static List<Widget> _buildExpandedChildren(
    List<Widget> children,
    double spacing,
  ) {
    if (children.isEmpty) return [];

    final List<Widget> result = [];
    for (int i = 0; i < children.length; i++) {
      result.add(Expanded(child: children[i]));
      if (i < children.length - 1) {
        result.add(SizedBox(width: spacing));
      }
    }
    return result;
  }

  /// Helper to build spaced children for Column
  static List<Widget> _buildSpacedChildren(
    List<Widget> children,
    double spacing,
  ) {
    if (children.isEmpty) return [];

    final List<Widget> result = [];
    for (int i = 0; i < children.length; i++) {
      result.add(children[i]);
      if (i < children.length - 1) {
        result.add(SizedBox(height: spacing));
      }
    }
    return result;
  }

  /// Calculate aspect ratio for grid items
  static double _calculateAspectRatio(
    double width,
    int columns,
    double spacing,
  ) {
    // Base aspect ratio, adjust based on your needs
    final itemWidth = (width - (spacing * (columns - 1))) / columns;
    return itemWidth / 60; // Adjust height as needed
  }
}

/// Responsive spacing widget
class ResponsiveSpacing extends StatelessWidget {
  final double mobile;
  final double web;

  const ResponsiveSpacing({super.key, this.mobile = 16.0, this.web = 24.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(height: kIsWeb ? web : mobile);
  }
}
