import 'package:flutter/cupertino.dart';

class AppPageRoute<T> extends CupertinoPageRoute<T> {
  AppPageRoute({
    required super.builder,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
    bool? reduceMotion,
  }) : _reduceMotion =
           reduceMotion ??
           WidgetsBinding
               .instance
               .platformDispatcher
               .accessibilityFeatures
               .disableAnimations;

  final bool _reduceMotion;

  @override
  Duration get transitionDuration =>
      _reduceMotion ? Duration.zero : const Duration(milliseconds: 220);

  @override
  Duration get reverseTransitionDuration =>
      _reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
}
