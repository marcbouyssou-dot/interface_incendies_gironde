import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';
import 'v5_bottom_navigation.dart';

enum ResponsibleDestination { home, needs, team, profile }

class ResponsibleBottomNavigation extends StatelessWidget {
  const ResponsibleBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < 4);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => V5BottomBar(
    key: const Key('responsible-bottom-navigation'),
    selectedIndex: selectedIndex,
    onDestinationSelected: onDestinationSelected,
    selectedColor: context.v5Colors.accent,
    destinations: const [
      V5BottomBarDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Accueil',
      ),
      V5BottomBarDestination(
        icon: Icons.assignment_outlined,
        selectedIcon: Icons.assignment_rounded,
        label: 'Besoins',
      ),
      V5BottomBarDestination(
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups_rounded,
        label: 'Équipe',
      ),
      V5BottomBarDestination(
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: 'Profil',
      ),
    ],
  );
}
