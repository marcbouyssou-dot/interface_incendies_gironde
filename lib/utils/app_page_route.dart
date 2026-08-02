import 'package:flutter/material.dart';

class AppPageRoute<T> extends MaterialPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 190);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 130);
}
