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
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colors.outline.withValues(alpha: 0.55),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarTheme.of(context).copyWith(
              height: 64,
              indicatorColor: Colors.transparent,
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
                  fontSize: 9.5,
                  height: 1.15,
                  letterSpacing: 0.1,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w600,
                ),
              ),
            ),
            child: NavigationBar(
              key: const Key('v5-bottom-navigation'),
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: colors.surface,
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.explore_outlined, size: 24),
                  selectedIcon: Icon(Icons.explore_rounded, size: 25),
                  label: 'Missions',
                ),
                NavigationDestination(
                  icon: Icon(Icons.volunteer_activism_outlined, size: 24),
                  selectedIcon: Icon(
                    Icons.volunteer_activism_rounded,
                    size: 25,
                  ),
                  label: 'Engagements',
                ),
                NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded, size: 24),
                  selectedIcon: Icon(Icons.person_rounded, size: 25),
                  label: 'Profil',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
