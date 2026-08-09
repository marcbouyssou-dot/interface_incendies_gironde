import 'package:flutter/material.dart';

import '../coordinator/territory_view_data.dart';
import '../models/need.dart';
import '../models/responsible_access.dart';
import '../models/responsible_account.dart';
import '../perspective/cross_role_perspective.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/responsible_access_administration_repository.dart';
import '../repositories/responsible_access_administration_repository_scope.dart';
import '../theme/coordinator_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/perspective_switcher.dart';
import '../widgets/professional_page_header.dart';
import 'coordinator_overview_screen.dart';

class CoordinatorActorsScreen extends StatefulWidget {
  const CoordinatorActorsScreen({
    super.key,
    required this.onManageResponsibles,
    required this.onManageLocations,
  });

  final VoidCallback onManageResponsibles;
  final VoidCallback onManageLocations;

  @override
  State<CoordinatorActorsScreen> createState() =>
      _CoordinatorActorsScreenState();
}

class _CoordinatorActorsScreenState extends State<CoordinatorActorsScreen> {
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _access;
  Stream<List<ResponsePlace>>? _locations;
  Stream<List<CoordinationNeed>>? _missions;
  ResponsibleAccessAdministrationRepository? _accountsRepository;
  Future<List<ResponsibleAccount>>? _accounts;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    final accountsRepository =
        ResponsibleAccessAdministrationRepositoryScope.of(context);
    if (!identical(liveData, _liveData)) {
      _liveData = liveData;
      _access = liveData.watchResponsibleAccess();
      _locations = liveData.watchLocations();
      _missions = liveData.watchMissions();
    }
    if (!identical(accountsRepository, _accountsRepository)) {
      _accountsRepository = accountsRepository;
      _accounts = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ResponsibleAccess?>(
      stream: _access,
      builder: (context, accessSnapshot) {
        if (accessSnapshot.hasError) {
          return const CoordinatorDataUnavailable(
            message: 'Les autorisations ne peuvent pas être vérifiées.',
          );
        }
        if (!accessSnapshot.hasData &&
            accessSnapshot.connectionState == ConnectionState.waiting) {
          return const CoordinatorLoadingState();
        }
        final access = accessSnapshot.data;
        if (access?.isCoordinator != true) {
          return const CoordinatorDataUnavailable(
            message:
                'Les accès Acteurs restent soumis au rôle Coordinateur réel.',
          );
        }
        _accounts ??= _accountsRepository!.listAccounts();
        return StreamBuilder<List<ResponsePlace>>(
          stream: _locations,
          builder: (context, locationsSnapshot) =>
              StreamBuilder<List<CoordinationNeed>>(
                stream: _missions,
                builder: (context, missionsSnapshot) {
                  if (locationsSnapshot.hasError || missionsSnapshot.hasError) {
                    return const CoordinatorDataUnavailable(
                      message: 'Les acteurs territoriaux sont indisponibles.',
                    );
                  }
                  if (!locationsSnapshot.hasData || !missionsSnapshot.hasData) {
                    return const CoordinatorLoadingState();
                  }
                  return FutureBuilder<List<ResponsibleAccount>>(
                    future: _accounts,
                    builder: (context, accountsSnapshot) {
                      if (accountsSnapshot.hasError) {
                        return const CoordinatorDataUnavailable(
                          message:
                              'La liste des responsables est indisponible.',
                        );
                      }
                      if (!accountsSnapshot.hasData) {
                        return const CoordinatorLoadingState();
                      }
                      return _CoordinatorActorsContent(
                        accounts: accountsSnapshot.data!,
                        locations: locationsSnapshot.data!,
                        missions: missionsSnapshot.data!,
                        onManageResponsibles: widget.onManageResponsibles,
                        onManageLocations: widget.onManageLocations,
                      );
                    },
                  );
                },
              ),
        );
      },
    );
  }
}

class _CoordinatorActorsContent extends StatelessWidget {
  const _CoordinatorActorsContent({
    required this.accounts,
    required this.locations,
    required this.missions,
    required this.onManageResponsibles,
    required this.onManageLocations,
  });

