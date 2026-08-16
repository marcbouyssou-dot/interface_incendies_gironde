import 'package:flutter/material.dart';

import '../coordinator/cockpit_view_data.dart';
import '../coordinator/territory_view_data.dart';
import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/coordinator_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/operational_territory_map.dart';
import '../widgets/territory_components.dart';
import '../widgets/v5_controls.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;
import 'coordinator_published_needs.dart';

class CoordinatorCockpitScreen extends StatefulWidget {
  const CoordinatorCockpitScreen({
    super.key,
    required this.publishedNeeds,
    required this.onViewMission,
    required this.onViewLocation,
    required this.onCreateNeed,
  });

  final CoordinatorPublishedNeeds publishedNeeds;
  final ValueChanged<CoordinationNeed> onViewMission;
  final ValueChanged<ResponsePlace> onViewLocation;
  final VoidCallback onCreateNeed;

  @override
  State<CoordinatorCockpitScreen> createState() =>
      _CoordinatorCockpitScreenState();
}

class _CoordinatorCockpitScreenState extends State<CoordinatorCockpitScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<List<ResponsePlace>>? _locations;
  Stream<ResponsibleAccess?>? _access;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (identical(liveData, _liveData)) return;
    _liveData = liveData;
    _missions = liveData.watchMissions();
    _locations = liveData.watchLocations();
    _access = liveData.watchResponsibleAccess();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<CoordinationNeed>>(
      valueListenable: widget.publishedNeeds,
      builder: (context, _, _) => StreamBuilder<List<CoordinationNeed>>(
        stream: _missions,
        builder: (context, missionsSnapshot) =>
            StreamBuilder<List<ResponsePlace>>(
              stream: _locations,
              builder: (context, locationsSnapshot) {
                if (missionsSnapshot.hasError || locationsSnapshot.hasError) {
                  return const _CockpitUnavailable();
                }
                if (!missionsSnapshot.hasData || !locationsSnapshot.hasData) {
                  return const _CockpitLoading();
                }
                return StreamBuilder<ResponsibleAccess?>(
                  stream: _access,
                  builder: (context, accessSnapshot) {
                    if (accessSnapshot.hasError) {
                      return const _CockpitUnavailable();
                    }
                    if (accessSnapshot.connectionState ==
                            ConnectionState.waiting &&
                        !accessSnapshot.hasData) {
                      return const _CockpitLoading();
                    }
                    final locations = locationsSnapshot.data!;
                    final access = accessSnapshot.data;
                    final visibleMissions = missionsVisibleToResponsible(
                      missions: widget.publishedNeeds.mergeWith(
                        missionsSnapshot.data!,
                      ),
                      locations: locations,
                      access: access,
                    );
                    final visibleLocations = access?.isCoordinator == true
                        ? locations
                        : locations
                              .where(
                                (location) =>
                                    access?.canManage(location.id) == true,
                              )
                              .toList(growable: false);
                    final cockpit = CoordinatorCockpitViewData.from(
                      missions: visibleMissions,
                      locations: visibleLocations,
                    );
                    return _CockpitContent(
                      cockpit: cockpit,
                      onViewMission: widget.onViewMission,
                      onViewLocation: widget.onViewLocation,
                      onCreateNeed: widget.onCreateNeed,
                    );
                  },
                );
              },
            ),
      ),
    );
  }
}

class _CockpitContent extends StatefulWidget {
  const _CockpitContent({
    required this.cockpit,
    required this.onViewMission,
    required this.onViewLocation,
    required this.onCreateNeed,
  });

  final CoordinatorCockpitViewData cockpit;
  final ValueChanged<CoordinationNeed> onViewMission;
  final ValueChanged<ResponsePlace> onViewLocation;
  final VoidCallback onCreateNeed;

  @override
  State<_CockpitContent> createState() => _CockpitContentState();
}

