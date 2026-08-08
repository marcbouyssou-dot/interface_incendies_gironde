import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/system_theme.dart';
import 'v5_foundation.dart';

abstract final class AppColors {
  static const navy = Color(0xFF10233E);
  static const navySoft = Color(0xFF1E385B);
  static const orange = Color(0xFFF37A32);
  static const orangeSoft = Color(0xFFFFE9DB);
  static const green = Color(0xFF168A63);
  static const greenSoft = Color(0xFFE0F3EB);
  static const red = Color(0xFFD94B4B);
  static const redSoft = Color(0xFFFFE8E8);
  static const background = Color(0xFFF6F7F8);
  static const surface = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF697586);
  static const border = Color(0xFFE4E8ED);
}

abstract final class AppTheme {
  static const lightSystemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFFF6F7F8),
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Color(0xFFF6F7F8),
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  static const darkSystemUiOverlayStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.navy,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: AppColors.navy,
    systemStatusBarContrastEnforced: false,
    systemNavigationBarContrastEnforced: false,
  );

  static Widget lightSystemSurface(BuildContext context, Widget? child) {
    return systemSurface(context, child);
  }

  static Widget darkSystemSurface(BuildContext context, Widget? child) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkSystemUiOverlayStyle,
      child: ColoredBox(
        color: AppColors.navy,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  static Widget systemSurface(BuildContext context, Widget? child) {
    activateLightApplicationChrome();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightSystemUiOverlayStyle,
      child: ColoredBox(
        color: V5Colors.light.canvas,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }

  static ThemeData get light =>
      _build(brightness: Brightness.light, colors: V5Colors.light);

  static ThemeData get dark =>
      _build(brightness: Brightness.dark, colors: V5Colors.dark);

  static ThemeData _build({
    required Brightness brightness,
    required V5Colors colors,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.brand,
      onPrimary: colors.onBrand,
      secondary: colors.accent,
      onSecondary: colors.onAccent,
      error: colors.danger,
      onError: brightness == Brightness.dark
          ? const Color(0xFF2A080D)
          : Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
      outline: colors.outline,
      surfaceContainerHighest: colors.surfaceMuted,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [colors],
      scaffoldBackgroundColor: colors.canvas,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _AppPageTransitionsBuilder(),
          TargetPlatform.fuchsia: _AppPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: _AppPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _AppPageTransitionsBuilder(),
        },
      ),
      fontFamily: 'sans-serif',
      textTheme: V5Typography.textTheme(colors),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(V5Radius.card)),
          side: BorderSide(color: colors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: V5Spacing.md,
          vertical: V5Spacing.sm,
        ),
        hintStyle: TextStyle(color: colors.textSecondary),
        labelStyle: TextStyle(color: colors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V5Radius.control),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V5Radius.control),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(V5Radius.control),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.surface,
        indicatorColor: brightness == Brightness.dark
            ? colors.warningContainer
            : V5Colors.light.warningContainer,
        height: 72,
        elevation: 0,
        labelTextStyle: WidgetStatePropertyAll(
          V5Typography.textTheme(colors).labelSmall,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.brand,
          foregroundColor: colors.onBrand,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(V5Radius.control),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AppPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.isFirst || MediaQuery.disableAnimationsOf(context)) return child;
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curvedAnimation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.018, 0),
          end: Offset.zero,
        ).animate(curvedAnimation),
        child: child,
      ),
    );
  }
}
