import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/responsible_mission_card.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;
import 'create_need_screen.dart';

class ResponsibleHomeScreen extends StatefulWidget {
  const ResponsibleHomeScreen({
    super.key,
    this.previewLocationId,
    required this.onOpenNeeds,
  });

  final String? previewLocationId;
  final VoidCallback onOpenNeeds;

  @override
  State<ResponsibleHomeScreen> createState() => _ResponsibleHomeScreenState();
}

class _ResponsibleHomeScreenState extends State<ResponsibleHomeScreen> {
  LiveCoordinationData? _liveData;
  Stream<List<CoordinationNeed>>? _missions;
  Stream<List<ResponsePlace>>? _locations;
  Stream<ResponsibleAccess?>? _responsibleAccess;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (identical(liveData, _liveData)) return;
    _liveData = liveData;
    _missions = liveData.watchMissions();
    _locations = liveData.watchLocations();
    _responsibleAccess = liveData.watchResponsibleAccess();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ColoredBox(
      key: const Key('responsible-home'),
      color: colors.canvas,
      child: StreamBuilder<ResponsibleAccess?>(
        stream: _responsibleAccess,
        builder: (context, accessSnapshot) {
          if (accessSnapshot.hasError) {
            return const _ResponsibleHomeUnavailable();
          }
          if (!accessSnapshot.hasData &&
              accessSnapshot.connectionState == ConnectionState.waiting) {
            return const _ResponsibleHomeLoading();
          }
          return StreamBuilder<List<CoordinationNeed>>(
            stream: _missions,
            builder: (context, missionsSnapshot) {
              if (missionsSnapshot.hasError) {
                return const _ResponsibleHomeUnavailable();
              }
              if (!missionsSnapshot.hasData) {
                return const _ResponsibleHomeLoading();
              }
              return StreamBuilder<List<ResponsePlace>>(
                stream: _locations,
                builder: (context, locationsSnapshot) {
                  if (locationsSnapshot.hasError) {
                    return const _ResponsibleHomeUnavailable();
                  }
                  if (!locationsSnapshot.hasData) {
                    return const _ResponsibleHomeLoading();
                  }
                  return _ResponsibleHomeContent(
                    access: accessSnapshot.data,
                    missions: missionsSnapshot.data!,
                    locations: locationsSnapshot.data!,
                    onCreateNeed: _openCreateNeed,
                    onOpenNeeds: widget.onOpenNeeds,
                    previewLocationId: widget.previewLocationId,
                  );
                },
              );
            },
          );
        },
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
}

class _ResponsibleHomeContent extends StatelessWidget {
  const _ResponsibleHomeContent({
    required this.access,
    required this.missions,
    required this.locations,
    required this.onCreateNeed,
    required this.onOpenNeeds,
    required this.previewLocationId,
  });

  final ResponsibleAccess? access;
  final List<CoordinationNeed> missions;
  final List<ResponsePlace> locations;
  final VoidCallback onCreateNeed;
  final VoidCallback onOpenNeeds;
  final String? previewLocationId;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final visibleMissions = missionsVisibleToResponsible(
      missions: missions,
      locations: locations,
      access: access,
      previewLocationId: previewLocationId,
    );
    final planningNeeds = visibleMissions
        .where((need) => need.isActive && !need.isCancelled)
        .toList(growable: false);
    final toHandle = planningNeeds
        .where((need) => need.status == NeedStatus.critical)
        .toList(growable: false);
    final underControl = planningNeeds
        .where((need) => need.status != NeedStatus.critical)
        .toList(growable: false);
    final quotas = ProfessionQuotas.aggregate(
      planningNeeds.map((need) => need.professionQuotas),
    );
    final remaining = quotas.values.fold<int>(
      0,
      (total, quota) => total + quota.missing,
    );
    final verdict = switch (remaining) {
      0 => 'Tout est couvert pour demain.',
      1 => '1 poste reste à couvrir demain.',
      _ => '$remaining postes restent à couvrir demain.',
    };
    final teamSummary = quotas.requiredTotal == 0
        ? 'Aucun professionnel mobilisé actuellement.'
        : quotas.registeredTotal == 0
        ? 'Aucun professionnel mobilisé actuellement.'
        : quotas.registeredTotal == 1
        ? '1 confirmé sur ${quotas.requiredTotal} attendus demain.'
        : '${quotas.registeredTotal} confirmés sur '
              '${quotas.requiredTotal} attendus demain.';
    final teamSupportingText = quotas.registeredTotal == 0
        ? 'Les confirmations apparaîtront ici.'
        : null;
    final centerContext = _centerContext(
      planningNeeds: planningNeeds,
      locations: locations,
      access: access,
      previewLocationId: previewLocationId,
    );

    return CustomScrollView(
      key: const PageStorageKey('responsible-home-scroll'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlanningHero(
                      verdict: verdict,
                      centerContext: centerContext,
                      secured: remaining == 0,
                    ),
                    const SizedBox(height: V5Spacing.xxl),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('responsible-create-need'),
                        onPressed: onCreateNeed,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: remaining == 0
                              ? colors.warningContainer
                              : colors.accent,
                          foregroundColor: remaining == 0
                              ? colors.accent
                              : colors.onAccent,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              V5Radius.control,
                            ),
                          ),
                        ),
                        child: const Text('Créer un besoin'),
                      ),
                    ),
                    const SizedBox(height: V5Spacing.xxxl),
                    _MissionSection(
                      title: 'À traiter',
                      emptyMessage:
                          'Rien ne nécessite votre intervention pour demain.',
                      needs: toHandle,
                      onOpenNeeds: onOpenNeeds,
                    ),
                    const SizedBox(height: V5Spacing.xxxl),
                    _MissionSection(
                      title: 'Sous contrôle',
                      description: 'Les besoins couverts ou bien avancés.',
                      emptyMessage: toHandle.isEmpty
                          ? 'Tous les besoins prévus sont sécurisés.'
                          : 'Les confirmations apparaîtront ici au fil des '
                                'mobilisations.',
                      needs: underControl,
                      onOpenNeeds: onOpenNeeds,
                    ),
                    const SizedBox(height: V5Spacing.xxxl),
                    Text(
                      'Équipe',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: V5Spacing.sm),
                    _TeamSummary(
                      message: teamSummary,
                      supportingText: teamSupportingText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _centerContext({
  required List<CoordinationNeed> planningNeeds,
  required List<ResponsePlace> locations,
  required ResponsibleAccess? access,
  required String? previewLocationId,
}) {
  final locationById = {
    for (final location in locations) location.id: location,
  };
  final names = <String>{};
  if (previewLocationId != null) {
    names.add(locationById[previewLocationId]?.name ?? 'Centre sélectionné');
  } else if (access?.isLocationRestricted == true) {
    for (final id in access!.locationIds) {
      names.add(locationById[id]?.name ?? 'Centre attribué');
    }
  } else {
    for (final need in planningNeeds) {
      names.add(responsePlaceForNeed(need, locations)?.name ?? need.place);
    }
  }
  final ordered = names.toList(growable: false)..sort();
  if (ordered.isEmpty) return 'Votre périmètre de centres';
  if (ordered.length == 1) return 'Centre : ${ordered.single}';
  if (ordered.length == 2) return 'Centres : ${ordered.join(' · ')}';
  return '${ordered.length} centres concernés';
}

class _PlanningHero extends StatelessWidget {
  const _PlanningHero({
    required this.verdict,
    required this.centerContext,
    required this.secured,
  });

  final String verdict;
  final String centerContext;
  final bool secured;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Semantics(
      container: true,
      liveRegion: true,
      label: '$verdict Demain, $centerContext',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (secured) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 24,
                      color: colors.success,
                    ),
                  ),
                  const SizedBox(width: V5Spacing.sm),
                ],
                Expanded(
                  child: Text(
                    verdict,
                    key: const Key('responsible-planning-verdict'),
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
              'Demain  •  $centerContext',
              key: const Key('responsible-planning-context'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionSection extends StatelessWidget {
  const _MissionSection({
    required this.title,
    required this.emptyMessage,
    required this.needs,
    required this.onOpenNeeds,
    this.description,
  });

  final String title;
  final String emptyMessage;
  final List<CoordinationNeed> needs;
  final VoidCallback onOpenNeeds;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (needs.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  borderRadius: BorderRadius.circular(V5Radius.pill),
                ),
                child: Text(
                  '${needs.length}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: V5Spacing.xxs),
          Text(description!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: V5Spacing.sm),
        if (needs.isEmpty)
          Container(
            key: title == 'À traiter'
                ? const Key('responsible-open-needs-empty')
                : null,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: colors.success,
                ),
                const SizedBox(width: V5Spacing.sm),
                Expanded(
                  child: Text(
                    emptyMessage,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            key: title == 'À traiter'
                ? const Key('responsible-open-needs')
                : null,
            children: [
              for (var index = 0; index < needs.length; index++) ...[
                ResponsibleMissionCard(
                  key: Key('responsible-open-need-${needs[index].id}'),
                  need: needs[index],
                  tone: _toneForNeed(needs[index]),
                  statusLabel: _homeStatusForNeed(needs[index]),
                  actions: [
                    TextButton(
                      key: Key('responsible-manage-need-${needs[index].id}'),
                      onPressed: onOpenNeeds,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.accent,
                        minimumSize: const Size(0, 44),
                      ),
                      child: Text(
                        needs[index].status == NeedStatus.critical
                            ? 'Gérer'
                            : 'Voir',
                      ),
                    ),
                  ],
                ),
                if (index < needs.length - 1)
                  const SizedBox(height: V5Spacing.sm),
              ],
            ],
          ),
      ],
    );
  }
}

ResponsibleMissionTone _toneForNeed(CoordinationNeed need) =>
    switch (need.status) {
      NeedStatus.critical => ResponsibleMissionTone.urgent,
      NeedStatus.toComplete => ResponsibleMissionTone.controlled,
      NeedStatus.complete => ResponsibleMissionTone.covered,
    };

String _homeStatusForNeed(CoordinationNeed need) => switch (need.status) {
  NeedStatus.critical => 'Urgent',
  NeedStatus.toComplete => 'Bien avancé',
  NeedStatus.complete => 'Couvert',
};

class _TeamSummary extends StatelessWidget {
  const _TeamSummary({required this.message, this.supportingText});

  final String message;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      key: const Key('responsible-team-summary'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: V5Spacing.md,
        vertical: V5Spacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.section),
      ),
      child: Row(
        children: [
          Icon(Icons.people_outline_rounded, size: 19, color: colors.accent),
          const SizedBox(width: V5Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (supportingText != null) ...[
                  const SizedBox(height: V5Spacing.xxs),
                  Text(
                    supportingText!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsibleHomeLoading extends StatelessWidget {
  const _ResponsibleHomeLoading();

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

class _ResponsibleHomeUnavailable extends StatelessWidget {
  const _ResponsibleHomeUnavailable();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(V5Spacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Text(
          'Le planning est temporairement indisponible.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: context.v5Colors.textSecondary,
          ),
        ),
      ),
    ),
  );
}
