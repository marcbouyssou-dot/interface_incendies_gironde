import 'package:flutter/material.dart';

import '../models/need.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/operation_read_repository.dart';
import '../services/accessible_mobilizations_provider.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/coordinator_bottom_navigation.dart';
import '../widgets/native_interactions.dart';
import '../widgets/v5_secondary_navigation.dart';
import 'admin_invitations_screen.dart';
import 'coordinator_actors_screen.dart';
import 'coordinator_cockpit_screen.dart';
import 'coordinator_more_screen.dart';
import 'coordinator_published_needs.dart';
import 'coordinator_territory_screen.dart';
import 'coordination_screen.dart';
import 'create_need_screen.dart';
import 'development_settings_screen.dart';
import 'location_administration_screen.dart';
import 'location_detail_screen.dart';
import 'notification_center_screen.dart';

class CoordinatorShell extends StatefulWidget {
  const CoordinatorShell({
    super.key,
    this.initialIndex = 0,
    this.accessibleMobilizationsProvider,
    this.multiMobilizationRepository,
    this.multiMobilizationMutationRepository,
    this.operationRepository,
  }) : assert(initialIndex >= 0 && initialIndex < 4);

  final int initialIndex;
  final AccessibleMobilizationsProvider? accessibleMobilizationsProvider;
  final MultiMobilizationCoordinationReadRepository?
  multiMobilizationRepository;
  final MultiMobilizationCoordinationMutationRepository?
  multiMobilizationMutationRepository;
  final OperationReadRepository? operationRepository;

  @override
  State<CoordinatorShell> createState() => _CoordinatorShellState();
}

class _CoordinatorShellState extends State<CoordinatorShell> {
  late int _currentIndex;
  final List<Widget?> _screens = List<Widget?>.filled(4, null);
  final _publishedNeeds = CoordinatorPublishedNeeds();
  int _actorsRevision = 0;
  String? _selectedMobilizationId;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens[_currentIndex] = _createScreen(_currentIndex);
  }

  Widget _createScreen(int index) => switch (index) {
    0 => CoordinatorCockpitScreen(
      publishedNeeds: _publishedNeeds,
      onViewMission: _openMission,
      onViewLocation: _openLocation,
      onCreateNeed: _openCreateNeed,
      accessibleMobilizationsProvider: widget.accessibleMobilizationsProvider,
      multiMobilizationRepository: widget.multiMobilizationRepository,
      operationRepository: widget.operationRepository,
      onMobilizationSelected: (id) => _selectedMobilizationId = id,
    ),
    1 => CoordinatorTerritoryScreen(publishedNeeds: _publishedNeeds),
    2 => CoordinatorActorsScreen(
      key: ValueKey('coordinator-actors-$_actorsRevision'),
      onManageResponsibles: _openResponsibles,
      onManageLocations: _openLocations,
    ),
    3 => CoordinatorMoreScreen(
      onOpenStatistics: _openStatistics,
      onOpenSettings: _openSettings,
      onOpenProfile: _openProfile,
      onOpenNotifications: _openNotifications,
      onSignOut: _signOut,
    ),
    _ => throw RangeError.index(index, _screens),
  };

  void _selectTab(int index) {
    setState(() {
      _screens[index] ??= _createScreen(index);
      _currentIndex = index;
    });
  }

  void _openCreateNeed() {
    final liveData = LiveCoordinationDataScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            body: SafeArea(
              child: CreateNeedScreen(
                mobilizationId: _selectedMobilizationId,
                createMission:
                    _selectedMobilizationId != null &&
                        widget.multiMobilizationMutationRepository != null
                    ? (draft) => widget.multiMobilizationMutationRepository!
                          .createMissionForMobilization(
                            _selectedMobilizationId!,
                            draft,
                          )
                    : null,
                onMissionPublished: _publishedNeeds.publish,
                onViewMission: () {
                  Navigator.of(context).pop();
                  _selectTab(1);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openMission(CoordinationNeed mission) {
    openMissionEditor(context, mission);
  }

  void _openLocation(ResponsePlace location) {
    final liveData = LiveCoordinationDataScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: LocationDetailScreen(
            location: location,
            missions: liveData.watchMissions(),
            locations: liveData.watchLocations(),
            responsibleAccess: liveData.watchResponsibleAccess(),
          ),
        ),
      ),
    );
  }

  Future<void> _openResponsibles() async {
    final liveData = LiveCoordinationDataScope.of(context);
    await Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const AdminInvitationsScreen(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _actorsRevision++;
      _screens[2] = _createScreen(2);
    });
  }

  void _openLocations() {
    Navigator.of(context).push(
      AppPageRoute<void>(builder: (_) => const LocationAdministrationScreen()),
    );
  }

  void _openStatistics() {
    final liveData = LiveCoordinationDataScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (routeContext) => LiveCoordinationDataScope(
          data: liveData,
          child: Scaffold(
            key: const Key('coordinator-statistics-route'),
            appBar: V5SecondaryNavigationBar(
              key: const Key('coordinator-statistics-navigation'),
              title: 'Statistiques',
              onBack: () => Navigator.of(routeContext).pop(),
            ),
            body: const SafeArea(top: false, child: CoordinationScreen()),
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

  void _openProfile() {
    final liveData = LiveCoordinationDataScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const CoordinatorProfileScreen(),
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
  void dispose() {
    _publishedNeeds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('coordinator-shell'),
      backgroundColor: context.v5Colors.canvas,
      body: SafeArea(
        bottom: false,
        child: NativeTabView(
          index: _currentIndex,
          children: List.generate(
            _screens.length,
            (index) => _screens[index] ?? const SizedBox.shrink(),
          ),
        ),
      ),
      bottomNavigationBar: CoordinatorBottomNavigation(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
      ),
    );
  }
}
