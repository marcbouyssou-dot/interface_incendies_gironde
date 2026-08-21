import 'package:flutter/material.dart';

import '../theme/platform_admin_identity.dart';
import 'v5_bottom_navigation.dart';

class PlatformAdminBottomNavigation extends StatelessWidget {
  const PlatformAdminBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < 5);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final compactStatisticsLabel =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return V5BottomBar(
      key: const Key('platform-admin-bottom-navigation'),
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      selectedColor: PlatformAdminIdentity.accent(context),
      destinations: [
        const V5BottomBarDestination(
          icon: Icons.campaign_outlined,
          selectedIcon: Icons.campaign_rounded,
          label: 'Opérations',
        ),
        const V5BottomBarDestination(
          icon: Icons.people_outline_rounded,
          selectedIcon: Icons.people_rounded,
          label: 'Acteurs',
        ),
        V5BottomBarDestination(
          icon: Icons.insights_outlined,
          selectedIcon: Icons.insights_rounded,
          label: compactStatisticsLabel ? 'Stats' : 'Statistiques',
        ),
        const V5BottomBarDestination(
          icon: Icons.history_outlined,
          selectedIcon: Icons.history_rounded,
          label: 'Historique',
        ),
        const V5BottomBarDestination(
          icon: Icons.more_horiz_rounded,
          selectedIcon: Icons.more_rounded,
          label: 'Plus',
        ),
      ],
    );
  }
}
