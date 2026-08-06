import 'package:flutter/material.dart';

import '../models/need.dart';
import '../models/responsible_access.dart';
import '../perspective/cross_role_perspective.dart';
import '../repositories/live_data_scope.dart';
import '../theme/v5_foundation.dart';
import '../widgets/perspective_switcher.dart';
import '../widgets/responsible_bottom_navigation.dart';
import 'responsible_home_screen.dart';
import 'responsible_needs_screen.dart';
import 'responsible_profile_screen.dart';
import 'responsible_team_screen.dart';

class ResponsibleShell extends StatefulWidget {
  const ResponsibleShell({
    super.key,
    this.initialIndex = 0,
    this.previewLocationId,
  }) : assert(initialIndex >= 0 && initialIndex < 4);

  final int initialIndex;
  final String? previewLocationId;

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
    0 => ResponsibleHomeScreen(
      previewLocationId: widget.previewLocationId,
      onOpenNeeds: () => _selectTab(1),
    ),
    1 => ResponsibleNeedsScreen(
      previewLocationId: widget.previewLocationId,
      onOpenTeam: () => _selectTab(2),
    ),
    2 => ResponsibleTeamScreen(previewLocationId: widget.previewLocationId),
    3 => ResponsibleProfileScreen(previewLocationId: widget.previewLocationId),
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
      body: Column(
        children: [
          if (widget.previewLocationId case final locationId?)
            _ResponsiblePreviewBanner(locationId: locationId),
          Expanded(
            child: SafeArea(
              top: widget.previewLocationId == null,
              bottom: false,
              child: IndexedStack(
                index: _currentIndex,
                children: List.generate(
                  _screens.length,
                  (index) => _screens[index] ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ResponsibleBottomNavigation(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
      ),
    );
  }
}

class _ResponsiblePreviewBanner extends StatefulWidget {
  const _ResponsiblePreviewBanner({required this.locationId});

  final String locationId;

  @override
  State<_ResponsiblePreviewBanner> createState() =>
      _ResponsiblePreviewBannerState();
}

class _ResponsiblePreviewBannerState extends State<_ResponsiblePreviewBanner> {
  LiveCoordinationData? _liveData;
  Stream<ResponsibleAccess?>? _access;
  Stream<List<ResponsePlace>>? _locations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final liveData = LiveCoordinationDataScope.of(context);
    if (identical(liveData, _liveData)) return;
    _liveData = liveData;
    _access = liveData.watchResponsibleAccess();
    _locations = liveData.watchLocations();
  }

  @override
  Widget build(BuildContext context) {
    final controller = CrossRolePerspectiveScope.of(context);
    return StreamBuilder<ResponsibleAccess?>(
      stream: _access,
      builder: (context, accessSnapshot) => StreamBuilder<List<ResponsePlace>>(
        stream: _locations,
        builder: (context, locationsSnapshot) {
          final locations = locationsSnapshot.data ?? const <ResponsePlace>[];
          ResponsePlace? location;
          for (final item in locations) {
            if (item.id == widget.locationId) {
              location = item;
              break;
            }
          }
          final access = accessSnapshot.data;
          return CrossRolePreviewBanner(
            label:
                'Vue Responsable de centre · ${location?.name ?? 'centre sélectionné'}',
            exitLabel: 'Coordinateur',
            accentColor: context.v5Colors.accent,
            containerColor: context.v5Colors.warningContainer,
            onExit: controller.showActualRole,
            onChange: access == null || !locationsSnapshot.hasData
                ? null
                : () => _changeCenter(controller, access, locations),
          );
        },
      ),
    );
  }

  Future<void> _changeCenter(
    CrossRolePerspectiveController controller,
    ResponsibleAccess access,
    List<ResponsePlace> locations,
  ) async {
    final location = await showResponsibleCenterPicker(
      context,
      access: access,
      locations: locations,
      selectedLocationId: widget.locationId,
    );
    if (location != null) controller.showResponsible(location.id);
  }
}
