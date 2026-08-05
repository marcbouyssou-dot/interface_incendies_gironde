import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import 'administration_dashboard_screen.dart';
import 'coordination_screen.dart';
import 'places_screen.dart';
import 'professional_shell.dart';
import 'responsible_shell.dart';
import 'slots_screen.dart';

enum _AppJourney { professional, responsible, coordinator }

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final List<Widget?> _screens = List<Widget?>.filled(4, null);
  CoordinationRepository? _repository;
  LiveCoordinationData? _liveData;
  StreamSubscription<ResponsibleAccess?>? _accessSubscription;
  ResponsibleAccess? _access;
  bool _accessResolved = false;

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

  Widget _createScreen(int index) => switch (index) {
    0 => const SlotsScreen(),
    1 => AdministrationDashboardScreen(
      onViewMission: () => _selectTab(0),
      onOpenStatistics: () => _selectTab(2),
      onRetryAccess: _refreshLiveData,
    ),
    2 => const CoordinationScreen(),
    3 => const PlacesScreen(),
    _ => throw RangeError.index(index, _screens),
  };

  void _selectTab(int index) {
    setState(() {
      _screens[index] ??= _createScreen(index);
      _currentIndex = index;
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
    return LiveCoordinationDataScope(
      data: _liveData!,
      child: switch (journey) {
        _AppJourney.professional => ProfessionalShell(
          initialIndex: widget.initialIndex == 1 ? 2 : 0,
        ),
        _AppJourney.responsible => ResponsibleShell(
          initialIndex: widget.initialIndex.clamp(0, 3),
        ),
        _AppJourney.coordinator => _buildHistoricalShell(),
      },
    );
  }

  Widget _buildHistoricalShell() {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded),
            label: 'Missions',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(
              Icons.add_circle_rounded,
              color: AppColors.orange,
            ),
            label: 'Déclarer',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Statistiques',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            selectedIcon: Icon(Icons.location_on_rounded),
            label: 'Plus',
          ),
        ],
      ),
    );
  }
}
