import 'package:flutter/material.dart';

class AppToastStyle {
  static const Duration duration = Duration(seconds: 2);
  static const Color backgroundColor = Color(0xFF0A0A0A);
  static const double elevation = 0;
  static const EdgeInsets margin = EdgeInsets.fromLTRB(16, 0, 16, 18);
  static const BorderRadius borderRadius = BorderRadius.all(Radius.circular(12));
  static const TextStyle messageTextStyle = TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.w600,
  );

  static BorderSide border(Color accent) {
    return BorderSide(color: accent.withValues(alpha: 0.45), width: 1);
  }
}
