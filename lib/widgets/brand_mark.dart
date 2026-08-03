import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 50,
    this.assetPath = officialAssetPath,
    this.onDarkBackground = false,
    this.showMobilizationSymbol = true,
  });

  static const officialAssetPath = AppIdentity.pictogramAsset;

  final double size;
  final String? assetPath;
  final bool onDarkBackground;
  final bool showMobilizationSymbol;

  @override
  Widget build(BuildContext context) {
    final background = assetPath == null
        ? (onDarkBackground
              ? Colors.white.withValues(alpha: .12)
              : AppColors.orangeSoft)
        : Colors.transparent;
    final mark = assetPath == null
        ? Icon(
            Icons.health_and_safety_rounded,
            color: AppColors.orange,
            size: size * .56,
          )
        : Image.asset(
            assetPath!,
            fit: BoxFit.contain,
            semanticLabel: 'Logo MobSanté',
          );
    return Semantics(
      label: 'Logo MobSanté',
      image: true,
      child: SizedBox.square(
        key: const Key('brand-logo-slot'),
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: assetPath == null
                      ? EdgeInsets.all(size * .12)
                      : EdgeInsets.zero,
                  child: mark,
                ),
              ),
            ),
            if (assetPath != null && showMobilizationSymbol)
              Positioned(
                top: -size * .08,
                right: -size * .06,
                width: size * .48,
                height: size * .54,
                child: Transform.scale(
                  scale: 1.72,
                  child: Image.asset(
                    AppIdentity.mobilizationSymbolAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'Symbole de mobilisation',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
