import 'package:flutter/material.dart';

@immutable
class V5Colors extends ThemeExtension<V5Colors> {
  const V5Colors({
    required this.brand,
    required this.onBrand,
    required this.accent,
    required this.onAccent,
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.danger,
    required this.dangerContainer,
    required this.info,
    required this.infoContainer,
    required this.shadow,
  });

  static const light = V5Colors(
    brand: Color(0xFF10233E),
    onBrand: Color(0xFFFFFFFF),
    accent: Color(0xFFF36F32),
    onAccent: Color(0xFFFFFFFF),
    canvas: Color(0xFFF6F7F8),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFF0F2F4),
    textPrimary: Color(0xFF10233E),
    textSecondary: Color(0xFF667085),
    outline: Color(0xFFDDE2E8),
    success: Color(0xFF168A63),
    successContainer: Color(0xFFE0F3EB),
    warning: Color(0xFFD96322),
    warningContainer: Color(0xFFFFE9DB),
    danger: Color(0xFFC83F4D),
    dangerContainer: Color(0xFFFFE7EA),
    info: Color(0xFF3567A6),
    infoContainer: Color(0xFFE7F0FB),
    shadow: Color(0xFF10233E),
  );

  static const dark = V5Colors(
    brand: Color(0xFFF2F5F8),
    onBrand: Color(0xFF10233E),
    accent: Color(0xFFFF8A52),
    onAccent: Color(0xFF241208),
    canvas: Color(0xFF0D1622),
    surface: Color(0xFF162231),
    surfaceElevated: Color(0xFF1D2A3A),
    surfaceMuted: Color(0xFF243244),
    textPrimary: Color(0xFFF2F5F8),
    textSecondary: Color(0xFFB3BECA),
    outline: Color(0xFF354457),
    success: Color(0xFF64D2A7),
    successContainer: Color(0xFF163C32),
    warning: Color(0xFFFFA16F),
    warningContainer: Color(0xFF4A2A1D),
    danger: Color(0xFFFF8B96),
    dangerContainer: Color(0xFF4A222A),
    info: Color(0xFF9CC5F5),
    infoContainer: Color(0xFF203750),
    shadow: Color(0xFF000000),
  );

  final Color brand;
  final Color onBrand;
  final Color accent;
  final Color onAccent;
  final Color canvas;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color danger;
  final Color dangerContainer;
  final Color info;
  final Color infoContainer;
  final Color shadow;

  @override
  V5Colors copyWith({
    Color? brand,
    Color? onBrand,
    Color? accent,
    Color? onAccent,
    Color? canvas,
    Color? surface,
    Color? surfaceElevated,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? outline,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? danger,
    Color? dangerContainer,
    Color? info,
    Color? infoContainer,
    Color? shadow,
  }) {
    return V5Colors(
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      outline: outline ?? this.outline,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      danger: danger ?? this.danger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  V5Colors lerp(covariant V5Colors? other, double t) {
    if (other == null) return this;
    return V5Colors(
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerContainer: Color.lerp(dangerContainer, other.dangerContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

abstract final class V5Spacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

abstract final class V5Radius {
  static const double compact = 10;
  static const double control = 14;
  static const double section = 16;
  static const double card = 20;
  static const double large = 28;
  static const double pill = 999;
}

abstract final class V5Elevation {
  static List<BoxShadow> level1(V5Colors colors) => [
    BoxShadow(
      color: colors.shadow.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> level2(V5Colors colors) => [
    BoxShadow(
      color: colors.shadow.withValues(alpha: 0.1),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

abstract final class V5Typography {
  static TextTheme textTheme(V5Colors colors) => TextTheme(
    displaySmall: TextStyle(
      color: colors.textPrimary,
      fontSize: 32,
      height: 1.08,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
    ),
    headlineLarge: TextStyle(
      color: colors.textPrimary,
      fontSize: 28,
      height: 1.12,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    ),
    headlineMedium: TextStyle(
      color: colors.textPrimary,
      fontSize: 22,
      height: 1.18,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.5,
    ),
    titleLarge: TextStyle(
      color: colors.textPrimary,
      fontSize: 19,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.25,
    ),
    titleMedium: TextStyle(
      color: colors.textPrimary,
      fontSize: 16,
      height: 1.25,
      fontWeight: FontWeight.w700,
    ),
    bodyLarge: TextStyle(
      color: colors.textPrimary,
      fontSize: 16,
      height: 1.45,
      fontWeight: FontWeight.w500,
    ),
    bodyMedium: TextStyle(
      color: colors.textSecondary,
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w500,
    ),
    bodySmall: TextStyle(
      color: colors.textSecondary,
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w500,
    ),
    labelLarge: TextStyle(
      color: colors.textPrimary,
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    labelMedium: TextStyle(
      color: colors.textSecondary,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w700,
    ),
    labelSmall: TextStyle(
      color: colors.textSecondary,
      fontSize: 12,
      height: 1.2,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w800,
    ),
  );
}

extension V5ThemeContext on BuildContext {
  V5Colors get v5Colors =>
      Theme.of(this).extension<V5Colors>() ?? V5Colors.light;
}
