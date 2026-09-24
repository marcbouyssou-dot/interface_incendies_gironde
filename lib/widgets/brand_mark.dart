import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/v5_foundation.dart';

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
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned.fill(
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
              if (assetPath != null && showMobilizationSymbol)
                Positioned(
                  top: 0,
                  right: 0,
                  width: size * .5,
                  height: size * .5,
                  child: Image.asset(
                    AppIdentity.mobilizationSymbolAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    excludeFromSemantics: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
