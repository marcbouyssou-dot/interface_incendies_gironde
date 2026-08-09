import 'package:flutter/material.dart';

abstract final class PlatformAdminIdentity {
  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF83CFC3)
      : const Color(0xFF286B63);

  static Color container(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF173C38)
      : const Color(0xFFDDEEEB);
}
