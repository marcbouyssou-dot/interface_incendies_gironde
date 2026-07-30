import 'package:flutter/material.dart';

import '../repositories/coordination_repository.dart';
import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/app_theme.dart';
import 'coordination_screen.dart';
import 'create_need_screen.dart';
import 'places_screen.dart';
import 'slots_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final List<Widget?> _screens = List<Widget?>.filled(4, null);
  CoordinationRepository? _repository;
  LiveCoordinationData? _liveData;

  @override
  void initState() {
    super.initState();
    _screens[0] = const SlotsScreen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = RepositoryScope.of(context);
    if (!identical(repository, _repository)) {
      _liveData?.dispose();
      _repository = repository;
      _liveData = LiveCoordinationData(repository);
    }
  }

  @override
  void dispose() {
    _liveData?.dispose();
    super.dispose();
  }

  Widget _createScreen(int index) => switch (index) {
    0 => const SlotsScreen(),
    1 => CreateNeedScreen(onViewMission: () => _selectTab(0)),
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

  @override
  Widget build(BuildContext context) {
    return LiveCoordinationDataScope(
      data: _liveData!,
      child: Scaffold(
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
              label: 'Situation',
            ),
            NavigationDestination(
              icon: Icon(Icons.location_on_outlined),
              selectedIcon: Icon(Icons.location_on_rounded),
              label: 'Plus',
            ),
          ],
        ),
      ),
    );
  }
}
