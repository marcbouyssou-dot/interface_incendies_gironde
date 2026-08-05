import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';
import '../widgets/responsible_bottom_navigation.dart';
import 'responsible_home_screen.dart';
import 'responsible_needs_screen.dart';
import 'responsible_profile_screen.dart';
import 'responsible_team_screen.dart';

class ResponsibleShell extends StatefulWidget {
  const ResponsibleShell({super.key, this.initialIndex = 0})
    : assert(initialIndex >= 0 && initialIndex < 4);

  final int initialIndex;

  @override
  State<ResponsibleShell> createState() => _ResponsibleShellState();
}

class _ResponsibleShellState extends State<ResponsibleShell> {
  late int _currentIndex;
  final List<Widget?> _screens = List<Widget?>.filled(4, null);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens[_currentIndex] = _createScreen(_currentIndex);
  }

  Widget _createScreen(int index) => switch (index) {
    0 => const ResponsibleHomeScreen(),
    1 => const ResponsibleNeedsScreen(),
    2 => const ResponsibleTeamScreen(),
    3 => const ResponsibleProfileScreen(),
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
    return Scaffold(
      key: const Key('responsible-shell'),
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
      bottomNavigationBar: ResponsibleBottomNavigation(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
      ),
    );
  }
}
