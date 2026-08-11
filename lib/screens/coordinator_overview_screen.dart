import 'package:flutter/material.dart';

import '../coordinator/territory_view_data.dart';
import '../models/health_profession.dart';
import '../models/need.dart';
import '../models/profession_quotas.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/coordinator_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/territory_components.dart';
import '../widgets/v5_controls.dart';
import '../widgets/professional_page_header.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;
import 'coordinator_published_needs.dart';

class CoordinatorOverviewScreen extends StatefulWidget {
  const CoordinatorOverviewScreen({
    super.key,
    required this.publishedNeeds,
    required this.onOpenTerritory,
    required this.onCreateNeed,
    required this.onManageResponsibles,
    required this.onManageLocations,
  });

  final CoordinatorPublishedNeeds publishedNeeds;
  final VoidCallback onOpenTerritory;
  final VoidCallback onCreateNeed;
  final VoidCallback onManageResponsibles;
  final VoidCallback onManageLocations;

  @override
  State<CoordinatorOverviewScreen> createState() =>
      _CoordinatorOverviewScreenState();
}

class _CoordinatorOverviewScreenState extends State<CoordinatorOverviewScreen> {
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
        builder: (context, missionsSnapshot) => StreamBuilder<List<ResponsePlace>>(
          stream: _locations,
          builder: (context, locationsSnapshot) {
            if (missionsSnapshot.hasError || locationsSnapshot.hasError) {
              return const CoordinatorDataUnavailable(
                message:
                    'La situation territoriale est temporairement indisponible.',
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
                    message: 'Les autorisations ne peuvent pas être vérifiées.',
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
                                accessSnapshot.data?.canManage(location.id) ==
                                true,
                          )
                          .toList(growable: false);
                final territory = CoordinatorTerritoryViewData.from(
                  missions: visibleMissions,
                  locations: visibleLocations,
                );
                final now = DateTime.now();
                final criticalMissions = visibleMissions
                    .where(
                      (mission) =>
                          mission.isActive &&
                          !mission.isCancelled &&
                          mission.status == NeedStatus.critical &&
                          (mission.endAt == null ||
                              now.isBefore(mission.endAt!)),
                    )
                    .toList(growable: false);
                final criticalCenters = <String>{
                  for (final mission in criticalMissions)
                    responsePlaceForNeed(mission, visibleLocations)?.name ??
                        mission.place,
                }.toList(growable: false)..sort();
                final criticalQuotas = ProfessionQuotas.aggregate(
                  criticalMissions.map((mission) => mission.professionQuotas),
                );
                final missingQuotas =
                    criticalQuotas.values
                        .where((quota) => quota.missing > 0)
                        .toList(growable: false)
                      ..sort(
                        (left, right) => right.missing.compareTo(left.missing),
                      );
                final criticalProfession = missingQuotas.isEmpty
                    ? 'Aucune profession critique.'
                    : '${HealthProfessionRegistry.byId(missingQuotas.first.professionId)?.missionLabel ?? missingQuotas.first.professionId} · ${missingQuotas.first.missing} poste${missingQuotas.first.missing > 1 ? 's' : ''}';
                return _CoordinatorOverviewContent(
                  territory: territory,
                  criticalCenters: criticalCenters,
                  criticalProfession: criticalProfession,
                  canAdminister: accessSnapshot.data?.isCoordinator == true,
                  onOpenTerritory: widget.onOpenTerritory,
                  onCreateNeed: widget.onCreateNeed,
                  onManageResponsibles: widget.onManageResponsibles,
                  onManageLocations: widget.onManageLocations,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CoordinatorOverviewContent extends StatelessWidget {
  const _CoordinatorOverviewContent({
    required this.territory,
    required this.criticalCenters,
    required this.criticalProfession,
    required this.canAdminister,
    required this.onOpenTerritory,
    required this.onCreateNeed,
    required this.onManageResponsibles,
    required this.onManageLocations,
  });

  final CoordinatorTerritoryViewData territory;
  final List<String> criticalCenters;
  final String criticalProfession;
  final bool canAdminister;
  final VoidCallback onOpenTerritory;
  final VoidCallback onCreateNeed;
  final VoidCallback onManageResponsibles;
  final VoidCallback onManageLocations;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final attention = territory.sectorsRequiringAttention;
    final criticalSectors = territory.sectors
        .where((sector) => sector.status == TerritoryOperationalStatus.critical)
        .toList(growable: false);
    final verdict = criticalSectors.isEmpty
        ? 'Aucun territoire critique.'
        : criticalSectors.length == 1
        ? 'Territoire critique : ${criticalSectors.single.group.label}.'
        : '${criticalSectors.length} territoires critiques.';
    return ColoredBox(
      color: colors.canvas,
      child: CustomScrollView(
        key: const PageStorageKey('coordinator-overview'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MobSanteJourneyHeader(
                        journey: MobSanteJourney.coordinator,
                        pageTitle: 'Pilotage territorial',
                      ),
                      const SizedBox(height: V5Spacing.lg),
                      TerritoryVerdict(
                        verdict: verdict,
                        contextLine: 'Gironde  •  Aujourd’hui et à venir',
                        stable: criticalSectors.isEmpty,
                      ),
                      const SizedBox(height: V5Spacing.lg),
                      _CoordinatorDecisionPriorities(
                        criticalCenters: criticalCenters,
                        criticalProfession: criticalProfession,
                      ),
                      const SizedBox(height: V5Spacing.xxl),
                      Text(
                        'Actions rapides',
                        key: const Key('coordinator-primary-actions'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: V5Spacing.sm),
                      _QuickActions(
                        canAdminister: canAdminister,
                        onCreateNeed: onCreateNeed,
                        onManageResponsibles: onManageResponsibles,
                        onManageLocations: onManageLocations,
                      ),
                      const SizedBox(height: V5Spacing.xxl),
                      Text(
                        'À surveiller',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: V5Spacing.sm),
                      if (attention.isEmpty)
                        const _StableTerritoryState()
                      else
                        for (
                          var index = 0;
                          index < attention.length;
                          index++
                        ) ...[
                          SectorStatusCard(
                            sector: attention[index],
                            onView: onOpenTerritory,
                          ),
                          if (index < attention.length - 1)
                            const SizedBox(height: V5Spacing.sm),
                        ],
                      const SizedBox(height: V5Spacing.xxl),
                      Text(
                        'Sous contrôle',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: V5Spacing.sm),
                      OperationalSummary(
                        coveredCenters: territory.coveredCenters,
                        activeNeeds: territory.activeNeeds,
                        mobilizedProfessionals:
                            territory.mobilizedProfessionals,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoordinatorDecisionPriorities extends StatelessWidget {
  const _CoordinatorDecisionPriorities({
    required this.criticalCenters,
    required this.criticalProfession,
  });

  final List<String> criticalCenters;
  final String criticalProfession;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      key: const Key('coordinator-decision-priorities'),
      width: double.infinity,
      padding: const EdgeInsets.all(V5Spacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      child: Column(
        children: [
          _CoordinatorDecisionLine(
            key: const Key('coordinator-critical-centers'),
            icon: Icons.location_city_outlined,
            label: 'Centres critiques',
            value: criticalCenters.isEmpty
                ? 'Aucun centre critique.'
                : criticalCenters.join(' · '),
          ),
          Divider(height: V5Spacing.xl, color: colors.outline),
          _CoordinatorDecisionLine(
            key: const Key('coordinator-critical-profession'),
            icon: Icons.medical_services_outlined,
            label: 'Profession critique',
            value: criticalProfession,
          ),
        ],
      ),
    );
  }
}

class _CoordinatorDecisionLine extends StatelessWidget {
  const _CoordinatorDecisionLine({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: CoordinatorIdentity.of(context).accent),
        const SizedBox(width: V5Spacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: V5Spacing.xxs),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StableTerritoryState extends StatelessWidget {
  const _StableTerritoryState();

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      key: const Key('coordinator-attention-empty'),
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
            child: Text(
              'Aucune zone ne nécessite d’intervention aujourd’hui ou à venir.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.canAdminister,
    required this.onCreateNeed,
    required this.onManageResponsibles,
    required this.onManageLocations,
  });

  final bool canAdminister;
  final VoidCallback onCreateNeed;
  final VoidCallback onManageResponsibles;
  final VoidCallback onManageLocations;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _QuickActionRow(
            key: const Key('administration-create-need'),
            icon: Icons.add_circle_outline_rounded,
            label: 'Créer ou superviser un besoin',
            onTap: onCreateNeed,
          ),
          if (canAdminister) ...[
            Divider(height: 1, indent: 54, color: colors.outline),
            _QuickActionRow(
              key: const Key('admin-invitations-entry'),
              icon: Icons.admin_panel_settings_outlined,
              label: 'Gérer les responsables',
              onTap: onManageResponsibles,
            ),
            Divider(height: 1, indent: 54, color: colors.outline),
            _QuickActionRow(
              key: const Key('admin-locations-entry'),
              icon: Icons.location_city_outlined,
              label: 'Gérer les lieux',
              onTap: onManageLocations,
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActionRow extends StatelessWidget {
  const _QuickActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final identity = CoordinatorIdentity.of(context);
    final colors = context.v5Colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: V5Spacing.md),
            child: Row(
              children: [
                Icon(icon, size: 20, color: identity.accent),
                const SizedBox(width: V5Spacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CoordinatorLoadingState extends StatelessWidget {
  const CoordinatorLoadingState({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: V5ActivityIndicator(
      size: 22,
      color: CoordinatorIdentity.of(context).accent,
    ),
  );
}

class CoordinatorDataUnavailable extends StatelessWidget {
  const CoordinatorDataUnavailable({super.key, required this.message});

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
