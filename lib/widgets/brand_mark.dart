import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/v5_foundation.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 50,
    this.assetPath = officialAssetPath,
    this.onDarkBackground = false,
  });

  static const officialAssetPath = AppIdentity.pictogramAsset;

  final double size;
  final String? assetPath;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final mark = assetPath == null
        ? Icon(
            Icons.health_and_safety_rounded,
            color: V5Colors.light.accent,
            size: size * .56,
          )
        : Image.asset(
            assetPath!,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            excludeFromSemantics: true,
          );
    return Semantics(
      label: 'MobSanté',
      image: true,
      child: ExcludeSemantics(
        child: SizedBox.square(
          key: const Key('brand-logo-slot'),
          dimension: size,
          child: assetPath == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: onDarkBackground
                        ? Colors.white.withValues(alpha: .12)
                        : V5Colors.light.warningContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(size * .12),
                    child: mark,
                  ),
                )
              : mark,
        ),
      ),
    );
  }
}
