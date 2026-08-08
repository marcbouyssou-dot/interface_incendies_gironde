import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import '../widgets/responsible_mission_card.dart';
import '../widgets/professional_page_header.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;
import 'create_need_screen.dart';
import 'responsible_published_needs.dart';

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
    required this.publishedNeeds,
    this.onMissionPublished,
    required this.onOpenTeam,
  });

  final String? previewLocationId;
  final ResponsiblePublishedNeeds publishedNeeds;
  final ValueChanged<CoordinationNeed>? onMissionPublished;
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
    return ValueListenableBuilder<List<CoordinationNeed>>(
      valueListenable: widget.publishedNeeds,
      builder: (context, _, _) => StreamBuilder<ResponsibleAccess?>(
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
                                missions: widget.publishedNeeds.mergeWith(
                                  missionsSnapshot.data!,
                                ),
                                locations: locations,
                                access: accessSnapshot.data,
                                previewLocationId: widget.previewLocationId,
                              )
                              .where(
                                (need) => need.isActive && !need.isCancelled,
                              )
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
            onMissionPublished: widget.onMissionPublished,
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
                      const MobSantePageHeader(
                        title: 'Mes besoins',
                        subtitle:
                            'Créez, suivez et ajustez les besoins de vos centres.',
                      ),
                      const SizedBox(height: V5Spacing.md),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
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
          if (needs.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _NeedsEmptyState(onCreateNeed: onCreateNeed),
                  ),
                ),
              ),
            )
          else if (filteredNeeds.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _FilteredNeedsEmptyState(filter: selectedFilter),
                  ),
                ),
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

class _NeedsEmptyState extends StatelessWidget {
  const _NeedsEmptyState({required this.onCreateNeed});

  final VoidCallback onCreateNeed;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      key: const Key('responsible-needs-empty'),
      width: double.infinity,
      padding: const EdgeInsets.all(V5Spacing.xl),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.successContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.check_rounded, size: 21, color: colors.success),
          ),
          const SizedBox(height: V5Spacing.md),
          Text(
            'Aucun besoin ouvert',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: V5Spacing.xs),
          Text(
            'Votre planning est actuellement couvert.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: V5Spacing.lg),
          OutlinedButton(
            key: const Key('responsible-needs-empty-create'),
            onPressed: onCreateNeed,
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.accent,
              minimumSize: const Size(0, 44),
              side: BorderSide(color: colors.outline),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(V5Radius.control),
              ),
            ),
            child: const Text('Créer un besoin'),
          ),
        ],
      ),
    );
  }
}

class _FilteredNeedsEmptyState extends StatelessWidget {
  const _FilteredNeedsEmptyState({required this.filter});

  final _NeedsFilter filter;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final (title, message) = switch (filter) {
      _NeedsFilter.attention => (
        'Rien à traiter',
        'Votre planning ne demande aucune intervention.',
      ),
      _NeedsFilter.inProgress => (
        'Aucun besoin en cours',
        'Les prochains remplissages apparaîtront ici.',
      ),
      _NeedsFilter.covered => (
        'Aucun besoin couvert',
        'Les besoins sécurisés apparaîtront ici.',
      ),
      _NeedsFilter.past => (
        'Aucun besoin passé',
        'L’historique de votre établissement apparaîtra ici.',
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: V5Spacing.lg,
        vertical: V5Spacing.md,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 20, color: colors.success),
          const SizedBox(width: V5Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: V5Spacing.xxs),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
