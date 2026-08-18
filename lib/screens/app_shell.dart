import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../models/mobilization.dart';
import '../models/need.dart';
import '../perspective/cross_role_perspective.dart';
import '../models/platform_administrator_access.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/operation_read_repository.dart';
import '../repositories/repository_scope.dart';
import '../repositories/platform_runtime.dart';
import '../repositories/platform_read_repository.dart';
import '../services/professional_verification_service.dart';
import '../services/accessible_mobilizations_provider.dart';
import '../services/operational_context_provider.dart';
import '../theme/app_theme.dart';
import '../theme/v5_foundation.dart';
import '../utils/system_theme.dart';
import '../utils/app_page_route.dart';
import '../utils/switch_latest.dart';
import '../widgets/v5_bottom_navigation.dart';
import '../widgets/perspective_switcher.dart';
import 'administration_dashboard_screen.dart';
import 'coordinator_shell.dart';
import 'coordination_screen.dart';
import 'create_need_screen.dart';
import 'places_screen.dart';
import 'platform_admin_shell.dart';
import 'professional_shell.dart';
import 'responsible_shell.dart';
import 'slots_screen.dart';
import 'notification_center_screen.dart';

enum _AppJourney { professional, responsible, coordinator, platformAdmin }

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialIndex = 0,
    this.useLegacyCoordinatorShellForTesting = false,
    this.professionalVerificationService =
        const FakeProfessionalVerificationService(),
    this.platformRuntime,
    this.initialNotificationId,
  });

  final int initialIndex;
  final ProfessionalVerificationService professionalVerificationService;
  final PlatformRuntime? platformRuntime;
  final String? initialNotificationId;

  /// Never enabled by the application entry point outside regression tests.
  final bool useLegacyCoordinatorShellForTesting;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _legacyCurrentIndex;
  final List<Widget?> _legacyScreens = List<Widget?>.filled(4, null);
  CoordinationRepository? _repository;
  LiveCoordinationData? _liveData;
  LiveCoordinationData? _platformAdminProfessionalPreviewData;
  LiveCoordinationData? _platformAdminResponsiblePreviewData;
  LiveCoordinationData? _platformAdminCoordinatorPreviewData;
  String? _platformAdminResponsibleLocationId;
  StreamSubscription<ResponsibleAccess?>? _accessSubscription;
  StreamSubscription<List<CoordinationNeed>>? _missionsWarmupSubscription;
  StreamSubscription<List<ResponsePlace>>? _locationsWarmupSubscription;
  StreamSubscription<PlatformAdministratorAccess?>?
  _platformAdministratorSubscription;
  ResponsibleAccess? _access;
  PlatformAdministratorAccess? _platformAdministrator;
  bool _accessResolved = false;
  bool _accessResolutionFailed = false;
  bool _platformAdministratorResolved = false;
  bool _showPlatformAdminAuthentication = false;
  bool _applicationRevealScheduled = false;
  bool _initialNotificationScheduled = false;

  @override
  void initState() {
    super.initState();
    _legacyCurrentIndex = widget.initialIndex.clamp(0, 3);
    if (widget.useLegacyCoordinatorShellForTesting) {
      _legacyScreens[_legacyCurrentIndex] = _createLegacyScreen(
        _legacyCurrentIndex,
      );
    }
    _watchPlatformAdministrator();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.platformRuntime, widget.platformRuntime)) {
      _watchPlatformAdministrator();
    }
  }

  void _watchPlatformAdministrator() {
    unawaited(_platformAdministratorSubscription?.cancel());
    _platformAdministrator = null;
    final runtime = widget.platformRuntime;
    if (runtime == null) {
      _platformAdministratorResolved = true;
      return;
    }
    _platformAdministratorResolved = false;
    markStartupEvent('mobsante-platform-route-start');
    _platformAdministratorSubscription = runtime
        .platformAdministrationReadRepository
        .watchCurrentAdministrator()
        .listen(
          _handlePlatformAdministrator,
          onError: (_, _) => _handlePlatformAdministratorError(),
        );
  }

  void _handlePlatformAdministrator(PlatformAdministratorAccess? access) {
    if (!mounted) return;
    markStartupEvent('mobsante-platform-route-ready');
    setState(() {
      _platformAdministrator = access;
      _platformAdministratorResolved = true;
    });
  }

  void _handlePlatformAdministratorError() {
    if (!mounted) return;
    markStartupEvent('mobsante-platform-route-ready');
    setState(() {
      _platformAdministrator = null;
      _platformAdministratorResolved = true;
    });
  }

  Future<void> _signOutPlatformAdministrator() async {
    CrossRolePerspectiveScope.of(context).showActualRole();
    await _repository!.signOutResponsible();
    if (mounted) {
      setState(() => _showPlatformAdminAuthentication = true);
    }
  }

  void _handlePlatformAdminSignedIn() {
    if (mounted) {
      setState(() => _showPlatformAdminAuthentication = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    if (!identical(repository, _repository)) {
      unawaited(_accessSubscription?.cancel());
      unawaited(_missionsWarmupSubscription?.cancel());
      unawaited(_locationsWarmupSubscription?.cancel());
      _liveData?.dispose();
      _disposePlatformAdminPreviewData();
      _repository = repository;
      _liveData = LiveCoordinationData(repository);
      markStartupEvent('mobsante-role-route-start');
      _accessSubscription = _liveData!.watchResponsibleAccess().listen(
        _handleAccess,
        onError: (_, _) => _handleAccessError(),
      );
      _prewarmMissionData();
    }
  }

  @override
  void dispose() {
    unawaited(_accessSubscription?.cancel());
    unawaited(_missionsWarmupSubscription?.cancel());
    unawaited(_locationsWarmupSubscription?.cancel());
    unawaited(_platformAdministratorSubscription?.cancel());
    _liveData?.dispose();
    unawaited(_platformAdminProfessionalPreviewData?.dispose());
    unawaited(_platformAdminResponsiblePreviewData?.dispose());
    unawaited(_platformAdminCoordinatorPreviewData?.dispose());
    super.dispose();
  }

  void _disposePlatformAdminPreviewData() {
    unawaited(_platformAdminProfessionalPreviewData?.dispose());
    unawaited(_platformAdminResponsiblePreviewData?.dispose());
    unawaited(_platformAdminCoordinatorPreviewData?.dispose());
    _platformAdminProfessionalPreviewData = null;
    _platformAdminResponsiblePreviewData = null;
    _platformAdminCoordinatorPreviewData = null;
    _platformAdminResponsibleLocationId = null;
  }

  Stream<List<CoordinationNeed>> _watchAdministrativeMissions(
    PlatformReadRepository platformRepository,
    MultiMobilizationCoordinationReadRepository repository,
  ) => switchLatest(platformRepository.watchMobilizations(), (mobilizations) {
    final ids = mobilizations
        .where((item) => item.status == MobilizationStatus.active)
        .map((item) => item.id)
        .toSet();
    return repository.watchMissionsForMobilizations(ids);
  });

  LiveCoordinationData _adminProfessionalPreviewData({
    PlatformReadRepository? platformRepository,
    MultiMobilizationCoordinationReadRepository? repository,
  }) => _platformAdminProfessionalPreviewData ??= LiveCoordinationData(
    _repository!,
    responsibleAccessOverride: () =>
        _previewContextStream<ResponsibleAccess?>(null),
    missionsOverride: platformRepository == null || repository == null
        ? null
        : () => _watchAdministrativeMissions(platformRepository, repository),
  );

  LiveCoordinationData _adminResponsiblePreviewData(
    String? locationId, {
    MultiMobilizationCoordinationReadRepository? repository,
  }) {
    if (_platformAdminResponsiblePreviewData != null &&
        _platformAdminResponsibleLocationId == locationId) {
      return _platformAdminResponsiblePreviewData!;
    }
    unawaited(_platformAdminResponsiblePreviewData?.dispose());
    _platformAdminResponsibleLocationId = locationId;
    return _platformAdminResponsiblePreviewData = LiveCoordinationData(
      _repository!,
      responsibleAccessOverride: () => _previewContextStream(
        ResponsibleAccess(
          uid: _platformAdministrator?.uid ?? 'platform-administrator',
          role: ResponsibleRole.siteManager,
          locationIds: locationId == null ? const {} : {locationId},
          active: true,
        ),
      ),
      missionsOverride: repository == null || locationId == null
          ? () => Stream<List<CoordinationNeed>>.value(const [])
          : () => repository.watchMissionsForLocations({locationId}),
    );
  }

  LiveCoordinationData _adminCoordinatorPreviewData({
    PlatformReadRepository? platformRepository,
    MultiMobilizationCoordinationReadRepository? repository,
  }) => _platformAdminCoordinatorPreviewData ??= LiveCoordinationData(
    _repository!,
    responsibleAccessOverride: () => _previewContextStream(
      ResponsibleAccess(
        uid: _platformAdministrator?.uid ?? 'platform-administrator',
        role: ResponsibleRole.coordinator,
        locationIds: const {},
        active: true,
      ),
    ),
    missionsOverride: platformRepository == null || repository == null
        ? null
        : () => _watchAdministrativeMissions(platformRepository, repository),
  );

  Stream<T> _previewContextStream<T>(T value) =>
      Stream<T>.multi((controller) => controller.add(value));

  void _handleAccess(ResponsibleAccess? access) {
    if (!mounted) return;
    markStartupEvent('mobsante-role-route-ready');
    setState(() {
      _access = access;
      _accessResolved = true;
      _accessResolutionFailed = false;
    });
  }

  void _handleAccessError() {
    if (!mounted) return;
    markStartupEvent('mobsante-role-route-ready');
    setState(() {
      _access = null;
      _accessResolved = true;
      _accessResolutionFailed = true;
    });
  }

  void _prewarmMissionData() {
    _missionsWarmupSubscription = _liveData!.watchMissions().listen((_) {
      markStartupEvent('mobsante-missions-data-ready');
      unawaited(_missionsWarmupSubscription?.cancel());
    }, onError: (_, _) => unawaited(_missionsWarmupSubscription?.cancel()));
    _locationsWarmupSubscription = _liveData!.watchLocations().listen((_) {
      markStartupEvent('mobsante-locations-data-ready');
      unawaited(_locationsWarmupSubscription?.cancel());
    }, onError: (_, _) => unawaited(_locationsWarmupSubscription?.cancel()));
  }

  void _scheduleApplicationReveal() {
    if (_applicationRevealScheduled) return;
    _applicationRevealScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      markStartupEvent('mobsante-app-shell-ready');
      revealApplication();
    });
  }

  Widget _createLegacyScreen(int index) => switch (index) {
    0 => const SlotsScreen(),
    1 => AdministrationDashboardScreen(
      onViewMission: () => _selectLegacyTab(0),
      onOpenStatistics: () => _selectLegacyTab(2),
      onRetryAccess: _refreshLiveData,
    ),
    2 => const CoordinationScreen(),
    3 => const PlacesScreen(),
    _ => throw RangeError.index(index, _legacyScreens),
  };

  void _selectLegacyTab(int index) {
    setState(() {
      _legacyScreens[index] ??= _createLegacyScreen(index);
      _legacyCurrentIndex = index;
    });
  }

  void _refreshLiveData() {
    final previous = _liveData;
    unawaited(_accessSubscription?.cancel());
    final next = LiveCoordinationData(_repository!);
    setState(() {
      _liveData = next;
      _access = null;
      _accessResolved = false;
      _accessResolutionFailed = false;
    });
    _accessSubscription = next.watchResponsibleAccess().listen(
      _handleAccess,
      onError: (_, _) => _handleAccessError(),
    );
    if (previous != null) unawaited(previous.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final previewMode = kDebugMode
        ? RolePreviewScope.of(context).mode
        : RolePreviewMode.automatic;
    final perspectiveController = CrossRolePerspectiveScope.of(context);
    final automaticJourney = !_accessResolved || _accessResolutionFailed
        ? _AppJourney.coordinator
        : _access == null
        ? _AppJourney.professional
        : _access!.roles.contains(ResponsibleRole.coordinator)
        ? _AppJourney.coordinator
        : _access!.roles.contains(ResponsibleRole.siteManager)
        ? _AppJourney.responsible
        : _AppJourney.coordinator;
    final journey = switch (previewMode) {
      RolePreviewMode.professional => _AppJourney.professional,
      RolePreviewMode.responsible => _AppJourney.responsible,
      RolePreviewMode.coordinator => _AppJourney.coordinator,
      RolePreviewMode.automatic => automaticJourney,
    };
    final isPlatformAdministrator =
        _platformAdministratorResolved &&
        (_platformAdministrator?.active ?? false);
    var displayedJourney = isPlatformAdministrator
        ? switch (perspectiveController.perspective) {
            CrossRolePerspective.actual => _AppJourney.platformAdmin,
            CrossRolePerspective.professional => _AppJourney.professional,
            CrossRolePerspective.responsible => _AppJourney.responsible,
            CrossRolePerspective.coordinator => _AppJourney.coordinator,
          }
        : journey;
    var crossRolePreview = false;
    crossRolePreview =
        isPlatformAdministrator &&
        perspectiveController.perspective != CrossRolePerspective.actual;
    final multiRuntime = widget.platformRuntime is MultiOperationPlatformRuntime
        ? widget.platformRuntime! as MultiOperationPlatformRuntime
        : null;
    final multiReadRepository =
        _repository is MultiMobilizationCoordinationReadRepository
        ? _repository! as MultiMobilizationCoordinationReadRepository
        : null;
    final previewReadRepository =
        crossRolePreview && multiReadRepository != null
        ? _PlatformAdminPreviewMissionRepository(multiReadRepository)
        : multiReadRepository;
    final multiMutationRepository =
        _repository is MultiMobilizationCoordinationMutationRepository
        ? _repository! as MultiMobilizationCoordinationMutationRepository
        : null;
    if (!_platformAdministratorResolved || !_accessResolved) {
      return LiveCoordinationDataScope(
        data: _liveData!,
        child: const _PlatformRouteLoading(),
      );
    }
    _scheduleApplicationReveal();
    if (displayedJourney != _AppJourney.platformAdmin) {
      _scheduleInitialNotification();
    }
    if (_showPlatformAdminAuthentication) {
      return LiveCoordinationDataScope(
        data: _liveData!,
        child: Scaffold(
          key: const Key('platform-admin-authentication'),
          backgroundColor: context.v5Colors.canvas,
          body: SafeArea(
            child: ResponsibleLogin(
              repository: _repository!,
              onSignedIn: _handlePlatformAdminSignedIn,
            ),
          ),
        ),
      );
    }
    final displayedShell = switch (displayedJourney) {
      _AppJourney.professional => ProfessionalShell(
        key: ValueKey(crossRolePreview ? 'admin-professional' : 'professional'),
        initialIndex: widget.initialIndex == 1 ? 2 : 0,
        verificationService: widget.professionalVerificationService,
      ),
      _AppJourney.responsible => ResponsibleShell(
        key: ValueKey(crossRolePreview ? 'admin-responsible' : 'responsible'),
        initialIndex: widget.initialIndex.clamp(0, 3),
        previewLocationId: crossRolePreview
            ? perspectiveController.responsibleLocationId
            : null,
        showPreviewBanner: !crossRolePreview,
      ),
      _AppJourney.coordinator =>
        widget.useLegacyCoordinatorShellForTesting
            ? _buildLegacyShell()
            : CoordinatorShell(
                initialIndex: widget.initialIndex.clamp(0, 3),
                accessibleMobilizationsProvider: crossRolePreview
                    ? multiRuntime == null
                          ? null
                          : _PlatformAdminAccessibleMobilizationsProvider(
                              widget.platformRuntime!.platformReadRepository,
                            )
                    : multiRuntime?.accessibleMobilizationsProvider,
                multiMobilizationRepository: previewReadRepository,
                multiMobilizationMutationRepository: crossRolePreview
                    ? null
                    : multiMutationRepository,
                operationRepository: multiRuntime?.operationReadRepository,
              ),
      _AppJourney.platformAdmin => PlatformAdminShell(
        initialIndex: widget.initialIndex == 3 ? 1 : 0,
        platformRepository: widget.platformRuntime!.platformReadRepository,
        mobilizationProvider:
            widget.platformRuntime!.currentMobilizationProvider,
        administrationRepository:
            widget.platformRuntime!.platformAdministrationReadRepository,
        administrationService:
            widget.platformRuntime!.platformAdministrationService,
        operationRepository: multiRuntime?.operationReadRepository,
        missionRepository: multiReadRepository,
        onSignOut: _signOutPlatformAdministrator,
      ),
    };
    final previewedJourney = switch (perspectiveController.perspective) {
      CrossRolePerspective.professional => 'Professionnel',
      CrossRolePerspective.responsible => 'Responsable',
      CrossRolePerspective.coordinator => 'Coordinateur',
      CrossRolePerspective.actual => 'Administrateur',
    };
    final framedShell = crossRolePreview
        ? _PlatformAdminPreviewFrame(
            journey: previewedJourney,
            onExit: perspectiveController.showActualRole,
            child: displayedShell,
          )
        : displayedShell;
    final contextAwareShell = multiRuntime == null
        ? framedShell
        : OperationalContextScope(
            provider: crossRolePreview
                ? _PlatformAdminOperationalContextProvider(
                    widget.platformRuntime!.platformReadRepository,
                    multiRuntime.operationReadRepository,
                  )
                : multiRuntime.operationalContextProvider,
            child: framedShell,
          );
    return LiveCoordinationDataScope(
      data: !crossRolePreview
          ? _liveData!
          : switch (displayedJourney) {
              _AppJourney.professional => _adminProfessionalPreviewData(
                platformRepository:
                    widget.platformRuntime?.platformReadRepository,
                repository: previewReadRepository,
              ),
              _AppJourney.responsible => _adminResponsiblePreviewData(
                perspectiveController.responsibleLocationId,
                repository: previewReadRepository,
              ),
              _AppJourney.coordinator => _adminCoordinatorPreviewData(
                platformRepository:
                    widget.platformRuntime?.platformReadRepository,
                repository: previewReadRepository,
              ),
              _AppJourney.platformAdmin => _liveData!,
            },
      child: contextAwareShell,
    );
  }

  void _scheduleInitialNotification() {
    final notificationId = widget.initialNotificationId;
    if (_initialNotificationScheduled ||
        notificationId == null ||
        notificationId.isEmpty) {
      return;
    }
    _initialNotificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        AppPageRoute<void>(
          builder: (_) =>
              NotificationCenterScreen(initialNotificationId: notificationId),
        ),
      );
    });
  }

  Widget _buildLegacyShell() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _legacyCurrentIndex,
          children: List.generate(
            _legacyScreens.length,
            (index) => _legacyScreens[index] ?? const SizedBox.shrink(),
          ),
        ),
      ),
      bottomNavigationBar: V5BottomBar(
        selectedIndex: _legacyCurrentIndex,
        onDestinationSelected: _selectLegacyTab,
        selectedColor: AppColors.orange,
        destinations: const [
          V5BottomBarDestination(
            icon: Icons.local_fire_department_outlined,
            selectedIcon: Icons.local_fire_department_rounded,
            label: 'Missions',
          ),
          V5BottomBarDestination(
            icon: Icons.add_circle_outline_rounded,
            selectedIcon: Icons.add_circle_rounded,
            label: 'Déclarer',
          ),
          V5BottomBarDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: 'Statistiques',
          ),
          V5BottomBarDestination(
            icon: Icons.location_on_outlined,
            selectedIcon: Icons.location_on_rounded,
            label: 'Plus',
          ),
        ],
      ),
    );
  }
}

