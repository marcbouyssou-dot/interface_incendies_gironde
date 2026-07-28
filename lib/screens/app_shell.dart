import 'package:flutter/material.dart';

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

  static const _screens = [
    SlotsScreen(),
    CreateNeedScreen(),
    CoordinationScreen(),
    PlacesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: _screens),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
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
    );
  }
}
