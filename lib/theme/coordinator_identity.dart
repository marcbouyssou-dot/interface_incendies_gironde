import 'package:flutter/material.dart';

@immutable
class CoordinatorIdentity {
  const CoordinatorIdentity({
    required this.accent,
    required this.onAccent,
    required this.container,
  });

  static const light = CoordinatorIdentity(
    accent: Color(0xFF6D4BC3),
    onAccent: Colors.white,
    container: Color(0xFFEDE7F8),
  );

  static const dark = CoordinatorIdentity(
    accent: Color(0xFFC6B3F4),
    onAccent: Color(0xFF24163F),
    container: Color(0xFF35264F),
  );

  final Color accent;
  final Color onAccent;
  final Color container;

  static CoordinatorIdentity of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
