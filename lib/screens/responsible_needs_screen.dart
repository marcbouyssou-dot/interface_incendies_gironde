import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import '../widgets/responsible_mission_card.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;
import 'create_need_screen.dart';

enum _NeedsFilter { attention, inProgress, covered, past }

extension on _NeedsFilter {
  String get label => switch (this) {
    _NeedsFilter.attention => 'À traiter',
    _NeedsFilter.inProgress => 'En cours',
    _NeedsFilter.covered => 'Couverts',
    _NeedsFilter.past => 'Passés',
  };
}

class ResponsibleNeedsScreen extends StatefulWidget {
  const ResponsibleNeedsScreen({
    super.key,
    this.previewLocationId,
    required this.onOpenTeam,
  });

  final String? previewLocationId;
  final VoidCallback onOpenTeam;

  @override
  State<ResponsibleNeedsScreen> createState() => _ResponsibleNeedsScreenState();
}

class _ResponsibleNeedsScreenState extends State<ResponsibleNeedsScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<List<ResponsePlace>>? _locations;
  Stream<ResponsibleAccess?>? _access;
  String? _editingMissionId;
  _NeedsFilter _filter = _NeedsFilter.attention;

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
    return StreamBuilder<ResponsibleAccess?>(
      stream: _access,
      builder: (context, accessSnapshot) =>
          StreamBuilder<List<CoordinationNeed>>(
            stream: _missions,
            builder: (context, missionsSnapshot) =>
                StreamBuilder<List<ResponsePlace>>(
                  stream: _locations,
                  builder: (context, locationsSnapshot) {
                    if (accessSnapshot.hasError ||
                        missionsSnapshot.hasError ||
                        locationsSnapshot.hasError) {
                      return const _NeedsMessage(
                        message:
                            'Les besoins sont temporairement indisponibles.',
                      );
                    }
                    if (!missionsSnapshot.hasData ||
                        !locationsSnapshot.hasData) {
                      return const _NeedsLoading();
                    }
                    final locations = locationsSnapshot.data!;
                    final needs =
                        missionsVisibleToResponsible(
                              missions: missionsSnapshot.data!,
                              locations: locations,
                              access: accessSnapshot.data,
                              previewLocationId: widget.previewLocationId,
                            )
                            .where((need) => need.isActive && !need.isCancelled)
                            .toList(growable: false);
                    return _ResponsibleNeedsContent(
                      needs: needs,
                      locations: locations,
                      access: accessSnapshot.data,
                      selectedFilter: _filter,
                      editingMissionId: _editingMissionId,
                      onFilterChanged: (filter) =>
                          setState(() => _filter = filter),
                      onCreateNeed: _openCreateNeed,
                      onEditNeed: _openEditor,
                      onOpenTeam: widget.onOpenTeam,
                    );
                  },
                ),
          ),
    );
  }

  void _openCreateNeed() {
    final liveData = _liveData!;
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: CreateNeedScreen(
            onViewMission: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(CoordinationNeed need) async {
    if (_editingMissionId != null) return;
    setState(() => _editingMissionId = need.id);
    try {
      await openMissionEditor(context, need);
    } finally {
      if (mounted) setState(() => _editingMissionId = null);
    }
  }
}

class _ResponsibleNeedsContent extends StatelessWidget {
  const _ResponsibleNeedsContent({
    required this.needs,
    required this.locations,
    required this.access,
    required this.selectedFilter,
    required this.editingMissionId,
    required this.onFilterChanged,
    required this.onCreateNeed,
    required this.onEditNeed,
    required this.onOpenTeam,
  });

  final List<CoordinationNeed> needs;
  final List<ResponsePlace> locations;
  final ResponsibleAccess? access;
  final _NeedsFilter selectedFilter;
  final String? editingMissionId;
  final ValueChanged<_NeedsFilter> onFilterChanged;
  final VoidCallback onCreateNeed;
  final ValueChanged<CoordinationNeed> onEditNeed;
  final VoidCallback onOpenTeam;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final filteredNeeds = needs
        .where((need) => _matchesFilter(need, selectedFilter))
        .toList(growable: false);
    return ColoredBox(
      color: colors.canvas,
      child: CustomScrollView(
        key: const PageStorageKey('responsible-needs'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Besoins',
                              style: Theme.of(context).textTheme.headlineLarge,
                            ),
                          ),
                          FilledButton(
                            key: const Key('responsible-needs-create'),
                            onPressed: onCreateNeed,
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.accent,
                              foregroundColor: colors.onAccent,
                              minimumSize: const Size(0, 44),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  V5Radius.control,
                                ),
                              ),
                            ),
                            child: const Text('Créer'),
                          ),
                        ],
                      ),
                      const SizedBox(height: V5Spacing.xs),
                      Text(
                        'Suivez et ajustez les besoins de vos centres.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: V5Spacing.lg),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final filter in _NeedsFilter.values) ...[
                              _FilterChip(
                                filter: filter,
                                selected: filter == selectedFilter,
                                onSelected: () => onFilterChanged(filter),
                              ),
                              if (filter != _NeedsFilter.values.last)
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
          if (filteredNeeds.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _NeedsMessage(
                message: 'Aucun besoin « ${selectedFilter.label} ».',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList.separated(
                itemCount: filteredNeeds.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: V5Spacing.sm),
                itemBuilder: (context, index) {
                  final need = filteredNeeds[index];
                  final location = responsePlaceForNeed(need, locations);
                  final locationId = need.locationId ?? location?.id;
                  final canManage =
                      access != null &&
                      locationId != null &&
                      access!.canManage(locationId) &&
                      need.isActive &&
                      !need.isCancelled;
                  final canCancel = canManage && need.createdBy == access!.uid;
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ResponsibleMissionCard(
                        key: Key('responsible-need-${need.id}'),
                        need: need,
                        tone: _toneForNeed(need),
                        statusLabel: _statusForNeed(need),
                        actions: [
                          if (canManage)
                            TextButton(
                              key: Key('responsible-edit-need-${need.id}'),
                              onPressed: editingMissionId == null
                                  ? () => onEditNeed(need)
                                  : null,
                              style: TextButton.styleFrom(
                                foregroundColor: colors.accent,
                                minimumSize: const Size(0, 44),
                              ),
                              child: Text(
                                editingMissionId == need.id
                                    ? 'Ouverture…'
                                    : 'Modifier',
                              ),
                            ),
                          if (canCancel)
                            MissionCancellationButton(
                              need: need,
                              label: 'Annuler',
                              showIcon: false,
                              foregroundColor: colors.textSecondary,
                            ),
                          TextButton(
                            key: Key('responsible-view-team-${need.id}'),
                            onPressed: onOpenTeam,
                            style: TextButton.styleFrom(
                              foregroundColor: colors.accent,
                              minimumSize: const Size(0, 44),
                            ),
                            child: const Text('Voir l’équipe'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.onSelected,
  });

  final _NeedsFilter filter;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ChoiceChip(
      key: Key('responsible-needs-filter-${filter.name}'),
      label: Text(filter.label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      selectedColor: colors.accent,
      backgroundColor: colors.surfaceElevated,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(V5Radius.pill),
      ),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: selected ? colors.onAccent : colors.textSecondary,
      ),
    );
  }
}

bool _matchesFilter(CoordinationNeed need, _NeedsFilter filter) {
  final isPast = need.endAt != null && need.endAt!.isBefore(DateTime.now());
  if (filter == _NeedsFilter.past) return isPast;
  if (isPast) return false;
  return switch (filter) {
    _NeedsFilter.attention => need.status == NeedStatus.critical,
    _NeedsFilter.inProgress => need.status == NeedStatus.toComplete,
    _NeedsFilter.covered => need.status == NeedStatus.complete,
    _NeedsFilter.past => false,
  };
}

ResponsibleMissionTone _toneForNeed(CoordinationNeed need) {
  if (need.endAt != null && need.endAt!.isBefore(DateTime.now())) {
    return ResponsibleMissionTone.past;
  }
  return switch (need.status) {
    NeedStatus.critical => ResponsibleMissionTone.urgent,
    NeedStatus.toComplete => ResponsibleMissionTone.attention,
    NeedStatus.complete => ResponsibleMissionTone.covered,
  };
}

String _statusForNeed(CoordinationNeed need) {
  if (need.endAt != null && need.endAt!.isBefore(DateTime.now())) {
    return 'Passé';
  }
  return switch (need.status) {
    NeedStatus.critical => 'À traiter',
    NeedStatus.toComplete => 'En cours',
    NeedStatus.complete => 'Couvert',
  };
}

class _NeedsLoading extends StatelessWidget {
  const _NeedsLoading();

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(
        color: context.v5Colors.accent,
        strokeWidth: 2,
      ),
    ),
  );
}

class _NeedsMessage extends StatelessWidget {
  const _NeedsMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );
}
