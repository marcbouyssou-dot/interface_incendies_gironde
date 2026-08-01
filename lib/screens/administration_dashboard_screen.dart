import 'package:flutter/material.dart';

import '../models/need.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'admin_invitations_screen.dart';
import 'create_need_screen.dart';

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
      MaterialPageRoute<void>(
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
      MaterialPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const AdminInvitationsScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageContainer(
      child: ListView(
        key: const PageStorageKey('administration-dashboard'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
        children: [
          PageHeader(
            eyebrow: 'Administration',
            title: access.isCoordinator
                ? 'Coordination départementale'
                : 'Votre accès responsable',
            subtitle: access.isCoordinator
                ? 'Pilotez les besoins et les accès aux centres.'
                : 'Gérez les besoins de votre périmètre.',
          ),
          const SizedBox(height: 18),
          _ResponsibleScopeCard(access: access, locations: locations),
          const SizedBox(height: 14),
          _AdministrationActionCard(
            key: const Key('administration-create-need'),
            semanticLabel: 'Créer un besoin',
            icon: Icons.add_circle_rounded,
            title: 'Créer un besoin',
            description: 'Publier les renforts nécessaires.',
            primary: true,
            onTap: () => _openCreateNeed(context),
          ),
          if (access.isCoordinator) ...[
            const SizedBox(height: 12),
            _AdministrationActionCard(
              key: const Key('admin-invitations-entry'),
              semanticLabel: 'Ouvrir la gestion des responsables',
              icon: Icons.admin_panel_settings_outlined,
              title: 'Responsables',
              description: 'Invitations et accès aux centres',
              onTap: () => _openInvitations(context),
            ),
          ],
          const SizedBox(height: 12),
          _AdministrationActionCard(
            key: const Key('administration-statistics'),
            semanticLabel: 'Ouvrir les statistiques',
            icon: Icons.bar_chart_rounded,
            title: 'Statistiques',
            description: 'Consulter la couverture opérationnelle.',
            onTap: onOpenStatistics,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('administration-sign-out'),
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }
}

class _ResponsibleScopeCard extends StatelessWidget {
  const _ResponsibleScopeCard({required this.access, required this.locations});

  final ResponsibleAccess access;
  final List<ResponsePlace> locations;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppColors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Votre périmètre',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (access.isCoordinator)
                    const Text(
                      'Tous les lieux de Gironde',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else
                    Text(
                      _siteManagerScope(locations),
                      key: const Key('responsible-scope-label'),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
    final foreground = primary ? Colors.white : AppColors.navy;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Card(
        color: primary ? AppColors.navy : Colors.white,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: primary ? AppColors.orange : AppColors.navy,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          description,
                          style: TextStyle(
                            color: primary
                                ? Colors.white70
                                : AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: foreground),
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
