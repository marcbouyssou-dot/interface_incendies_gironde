import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../models/responsible_account.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/responsible_access_administration_repository.dart';
import '../repositories/responsible_access_administration_repository_scope.dart';
import '../theme/coordinator_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/perspective_switcher.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/v5_secondary_navigation.dart';
import 'coordinator_overview_screen.dart';

class CoordinatorMoreScreen extends StatefulWidget {
  const CoordinatorMoreScreen({
    super.key,
    required this.onOpenStatistics,
    required this.onOpenSettings,
    required this.onOpenProfile,
    required this.onSignOut,
  });

  final VoidCallback onOpenStatistics;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenProfile;
  final Future<void> Function() onSignOut;

  @override
  State<CoordinatorMoreScreen> createState() => _CoordinatorMoreScreenState();
}

class _CoordinatorMoreScreenState extends State<CoordinatorMoreScreen> {
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _access;
  Stream<List<ResponsePlace>>? _locations;
  bool _signingOut = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (identical(liveData, _liveData)) return;
    _liveData = liveData;
    _access = liveData.watchResponsibleAccess();
    _locations = liveData.watchLocations();
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.onSignOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ResponsibleAccess?>(
      stream: _access,
      builder: (context, accessSnapshot) => StreamBuilder<List<ResponsePlace>>(
        stream: _locations,
        builder: (context, locationsSnapshot) {
          if (accessSnapshot.hasError || locationsSnapshot.hasError) {
            return const CoordinatorDataUnavailable(
              message: 'Les accès Coordinateur sont indisponibles.',
            );
          }
          if (!locationsSnapshot.hasData) {
            return const CoordinatorLoadingState();
          }
          return _CoordinatorMoreContent(
            access: accessSnapshot.data,
            locations: locationsSnapshot.data!,
            signingOut: _signingOut,
            onOpenStatistics: widget.onOpenStatistics,
            onOpenSettings: widget.onOpenSettings,
            onOpenProfile: widget.onOpenProfile,
            onSignOut: _signOut,
          );
        },
      ),
    );
  }
}

class _CoordinatorMoreContent extends StatelessWidget {
  const _CoordinatorMoreContent({
    required this.access,
    required this.locations,
    required this.signingOut,
    required this.onOpenStatistics,
    required this.onOpenSettings,
    required this.onOpenProfile,
    required this.onSignOut,
  });

  final ResponsibleAccess? access;
  final List<ResponsePlace> locations;
  final bool signingOut;
  final VoidCallback onOpenStatistics;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenProfile;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final identity = CoordinatorIdentity.of(context);
    return ColoredBox(
      color: colors.canvas,
      child: ListView(
        key: const PageStorageKey('coordinator-more'),
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const MobSantePageHeader(
                    title: 'Coordination',
                    subtitle:
                        'Perspectives, statistiques, réglages et administration.',
                  ),
                  const SizedBox(height: V5Spacing.xxl),
                  if (access?.isCoordinator == true)
                    CoordinatorPerspectiveSection(
                      access: access!,
                      locations: locations,
                      accentColor: identity.accent,
                    )
                  else
                    Text(
                      'Cette perspective est réservée aux Coordinateurs.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  const SizedBox(height: V5Spacing.xxxl),
                  _MoreGroup(
                    children: [
                      if (access?.isCoordinator == true)
                        _MoreRow(
                          key: const Key('administration-statistics'),
                          icon: Icons.insights_outlined,
                          label: 'Statistiques globales',
                          onTap: onOpenStatistics,
                        ),
                      _MoreRow(
                        key: const Key('open-development-settings'),
                        icon: Icons.settings_outlined,
                        label: 'Réglages',
                        onTap: onOpenSettings,
                      ),
                      _MoreRow(
                        key: const Key('coordinator-profile'),
                        icon: Icons.person_outline_rounded,
                        label: 'Profil',
                        onTap: onOpenProfile,
                      ),
                    ],
                  ),
                  const SizedBox(height: V5Spacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      key: const Key('administration-sign-out'),
                      onPressed: signingOut ? null : onSignOut,
                      style: TextButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: colors.textSecondary,
                      ),
                      child: Text(
                        signingOut ? 'Déconnexion…' : 'Se déconnecter',
                      ),
                    ),
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

class _MoreGroup extends StatelessWidget {
  const _MoreGroup({required this.children});

  final List<Widget> children;

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
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              Divider(
                height: 1,
                thickness: 0.5,
                indent: 54,
                color: colors.outline,
              ),
          ],
        ],
      ),
    );
  }
}

class _MoreRow extends StatelessWidget {
  const _MoreRow({
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
    final colors = context.v5Colors;
    final identity = CoordinatorIdentity.of(context);
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

class CoordinatorProfileScreen extends StatefulWidget {
  const CoordinatorProfileScreen({super.key});

  @override
  State<CoordinatorProfileScreen> createState() =>
      _CoordinatorProfileScreenState();
}

class _CoordinatorProfileScreenState extends State<CoordinatorProfileScreen> {
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _access;
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
    }
    if (!identical(accountsRepository, _accountsRepository)) {
      _accountsRepository = accountsRepository;
      _accounts = accountsRepository.listAccounts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return StreamBuilder<ResponsibleAccess?>(
      stream: _access,
      builder: (context, accessSnapshot) =>
          FutureBuilder<List<ResponsibleAccount>>(
            future: _accounts,
            builder: (context, accountsSnapshot) {
              final access = accessSnapshot.data;
              final account = accountsSnapshot.data
                  ?.where((candidate) => candidate.uid == access?.uid)
                  .firstOrNull;
              final displayName = account?.identityLabel ?? 'Coordinateur';
              return Scaffold(
                backgroundColor: colors.canvas,
                appBar: const V5SecondaryNavigationBar(title: 'Profil'),
                body: SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(V5Spacing.xl),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(V5Spacing.lg),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: BorderRadius.circular(V5Radius.card),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                key: const Key('coordinator-profile-name'),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: V5Spacing.xs),
                              Text(
                                'Coordinateur territorial',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: V5Spacing.xxs),
                              Text(
                                'Périmètre départemental',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (account?.email case final email?) ...[
                                const SizedBox(height: V5Spacing.xs),
                                Text(
                                  email,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}
