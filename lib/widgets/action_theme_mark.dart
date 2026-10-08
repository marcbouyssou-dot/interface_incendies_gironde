import 'package:flutter/material.dart';

import 'brand_mark.dart';

/// Visual theme for an Action. An absent or unknown key stays neutral.
String? actionThemeLabel(String? themeKey) => switch (themeKey) {
  'fire' => 'Thème feu',
  'flood' => 'Thème inondation',
  'heat' => 'Thème chaleur',
  'storm' => 'Thème tempête',
  'health_support' => 'Thème soutien sanitaire',
  _ => null,
};

IconData? _themeIcon(String? themeKey) => switch (themeKey) {
  'flood' => Icons.water_outlined,
  'heat' => Icons.wb_sunny_outlined,
  'storm' => Icons.thunderstorm_outlined,
  'health_support' => Icons.health_and_safety_outlined,
  _ => null,
};

class ActionThemeMark extends StatelessWidget {
  const ActionThemeMark({super.key, required this.themeKey, this.size = 44});

  static const fireAssetPath = 'assets/branding/mobilization_flame.png';

  final String? themeKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = _themeIcon(themeKey);
    final label = actionThemeLabel(themeKey);
    return Semantics(
      label: label == null ? 'Action MobSanté' : 'Action MobSanté, $label',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          key: Key('action-theme-${label == null ? 'neutral' : themeKey}'),
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: BrandMark(size: size)),
              if (themeKey == 'fire')
                Positioned(
                  top: 0,
                  right: 0,
                  width: size * .5,
                  height: size * .5,
                  child: Image.asset(
                    fireAssetPath,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                )
              else if (icon != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(icon, size: size * .45),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
