import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Widget that shows hover effects on web, tap effects on mobile
class HoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? hoverColor;
  final Color? splashColor;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;

  const HoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.hoverColor,
    this.splashColor,
    this.borderRadius,
    this.padding,
  });

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hoverColor =
        widget.hoverColor ?? theme.colorScheme.primary.withValues(alpha: 0.08);
    final splashColor = widget.splashColor ?? theme.colorScheme.primary;

    Widget content = Container(
      padding: widget.padding,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        color: kIsWeb && _isHovered ? hoverColor : Colors.transparent,
      ),
      child: widget.child,
    );

    if (widget.onTap != null) {
      if (kIsWeb) {
        // Web: Use MouseRegion for hover effects
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: widget.onTap, child: content),
        );
      } else {
        // Mobile: Use InkWell for tap effects
        return InkWell(
          onTap: widget.onTap,
          splashColor: splashColor,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
          child: content,
        );
      }
    }

    return content;
  }
}

/// Button with hover effects on web
class HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? hoverColor;
  final Color? backgroundColor;
  final EdgeInsets? padding;
  final BorderRadius? borderRadius;

  const HoverButton({
    super.key,
    required this.child,
    this.onPressed,
    this.hoverColor,
    this.backgroundColor,
    this.padding,
    this.borderRadius,
  });

  @override
  State<HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.colorScheme.primary;

    Widget button = Container(
      padding:
          widget.padding ??
          const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
        border: kIsWeb && _isHovered
            ? Border.all(color: theme.colorScheme.primary, width: 2)
            : null,
      ),
      child: widget.child,
    );

    if (kIsWeb) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onPressed != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: button,
          ),
        ),
      );
    }

    return InkWell(
      onTap: widget.onPressed,
      borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
      child: button,
    );
  }
}

/// ListTile with hover effects
class HoverListTile extends StatefulWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? hoverColor;

  const HoverListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.hoverColor,
  });

  @override
  State<HoverListTile> createState() => _HoverListTileState();
}

class _HoverListTileState extends State<HoverListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hoverColor =
        widget.hoverColor ?? theme.colorScheme.primary.withValues(alpha: 0.08);

    Widget tile = ListTile(
      leading: widget.leading,
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: widget.trailing,
      onTap: widget.onTap,
    );

    if (kIsWeb) {
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Container(
          color: _isHovered ? hoverColor : Colors.transparent,
          child: tile,
        ),
      );
    }

    return tile;
  }
}
