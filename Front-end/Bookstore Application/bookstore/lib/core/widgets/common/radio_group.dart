import 'package:flutter/material.dart';

/// A widget that manages a group of radio buttons
/// Replaces the deprecated groupValue parameter in RadioListTile
class RadioGroup<T> extends StatelessWidget {
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget child;

  const RadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _RadioGroupScope<T>(
      groupValue: groupValue,
      onChanged: onChanged,
      child: child,
    );
  }
}

class _RadioGroupScope<T> extends InheritedWidget {
  final T? groupValue;
  final ValueChanged<T?>? onChanged;

  const _RadioGroupScope({
    required this.groupValue,
    required this.onChanged,
    required super.child,
  });

  static _RadioGroupScope<T>? of<T>(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_RadioGroupScope<T>>();
  }

  @override
  bool updateShouldNotify(_RadioGroupScope<T> oldWidget) {
    return groupValue != oldWidget.groupValue ||
        onChanged != oldWidget.onChanged;
  }
}

/// A wrapper for RadioListTile that gets groupValue from RadioGroup ancestor
class RadioGroupTile<T> extends StatelessWidget {
  final T value;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final ListTileControlAffinity? controlAffinity;
  final Color? activeColor;
  final bool? selected;
  final Color? selectedTileColor;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final bool? isThreeLine;
  final VisualDensity? visualDensity;
  final FocusNode? focusNode;
  final bool? autofocus;
  final bool? enableFeedback;

  const RadioGroupTile({
    super.key,
    required this.value,
    this.title,
    this.subtitle,
    this.secondary,
    this.controlAffinity,
    this.activeColor,
    this.selected,
    this.selectedTileColor,
    this.shape,
    this.contentPadding,
    this.dense,
    this.isThreeLine,
    this.visualDensity,
    this.focusNode,
    this.autofocus,
    this.enableFeedback,
  });

  @override
  Widget build(BuildContext context) {
    final scope = _RadioGroupScope.of<T>(context);
    if (scope == null) {
      throw FlutterError('RadioGroupTile must be a descendant of RadioGroup');
    }

    return RadioListTile<T>(
      value: value,
      // ignore: deprecated_member_use
      groupValue: scope.groupValue,
      // ignore: deprecated_member_use
      onChanged: scope.onChanged,
      title: title,
      subtitle: subtitle,
      secondary: secondary,
      controlAffinity: controlAffinity,
      activeColor: activeColor,
      selected: selected ?? false,
      selectedTileColor: selectedTileColor,
      shape: shape,
      contentPadding: contentPadding,
      dense: dense ?? false,
      isThreeLine: isThreeLine ?? false,
      visualDensity: visualDensity,
      focusNode: focusNode,
      autofocus: autofocus ?? false,
      enableFeedback: enableFeedback ?? false,
    );
  }
}
