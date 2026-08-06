import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';

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
                      ? colors.accent
                      : colors.textSecondary,
                ),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  color: states.contains(WidgetState.selected)
                      ? colors.accent
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
              key: const Key('responsible-bottom-navigation'),
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: colors.surface,
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined, size: 24),
                  selectedIcon: Icon(Icons.home_rounded, size: 25),
                  label: 'Accueil',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined, size: 24),
                  selectedIcon: Icon(Icons.assignment_rounded, size: 25),
                  label: 'Besoins',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined, size: 24),
                  selectedIcon: Icon(Icons.groups_rounded, size: 25),
                  label: 'Équipe',
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
