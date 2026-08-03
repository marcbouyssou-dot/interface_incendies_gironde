import 'package:flutter/material.dart';

import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_page_route.dart';
import '../widgets/common.dart';
import 'admin_invitations_screen.dart';
import 'create_need_screen.dart';
import 'location_administration_screen.dart';

abstract final class _AdministrationVisuals {
  static const background = Color(0xFFF5F5F3);
  static const surface = Colors.white;
  static const navy = Color(0xFF173052);
  static const fieldBackground = Color(0xFFF1F1EF);
  static const border = Color(0xFFE5E5E1);
  static const textMuted = Color(0xFF7C817F);
}

class AdministrationDashboardScreen extends StatefulWidget {
  const AdministrationDashboardScreen({
    super.key,
    required this.onViewMission,
    required this.onOpenStatistics,
    required this.onRetryAccess,
  });

  final VoidCallback onViewMission;
  final VoidCallback onOpenStatistics;
  final VoidCallback onRetryAccess;

  @override
  State<AdministrationDashboardScreen> createState() =>
      _AdministrationDashboardScreenState();
}

class _AdministrationDashboardScreenState
    extends State<AdministrationDashboardScreen> {
  CoordinationRepository? _repository;
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _access;
  Stream<List<ResponsePlace>>? _locations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    final liveData = LiveCoordinationDataScope.of(context);
    if (!identical(repository, _repository) ||
        !identical(liveData, _liveData)) {
      _repository = repository;
      _liveData = liveData;
      _access = liveData.watchResponsibleAccess();
      _locations = liveData.watchLocations();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ResponsibleAccess?>(
      stream: _access,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (isInvalidResponsibleAccessError(snapshot.error)) {
            return const InvalidResponsibleAccessState();
          }
          return _ResponsibleAccessUnavailable(
            message: 'Votre accès responsable ne peut pas être vérifié.',
            onRetry: widget.onRetryAccess,
            onSignOut: _repository!.signOutResponsible,
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final access = snapshot.data;
        if (access == null) {
          return ResponsibleLogin(repository: _repository!);
        }
        if (!access.active) {
          return _ResponsibleAccessUnavailable(
            message: 'Votre compte responsable est inactif.',
            onRetry: widget.onRetryAccess,
            onSignOut: _repository!.signOutResponsible,
          );
        }
        if (!access.hasPrivilegedAccess) {
          return _ResponsibleAccessUnavailable(
            message: 'Votre compte ne dispose pas d’un rôle autorisé.',
            onRetry: widget.onRetryAccess,
            onSignOut: _repository!.signOutResponsible,
          );
        }
        return StreamBuilder<List<ResponsePlace>>(
          stream: _locations,
          builder: (context, locationsSnapshot) {
            if (locationsSnapshot.hasError) {
              return const CriticalDataUnavailableState(
                stateKey: Key('administration-locations-unavailable-state'),
                eyebrow: 'Administration',
                title: 'Informations des centres indisponibles',
                message:
                    'Nous ne pouvons pas charger les informations des centres '
                    'pour le moment.',
                safetyMessage:
                    'Les actions liées aux centres sont suspendues afin '
                    'd’éviter toute utilisation de données périmées.',
              );
            }
            if (!locationsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _AdministrationDashboard(
              access: access,
              locations: locationsSnapshot.data!,
              liveData: _liveData!,
              onViewMission: widget.onViewMission,
              onOpenStatistics: widget.onOpenStatistics,
              onSignOut: _repository!.signOutResponsible,
            );
          },
        );
      },
    );
  }
}

class _AdministrationDashboard extends StatelessWidget {
  const _AdministrationDashboard({
    required this.access,
    required this.locations,
    required this.liveData,
    required this.onViewMission,
    required this.onOpenStatistics,
    required this.onSignOut,
  });

  final ResponsibleAccess access;
  final List<ResponsePlace> locations;
  final LiveCoordinationData liveData;
  final VoidCallback onViewMission;
  final VoidCallback onOpenStatistics;
  final Future<void> Function() onSignOut;

  void _openCreateNeed(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: CreateNeedScreen(
            onViewMission: () {
              Navigator.of(context).pop();
              onViewMission();
            },
          ),
        ),
      ),
    );
  }

  void _openInvitations(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const AdminInvitationsScreen(),
        ),
      ),
    );
  }

  void _openLocations(BuildContext context) {
    Navigator.of(context).push(
      AppPageRoute<void>(builder: (_) => const LocationAdministrationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth <= 556
              ? 18.0
              : (constraints.maxWidth - 520) / 2;
          return Material(
            color: _AdministrationVisuals.background,
            child: ListView(
              key: const PageStorageKey('administration-dashboard'),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                36,
              ),
              children: [
                _AdministrationHeader(access: access),
                const SizedBox(height: 20),
                _AdministrationActionCard(
                  key: const Key('administration-create-need'),
                  semanticLabel: 'Créer un besoin',
                  icon: Icons.add_circle_rounded,
                  title: 'Créer un besoin',
                  description: 'Publier les renforts nécessaires.',
                  primary: true,
                  onTap: () => _openCreateNeed(context),
                ),
                const SizedBox(height: 14),
                _ResponsibleScopeCard(access: access, locations: locations),
                const SizedBox(height: 22),
                const _AdministrationSectionTitle(),
                const SizedBox(height: 10),
                if (access.isCoordinator) ...[
                  _AdministrationActionCard(
                    key: const Key('admin-locations-entry'),
                    semanticLabel: 'Ouvrir la gestion des lieux',
                    icon: Icons.location_city_outlined,
                    title: 'Lieux',
                    description: 'Créer, modifier et désactiver les centres',
                    onTap: () => _openLocations(context),
                  ),
                  const SizedBox(height: 10),
                  _AdministrationActionCard(
                    key: const Key('admin-invitations-entry'),
                    semanticLabel: 'Ouvrir la gestion des responsables',
                    icon: Icons.admin_panel_settings_outlined,
                    title: 'Responsables',
                    description: 'Invitations et accès aux centres',
                    onTap: () => _openInvitations(context),
                  ),
                  const SizedBox(height: 10),
                ],
                _AdministrationActionCard(
                  key: const Key('administration-statistics'),
                  semanticLabel: 'Ouvrir les statistiques',
                  icon: Icons.bar_chart_rounded,
                  title: 'Statistiques',
                  description: 'Consulter la couverture opérationnelle.',
                  onTap: onOpenStatistics,
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton.icon(
                    key: const Key('administration-sign-out'),
                    style: TextButton.styleFrom(
                      foregroundColor: _AdministrationVisuals.textMuted,
                      minimumSize: const Size(180, 48),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: onSignOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Se déconnecter'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdministrationHeader extends StatelessWidget {
  const _AdministrationHeader({required this.access});

  final ResponsibleAccess access;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ESPACE RESPONSABLE',
          style: TextStyle(
            color: _AdministrationVisuals.textMuted,
            fontSize: 10,
            letterSpacing: 1.3,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          access.isCoordinator
              ? 'Coordination départementale'
              : 'Votre accès responsable',
          style: const TextStyle(
            color: _AdministrationVisuals.navy,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          access.isCoordinator
              ? 'Pilotez les besoins et les accès aux centres.'
              : 'Gérez les besoins de votre périmètre.',
          style: const TextStyle(
            color: _AdministrationVisuals.textMuted,
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _AdministrationSectionTitle extends StatelessWidget {
  const _AdministrationSectionTitle();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ADMINISTRATION',
          style: TextStyle(
            color: _AdministrationVisuals.textMuted,
            fontSize: 10,
            letterSpacing: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Autres accès',
          style: TextStyle(
            color: _AdministrationVisuals.navy,
            fontSize: 19,
            letterSpacing: -0.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ResponsibleScopeCard extends StatelessWidget {
  const _ResponsibleScopeCard({required this.access, required this.locations});

  final ResponsibleAccess access;
  final List<ResponsePlace> locations;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AdministrationVisuals.fieldBackground,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _AdministrationVisuals.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _AdministrationVisuals.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _AdministrationVisuals.border),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: _AdministrationVisuals.navy,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VOTRE PÉRIMÈTRE',
                  style: TextStyle(
                    color: _AdministrationVisuals.textMuted,
                    fontSize: 9,
                    letterSpacing: 0.75,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                if (access.isCoordinator)
                  const Text(
                    'Tous les lieux de Gironde',
                    style: TextStyle(
                      color: _AdministrationVisuals.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  Text(
                    _siteManagerScope(locations),
                    key: const Key('responsible-scope-label'),
                    style: const TextStyle(
                      color: _AdministrationVisuals.navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _siteManagerScope(List<ResponsePlace> values) {
    if (access.locationIds.length != 1) {
      return '${access.locationIds.length} centres autorisés';
    }
    final id = access.locationIds.single;
    final location = values
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    return location?.name ?? '1 centre autorisé';
  }
}

class _AdministrationActionCard extends StatelessWidget {
  const _AdministrationActionCard({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.primary = false,
  });

  final String semanticLabel;
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : _AdministrationVisuals.navy;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: primary ? AppColors.orange : _AdministrationVisuals.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(primary ? 18 : 15),
          side: BorderSide(
            color: primary ? AppColors.orange : _AdministrationVisuals.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: primary ? 88 : 76),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: primary ? 18 : 15,
                vertical: primary ? 17 : 13,
              ),
              child: Row(
                children: [
                  Container(
                    width: primary ? 46 : 42,
                    height: primary ? 46 : 42,
                    decoration: BoxDecoration(
                      color: primary
                          ? Colors.white.withValues(alpha: 0.16)
                          : _AdministrationVisuals.fieldBackground,
                      borderRadius: BorderRadius.circular(primary ? 14 : 12),
                    ),
                    child: Icon(
                      icon,
                      color: foreground,
                      size: primary ? 25 : 22,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: foreground,
                            fontSize: primary ? 17 : 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            color: primary
                                ? Colors.white.withValues(alpha: 0.86)
                                : _AdministrationVisuals.textMuted,
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: primary
                        ? Colors.white
                        : _AdministrationVisuals.textMuted,
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

class _ResponsibleAccessUnavailable extends StatelessWidget {
  const _ResponsibleAccessUnavailable({
    required this.message,
    required this.onRetry,
    required this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 42, 20, 32),
        children: [
          const PageHeader(
            eyebrow: 'Administration',
            title: 'Accès indisponible',
            subtitle: 'Votre accès ne peut pas être utilisé pour le moment.',
          ),
          const SizedBox(height: 22),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.red,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    key: const Key('responsible-access-error'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    key: const Key('responsible-access-retry'),
                    onPressed: onRetry,
                    child: const Text('Réessayer'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('responsible-access-sign-out'),
                    onPressed: onSignOut,
                    child: const Text('Se déconnecter'),
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
