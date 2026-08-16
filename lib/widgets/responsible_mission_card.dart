import 'package:flutter/material.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../theme/v5_foundation.dart';
import 'operation_context_badge.dart';

enum ResponsibleMissionTone { urgent, attention, controlled, covered, past }

class ResponsibleMissionCard extends StatelessWidget {
  const ResponsibleMissionCard({
    super.key,
    required this.need,
    required this.tone,
    required this.statusLabel,
    this.actions = const [],
  });

  final CoordinationNeed need;
  final ResponsibleMissionTone tone;
  final String statusLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final required = need.professionQuotas.requiredTotal;
    final registered = need.professionQuotas.registeredTotal;
    final toneColor = switch (tone) {
      ResponsibleMissionTone.urgent => colors.danger,
      ResponsibleMissionTone.attention ||
      ResponsibleMissionTone.controlled => colors.accent,
      ResponsibleMissionTone.covered => colors.success,
      ResponsibleMissionTone.past => colors.textSecondary,
    };
    final toneContainer = switch (tone) {
      ResponsibleMissionTone.urgent => colors.dangerContainer,
      ResponsibleMissionTone.attention ||
      ResponsibleMissionTone.controlled => colors.warningContainer,
      ResponsibleMissionTone.covered => colors.successContainer,
      ResponsibleMissionTone.past => colors.surfaceMuted,
    };
    final quotas = need.professionQuotas.values
        .where((quota) => quota.required > 0)
        .toList(growable: false);
    final coverage = required == 0
        ? 1.0
        : (registered / required).clamp(0, 1).toDouble();
    final useStackedLayout = MediaQuery.textScalerOf(context).scale(12) >= 18;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: _semanticSummary(quotas, registered, required),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 14),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(V5Radius.card),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.035),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MissionOperationContextBadge(mobilizationId: need.mobilizationId),
            if (need.mobilizationId != null)
              const SizedBox(height: V5Spacing.xs),
            if (useStackedLayout) ...[
              Text(need.place, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: V5Spacing.xs),
              _MissionStatusBadge(
                label: statusLabel,
                foreground: toneColor,
                background: toneContainer,
              ),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      need.place,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: V5Spacing.sm),
                  _MissionStatusBadge(
                    label: statusLabel,
                    foreground: toneColor,
                    background: toneContainer,
                  ),
                ],
              ),
            const SizedBox(height: V5Spacing.xs),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: colors.textSecondary,
                ),
                const SizedBox(width: V5Spacing.xs),
                Expanded(
                  child: Text(
                    '${need.date} · ${need.time}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            if (quotas.isNotEmpty) ...[
              const SizedBox(height: V5Spacing.md),
              for (var index = 0; index < quotas.length; index++) ...[
                _ProfessionProgress(
                  professionId: quotas[index].professionId,
                  registered: quotas[index].registered,
                  required: quotas[index].required,
                ),
                if (index < quotas.length - 1)
                  const SizedBox(height: V5Spacing.xs),
              ],
            ],
            const SizedBox(height: V5Spacing.md),
            Semantics(
              label: 'Progression du besoin',
              value: _coverageLabel(registered, required),
              child: ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(V5Radius.pill),
                  child: LinearProgressIndicator(
                    value: coverage,
                    minHeight: 4,
                    backgroundColor: colors.surfaceMuted,
                    color: toneColor,
                  ),
                ),
              ),
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: V5Spacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: V5Spacing.xs,
                  runSpacing: V5Spacing.xxs,
                  children: actions,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _semanticSummary(
    List<ProfessionQuota> quotas,
    int registered,
    int required,
  ) {
    final professions = quotas
        .map(
          (quota) =>
              HealthProfessionRegistry.byId(quota.professionId)?.missionLabel ??
              quota.professionId,
        )
        .join(', ');
    final professionLabel = professions.isEmpty
        ? 'sans profession demandée'
        : 'pour $professions';
    return 'Besoin $professionLabel, ${need.place}, ${need.date}, '
        '${need.time}. État : $statusLabel. '
        '${_coverageLabel(registered, required)}.';
  }

  String _coverageLabel(int registered, int required) {
    if (required == 0) return 'Aucun poste demandé';
    final remaining = (required - registered).clamp(0, required);
    final filled = registered == 1
        ? '1 poste pourvu'
        : '$registered postes pourvus';
    final open = remaining == 1
        ? '1 poste à couvrir'
        : '$remaining postes à couvrir';
    return '$filled sur $required, $open';
  }
}

class _ProfessionProgress extends StatelessWidget {
  const _ProfessionProgress({
    required this.professionId,
    required this.registered,
    required this.required,
  });

  final String professionId;
  final int registered;
  final int required;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final profession = HealthProfessionRegistry.byId(professionId);
    final useStackedLayout = MediaQuery.textScalerOf(context).scale(12) >= 18;
    final professionLabel = profession?.missionLabel ?? professionId;
    final count = Text(
      '$registered / $required',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: colors.textPrimary,
        fontWeight: FontWeight.w800,
      ),
    );
    if (useStackedLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            professionLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: V5Spacing.xxs),
          count,
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Text(
            professionLabel,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(width: V5Spacing.sm),
        count,
      ],
    );
  }
}

class _MissionStatusBadge extends StatelessWidget {
  const _MissionStatusBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(V5Radius.pill),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: foreground, letterSpacing: 0.1),
    ),
  );
}