class _PlatformAdminPreviewFrame extends StatelessWidget {
  const _PlatformAdminPreviewFrame({
    required this.journey,
    required this.onExit,
    required this.child,
  });

  final String journey;
  final VoidCallback onExit;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.v5Colors.canvas,
    child: Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: CrossRolePreviewBanner(
              label: 'Administrateur',
              title: 'Prévisualisation $journey',
              exitLabel: 'Retour Administrateur',
              onExit: onExit,
              compact: true,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}

class _PlatformAdminAccessibleMobilizationsProvider
    implements AccessibleMobilizationsProvider {
  const _PlatformAdminAccessibleMobilizationsProvider(this.repository);

  final PlatformReadRepository repository;

  @override
  Stream<List<Mobilization>> watchAccessibleMobilizations() =>
      repository.watchMobilizations().map(
        (items) => items
            .where((item) => item.status == MobilizationStatus.active)
            .toList(growable: false),
      );
}

/// Les Rules évaluent l'identité Firebase réelle, qui reste Administrateur,
/// et non la perspective affichée. Les missions actives sont déjà lisibles par
/// la session professionnelle anonyme ; la prévisualisation part donc de ce
/// flux autorisé puis applique localement le périmètre demandé.
class _PlatformAdminPreviewMissionRepository
    implements MultiMobilizationCoordinationReadRepository {
  const _PlatformAdminPreviewMissionRepository(this.source);

  final MultiMobilizationCoordinationReadRepository source;

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() =>
      source.watchAllActiveMissions();

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(
    Set<String> locationIds,
  ) => _filter(
    locationIds,
    (mission, ids) =>
        mission.locationId != null && ids.contains(mission.locationId),
  );

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> mobilizationIds,
  ) => _filter(
    mobilizationIds,
    (mission, ids) => ids.contains(mission.mobilizationId),
  );

