import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../models/mobilization.dart';
import '../models/need.dart';
import '../perspective/cross_role_perspective.dart';
import '../models/platform_administrator_access.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/admin_invitation_repository_scope.dart';
import '../repositories/location_administration_repository_scope.dart';
import '../repositories/location_read_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/operation_read_repository.dart';
import '../repositories/organization_scoped_engagement_read_repository.dart';
import '../repositories/organization_scoped_mission_read_repository.dart';
import '../repositories/organization_scoped_location_read_repository.dart';
import '../repositories/organization_scoped_operation_read_repository.dart';
import '../repositories/organization_scoped_platform_read_repository.dart';
import '../repositories/platform_actor_read_repository.dart';
import '../repositories/repository_scope.dart';
import '../repositories/platform_runtime.dart';
import '../repositories/platform_read_repository.dart';
import '../repositories/read_only_preview_coordination_repository.dart';
import '../repositories/responsible_access_administration_repository_scope.dart';
import '../services/professional_verification_service.dart';
import '../services/accessible_mobilizations_provider.dart';
import '../services/current_mobilization_provider.dart';
import '../services/operational_context_provider.dart';
import '../services/organization_context_controller.dart';
import '../services/organization_responsible_access_resolver.dart';
import '../services/organization_scoped_accessible_mobilizations_provider.dart';
import '../services/platform_administration_service.dart';
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
  CoordinationRepository? _readOnlyPreviewRepository;
  String? _readOnlyPreviewOperationId;
  String? _platformAdminResponsibleLocationId;
  String? _platformAdminProfessionalOperationId;
  String? _platformAdminResponsibleOperationId;
  String? _platformAdminCoordinatorOperationId;
  StreamSubscription<ResponsibleAccess?>? _accessSubscription;
  StreamSubscription<String?>? _administrativeIdentitySubscription;
  StreamSubscription<List<CoordinationNeed>>? _missionsWarmupSubscription;
  StreamSubscription<List<ResponsePlace>>? _locationsWarmupSubscription;
  StreamSubscription<PlatformAdministratorAccess?>?
  _platformAdministratorSubscription;
  ValueListenable<PlatformAdministrationSessionState>?
  _platformAdministrationSessionState;
  OrganizationContextController? _organizationContextController;
  OperationReadRepository? _rawOperationRepository;
  OrganizationContextController? _operationRepositoryContext;
  OperationReadRepository? _organizationScopedOperationRepository;
  PlatformReadRepository? _rawPlatformRepository;
  OperationReadRepository? _platformOperationRepository;
  OrganizationContextController? _platformRepositoryContext;
  PlatformReadRepository? _organizationScopedPlatformRepository;
  PlatformReadRepository? _mobilizationProviderRepository;
  MobilizationContextProvider? _organizationScopedMobilizationProvider;
  AccessibleMobilizationsProvider? _rawAccessibleMobilizationsProvider;
  PlatformReadRepository? _accessibleMobilizationsPlatformRepository;
  OrganizationContextController? _accessibleMobilizationsContext;
  AccessibleMobilizationsProvider?
  _organizationScopedAccessibleMobilizationsProvider;
  MultiMobilizationCoordinationReadRepository? _rawMissionReadRepository;
  PlatformReadRepository? _missionPlatformRepository;
  MultiMobilizationCoordinationReadRepository?
  _organizationScopedMissionReadRepository;
  MissionAccessReadRepository? _engagementMissionRepository;
  MissionEngagementReadRepository? _organizationScopedEngagementReadRepository;
  LocationReadRepository? _rawLocationReadRepository;
  OrganizationContextController? _locationRepositoryContext;
  LocationReadRepository? _organizationScopedLocationReadRepository;
  LocationReadRepository? _platformLocationStreamRepository;
  Stream<List<ResponsePlace>>? _platformLocationStream;
  ResponsibleAccess? _access;
  String? _administrativeUid;
  PlatformAdministratorAccess? _platformAdministrator;
  bool _accessResolved = false;
  bool _accessResolutionFailed = false;
  bool _platformAdministratorResolved = false;
  bool _platformAdministrationSessionExpired = false;
  bool _protectedRouteClosureScheduled = false;
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
    _platformAdministrationSessionState?.removeListener(
      _handlePlatformAdministrationSessionChanged,
    );
    _platformAdministrationSessionState = null;
    _platformAdministrator = null;
    _platformAdministrationSessionExpired = false;
    final runtime = widget.platformRuntime;
    if (runtime == null) {
      _platformAdministratorResolved = true;
      return;
    }
    _platformAdministratorResolved = false;
    final administrationService = runtime.platformAdministrationService;
    if (administrationService is PlatformAdministrationSessionProvider) {
      final sessionProvider =
          administrationService as PlatformAdministrationSessionProvider;
      _platformAdministrationSessionState = sessionProvider.sessionState
        ..addListener(_handlePlatformAdministrationSessionChanged);
    }
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
    final sessionExpired =
        (access?.active ?? false) &&
        _platformAdministrationSessionState?.value ==
            PlatformAdministrationSessionState.expired;
    setState(() {
      _platformAdministrator = access;
      _platformAdministratorResolved = true;
      if (sessionExpired) _platformAdministrationSessionExpired = true;
    });
    _syncOrganizationContext();
    if (sessionExpired) _scheduleProtectedRouteClosure();
  }

  void _handlePlatformAdministrationSessionChanged() {
    if (!mounted) return;
    final expired =
        _platformAdministrationSessionState?.value ==
        PlatformAdministrationSessionState.expired;
    if (!expired) {
      if (_platformAdministrationSessionExpired) {
        setState(() => _platformAdministrationSessionExpired = false);
      }
      return;
    }
    if (!(_platformAdministrator?.active ?? false) ||
        _platformAdministrationSessionExpired) {
      return;
    }
    setState(() => _platformAdministrationSessionExpired = true);
    _scheduleProtectedRouteClosure();
  }

  void _scheduleProtectedRouteClosure() {
    if (_protectedRouteClosureScheduled) return;
    _protectedRouteClosureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _protectedRouteClosureScheduled = false;
      if (!mounted || !_platformAdministrationSessionExpired) return;
      CrossRolePerspectiveScope.of(context).showActualRole();
      Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  void _handlePlatformAdministratorError() {
    if (!mounted) return;
    markStartupEvent('mobsante-platform-route-ready');
    setState(() {
      _platformAdministrator = null;
      _platformAdministratorResolved = true;
    });
    _syncOrganizationContext();
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
    final organizationContextController =
        OrganizationContextScope.maybeControllerOf(context);
    if (!identical(
      organizationContextController,
      _organizationContextController,
    )) {
      _organizationContextController = organizationContextController;
      _syncOrganizationContext();
    }
    final repository = RepositoryScope.rawOf(context);
    if (!identical(repository, _repository)) {
      unawaited(_accessSubscription?.cancel());
      unawaited(_administrativeIdentitySubscription?.cancel());
      unawaited(_missionsWarmupSubscription?.cancel());
      unawaited(_locationsWarmupSubscription?.cancel());
      _liveData?.dispose();
      _disposePlatformAdminPreviewData();
      _repository = repository;
      _administrativeUid = null;
      _readOnlyPreviewRepository = null;
      _readOnlyPreviewOperationId = null;
      _liveData = _createLiveData(repository);
      markStartupEvent('mobsante-role-route-start');
      _accessSubscription = _liveData!.watchResponsibleAccess().listen(
        _handleAccess,
        onError: (_, _) => _handleAccessError(),
      );
      if (repository is AdministrativeIdentityReadRepository) {
        _administrativeIdentitySubscription =
            (repository as AdministrativeIdentityReadRepository)
                .watchAdministrativeUid()
                .listen(
                  _handleAdministrativeUid,
                  onError: (_, _) => _handleAdministrativeUid(null),
                );
      } else {
        _administrativeIdentitySubscription = null;
      }
      _prewarmMissionData();
    }
  }

  @override
  void dispose() {
    unawaited(_accessSubscription?.cancel());
    unawaited(_administrativeIdentitySubscription?.cancel());
    unawaited(_missionsWarmupSubscription?.cancel());
    unawaited(_locationsWarmupSubscription?.cancel());
    unawaited(_platformAdministratorSubscription?.cancel());
    _platformAdministrationSessionState?.removeListener(
      _handlePlatformAdministrationSessionChanged,
    );
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
    _platformAdminProfessionalOperationId = null;
    _platformAdminResponsibleOperationId = null;
    _platformAdminCoordinatorOperationId = null;
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
    CrossRoleOperationContext? operationContext,
  }) {
    if (_platformAdminProfessionalPreviewData != null &&
        _platformAdminProfessionalOperationId ==
            operationContext?.operationId) {
      return _platformAdminProfessionalPreviewData!;
    }
    unawaited(_platformAdminProfessionalPreviewData?.dispose());
    _platformAdminProfessionalOperationId = operationContext?.operationId;
    return _platformAdminProfessionalPreviewData = LiveCoordinationData(
      _repository!,
      responsibleAccessOverride: () =>
          _previewContextStream<ResponsibleAccess?>(null),
      missionsOverride: platformRepository == null || repository == null
          ? null
          : () => _watchAdministrativeMissions(platformRepository, repository),
      administrativeEngagementRepository:
          _contextualizedEngagementReadRepository(repository),
      locationsOverride: operationContext == null
          ? null
          : () => _watchPreviewLocations(operationContext.locationIds),
    );
  }

  LiveCoordinationData _adminResponsiblePreviewData(
    String? locationId, {
    MultiMobilizationCoordinationReadRepository? repository,
    CrossRoleOperationContext? operationContext,
  }) {
    if (_platformAdminResponsiblePreviewData != null &&
        _platformAdminResponsibleLocationId == locationId &&
        _platformAdminResponsibleOperationId == operationContext?.operationId) {
      return _platformAdminResponsiblePreviewData!;
    }
    unawaited(_platformAdminResponsiblePreviewData?.dispose());
    _platformAdminResponsibleLocationId = locationId;
    _platformAdminResponsibleOperationId = operationContext?.operationId;
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
      administrativeEngagementRepository:
          _contextualizedEngagementReadRepository(repository),
      locationsOverride: operationContext == null || locationId == null
          ? null
          : () => _watchPreviewLocations({locationId}),
    );
  }

  LiveCoordinationData _adminCoordinatorPreviewData({
    PlatformReadRepository? platformRepository,
    MultiMobilizationCoordinationReadRepository? repository,
    CrossRoleOperationContext? operationContext,
  }) {
    if (_platformAdminCoordinatorPreviewData != null &&
        _platformAdminCoordinatorOperationId == operationContext?.operationId) {
      return _platformAdminCoordinatorPreviewData!;
    }
    unawaited(_platformAdminCoordinatorPreviewData?.dispose());
    _platformAdminCoordinatorOperationId = operationContext?.operationId;
    return _platformAdminCoordinatorPreviewData = LiveCoordinationData(
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
      administrativeEngagementRepository:
          _contextualizedEngagementReadRepository(repository),
      locationsOverride: operationContext == null
          ? null
          : () => _watchPreviewLocations(operationContext.locationIds),
    );
  }

  Stream<List<ResponsePlace>> _watchPreviewLocations(Set<String> ids) {
    if (ids.isEmpty) return Stream.value(const []);
    return _repository!.watchLocations().map(
      (locations) => locations
          .where((location) => ids.contains(location.id))
          .toList(growable: false),
    );
  }

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
    _syncOrganizationContext();
  }

  void _handleAdministrativeUid(String? uid) {
    if (!mounted || uid == _administrativeUid) return;
    _administrativeUid = uid;
    _syncOrganizationContext();
  }

  void _handleAccessError() {
    if (!mounted) return;
    markStartupEvent('mobsante-role-route-ready');
    setState(() {
      _access = null;
      _accessResolved = true;
      _accessResolutionFailed = true;
    });
    _syncOrganizationContext();
  }

  void _syncOrganizationContext() {
    final controller = _organizationContextController;
    if (controller == null) return;
    final administrator = _platformAdministrator;
    if (administrator?.active == true) {
      final access = _access;
      controller.resolveLegacyIdentity(
        uid: administrator!.uid,
        legacyRoleValues:
            access?.active == true && access?.uid == administrator.uid
            ? access!.roles
            : const [],
        isPlatformAdministrator: true,
      );
      return;
    }
    final uid = _administrativeUid ?? _access?.uid;
    if (uid == null) {
      controller.clear();
      return;
    }
    final current = controller.value;
    if (current != null &&
        current.uid == uid &&
        (current.membership != null || !current.isLegacy)) {
      return;
    }
    final access = _access;
    controller.resolveLegacyIdentity(
      uid: uid,
      legacyRoleValues: access?.active == true && access?.uid == uid
          ? access!.roles
          : const [],
    );
  }

  OperationReadRepository? _contextualizedOperationRepository(
    MultiOperationPlatformRuntime? runtime,
  ) {
    if (runtime == null) return null;
    final rawRepository = runtime.operationReadRepository;
    final context = _organizationContextController;
    if (context == null) return rawRepository;
    if (!identical(rawRepository, _rawOperationRepository) ||
        !identical(context, _operationRepositoryContext)) {
      _rawOperationRepository = rawRepository;
      _operationRepositoryContext = context;
      _organizationScopedOperationRepository =
          OrganizationScopedOperationReadRepository(
            delegate: rawRepository,
            context: context,
          );
    }
    return _organizationScopedOperationRepository;
  }

  PlatformReadRepository? _contextualizedPlatformRepository(
    PlatformRuntime? runtime,
    OperationReadRepository? operationRepository,
  ) {
    if (runtime == null) return null;
    final rawRepository = runtime.platformReadRepository;
    if (operationRepository == null) return rawRepository;
    final context = _organizationContextController;
    if (context == null) return rawRepository;
    if (!identical(rawRepository, _rawPlatformRepository) ||
        !identical(operationRepository, _platformOperationRepository) ||
        !identical(context, _platformRepositoryContext)) {
      _rawPlatformRepository = rawRepository;
      _platformOperationRepository = operationRepository;
      _platformRepositoryContext = context;
      _organizationScopedPlatformRepository =
          OrganizationScopedPlatformReadRepository(
            delegate: rawRepository,
            operationRepository: operationRepository,
            context: context,
          );
    }
    return _organizationScopedPlatformRepository;
  }

  MobilizationContextProvider? _contextualizedMobilizationProvider(
    PlatformRuntime? runtime,
    PlatformReadRepository? repository,
  ) {
    if (runtime == null || repository == null) return null;
    if (identical(repository, runtime.platformReadRepository)) {
      return runtime.currentMobilizationProvider;
    }
    if (!identical(repository, _mobilizationProviderRepository)) {
      _mobilizationProviderRepository = repository;
      _organizationScopedMobilizationProvider = CurrentMobilizationProvider(
        repository: repository,
      );
    }
    return _organizationScopedMobilizationProvider;
  }

  AccessibleMobilizationsProvider? _contextualizedAccessibleMobilizations(
    MultiOperationPlatformRuntime? runtime,
    PlatformReadRepository? platformRepository,
  ) {
    if (runtime == null || platformRepository == null) return null;
    final rawProvider = runtime.accessibleMobilizationsProvider;
    final context = _organizationContextController;
    if (context == null) return rawProvider;
    if (!identical(rawProvider, _rawAccessibleMobilizationsProvider) ||
        !identical(
          platformRepository,
          _accessibleMobilizationsPlatformRepository,
        ) ||
        !identical(context, _accessibleMobilizationsContext)) {
      _rawAccessibleMobilizationsProvider = rawProvider;
      _accessibleMobilizationsPlatformRepository = platformRepository;
      _accessibleMobilizationsContext = context;
      _organizationScopedAccessibleMobilizationsProvider =
          OrganizationScopedAccessibleMobilizationsProvider(
            legacyDelegate: rawProvider,
            organizationRepository: platformRepository,
            context: context,
          );
    }
    return _organizationScopedAccessibleMobilizationsProvider;
  }

  MultiMobilizationCoordinationReadRepository?
  _contextualizedMissionReadRepository(
    PlatformReadRepository? platformRepository,
  ) {
    final repository = _repository;
    if (repository == null ||
        repository is! MultiMobilizationCoordinationReadRepository) {
      return null;
    }
    final rawRepository =
        repository as MultiMobilizationCoordinationReadRepository;
    if (platformRepository == null || _organizationContextController == null) {
      return rawRepository;
    }
    if (!identical(rawRepository, _rawMissionReadRepository) ||
        !identical(platformRepository, _missionPlatformRepository)) {
      _rawMissionReadRepository = rawRepository;
      _missionPlatformRepository = platformRepository;
      _organizationScopedMissionReadRepository =
          OrganizationScopedMissionReadRepository(
            delegate: rawRepository,
            platformRepository: platformRepository,
            missionLookup: repository.getMission,
          );
    }
    return _organizationScopedMissionReadRepository;
  }

  MissionEngagementReadRepository? _contextualizedEngagementReadRepository(
    MultiMobilizationCoordinationReadRepository? missionRepository,
  ) {
    final repository = _repository;
    if (repository == null || missionRepository == null) return null;
    if (_organizationContextController == null) return repository;
    if (missionRepository is! MissionAccessReadRepository) {
      return const _UnavailableMissionEngagementReadRepository();
    }
    final accessRepository = missionRepository as MissionAccessReadRepository;
    if (!identical(accessRepository, _engagementMissionRepository)) {
      _engagementMissionRepository = accessRepository;
      _organizationScopedEngagementReadRepository =
          OrganizationScopedEngagementReadRepository(
            delegate: repository,
            missionRepository: accessRepository,
          );
    }
    return _organizationScopedEngagementReadRepository;
  }

  LocationReadRepository _contextualizedLocationReadRepository(
    CoordinationRepository repository,
  ) {
    final context = _organizationContextController;
    if (context == null) return repository;
    if (!identical(repository, _rawLocationReadRepository) ||
        !identical(context, _locationRepositoryContext)) {
      _rawLocationReadRepository = repository;
      _locationRepositoryContext = context;
      _organizationScopedLocationReadRepository =
          OrganizationScopedLocationReadRepository(
            delegate: repository,
            context: context,
          );
    }
    return _organizationScopedLocationReadRepository!;
  }

  Stream<List<ResponsePlace>> _contextualizedPlatformLocationStream(
    CoordinationRepository repository,
  ) {
    final locationRepository = _contextualizedLocationReadRepository(
      repository,
    );
    if (!identical(locationRepository, _platformLocationStreamRepository)) {
      _platformLocationStreamRepository = locationRepository;
      _platformLocationStream = locationRepository.watchLocations();
    }
    return _platformLocationStream!;
  }

  LiveCoordinationData _createLiveData(CoordinationRepository repository) {
    final multiRuntime = widget.platformRuntime is MultiOperationPlatformRuntime
        ? widget.platformRuntime! as MultiOperationPlatformRuntime
        : null;
    final operationRepository = _contextualizedOperationRepository(
      multiRuntime,
    );
    final platformRepository = _contextualizedPlatformRepository(
      widget.platformRuntime,
      operationRepository,
    );
    final missionRepository = _contextualizedMissionReadRepository(
      platformRepository,
    );
    final locationRepository = _contextualizedLocationReadRepository(
      repository,
    );
    return LiveCoordinationData(
      repository,
      responsibleAccessOverride:
          _organizationContextController == null ||
              repository is! AdministrativeIdentityReadRepository
          ? null
          : () => const OrganizationResponsibleAccessResolver().watch(
              legacyAccess: repository.watchResponsibleAccess(),
              context: _organizationContextController!,
              closeWhenLegacyAccessCloses: false,
            ),
      administrativeMissionRepository: missionRepository,
      administrativeEngagementRepository:
          _contextualizedEngagementReadRepository(missionRepository),
      administrativeLocationRepository:
          widget.useLegacyCoordinatorShellForTesting
          ? null
          : locationRepository,
    );
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
    final next = _createLiveData(_repository!);
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
        (_platformAdministratorResolved &&
            (_platformAdministrator?.active ?? false)) ||
        _platformAdministrationSessionExpired;
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
    final operationPreviewContext = crossRolePreview
        ? perspectiveController.operationContext
        : null;
    final multiRuntime = widget.platformRuntime is MultiOperationPlatformRuntime
        ? widget.platformRuntime! as MultiOperationPlatformRuntime
        : null;
    final operationRepository = _contextualizedOperationRepository(
      multiRuntime,
    );
    final platformRepository = _contextualizedPlatformRepository(
      widget.platformRuntime,
      operationRepository,
    );
    final mobilizationProvider = _contextualizedMobilizationProvider(
      widget.platformRuntime,
      platformRepository,
    );
    final accessibleMobilizationsProvider =
        _contextualizedAccessibleMobilizations(
          multiRuntime,
          platformRepository,
        );
    final multiReadRepository = _contextualizedMissionReadRepository(
      platformRepository,
    );
    final locationStream = _contextualizedPlatformLocationStream(_repository!);
    final previewReadRepository =
        crossRolePreview && multiReadRepository != null
        ? _PlatformAdminPreviewMissionRepository(
            multiReadRepository,
            allowedMobilizationIds: operationPreviewContext?.mobilizationIds,
          )
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
                              platformRepository!,
                              allowedMobilizationIds:
                                  operationPreviewContext?.mobilizationIds,
                            )
                    : accessibleMobilizationsProvider,
                multiMobilizationRepository: previewReadRepository,
                multiMobilizationMutationRepository: crossRolePreview
                    ? null
                    : multiMutationRepository,
                operationRepository: operationRepository,
              ),
      _AppJourney.platformAdmin => PlatformAdminShell(
        initialIndex: widget.initialIndex == 3 ? 4 : 0,
        platformRepository: platformRepository!,
        mobilizationProvider: mobilizationProvider!,
        administrationRepository:
            widget.platformRuntime!.platformAdministrationReadRepository,
        administrationService:
            widget.platformRuntime!.platformAdministrationService,
        operationRepository: operationRepository,
        missionRepository: multiReadRepository,
        locationStream: locationStream,
        actorRepository: widget.platformRuntime is PlatformActorRuntime
            ? (widget.platformRuntime! as PlatformActorRuntime)
                  .platformActorReadRepository
            : const NoPlatformActorReadRepository(),
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
            operationName: operationPreviewContext?.operationName,
            onExit: perspectiveController.showActualRole,
            child: displayedShell,
          )
        : displayedShell;
    final contextAwareShell = multiRuntime == null
        ? framedShell
        : OperationalContextScope(
            provider: crossRolePreview
                ? _PlatformAdminOperationalContextProvider(
                    platformRepository!,
                    operationRepository!,
                    operationId: operationPreviewContext?.operationId,
                    allowedMobilizationIds:
                        operationPreviewContext?.mobilizationIds,
                  )
                : multiRuntime.operationalContextProvider,
            child: framedShell,
          );
    return LiveCoordinationDataScope(
      data: !crossRolePreview
          ? _liveData!
          : switch (displayedJourney) {
              _AppJourney.professional => _adminProfessionalPreviewData(
                platformRepository: platformRepository,
                repository: previewReadRepository,
                operationContext: operationPreviewContext,
              ),
              _AppJourney.responsible => _adminResponsiblePreviewData(
                perspectiveController.responsibleLocationId,
                repository: previewReadRepository,
                operationContext: operationPreviewContext,
              ),
              _AppJourney.coordinator => _adminCoordinatorPreviewData(
                platformRepository: platformRepository,
                repository: previewReadRepository,
                operationContext: operationPreviewContext,
              ),
              _AppJourney.platformAdmin => _liveData!,
            },
      child: crossRolePreview
          ? _wrapReadOnlyPreview(contextAwareShell, operationPreviewContext)
          : contextAwareShell,
    );
  }

  Widget _wrapReadOnlyPreview(
    Widget child,
    CrossRoleOperationContext? operationContext,
  ) {
    if (_readOnlyPreviewRepository == null ||
        _readOnlyPreviewOperationId != operationContext?.operationId) {
      _readOnlyPreviewOperationId = operationContext?.operationId;
      _readOnlyPreviewRepository = ReadOnlyPreviewCoordinationRepository(
        _repository!,
        operationContext: operationContext,
      );
    }
    final repository = _readOnlyPreviewRepository!;
    return RepositoryScope(
      repository: repository,
      child: AdminInvitationRepositoryScope(
        repository: repository.adminInvitationRepository,
        child: LocationAdministrationRepositoryScope(
          repository: repository.locationAdministrationRepository,
          child: ResponsibleAccessAdministrationRepositoryScope(
            repository: repository.responsibleAccessAdministrationRepository,
            child: child,
          ),
        ),
      ),
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
    this.operationName,
    required this.onExit,
    required this.child,
  });

  final String journey;
  final String? operationName;
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
              title: operationName == null
                  ? 'Prévisualisation $journey'
                  : 'Prévisualisation $journey · $operationName',
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
  const _PlatformAdminAccessibleMobilizationsProvider(
    this.repository, {
    this.allowedMobilizationIds,
  });

  final PlatformReadRepository repository;
  final Set<String>? allowedMobilizationIds;

  @override
  Stream<List<Mobilization>> watchAccessibleMobilizations() =>
      repository.watchMobilizations().map(
        (items) => items
            .where(
              (item) =>
                  item.status == MobilizationStatus.active &&
                  (allowedMobilizationIds == null ||
                      allowedMobilizationIds!.contains(item.id)),
            )
            .toList(growable: false),
      );
}

