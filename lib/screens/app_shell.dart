import 'dart:async';

import 'package:flutter/material.dart';

import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import 'administration_dashboard_screen.dart';
import 'coordination_screen.dart';
import 'places_screen.dart';
import 'professional_shell.dart';
import 'slots_screen.dart';

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
  bool _useProfessionalShell = false;

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
    final useProfessionalShell = access == null;
    if (!mounted || useProfessionalShell == _useProfessionalShell) return;
    setState(() => _useProfessionalShell = useProfessionalShell);
  }

  void _handleAccessError() {
    if (!mounted || !_useProfessionalShell) return;
    setState(() => _useProfessionalShell = false);
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
      _useProfessionalShell = false;
    });
    _accessSubscription = next.watchResponsibleAccess().listen(
      _handleAccess,
      onError: (_, _) => _handleAccessError(),
    );
    if (previous != null) unawaited(previous.dispose());
  }

  @override
  Widget build(BuildContext context) {
    return LiveCoordinationDataScope(
      data: _liveData!,
      child: _useProfessionalShell
          ? ProfessionalShell(initialIndex: widget.initialIndex == 1 ? 2 : 0)
          : _buildHistoricalShell(),
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
