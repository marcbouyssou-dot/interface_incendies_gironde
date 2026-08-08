import 'package:flutter/material.dart';

import '../repositories/live_data_scope.dart';
import '../repositories/repository_scope.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/v5_bottom_navigation.dart';
import '../widgets/perspective_switcher.dart';
import 'create_need_screen.dart';
import 'development_settings_screen.dart';
import 'professional_engagements_screen.dart';
import 'professional_profile_screen.dart';
import 'slots_screen.dart';

class ProfessionalShell extends StatefulWidget {
  const ProfessionalShell({
    super.key,
    this.initialIndex = 0,
    this.crossRolePreviewLabel,
    this.onExitCrossRolePreview,
  }) : assert(initialIndex >= 0 && initialIndex < 3),
       assert(
         (crossRolePreviewLabel == null) == (onExitCrossRolePreview == null),
       );

  final int initialIndex;
  final String? crossRolePreviewLabel;
  final VoidCallback? onExitCrossRolePreview;

  @override
  State<ProfessionalShell> createState() => _ProfessionalShellState();
}

class _ProfessionalShellState extends State<ProfessionalShell> {
  late int _currentIndex;
  final List<Widget?> _screens = List<Widget?>.filled(3, null);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens[_currentIndex] = _createScreen(_currentIndex);
  }

  Widget _createScreen(int index) => switch (index) {
    0 => const SlotsScreen(professionalJourney: true),
    1 => const ProfessionalEngagementsScreen(),
    2 => ProfessionalProfileScreen(
      onOpenResponsibleAccess: _openResponsibleAccess,
      onOpenSettings: _openSettings,
      onSignOut: _signOut,
      onExitCrossRolePreview: widget.onExitCrossRolePreview,
    ),
    _ => throw RangeError.index(index, _screens),
  };

  void _selectTab(int index) {
    setState(() {
      _screens[index] ??= _createScreen(index);
      _currentIndex = index;
    });
  }

  void _openResponsibleAccess() {
    final repository = RepositoryScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => Scaffold(
          body: SafeArea(
            child: ResponsibleLogin(
              repository: repository,
              onSignedIn: () {
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openSettings() {
    final liveData = LiveCoordinationDataScope.of(context);
    Navigator.of(context).push(
      AppPageRoute<void>(
        builder: (_) => LiveCoordinationDataScope(
          data: liveData,
          child: const DevelopmentSettingsScreen(),
        ),
      ),
    );
  }

  Future<void> _signOut() => RepositoryScope.of(context).signOutResponsible();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.v5Colors.canvas,
      body: Column(
        children: [
          if (widget.crossRolePreviewLabel case final label?)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: CrossRolePreviewBanner(
                  label: label,
                  onExit: widget.onExitCrossRolePreview!,
                  compact: true,
                ),
              ),
            ),
          Expanded(
            child: SafeArea(
              top: widget.crossRolePreviewLabel == null,
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
      bottomNavigationBar: V5BottomNavigation(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
      ),
    );
  }
}
