import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';

enum V5BottomDestination { missions, engagements, profile }

class V5BottomNavigation extends StatelessWidget {
  const V5BottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < 3);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: NavigationBarTheme(
          data: NavigationBarTheme.of(context).copyWith(
            indicatorColor: colors.infoContainer,
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected)
                    ? colors.info
                    : colors.textSecondary,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected)
                    ? colors.info
                    : colors.textSecondary,
                fontSize: 10,
                height: 1.2,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          child: NavigationBar(
            key: const Key('v5-bottom-navigation'),
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            backgroundColor: colors.surface,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore_rounded),
                label: 'Missions',
              ),
              NavigationDestination(
                icon: Icon(Icons.volunteer_activism_outlined),
                selectedIcon: Icon(Icons.volunteer_activism_rounded),
                label: 'Engagements',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
