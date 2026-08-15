import 'package:flutter/material.dart';

import '../coordinator/territory_view_data.dart';
import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/coordinator_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/territory_components.dart';
import '../widgets/professional_page_header.dart';
import 'coordinator_overview_screen.dart';
import 'coordinator_published_needs.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;

enum _TerritoryFilter { all, watch, critical, stable }

extension on _TerritoryFilter {
  String get label => switch (this) {
    _TerritoryFilter.all => 'Tous',
    _TerritoryFilter.watch => 'À surveiller',
    _TerritoryFilter.critical => 'Critiques',
    _TerritoryFilter.stable => 'Stables',
  };
}

class CoordinatorTerritoryScreen extends StatefulWidget {
  const CoordinatorTerritoryScreen({super.key, required this.publishedNeeds});

  final CoordinatorPublishedNeeds publishedNeeds;

  @override
  State<CoordinatorTerritoryScreen> createState() =>
      _CoordinatorTerritoryScreenState();
}

class _CoordinatorTerritoryScreenState
    extends State<CoordinatorTerritoryScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<List<ResponsePlace>>? _locations;
  Stream<ResponsibleAccess?>? _access;
  _TerritoryFilter _filter = _TerritoryFilter.all;

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
                  return const CoordinatorDataUnavailable(
                    message: 'La lecture territoriale est indisponible.',
                  );
                }
                if (!missionsSnapshot.hasData || !locationsSnapshot.hasData) {
                  return const CoordinatorLoadingState();
                }
                return StreamBuilder<ResponsibleAccess?>(
                  stream: _access,
                  builder: (context, accessSnapshot) {
                    if (accessSnapshot.hasError) {
                      return const CoordinatorDataUnavailable(
                        message:
                            'Les autorisations ne peuvent pas être vérifiées.',
                      );
                    }
                    final visibleMissions = missionsVisibleToResponsible(
                      missions: widget.publishedNeeds.mergeWith(
                        missionsSnapshot.data!,
                      ),
                      locations: locationsSnapshot.data!,
                      access: accessSnapshot.data,
                    );
                    final visibleLocations =
                        accessSnapshot.data?.isCoordinator == true
                        ? locationsSnapshot.data!
                        : locationsSnapshot.data!
                              .where(
                                (location) =>
                                    accessSnapshot.data?.canManage(
                                      location.id,
                                    ) ==
                                    true,
                              )
                              .toList(growable: false);
                    final territory = CoordinatorTerritoryViewData.from(
                      missions: visibleMissions,
                      locations: visibleLocations,
                    );
                    return _TerritoryContent(
                      territory: territory,
                      filter: _filter,
                      onFilterChanged: (filter) =>
                          setState(() => _filter = filter),
                    );
                  },
                );
              },
            ),
      ),
    );
  }
}

class _TerritoryContent extends StatelessWidget {
  const _TerritoryContent({
    required this.territory,
    required this.filter,
    required this.onFilterChanged,
  });

  final CoordinatorTerritoryViewData territory;
  final _TerritoryFilter filter;
  final ValueChanged<_TerritoryFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final sectors = territory.sectors
        .where((sector) => _matchesFilter(sector, filter))
        .toList(growable: false);
    return ColoredBox(
      color: colors.canvas,
      child: CustomScrollView(
        key: const PageStorageKey('coordinator-territory'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MobSantePageHeader(title: 'Territoire'),
                      const SizedBox(height: V5Spacing.lg),
                      Text(
                        'Aujourd’hui et à venir',
                        key: const Key('coordinator-territory-period'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: V5Spacing.sm),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final option in _TerritoryFilter.values) ...[
                              _TerritoryFilterChip(
                                filter: option,
                                selected: filter == option,
                                onSelected: () => onFilterChanged(option),
                              ),
                              if (option != _TerritoryFilter.values.last)
                                const SizedBox(width: V5Spacing.xs),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (sectors.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: CoordinatorDataUnavailable(
                message:
                    'Aucun secteur ne correspond à ce filtre aujourd’hui ou à venir.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList.separated(
                key: const Key('coordinator-territory-list'),
                itemCount: sectors.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: V5Spacing.sm),
                itemBuilder: (context, index) => Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: SectorStatusCard(sector: sectors[index]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TerritoryFilterChip extends StatelessWidget {
  const _TerritoryFilterChip({
    required this.filter,
    required this.selected,
    required this.onSelected,
  });

  final _TerritoryFilter filter;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final identity = CoordinatorIdentity.of(context);
    return ChoiceChip(
      key: Key('coordinator-territory-filter-${filter.name}'),
      label: Text(filter.label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: identity.accent,
      backgroundColor: colors.surfaceElevated,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V5Radius.pill),
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? identity.onAccent : colors.textSecondary,
      ),
    );
  }
}

bool _matchesFilter(
  TerritorySectorViewData sector,
  _TerritoryFilter filter,
) => switch (filter) {
  _TerritoryFilter.all => true,
  _TerritoryFilter.watch => sector.status == TerritoryOperationalStatus.watch,
  _TerritoryFilter.critical =>
    sector.status == TerritoryOperationalStatus.critical,
  _TerritoryFilter.stable => sector.status == TerritoryOperationalStatus.stable,
};