class _CockpitContentState extends State<_CockpitContent> {
  CockpitFilter _filter = CockpitFilter.all;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final filteredCockpit = widget.cockpit.filteredBy(_filter);
    return ColoredBox(
      color: colors.canvas,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final centeredPadding = (constraints.maxWidth - 760) / 2;
          final safeHorizontalPadding = centeredPadding > V5Spacing.lg
              ? centeredPadding
              : V5Spacing.lg;
          final mapHeight = constraints.maxWidth >= 760 ? 320.0 : 276.0;
          return CustomScrollView(
            key: const PageStorageKey('coordinator-cockpit'),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  safeHorizontalPadding,
                  V5Spacing.xl,
                  safeHorizontalPadding,
                  V5Spacing.xxxl,
                ),
                sliver: SliverList.list(
                  children: [
                    _CockpitHeader(cockpit: widget.cockpit),
                    const SizedBox(height: V5Spacing.lg),
                    _CockpitFilters(
                      selected: _filter,
                      onSelected: (filter) => setState(() => _filter = filter),
                    ),
                    const SizedBox(height: V5Spacing.xl),
                    OperationalTerritoryMap(
                      points: filteredCockpit.mapPoints,
                      locationCount: filteredCockpit.locationCount,
                      missionCount: filteredCockpit.missionCount,
                      tensionCount: filteredCockpit.tensionCount,
                      onViewLocation: widget.onViewLocation,
                      height: mapHeight,
                    ),
                    const SizedBox(height: V5Spacing.xxl),
                    _PrioritySection(
                      priorities: filteredCockpit.priorities,
                      filter: _filter,
                      onViewMission: widget.onViewMission,
                    ),
                    const SizedBox(height: V5Spacing.xxl),
                    _AlertsSection(
                      alerts: widget.cockpit.alerts,
                      onViewMission: widget.onViewMission,
                    ),
                    const SizedBox(height: V5Spacing.xxl),
                    _OperationalSummary(cockpit: filteredCockpit),
                    const SizedBox(height: V5Spacing.xxl),
                    _RecentActivitySection(
                      activity: widget.cockpit.recentActivity,
                      onViewMission: widget.onViewMission,
                    ),
                    const SizedBox(height: V5Spacing.xxl),
                    _QuickActions(
                      primaryMission:
                          filteredCockpit.priorities.firstOrNull?.mission,
                      onViewMission: widget.onViewMission,
                      onCreateNeed: widget.onCreateNeed,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CockpitFilters extends StatelessWidget {
  const _CockpitFilters({required this.selected, required this.onSelected});

  final CockpitFilter selected;
  final ValueChanged<CockpitFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      container: true,
      label: 'Filtres rapides du cockpit',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final columns = textScale >= 1.6
              ? 1
              : constraints.maxWidth >= 620
              ? 4
              : 2;
          final itemWidth =
              (constraints.maxWidth - V5Spacing.xs * (columns - 1)) / columns;
          return Wrap(
            key: const Key('cockpit-filters'),
            spacing: V5Spacing.xs,
            runSpacing: V5Spacing.xs,
            children: [
              for (final filter in CockpitFilter.values)
                SizedBox(
                  width: itemWidth,
                  height: textScale >= 1.6 ? null : 44,
                  child: ChoiceChip(
                    key: Key('cockpit-filter-${filter.name}'),
                    label: SizedBox(
                      width: double.infinity,
                      child: Text(filter.label, textAlign: TextAlign.center),
                    ),
                    selected: selected == filter,
                    onSelected: (_) => onSelected(filter),
                    showCheckmark: true,
                    selectedColor: colors.infoContainer,
                    side: BorderSide(
                      color: selected == filter ? colors.info : colors.outline,
                    ),
                    labelStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: selected == filter
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CockpitHeader extends StatelessWidget {
  const _CockpitHeader({required this.cockpit});

  final CoordinatorCockpitViewData cockpit;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final statusColor = territoryStatusColor(cockpit.globalStatus, colors);
    final statusIcon = switch (cockpit.globalStatus) {
      TerritoryOperationalStatus.stable => Icons.check_circle_rounded,
      TerritoryOperationalStatus.watch => Icons.error_rounded,
      TerritoryOperationalStatus.critical => Icons.warning_rounded,
    };
    return Semantics(
      container: true,
      liveRegion: true,
      label:
          '${cockpit.globalStateLabel}. ${cockpit.territoryName}. Situation actualisée à ${cockpit.refreshedAtLabel}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(statusIcon, color: statusColor, size: 22),
                ),
                const SizedBox(width: V5Spacing.xs),
                Expanded(
                  child: Text(
                    cockpit.globalStateLabel,
                    key: const Key('cockpit-global-state'),
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: V5Spacing.xs),
            Text(
              cockpit.territoryName,
              key: const Key('cockpit-territory-name'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: V5Spacing.sm),
            Text(
              'Situation actualisée · ${cockpit.refreshedAtLabel}',
              key: const Key('cockpit-refreshed-at'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrioritySection extends StatelessWidget {
  const _PrioritySection({
    required this.priorities,
    required this.filter,
    required this.onViewMission,
  });

  final List<CockpitPriority> priorities;
  final CockpitFilter filter;
  final ValueChanged<CoordinationNeed> onViewMission;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('cockpit-priorities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (priorities.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.warning_rounded,
                  color: context.v5Colors.danger,
                  size: 22,
                ),
              ),
              const SizedBox(width: V5Spacing.xs),
              Expanded(
                child: Text(
                  '${priorities.length} action${priorities.length > 1 ? 's' : ''} prioritaire${priorities.length > 1 ? 's' : ''}',
                  key: const Key('cockpit-priority-title'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: context.v5Colors.danger,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: V5Spacing.sm),
        if (priorities.isEmpty)
          _NoPriority(filter: filter)
        else
          for (var index = 0; index < priorities.length; index++) ...[
            _PriorityCard(
              index: index,
              priority: priorities[index],
              onViewMission: () => onViewMission(priorities[index].mission),
            ),
            if (index < priorities.length - 1)
              const SizedBox(height: V5Spacing.sm),
          ],
      ],
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.index,
    required this.priority,
    required this.onViewMission,
  });

  final int index;
  final CockpitPriority priority;
  final VoidCallback onViewMission;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final status = priority.mission.status == NeedStatus.critical
        ? TerritoryOperationalStatus.critical
        : TerritoryOperationalStatus.watch;
    final statusColor = territoryStatusColor(status, colors);
    final stack = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final details = Semantics(
      label:
          '${priority.locationLabel}. ${priority.needLabel}. '
          '${priority.coverageLabel}. ${priority.timingLabel}. '
          'Échéance ${priority.timeHorizon.label}.',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_rounded, color: statusColor, size: 21),
            const SizedBox(width: V5Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    priority.locationLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: V5Spacing.xxs),
                  Text(
                    priority.operationalDetailLabel,
                    key: Key('cockpit-priority-$index-detail'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: V5Spacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      key: Key('cockpit-priority-$index-horizon'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: V5Spacing.xs,
                        vertical: V5Spacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(V5Radius.pill),
                      ),
                      child: Text(
                        priority.timeHorizon.label,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final action = TextButton(
      key: Key('cockpit-priority-$index-view'),
      onPressed: onViewMission,
      style: TextButton.styleFrom(
        foregroundColor: CoordinatorIdentity.of(context).accent,
        minimumSize: const Size(44, 44),
      ),
      child: const Text('Voir la mission'),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(
        V5Spacing.md,
        V5Spacing.md,
        V5Spacing.sm,
        V5Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: V5Elevation.level1(colors),
      ),
      child: stack
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: V5Spacing.xs),
                action,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: details),
                const SizedBox(width: V5Spacing.xs),
                action,
              ],
            ),
    );
  }
}

class _NoPriority extends StatelessWidget {
  const _NoPriority({required this.filter});

  final CockpitFilter filter;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final isUnfiltered = filter == CockpitFilter.all;
    final title = isUnfiltered
        ? 'Aucune action urgente'
        : 'Aucune tension pour ce filtre';
    final detail = isUnfiltered
        ? 'Le territoire est actuellement couvert.'
        : 'Aucune mission ne nécessite une action dans cette vue.';
    return Semantics(
      label: '$title. $detail',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(V5Spacing.md),
          decoration: BoxDecoration(
            color: colors.successContainer,
            borderRadius: BorderRadius.circular(V5Radius.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, color: colors.success),
              const SizedBox(width: V5Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: V5Spacing.xxs),
                    Text(
                      detail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.alerts, required this.onViewMission});

  final List<CockpitAlert> alerts;
  final ValueChanged<CoordinationNeed> onViewMission;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('cockpit-alerts'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Alertes', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: V5Spacing.sm),
        if (alerts.isEmpty)
          Semantics(
            label: 'Aucune alerte active.',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    color: context.v5Colors.success,
                    size: 20,
                  ),
                  const SizedBox(width: V5Spacing.sm),
                  Text(
                    'Aucune alerte active',
                    key: const Key('cockpit-alerts-empty'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.v5Colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (var index = 0; index < alerts.length; index++) ...[
            _AlertTile(
              index: index,
              alert: alerts[index],
              onTap: () => onViewMission(alerts[index].mission),
            ),
            if (index < alerts.length - 1) const SizedBox(height: V5Spacing.sm),
          ],
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({
    required this.index,
    required this.alert,
    required this.onTap,
  });

  final int index;
  final CockpitAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (color, container, icon) = switch (alert.level) {
      CockpitAlertLevel.urgent => (
        colors.danger,
        colors.dangerContainer,
        Icons.warning_rounded,
      ),
      CockpitAlertLevel.watch => (
        colors.warning,
        colors.warningContainer,
        Icons.error_outline_rounded,
      ),
      CockpitAlertLevel.information => (
        colors.info,
        colors.infoContainer,
        Icons.info_outline_rounded,
      ),
    };
    return Semantics(
      button: true,
      label: '${alert.accessibilityLabel} Ouvrir la mission.',
      child: ExcludeSemantics(
        child: Material(
          color: container,
          borderRadius: BorderRadius.circular(V5Radius.card),
          child: InkWell(
            key: Key('cockpit-alert-$index'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(V5Radius.card),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: V5Spacing.md,
                  vertical: V5Spacing.sm,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, color: color, size: 21),
                    const SizedBox(width: V5Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            alert.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: V5Spacing.xxs),
                          Text(
                            '${alert.locationLabel} · ${alert.detail}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: V5Spacing.xs),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OperationalSummary extends StatelessWidget {
  const _OperationalSummary({required this.cockpit});

  final CoordinatorCockpitViewData cockpit;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      (
        cockpit.missionCount == 1 ? 'mission active' : 'missions actives',
        '${cockpit.missionCount}',
      ),
      (
        cockpit.criticalMissions == 1
            ? 'mission critique'
            : 'missions critiques',
        '${cockpit.criticalMissions}',
      ),
      ('couverture globale', '${cockpit.coveragePercent} %'),
      ('profession la plus tendue', cockpit.mostNeededProfession),
    ];
    final stack = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    return Column(
      key: const Key('cockpit-operational-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Résumé opérationnel',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: V5Spacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = stack
                ? 1
                : constraints.maxWidth >= 640
                ? 4
                : 2;
            final cardWidth =
                (constraints.maxWidth - V5Spacing.sm * (columns - 1)) / columns;
            return Wrap(
              spacing: V5Spacing.sm,
              runSpacing: V5Spacing.sm,
              children: [
                for (var index = 0; index < metrics.length; index++)
                  SizedBox(
                    width: cardWidth,
                    child: _MetricCard(
                      label: metrics[index].$1,
                      value: metrics[index].$2,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection({
    required this.activity,
    required this.onViewMission,
  });

  final List<CockpitActivity> activity;
  final ValueChanged<CoordinationNeed> onViewMission;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      key: const Key('cockpit-recent-activity'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activité récente',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: V5Spacing.sm),
        if (activity.isEmpty)
          Text(
            'Aucune activité récente',
            key: const Key('cockpit-activity-empty'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          )
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: BorderRadius.circular(V5Radius.card),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              children: [
                for (var index = 0; index < activity.length; index++) ...[
                  _ActivityTile(
                    index: index,
                    activity: activity[index],
                    onTap: () => onViewMission(activity[index].mission),
                  ),
                  if (index < activity.length - 1)
                    Divider(height: 1, color: colors.outline),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.index,
    required this.activity,
    required this.onTap,
  });

  final int index;
  final CockpitActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (color, icon) = switch (activity.kind) {
      CockpitActivityKind.published => (
        colors.info,
        Icons.add_circle_outline_rounded,
      ),
      CockpitActivityKind.updated => (colors.info, Icons.sync_rounded),
      CockpitActivityKind.cancelled => (colors.danger, Icons.cancel_outlined),
    };
    return Semantics(
      button: true,
      label: '${activity.accessibilityLabel} Ouvrir la mission.',
      child: ExcludeSemantics(
        child: InkWell(
          key: Key('cockpit-activity-$index'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(V5Radius.card),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: V5Spacing.md,
                vertical: V5Spacing.sm,
              ),
              child: Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: V5Spacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${activity.timeLabel} · ${activity.locationLabel}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.textSecondary),
                        ),
                        const SizedBox(height: V5Spacing.xxs),
                        Text(
                          activity.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: V5Spacing.xs),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      label: '$label : $value',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(V5Spacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(V5Radius.section),
            border: Border.all(color: colors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: CoordinatorIdentity.of(context).accent,
                ),
              ),
              const SizedBox(height: V5Spacing.xs),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.primaryMission,
    required this.onViewMission,
    required this.onCreateNeed,
  });

  final CoordinationNeed? primaryMission;
  final ValueChanged<CoordinationNeed> onViewMission;
  final VoidCallback onCreateNeed;

  @override
  Widget build(BuildContext context) {
    final stack = MediaQuery.textScalerOf(context).scale(1) >= 1.6;
    final view = V5Button(
      key: const Key('cockpit-view-mission'),
      expanded: true,
      icon: Icons.play_arrow_rounded,
      label: 'Traiter la priorité',
      backgroundColor: CoordinatorIdentity.of(context).accent,
      foregroundColor: CoordinatorIdentity.of(context).onAccent,
      onPressed: primaryMission == null
          ? null
          : () => onViewMission(primaryMission!),
    );
    final create = V5Button(
      key: const Key('cockpit-create-need'),
      expanded: true,
      icon: Icons.add_circle_outline_rounded,
      label: 'Créer un besoin',
      tone: V5ButtonTone.secondary,
      onPressed: onCreateNeed,
    );
    return Column(
      key: const Key('cockpit-quick-actions'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions rapides', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: V5Spacing.sm),
        if (stack) ...[
          view,
          const SizedBox(height: V5Spacing.sm),
          create,
        ] else
          Row(
            children: [
              Expanded(child: view),
              const SizedBox(width: V5Spacing.sm),
              Expanded(child: create),
            ],
          ),
      ],
    );
  }
}

class _CockpitLoading extends StatelessWidget {
  const _CockpitLoading();

  @override
  Widget build(BuildContext context) => Center(
    child: V5ActivityIndicator(
      size: 22,
      color: CoordinatorIdentity.of(context).accent,
    ),
  );
}

class _CockpitUnavailable extends StatelessWidget {
  const _CockpitUnavailable();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: Text(
        'Le cockpit opérationnel est temporairement indisponible.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
