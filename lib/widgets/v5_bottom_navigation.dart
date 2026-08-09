import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme/v5_foundation.dart';

enum V5BottomDestination { missions, engagements, profile }

class V5BottomBarDestination {
  const V5BottomBarDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class V5BottomBar extends StatelessWidget {
  const V5BottomBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.selectedColor,
  }) : assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<V5BottomBarDestination> destinations;
  final Color selectedColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.canvas,
        border: Border(
          top: BorderSide(
            color: colors.outline.withValues(alpha: 0.32),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _V5BottomBarItem(
                    destination: destinations[index],
                    selected: selectedIndex == index,
                    selectedColor: selectedColor,
                    onPressed: () => onDestinationSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _V5BottomBarItem extends StatelessWidget {
  const _V5BottomBarItem({
    required this.destination,
    required this.selected,
    required this.selectedColor,
    required this.onPressed,
  });

  final V5BottomBarDestination destination;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final foreground = selected ? selectedColor : colors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      child: CupertinoButton(
        minimumSize: const Size.square(44),
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(
                selected ? destination.selectedIcon : destination.icon,
                key: ValueKey(selected),
                size: selected ? 25 : 24,
                color: foreground,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              destination.label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class V5BottomNavigation extends StatelessWidget {
  const V5BottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  }) : assert(selectedIndex >= 0 && selectedIndex < 3);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => V5BottomBar(
    key: const Key('v5-bottom-navigation'),
    selectedIndex: selectedIndex,
    onDestinationSelected: onDestinationSelected,
    selectedColor: context.v5Colors.info,
    destinations: const [
      V5BottomBarDestination(
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
        label: 'Missions',
      ),
      V5BottomBarDestination(
        icon: Icons.volunteer_activism_outlined,
        selectedIcon: Icons.volunteer_activism_rounded,
        label: 'Engagements',
      ),
      V5BottomBarDestination(
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
        label: 'Profil',
      ),
    ],
  );
}
