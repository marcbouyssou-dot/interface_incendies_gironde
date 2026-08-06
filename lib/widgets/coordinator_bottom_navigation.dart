import 'package:flutter/material.dart';

import '../theme/coordinator_identity.dart';
import '../theme/v5_foundation.dart';

class CoordinatorBottomNavigation extends StatelessWidget {
  const CoordinatorBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final identity = CoordinatorIdentity.of(context);
    return Material(
      color: colors.canvas,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colors.outline.withValues(alpha: 0.32),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: colors.canvas,
              indicatorColor: Colors.transparent,
              height: 64,
              elevation: 0,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  color: states.contains(WidgetState.selected)
                      ? identity.accent
                      : colors.textSecondary,
                  size: 24,
                ),
              ),
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => TextStyle(
                  color: states.contains(WidgetState.selected)
                      ? identity.accent
                      : colors.textSecondary,
                  fontSize: 9.5,
                  height: 1.15,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
            child: NavigationBar(
              key: const Key('coordinator-bottom-navigation'),
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              backgroundColor: colors.canvas,
              elevation: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.radar_outlined),
                  selectedIcon: Icon(Icons.radar_rounded),
                  label: 'Vue d’ensemble',
                ),
                NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map_rounded),
                  label: 'Territoire',
                ),
                NavigationDestination(
                  icon: Icon(Icons.groups_outlined),
                  selectedIcon: Icon(Icons.groups_rounded),
                  label: 'Acteurs',
                ),
                NavigationDestination(
                  icon: Icon(Icons.more_horiz_rounded),
                  selectedIcon: Icon(Icons.more_horiz_rounded),
                  label: 'Plus',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
