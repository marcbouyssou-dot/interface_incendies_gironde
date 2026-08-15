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
    required this.onCreateNeed,
  });

  final CoordinatorPublishedNeeds publishedNeeds;
  final ValueChanged<CoordinationNeed> onViewMission;
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

class _CockpitContent extends StatelessWidget {
  const _CockpitContent({
    required this.cockpit,
    required this.onViewMission,
    required this.onCreateNeed,
  });

  final CoordinatorCockpitViewData cockpit;
  final ValueChanged<CoordinationNeed> onViewMission;
  final VoidCallback onCreateNeed;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
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
                    _CockpitHeader(cockpit: cockpit),
                    const SizedBox(height: V5Spacing.xl),
                    OperationalTerritoryMap(
                      points: cockpit.mapPoints,
                      height: mapHeight,
                    ),
                    const SizedBox(height: V5Spacing.xxl),
                    _PrioritySection(
                      priorities: cockpit.priorities,
                      onViewMission: onViewMission,
                    ),
                    const SizedBox(height: V5Spacing.xxl),
                    _OperationalSummary(cockpit: cockpit),
                    const SizedBox(height: V5Spacing.xxl),
                    _QuickActions(
                      primaryMission: cockpit.priorities.firstOrNull?.mission,
                      onViewMission: onViewMission,
                      onCreateNeed: onCreateNeed,
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
      label: '${cockpit.territoryName}. ${cockpit.globalStateLabel}.',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              cockpit.territoryName,
              key: const Key('cockpit-territory-name'),
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: V5Spacing.sm),
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
          ],
        ),
      ),
    );
  }
}

class _PrioritySection extends StatelessWidget {
  const _PrioritySection({
    required this.priorities,
    required this.onViewMission,
  });

  final List<CockpitPriority> priorities;
  final ValueChanged<CoordinationNeed> onViewMission;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('cockpit-priorities'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tensions prioritaires',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: V5Spacing.sm),
        if (priorities.isEmpty)
          const _NoPriority()
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
          '${priority.locationLabel}. ${priority.needLabel}. ${priority.timingLabel}.',
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
                    priority.needLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    priority.timingLabel,
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
  const _NoPriority();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      label: 'Aucune tension prioritaire.',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(V5Spacing.md),
          decoration: BoxDecoration(
            color: colors.successContainer,
            borderRadius: BorderRadius.circular(V5Radius.card),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: colors.success),
              const SizedBox(width: V5Spacing.sm),
              Expanded(
                child: Text(
                  'Aucune tension prioritaire',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
      ('Couverture globale', '${cockpit.coveragePercent} %'),
      ('Missions critiques', '${cockpit.criticalMissions}'),
      ('Profession en tension', cockpit.mostNeededProfession),
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
        if (stack)
          for (var index = 0; index < metrics.length; index++) ...[
            _MetricCard(label: metrics[index].$1, value: metrics[index].$2),
            if (index < metrics.length - 1)
              const SizedBox(height: V5Spacing.sm),
          ]
        else
          Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(
                  child: _MetricCard(
                    label: metrics[index].$1,
                    value: metrics[index].$2,
                  ),
                ),
                if (index < metrics.length - 1)
                  const SizedBox(width: V5Spacing.sm),
              ],
            ],
          ),
      ],
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
      icon: Icons.visibility_outlined,
      label: 'Voir mission',
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
