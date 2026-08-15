import 'package:flutter/material.dart';

import '../theme/coordinator_identity.dart';
import 'v5_bottom_navigation.dart';

class CoordinatorBottomNavigation extends StatelessWidget {
  const CoordinatorBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => V5BottomBar(
    key: const Key('coordinator-bottom-navigation'),
    selectedIndex: selectedIndex,
    onDestinationSelected: onDestinationSelected,
    selectedColor: CoordinatorIdentity.of(context).accent,
    destinations: const [
      V5BottomBarDestination(
        icon: Icons.radar_outlined,
        selectedIcon: Icons.radar_rounded,
        label: 'Cockpit',
      ),
      V5BottomBarDestination(
        icon: Icons.map_outlined,
        selectedIcon: Icons.map_rounded,
        label: 'Territoire',
      ),
      V5BottomBarDestination(
        icon: Icons.groups_outlined,
        selectedIcon: Icons.groups_rounded,
        label: 'Acteurs',
      ),
      V5BottomBarDestination(
        icon: Icons.more_horiz_rounded,
        selectedIcon: Icons.more_horiz_rounded,
        label: 'Plus',
      ),
    ],
  );
}
