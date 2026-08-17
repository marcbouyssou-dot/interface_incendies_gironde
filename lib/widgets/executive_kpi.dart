import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';

enum ExecutiveKpiTone { neutral, success, warning, critical }

class ExecutiveKpi extends StatelessWidget {
  const ExecutiveKpi({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.tone = ExecutiveKpiTone.neutral,
    this.semanticLabel,
  });

  final String value;
  final String label;
  final IconData icon;
  final ExecutiveKpiTone tone;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (foreground, background) = switch (tone) {
      ExecutiveKpiTone.neutral => (colors.textPrimary, colors.surfaceElevated),
      ExecutiveKpiTone.success => (colors.success, colors.successContainer),
      ExecutiveKpiTone.warning => (colors.warning, colors.warningContainer),
      ExecutiveKpiTone.critical => (colors.danger, colors.dangerContainer),
    };
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final height = (136 + ((scale - 1).clamp(0, 2) * 128)).toDouble();
    return SizedBox(
      height: height,
      child: Semantics(
        container: true,
        label: semanticLabel ?? '$value, $label',
        child: ExcludeSemantics(
          child: Container(
            padding: const EdgeInsets.all(V5Spacing.md),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(V5Radius.section),
              border: Border.all(color: foreground.withValues(alpha: 0.16)),
              boxShadow: V5Elevation.level1(colors),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: foreground),
                const SizedBox(height: V5Spacing.xs),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: V5Spacing.xxs),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class OperationKpi extends ExecutiveKpi {
  const OperationKpi({
    super.key,
    required int count,
    super.label = 'opérations actives',
  }) : super(value: '$count', icon: Icons.domain_rounded);
}

class CoverageKpi extends ExecutiveKpi {
  const CoverageKpi({
    super.key,
    required int? percent,
    super.label = 'couverture globale',
    super.tone,
    super.semanticLabel,
  }) : super(
         value: percent == null ? '—' : '$percent %',
         icon: Icons.donut_large_rounded,
       );
}

class CriticalKpi extends ExecutiveKpi {
  const CriticalKpi({
    super.key,
    required int count,
    super.label = 'missions critiques',
  }) : super(
         value: '$count',
         icon: Icons.warning_amber_rounded,
         tone: count == 0
             ? ExecutiveKpiTone.success
             : ExecutiveKpiTone.critical,
       );
}

class ProfessionKpi extends ExecutiveKpi {
  const ProfessionKpi({
    super.key,
    required int count,
    super.label = 'professionnels mobilisés',
  }) : super(value: '$count', icon: Icons.groups_rounded);
}