  final List<ResponsibleAccount> accounts;
  final List<ResponsePlace> locations;
  final List<CoordinationNeed> missions;
  final VoidCallback onManageResponsibles;
  final VoidCallback onManageLocations;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final managers = accounts
        .where(
          (account) =>
              account.access.roles.contains(ResponsibleRole.siteManager),
        )
        .toList(growable: false);
    final territory = CoordinatorTerritoryViewData.from(
      missions: missions,
      locations: locations,
    );
    return ColoredBox(
      color: colors.canvas,
      child: ListView(
        key: const PageStorageKey('coordinator-actors'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MobSantePageHeader(
                    title: 'Acteurs',
                    subtitle:
                        'Responsables, professionnels mobilisés et lieux du dispositif.',
                  ),
                  const SizedBox(height: V5Spacing.xxl),
                  _ActorSectionHeader(
                    title: 'Responsables',
                    actionLabel: 'Gérer',
                    onAction: onManageResponsibles,
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _ResponsibleList(accounts: managers, locations: locations),
                  const SizedBox(height: V5Spacing.xxxl),
                  const _ActorSectionHeader(title: 'Professionnels'),
                  const SizedBox(height: V5Spacing.sm),
                  _ProfessionalSummary(
                    mobilized: territory.mobilizedProfessionals,
                  ),
                  const SizedBox(height: V5Spacing.xxxl),
                  _ActorSectionHeader(
                    title: 'Lieux',
                    actionLabel: 'Gérer',
                    onAction: onManageLocations,
                  ),
                  const SizedBox(height: V5Spacing.sm),
                  _LocationsSummary(
                    count: locations
                        .where((location) => location.isEnabled)
                        .length,
                    onTap: onManageLocations,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActorSectionHeader extends StatelessWidget {
  const _ActorSectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final identity = CoordinatorIdentity.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: identity.accent),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _ResponsibleList extends StatelessWidget {
  const _ResponsibleList({required this.accounts, required this.locations});

  final List<ResponsibleAccount> accounts;
  final List<ResponsePlace> locations;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    if (accounts.isEmpty) {
      return _ActorSurface(
        child: Text(
          'Aucun responsable de centre.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return _ActorSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < accounts.length; index++) ...[
            _ResponsibleRow(account: accounts[index], locations: locations),
            if (index < accounts.length - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: V5Spacing.lg,
                color: colors.outline,
              ),
          ],
        ],
      ),
    );
  }
}

class _ResponsibleRow extends StatelessWidget {
  const _ResponsibleRow({required this.account, required this.locations});

  final ResponsibleAccount account;
  final List<ResponsePlace> locations;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final identity = CoordinatorIdentity.of(context);
    final locationNames = [
      for (final id in account.access.locationIds)
        locations.where((location) => location.id == id).firstOrNull?.name ??
            'Centre attribué',
    ]..sort();
    final scope = locationNames.isEmpty
        ? 'Aucun centre attribué'
        : locationNames.join(' · ');
    final canPreview = account.access.active && locationNames.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.identityLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: V5Spacing.xxs),
                Text(scope, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: V5Spacing.xxs),
                Text(
                  account.access.active ? 'Actif' : 'Inactif',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: account.access.active
                        ? colors.success
                        : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (canPreview)
            TextButton(
              key: Key('coordinator-preview-${account.uid}'),
              onPressed: () => _openPerspective(context),
              style: TextButton.styleFrom(
                foregroundColor: identity.accent,
                minimumSize: const Size(44, 44),
              ),
              child: const Text('Voir comme'),
            ),
        ],
      ),
    );
  }

  Future<void> _openPerspective(BuildContext context) async {
    final selected = await showResponsibleCenterPicker(
      context,
      access: account.access,
      locations: locations,
      accentColor: CoordinatorIdentity.of(context).accent,
    );
    if (selected != null && context.mounted) {
      CrossRolePerspectiveScope.of(context).showResponsible(selected.id);
    }
  }
}

class _ProfessionalSummary extends StatelessWidget {
  const _ProfessionalSummary({required this.mobilized});

  final int mobilized;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return _ActorSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$mobilized professionnels mobilisés',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: V5Spacing.xxs),
          Text(
            'Aucune donnée nominative supplémentaire n’est exposée.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LocationsSummary extends StatelessWidget {
  const _LocationsSummary({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return _ActorSurface(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('coordinator-actors-locations'),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: V5Spacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$count lieux actifs',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textSecondary,
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

class _ActorSurface extends StatelessWidget {
  const _ActorSurface({
    required this.child,
    this.padding = const EdgeInsets.all(V5Spacing.md),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(V5Radius.card),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