/// Les Rules évaluent l'identité Firebase réelle, qui reste Administrateur,
/// et non la perspective affichée. Les missions actives sont déjà lisibles par
/// la session professionnelle anonyme ; la prévisualisation part donc de ce
/// flux autorisé puis applique localement le périmètre demandé.
class _PlatformAdminPreviewMissionRepository
    implements
        MultiMobilizationCoordinationReadRepository,
        MissionAccessReadRepository {
  const _PlatformAdminPreviewMissionRepository(
    this.source, {
    this.allowedMobilizationIds,
  });

  final MultiMobilizationCoordinationReadRepository source;
  final Set<String>? allowedMobilizationIds;

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() =>
      source.watchAllActiveMissions().map(_withinOperation);

  @override
  Stream<CoordinationNeed?> watchAccessibleMission(String missionId) {
    final repository = source;
    if (repository is! MissionAccessReadRepository) {
      return Stream<CoordinationNeed?>.value(null);
    }
    return (repository as MissionAccessReadRepository)
        .watchAccessibleMission(missionId)
        .map(
          (mission) => mission != null && _missionWithinOperation(mission)
              ? mission
              : null,
        );
  }

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
          .where(
            (mission) =>
                _missionWithinOperation(mission) && includes(mission, ids),
          )
          .toList(growable: false),
    );
  }

  List<CoordinationNeed> _withinOperation(List<CoordinationNeed> missions) =>
      missions.where(_missionWithinOperation).toList(growable: false);

  bool _missionWithinOperation(CoordinationNeed mission) =>
      allowedMobilizationIds == null ||
      allowedMobilizationIds!.contains(mission.mobilizationId);
}

