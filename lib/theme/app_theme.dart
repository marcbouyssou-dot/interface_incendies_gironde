import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF10233E);
  static const navySoft = Color(0xFF1E385B);
  static const orange = Color(0xFFF37A32);
  static const orangeSoft = Color(0xFFFFE9DB);
  static const green = Color(0xFF168A63);
  static const greenSoft = Color(0xFFE0F3EB);
  static const red = Color(0xFFD94B4B);
  static const redSoft = Color(0xFFFFE8E8);
  static const background = Color(0xFFF4F6F8);
  static const surface = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFF697586);
  static const border = Color(0xFFE4E8ED);
}

abstract final class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.navy,
      onPrimary: Colors.white,
      secondary: AppColors.orange,
      onSecondary: Colors.white,
      error: AppColors.red,
      surface: AppColors.surface,
      onSurface: AppColors.navy,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
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
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: AppColors.navy,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          color: AppColors.navy,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
        bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: AppColors.navy),
        bodyMedium: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: AppColors.textMuted,
        ),
        labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.orange, width: 1.5),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.orangeSoft,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
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
