import 'package:flutter/material.dart';

import '../coordinator/territory_view_data.dart';
import '../models/need.dart';
import '../theme/coordinator_identity.dart';
import '../theme/v5_foundation.dart';

class TerritoryVerdict extends StatelessWidget {
  const TerritoryVerdict({
    super.key,
    required this.verdict,
    required this.contextLine,
    required this.stable,
  });

  final String verdict;
  final String contextLine;
  final bool stable;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final identity = CoordinatorIdentity.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$verdict $contextLine',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stable) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 23,
                      color: colors.success,
                    ),
                  ),
                  const SizedBox(width: V5Spacing.sm),
                ],
                Expanded(
                  child: Text(
                    verdict,
                    key: const Key('territory-verdict'),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: colors.textPrimary,
                      fontSize: 34,
                      height: 1.08,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: V5Spacing.sm),
            Text(
              contextLine,
              key: const Key('territory-verdict-context'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: identity.accent,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TerritoryStatusRow extends StatelessWidget {
  const TerritoryStatusRow({
    super.key,
    required this.label,
    required this.value,
    this.status,
    this.icon,
  });

  final String label;
  final String value;
  final TerritoryOperationalStatus? status;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final identity = CoordinatorIdentity.of(context);
    final accent = status == null
        ? identity.accent
        : territoryStatusColor(status!, colors);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: V5Spacing.sm),
          ],
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: V5Spacing.md),
          Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SectorStatusCard extends StatelessWidget {
  const SectorStatusCard({
    super.key,
    required this.sector,
    this.onView,
    this.trend,
  });

  final TerritorySectorViewData sector;
  final VoidCallback? onView;
  final String? trend;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final identity = CoordinatorIdentity.of(context);
    final statusColor = territoryStatusColor(sector.status, colors);
    final statusContainer = territoryStatusContainer(sector.status, colors);
    return Container(
      key: Key('sector-status-${sector.group.name}'),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
        boxShadow: V5Elevation.level1(colors),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  sector.group.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: V5Spacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusContainer,
                  borderRadius: BorderRadius.circular(V5Radius.pill),
                ),
                child: Text(
                  sector.status.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: V5Spacing.sm),
          TerritoryStatusRow(
            label: 'Besoins actifs',
            value: '${sector.activeNeeds}',
            icon: Icons.assignment_outlined,
            status: sector.status,
          ),
          TerritoryStatusRow(
            label: 'Non couverts',
            value: '${sector.uncoveredNeeds}',
            icon: Icons.shield_outlined,
            status: sector.status,
          ),
          TerritoryStatusRow(
            label: 'Prochaine échéance',
            value: sector.nextDeadline,
            icon: Icons.schedule_rounded,
            status: sector.status,
          ),
          if (trend != null)
            TerritoryStatusRow(
              label: 'Tendance',
              value: trend!,
              icon: Icons.trending_flat_rounded,
              status: sector.status,
            ),
          if (onView != null) ...[
            const SizedBox(height: V5Spacing.xxs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onView,
                style: TextButton.styleFrom(
                  foregroundColor: identity.accent,
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('Voir'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OperationalSummary extends StatelessWidget {
  const OperationalSummary({
    super.key,
    required this.coveredCenters,
    required this.activeNeeds,
    required this.mobilizedProfessionals,
  });

  final int coveredCenters;
  final int activeNeeds;
  final int mobilizedProfessionals;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      key: const Key('coordinator-operational-summary'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: V5Spacing.lg,
        vertical: V5Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      child: Column(
        children: [
          TerritoryStatusRow(
            label: 'Centres couverts',
            value: '$coveredCenters',
            icon: Icons.check_circle_outline_rounded,
            status: TerritoryOperationalStatus.stable,
          ),
          Divider(height: 1, thickness: 0.5, color: colors.outline),
          TerritoryStatusRow(
            label: 'Besoins actifs',
            value: '$activeNeeds',
            icon: Icons.assignment_outlined,
          ),
          Divider(height: 1, thickness: 0.5, color: colors.outline),
          TerritoryStatusRow(
            label: 'Professionnels mobilisés',
            value: '$mobilizedProfessionals',
            icon: Icons.people_outline_rounded,
          ),
        ],
      ),
    );
  }
}

Color territoryStatusColor(
  TerritoryOperationalStatus status,
  V5Colors colors,
) => switch (status) {
  TerritoryOperationalStatus.stable => colors.success,
  TerritoryOperationalStatus.watch => colors.warning,
  TerritoryOperationalStatus.critical => colors.danger,
};

Color territoryStatusContainer(
  TerritoryOperationalStatus status,
  V5Colors colors,
) => switch (status) {
  TerritoryOperationalStatus.stable => colors.successContainer,
  TerritoryOperationalStatus.watch => colors.warningContainer,
  TerritoryOperationalStatus.critical => colors.dangerContainer,
};
