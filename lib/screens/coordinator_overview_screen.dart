import 'package:flutter/material.dart';

import '../coordinator/territory_view_data.dart';
import '../models/need.dart';
import '../models/responsible_access.dart';
import '../repositories/live_data_scope.dart';
import '../theme/coordinator_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/territory_components.dart';
import 'coordination_screen.dart' show missionsVisibleToResponsible;

class CoordinatorOverviewScreen extends StatefulWidget {
  const CoordinatorOverviewScreen({
    super.key,
    required this.onOpenTerritory,
    required this.onCreateNeed,
    required this.onManageResponsibles,
    required this.onManageLocations,
  });

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
    return StreamBuilder<List<CoordinationNeed>>(
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
                missions: missionsSnapshot.data!,
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
              return _CoordinatorOverviewContent(
                territory: territory,
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
    );
  }
}

class _CoordinatorOverviewContent extends StatelessWidget {
  const _CoordinatorOverviewContent({
    required this.territory,
    required this.canAdminister,
    required this.onOpenTerritory,
    required this.onCreateNeed,
    required this.onManageResponsibles,
    required this.onManageLocations,
  });

  final CoordinatorTerritoryViewData territory;
  final bool canAdminister;
  final VoidCallback onOpenTerritory;
  final VoidCallback onCreateNeed;
  final VoidCallback onManageResponsibles;
  final VoidCallback onManageLocations;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final attention = territory.sectorsRequiringAttention;
    final verdict = attention.isEmpty
        ? 'Territoire stable.'
        : attention.length == 1
        ? '1 zone nécessite votre attention.'
        : '${attention.length} zones nécessitent votre attention.';
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
                      TerritoryVerdict(
                        verdict: verdict,
                        contextLine:
                            'Gironde  •  Besoins actifs  •  Données en direct',
                        stable: attention.isEmpty,
                      ),
                      const SizedBox(height: V5Spacing.xxxl),
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
                      const SizedBox(height: V5Spacing.xxxl),
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
                      const SizedBox(height: V5Spacing.xxxl),
                      Text(
                        'Actions rapides',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: V5Spacing.sm),
                      _QuickActions(
                        canAdminister: canAdminister,
                        onCreateNeed: onCreateNeed,
                        onManageResponsibles: onManageResponsibles,
                        onManageLocations: onManageLocations,
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
              'Aucune zone ne nécessite d’intervention.',
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
    child: SizedBox.square(
      dimension: 22,
      child: CircularProgressIndicator(
        color: CoordinatorIdentity.of(context).accent,
        strokeWidth: 2,
      ),
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
