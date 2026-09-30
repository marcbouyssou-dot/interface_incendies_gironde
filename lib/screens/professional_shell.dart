import 'package:flutter/material.dart';

import '../dev/role_preview.dart';
import '../models/need.dart';
import '../repositories/repository_scope.dart';
import '../services/professional_verification_service.dart';
import '../theme/v5_foundation.dart';
import '../utils/app_page_route.dart';
import '../widgets/v5_bottom_navigation.dart';
import '../widgets/native_interactions.dart';
import 'professional_engagements_screen.dart';
import 'professional_profile_screen.dart';
import 'notification_center_screen.dart';
import 'slots_screen.dart';

class ProfessionalShell extends StatefulWidget {
  const ProfessionalShell({
    super.key,
    this.initialIndex = 0,
    this.verificationService = const FakeProfessionalVerificationService(),
  }) : assert(initialIndex >= 0 && initialIndex < 3);

  final int initialIndex;
  final ProfessionalVerificationService verificationService;

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
    0 => SlotsScreen(
      professionalJourney: true,
      onCompleteProfileForMission: _completeProfileForMission,
    ),
    1 => const ProfessionalEngagementsScreen(),
    2 => ProfessionalProfileScreen(
      onOpenNotifications: _openNotifications,
      onSignOut: _signOut,
      verificationService: widget.verificationService,
    ),
    _ => throw RangeError.index(index, _screens),
  };

  void _selectTab(int index) {
    setState(() {
      _screens[index] ??= _createScreen(index);
      _currentIndex = index;
    });
  }

  void _completeProfileForMission(CoordinationNeed mission) {
    setState(() {
      _screens[2] = ProfessionalProfileScreen(
        key: ValueKey('profile-completion-${mission.id}'),
        initiallyOpenEditor: true,
        returnToMissionLabel: mission.place,
        onReturnToMission: () => _selectTab(0),
        onOpenNotifications: _openNotifications,
        onSignOut: _signOut,
        verificationService: widget.verificationService,
      );
      _currentIndex = 2;
    });
  }

  void _openNotifications() {
    Navigator.of(context).push(
      AppPageRoute<void>(builder: (_) => const NotificationCenterScreen()),
    );
  }

  Future<void> _signOut() => RepositoryScope.of(context).signOutResponsible();

  @override
  Widget build(BuildContext context) {
    return RolePreviewDebugOverlay(
      journeyLabel: 'Professionnel',
      child: Scaffold(
        backgroundColor: context.v5Colors.canvas,
        body: SafeArea(
          bottom: false,
          child: NativeTabView(
            index: _currentIndex,
            children: List.generate(
              _screens.length,
              (index) => _screens[index] ?? const SizedBox.shrink(),
            ),
          ),
        ),
        bottomNavigationBar: V5BottomNavigation(
          selectedIndex: _currentIndex,
          onDestinationSelected: _selectTab,
        ),
      ),
    );
  }
}
