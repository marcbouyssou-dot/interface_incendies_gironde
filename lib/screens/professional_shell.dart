import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../models/volunteer_profile.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../services/professional_verification_service.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/native_interactions.dart';
import '../widgets/professional_page_header.dart';
import '../widgets/v5_bottom_navigation.dart';
import '../widgets/v5_controls.dart';
import '../widgets/v5_form_system.dart';
import 'create_need_screen.dart';
import 'development_settings_screen.dart';
import 'professional_engagements_screen.dart';
import 'professional_profile_screen.dart';
import 'notification_center_screen.dart';
import 'slots_screen.dart';

class ProfessionalShell extends StatefulWidget {
  const ProfessionalShell({
    super.key,
    this.initialIndex = 0,
    this.verificationService = const FakeProfessionalVerificationService(),
  }) : assert(initialIndex >= 0 && initialIndex < 3);

  final int initialIndex;
  final ProfessionalVerificationService verificationService;

  @override
  State<ProfessionalShell> createState() => _ProfessionalShellState();
}

class _ProfessionalShellState extends State<ProfessionalShell> {
  late int _currentIndex;
  final List<Widget?> _screens = List<Widget?>.filled(3, null);
  Object? _repositoryIdentity;
  Future<VolunteerProfile?>? _profile;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens[_currentIndex] = _createScreen(_currentIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    if (!identical(repository, _repositoryIdentity)) {
      _repositoryIdentity = repository;
      _profile = repository.getVolunteerProfile();
    }
  }

  Widget _createScreen(int index) => switch (index) {
    0 => const SlotsScreen(professionalJourney: true),
    1 => const ProfessionalEngagementsScreen(),
    2 => ProfessionalProfileScreen(
      onOpenResponsibleAccess: _openResponsibleAccess,
      onOpenSettings: _openSettings,
      onOpenNotifications: _openNotifications,
      onSignOut: _signOut,
      verificationService: widget.verificationService,
    ),
    _ => throw RangeError.index(index, _screens),
  };

  void _selectTab(int index) {
    setState(() {
      if (index != 2) {
        _profile = RepositoryScope.of(context).getVolunteerProfile();
      }
      _screens[index] ??= _createScreen(index);
      _currentIndex = index;
    });
  }

  Widget _operationalTabs() => FutureBuilder<VolunteerProfile?>(
    future: _profile,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const V5LoadingState(label: 'Chargement du profil…');
      }
      if (snapshot.data?.hasVerifiedProfessionalIdentity != true) {
        return _ProfessionalDiscoveryState(
          missions: _currentIndex == 0,
          onCompleteProfile: () => _selectTab(2),
        );
      }
      return NativeTabView(
        index: _currentIndex,
        children: List.generate(
          _screens.length,
          (index) => _screens[index] ?? const SizedBox.shrink(),
        ),
      );
    },
  );

  void _openResponsibleAccess() {
    final repository = RepositoryScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: ResponsibleLogin(
              repository: repository,
              onSignedIn: () {
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    final liveData = LiveCoordinationDataScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const DevelopmentSettingsScreen(),
        ),
      ),
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      AppPageRoute<void>(builder: (_) => const NotificationCenterScreen()),
    );
  }

  Future<void> _signOut() => RepositoryScope.of(context).signOutResponsible();

  @override
  Widget build(BuildContext context) {
    return RolePreviewDebugOverlay(
      journeyLabel: 'Professionnel de santé',
      child: Scaffold(
        backgroundColor: context.v5Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: _currentIndex == 2 ? _screens[2]! : _operationalTabs(),
        ),
        bottomNavigationBar: V5BottomNavigation(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
        ),
      ),
    );
  }
}

class _ProfessionalDiscoveryState extends StatelessWidget {
  const _ProfessionalDiscoveryState({
    required this.missions,
    required this.onCompleteProfile,
  });

  final bool missions;
  final VoidCallback onCompleteProfile;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ColoredBox(
      color: colors.canvas,
      child: SingleChildScrollView(
        key: Key(
          missions
              ? 'professional-missions-discovery'
              : 'professional-engagements-discovery',
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MobSanteJourneyHeader(
                    journey: MobSanteJourney.professional,
                    pageTitle: missions
                        ? 'Des missions ont besoin de professionnels comme vous'
                        : 'Vos engagements apparaîtront ici',
                    pageTitleKey: const Key('professional-page-title'),
                  ),
                  const SizedBox(height: V5Spacing.md),
                  if (missions) ...[
                    Text(
                      'MobSanté met en relation les professionnels de santé '
                      'avec les besoins sur le terrain.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: V5Spacing.md),
                  ],
                  Text(
                    missions
                        ? 'Finalisez votre profil professionnel pour découvrir '
                              'les missions correspondant à votre profession, '
                              'consulter leurs informations pratiques et vous engager.'
                        : 'Une fois votre profil professionnel vérifié, vous '
                              'pourrez vous engager sur des missions et retrouver '
                              'ici toutes les informations pratiques.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: V5Spacing.md),
                  FilledButton(
                    key: const Key('professional-verification-cta'),
                    onPressed: onCompleteProfile,
                    child: const Text('Compléter mon profil'),
                  ),
                  if (missions) ...[
                    const SizedBox(height: V5Spacing.lg),
                    V5Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Comment ça marche',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: V5Spacing.sm),
                          const Text(
                            'Les missions sont proposées selon votre '
                            'profession et vos disponibilités.',
                          ),
                          const SizedBox(height: V5Spacing.xs),
                          const Text(
                            'Vous pouvez consulter leurs informations '
                            'pratiques avant de vous engager.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
