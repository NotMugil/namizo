import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A wrapper widget to support IconData, PhosphorIconData, and custom Widgets
/// with custom colors and sizes seamlessly.
class AppIcon extends StatelessWidget {
  final Object icon;
  final Color? color;
  final double? size;

  const AppIcon(
    this.icon, {
    super.key,
    this.color,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final target = icon;

    Widget result;
    if (target is PhosphorIconData) {
      result = PhosphorIcon(
        target,
        color: color,
        size: size,
      );
    } else if (target is IconData) {
      result = Icon(
        target,
        color: color,
        size: size,
      );
    } else if (target is Widget) {
      result = target;
      if (color != null || size != null) {
        result = IconTheme(
          data: IconThemeData(
            color: color,
            size: size,
          ),
          child: result,
        );
      }
    } else {
      result = const SizedBox.shrink();
    }

    return result;
  }
}