  Stream<List<CoordinationNeed>> _filter(
    Set<String> ids,
    bool Function(CoordinationNeed mission, Set<String> ids) includes,
  ) {
    if (ids.isEmpty) return Stream.value(const []);
    return source.watchAllActiveMissions().map(
      (missions) => missions
          .where((mission) => includes(mission, ids))
          .toList(growable: false),
    );
  }
}

class _PlatformAdminOperationalContextProvider
    implements OperationalContextProvider {
  const _PlatformAdminOperationalContextProvider(
    this.platformRepository,
    this.operationRepository,
  );

  final PlatformReadRepository platformRepository;
  final OperationReadRepository operationRepository;

  @override
  Stream<OperationalMissionContext?> watchForMobilization(
    String mobilizationId,
  ) => switchLatest(
    platformRepository.watchMobilizations(includeInactive: true),
    (mobilizations) {
      Mobilization? mobilization;
      for (final item in mobilizations) {
        if (item.id == mobilizationId) {
          mobilization = item;
          break;
        }
      }
      if (mobilization == null) {
        return Stream<OperationalMissionContext?>.value(null);
      }
      final selectedMobilization = mobilization;
      final operationId = selectedMobilization.operationId;
      if (operationId == null) {
        return Stream.value(
          OperationalMissionContext(
            mobilizationId: selectedMobilization.id,
            mobilizationName: selectedMobilization.name,
          ),
        );
      }
      return operationRepository
          .watchOperation(operationId)
          .map(
            (operation) => operation == null
                ? null
                : OperationalMissionContext(
                    mobilizationId: selectedMobilization.id,
                    mobilizationName: selectedMobilization.name,
                    operationId: operation.id,
                    operationName: operation.name,
                    operationType: operation.type,
                  ),
          );
    },
  );
}

class _PlatformRouteLoading extends StatelessWidget {
  const _PlatformRouteLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.v5Colors.canvas,
    body: const SafeArea(
      child: Center(child: CircularProgressIndicator.adaptive()),
    ),
  );
}