class _UnavailableMissionEngagementReadRepository
    implements MissionEngagementReadRepository {
  const _UnavailableMissionEngagementReadRepository();

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) =>
      Stream<List<EngagementInfo>>.value(const []);
}

class _PlatformAdminOperationalContextProvider
    implements OperationalContextProvider {
  const _PlatformAdminOperationalContextProvider(
    this.platformRepository,
    this.operationRepository, {
    this.operationId,
    this.allowedMobilizationIds,
  });

  final PlatformReadRepository platformRepository;
  final OperationReadRepository operationRepository;
  final String? operationId;
  final Set<String>? allowedMobilizationIds;

  @override
  Stream<OperationalMissionContext?> watchForMobilization(
    String mobilizationId,
  ) {
    if (allowedMobilizationIds != null &&
        !allowedMobilizationIds!.contains(mobilizationId)) {
      return Stream.value(null);
    }
    return switchLatest(
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
        final selectedOperationId = selectedMobilization.operationId;
        if (operationId != null && selectedOperationId != operationId) {
          return Stream<OperationalMissionContext?>.value(null);
        }
        if (selectedOperationId == null) {
          return Stream.value(
            OperationalMissionContext(
              mobilizationId: selectedMobilization.id,
              mobilizationName: selectedMobilization.name,
            ),
          );
        }
        return operationRepository
            .watchOperation(selectedOperationId)
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
