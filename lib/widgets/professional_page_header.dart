import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../theme/v5_foundation.dart';
import 'brand_mark.dart';

class ProfessionalPageHeader extends StatelessWidget {
  const ProfessionalPageHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const BrandMark(size: 36),
            const SizedBox(width: V5Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppIdentity.productName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'La mobilisation santé, simplement.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: V5Spacing.lg),
        Text(
          title,
          key: const Key('professional-page-title'),
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if (subtitle case final value? when value.trim().isNotEmpty) ...[
          const SizedBox(height: V5Spacing.xs),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );
  }
}
