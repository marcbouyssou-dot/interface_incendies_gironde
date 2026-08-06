import 'package:flutter/material.dart';

import '../models/health_profession.dart';
import '../models/need.dart';
import '../theme/v5_foundation.dart';

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
    return Container(
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: toneContainer,
                  borderRadius: BorderRadius.circular(V5Radius.pill),
                ),
                child: Text(
                  statusLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: toneColor,
                    letterSpacing: 0.1,
                  ),
                ),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(V5Radius.pill),
            child: LinearProgressIndicator(
              value: required == 0
                  ? 1
                  : (registered / required).clamp(0, 1).toDouble(),
              minHeight: 4,
              backgroundColor: colors.surfaceMuted,
              color: toneColor,
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
    );
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
    return Row(
      children: [
        Expanded(
          child: Text(
            profession?.missionLabel ?? professionId,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textPrimary),
          ),
        ),
        const SizedBox(width: V5Spacing.sm),
        Text(
          '$registered / $required',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
