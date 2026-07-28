import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 50,
    this.assetPath = officialAssetPath,
    this.onDarkBackground = false,
  });

  static const officialAssetPath = 'assets/branding/logo_hd.png';

  final double size;
  final String? assetPath;
  final bool onDarkBackground;

  @override
  Widget build(BuildContext context) {
    final background = assetPath == null
        ? (onDarkBackground
              ? Colors.white.withValues(alpha: .12)
              : AppColors.orangeSoft)
        : Colors.transparent;
    final mark = assetPath == null
        ? Icon(
            Icons.sports_motorsports_rounded,
            color: AppColors.orange,
            size: size * .56,
          )
        : Image.asset(
            assetPath!,
            fit: BoxFit.contain,
            semanticLabel: 'Logo casque et flamme URPS MK NA',
          );
    return Semantics(
      label: 'Logo casque et flamme',
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: Container(
          key: const Key('brand-logo-slot'),
          width: size,
          height: size,
          padding: assetPath == null
              ? EdgeInsets.all(size * .12)
              : EdgeInsets.zero,
          color: background,
          child: mark,
        ),
      ),
    );
  }
}
