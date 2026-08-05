import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';

enum DecisionHeaderState { noUpdates, newMissions, urgentMission, loading }

class DecisionHeader extends StatelessWidget {
  const DecisionHeader({
    super.key,
    required this.state,
    this.verdict,
    this.secondary,
    this.verdictColor,
    this.showSecondary = true,
  });

  final DecisionHeaderState state;
  final String? verdict;
  final String? secondary;
  final Color? verdictColor;
  final bool showSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    if (state == DecisionHeaderState.loading) {
      return const _DecisionHeaderLoading();
    }

    final content = _contentFor(state);
    final resolvedVerdictColor =
        verdictColor ??
        switch (state) {
          DecisionHeaderState.urgentMission => colors.danger,
          DecisionHeaderState.newMissions => colors.textPrimary,
          DecisionHeaderState.noUpdates => colors.textPrimary,
          DecisionHeaderState.loading => colors.textPrimary,
        };

    return Semantics(
      container: true,
      liveRegion: state != DecisionHeaderState.noUpdates,
      label: showSecondary
          ? '${verdict ?? content.$1}. ${secondary ?? content.$2}'
          : verdict ?? content.$1,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              verdict ?? content.$1,
              key: const Key('decision-header-verdict'),
              style: Theme.of(
                context,
              ).textTheme.headlineLarge?.copyWith(color: resolvedVerdictColor),
            ),
            if (showSecondary) ...[
              const SizedBox(height: V5Spacing.xs),
              Text(
                secondary ?? content.$2,
                key: const Key('decision-header-secondary'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, String) _contentFor(DecisionHeaderState state) => switch (state) {
    DecisionHeaderState.noUpdates => (
      'Rien de nouveau pour l’instant',
      'Nous vous préviendrons dès qu’une mission sera disponible.',
    ),
    DecisionHeaderState.newMissions => (
      'De nouvelles missions sont disponibles',
      'Consultez les besoins et choisissez où aider.',
    ),
    DecisionHeaderState.urgentMission => (
      'Une mission urgente a besoin de vous',
      'Une équipe attend encore des renforts.',
    ),
    DecisionHeaderState.loading => ('', ''),
  };
}

class _DecisionHeaderLoading extends StatelessWidget {
  const _DecisionHeaderLoading();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Chargement des missions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SkeletonLine(
            key: const Key('decision-header-verdict-loading'),
            widthFactor: 0.78,
            height: 30,
            color: colors.surfaceMuted,
          ),
          const SizedBox(height: V5Spacing.sm),
          _SkeletonLine(
            key: const Key('decision-header-secondary-loading'),
            widthFactor: 0.58,
            height: 16,
            color: colors.surfaceMuted,
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({
    super.key,
    required this.widthFactor,
    required this.height,
    required this.color,
  });

  final double widthFactor;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(V5Radius.compact),
        ),
      ),
    );
  }
}
