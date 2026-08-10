import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../perspective/cross_role_perspective.dart';
import '../models/platform_administrator_access.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../repositories/platform_runtime.dart';
import '../services/professional_verification_service.dart';
import '../theme/app_theme.dart';
import '../theme/v5_foundation.dart';
import '../widgets/v5_bottom_navigation.dart';
import 'administration_dashboard_screen.dart';
import 'coordinator_shell.dart';
import 'coordination_screen.dart';
import 'create_need_screen.dart';
import 'places_screen.dart';
import 'platform_admin_shell.dart';
import 'professional_shell.dart';
import 'responsible_shell.dart';
import 'slots_screen.dart';

enum _AppJourney { professional, responsible, coordinator, platformAdmin }

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.initialIndex = 0,
    this.useLegacyCoordinatorShellForTesting = false,
    this.professionalVerificationService =
        const FakeProfessionalVerificationService(),
    this.platformRuntime,
  });

  final int initialIndex;
  final ProfessionalVerificationService professionalVerificationService;
  final PlatformRuntime? platformRuntime;

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
  StreamSubscription<ResponsibleAccess?>? _accessSubscription;
  StreamSubscription<PlatformAdministratorAccess?>?
  _platformAdministratorSubscription;
  ResponsibleAccess? _access;
  PlatformAdministratorAccess? _platformAdministrator;
  bool _accessResolved = false;
  bool _platformAdministratorResolved = false;
  bool _showPlatformAdminAuthentication = false;

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
    setState(() {
      _platformAdministrator = access;
      _platformAdministratorResolved = true;
    });
  }

  void _handlePlatformAdministratorError() {
    if (!mounted) return;
    setState(() {
      _platformAdministrator = null;
      _platformAdministratorResolved = true;
    });
  }

  Future<void> _signOutPlatformAdministrator() async {
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
      _liveData?.dispose();
      _repository = repository;
      _liveData = LiveCoordinationData(repository);
      _accessSubscription = _liveData!.watchResponsibleAccess().listen(
        _handleAccess,
        onError: (_, _) => _handleAccessError(),
      );
    }
  }

  @override
  void dispose() {
    unawaited(_accessSubscription?.cancel());
    unawaited(_platformAdministratorSubscription?.cancel());
    _liveData?.dispose();
    super.dispose();
  }

  void _handleAccess(ResponsibleAccess? access) {
    if (!mounted) return;
    setState(() {
      _access = access;
      _accessResolved = true;
    });
  }

  void _handleAccessError() {
    if (!mounted) return;
    if (_access == null) setState(() => _accessResolved = false);
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
    final automaticJourney = !_accessResolved
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
    var displayedJourney =
        _platformAdministratorResolved &&
            (_platformAdministrator?.active ?? false)
        ? _AppJourney.platformAdmin
        : journey;
    String? responsiblePreviewLocationId;
    var crossRolePreview = false;
    final access = _access;
    if (displayedJourney != _AppJourney.platformAdmin &&
        previewMode == RolePreviewMode.automatic &&
        _accessResolved &&
        access != null &&
        access.active) {
      switch (perspectiveController.perspective) {
        case CrossRolePerspective.actual:
          break;
        case CrossRolePerspective.professional:
          if (access.isCoordinator || access.isSiteManager) {
            displayedJourney = _AppJourney.professional;
            crossRolePreview = displayedJourney != automaticJourney;
          }
        case CrossRolePerspective.responsible:
          final locationId = perspectiveController.responsibleLocationId;
          if (access.isCoordinator &&
              locationId != null &&
              access.canManage(locationId)) {
            displayedJourney = _AppJourney.responsible;
            responsiblePreviewLocationId = locationId;
            crossRolePreview = true;
          }
      }
    }
    if (!_platformAdministratorResolved) {
      return LiveCoordinationDataScope(
        data: _liveData!,
        child: const _PlatformRouteLoading(),
      );
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
    return LiveCoordinationDataScope(
      data: _liveData!,
      child: switch (displayedJourney) {
        _AppJourney.professional => ProfessionalShell(
          key: ValueKey(
            crossRolePreview ? 'professional-perspective' : 'professional',
          ),
          initialIndex: widget.initialIndex == 1 ? 2 : 0,
          verificationService: widget.professionalVerificationService,
          crossRolePreviewLabel: crossRolePreview
              ? automaticJourney == _AppJourney.coordinator
                    ? 'Coordinateur'
                    : 'Responsable de centre'
              : null,
          onExitCrossRolePreview: crossRolePreview
              ? perspectiveController.showActualRole
              : null,
        ),
        _AppJourney.responsible => ResponsibleShell(
          key: ValueKey(
            responsiblePreviewLocationId == null
                ? 'responsible'
                : 'responsible-$responsiblePreviewLocationId',
          ),
          initialIndex: widget.initialIndex.clamp(0, 3),
          previewLocationId: responsiblePreviewLocationId,
        ),
        _AppJourney.coordinator =>
          widget.useLegacyCoordinatorShellForTesting
              ? _buildLegacyShell()
              : CoordinatorShell(initialIndex: widget.initialIndex.clamp(0, 3)),
        _AppJourney.platformAdmin => PlatformAdminShell(
          initialIndex: widget.initialIndex == 3 ? 1 : 0,
          platformRepository: widget.platformRuntime!.platformReadRepository,
          mobilizationProvider:
              widget.platformRuntime!.currentMobilizationProvider,
          administrationRepository:
              widget.platformRuntime!.platformAdministrationReadRepository,
          administrationService:
              widget.platformRuntime!.platformAdministrationService,
          onSignOut: _signOutPlatformAdministrator,
        ),
      },
    );
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
