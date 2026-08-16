import 'package:flutter/material.dart';

import '../theme/platform_admin_identity.dart';
import 'v5_bottom_navigation.dart';

class PlatformAdminBottomNavigation extends StatelessWidget {
  const PlatformAdminBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < 2);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => V5BottomBar(
    key: const Key('platform-admin-bottom-navigation'),
    selectedIndex: selectedIndex,
    onDestinationSelected: onDestinationSelected,
    selectedColor: PlatformAdminIdentity.accent(context),
    destinations: const [
      V5BottomBarDestination(
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign_rounded,
        label: 'Opérations',
      ),
      V5BottomBarDestination(
        icon: Icons.more_horiz_rounded,
        selectedIcon: Icons.more_rounded,
        label: 'Plus',
      ),
    ],
  );
}
