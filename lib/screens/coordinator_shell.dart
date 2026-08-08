import 'package:flutter/material.dart';

import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/coordinator_bottom_navigation.dart';
import 'admin_invitations_screen.dart';
import 'coordinator_actors_screen.dart';
import 'coordinator_more_screen.dart';
import 'coordinator_overview_screen.dart';
import 'coordinator_published_needs.dart';
import 'coordinator_territory_screen.dart';
import 'coordination_screen.dart';
import 'create_need_screen.dart';
import 'development_settings_screen.dart';
import 'location_administration_screen.dart';

class CoordinatorShell extends StatefulWidget {
  const CoordinatorShell({super.key, this.initialIndex = 0})
    : assert(initialIndex >= 0 && initialIndex < 4);

  final int initialIndex;

  @override
  State<CoordinatorShell> createState() => _CoordinatorShellState();
}

class _CoordinatorShellState extends State<CoordinatorShell> {
  late int _currentIndex;
  final List<Widget?> _screens = List<Widget?>.filled(4, null);
  final _publishedNeeds = CoordinatorPublishedNeeds();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens[_currentIndex] = _createScreen(_currentIndex);
  }

  Widget _createScreen(int index) => switch (index) {
    0 => CoordinatorOverviewScreen(
      publishedNeeds: _publishedNeeds,
      onOpenTerritory: () => _selectTab(1),
      onCreateNeed: _openCreateNeed,
      onManageResponsibles: _openResponsibles,
      onManageLocations: _openLocations,
    ),
    1 => CoordinatorTerritoryScreen(publishedNeeds: _publishedNeeds),
    2 => CoordinatorActorsScreen(
      onManageResponsibles: _openResponsibles,
      onManageLocations: _openLocations,
    ),
    3 => CoordinatorMoreScreen(
      onOpenStatistics: _openStatistics,
      onOpenSettings: _openSettings,
      onOpenProfile: _openProfile,
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
            body: SafeArea(
              child: CreateNeedScreen(
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

  void _openResponsibles() {
    final liveData = LiveCoordinationDataScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const AdminInvitationsScreen(),
        ),
      ),
    );
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
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const Scaffold(body: SafeArea(child: CoordinationScreen())),
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
        child: IndexedStack(
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
