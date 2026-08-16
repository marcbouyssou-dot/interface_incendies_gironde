import 'package:flutter/material.dart';

import '../repositories/platform_administration_read_repository.dart';
import '../repositories/coordination_repository.dart';
import '../repositories/platform_read_repository.dart';
import '../repositories/operation_read_repository.dart';
import '../services/current_mobilization_provider.dart';
import '../services/platform_administration_service.dart';
import '../theme/platform_admin_identity.dart';
import '../theme/v5_foundation.dart';
import '../widgets/native_interactions.dart';
import '../widgets/platform_admin_bottom_navigation.dart';
import 'platform_admin_mobilization_screen.dart';
import 'platform_admin_operations_screen.dart';
import 'platform_admin_more_screen.dart';

class PlatformAdminShell extends StatefulWidget {
  const PlatformAdminShell({
    super.key,
    required this.platformRepository,
    required this.mobilizationProvider,
    required this.administrationRepository,
    required this.administrationService,
    required this.onSignOut,
    this.operationRepository,
    this.missionRepository,
    this.initialIndex = 0,
  }) : assert(initialIndex >= 0 && initialIndex < 2);

  final PlatformReadRepository platformRepository;
  final MobilizationContextProvider mobilizationProvider;
  final PlatformAdministrationReadRepository administrationRepository;
  final PlatformAdministrationService administrationService;
  final Future<void> Function() onSignOut;
  final OperationReadRepository? operationRepository;
  final MultiMobilizationCoordinationReadRepository? missionRepository;
  final int initialIndex;

  @override
  State<PlatformAdminShell> createState() => _PlatformAdminShellState();
}

class _PlatformAdminShellState extends State<PlatformAdminShell> {
  late int _currentIndex;
  final List<Widget?> _screens = List<Widget?>.filled(2, null);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens[_currentIndex] = _createScreen(_currentIndex);
  }

  Widget _createScreen(int index) => switch (index) {
    0 =>
      widget.operationRepository == null
          ? PlatformAdminMobilizationScreen(
              platformRepository: widget.platformRepository,
              mobilizationProvider: widget.mobilizationProvider,
              administrationRepository: widget.administrationRepository,
              administrationService: widget.administrationService,
            )
          : PlatformAdminOperationsScreen(
              operationRepository: widget.operationRepository!,
              platformRepository: widget.platformRepository,
              mobilizationProvider: widget.mobilizationProvider,
              administrationRepository: widget.administrationRepository,
              administrationService: widget.administrationService,
              missionRepository: widget.missionRepository,
            ),
    1 => PlatformAdminMoreScreen(onSignOut: widget.onSignOut),
    _ => throw RangeError.index(index, _screens),
  };

  void _selectTab(int index) {
    setState(() {
      _screens[index] ??= _createScreen(index);
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('platform-admin-shell'),
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
    bottomNavigationBar: PlatformAdminBottomNavigation(
      selectedIndex: _currentIndex,
      onDestinationSelected: _selectTab,
    ),
  );
}

class PlatformAdminComingSoonScreen extends StatelessWidget {
  const PlatformAdminComingSoonScreen({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    final accent = PlatformAdminIdentity.accent(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(V5Spacing.xl),
        child: Semantics(
          label: '$title, à venir',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: PlatformAdminIdentity.container(context),
                  borderRadius: BorderRadius.circular(V5Radius.card),
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(height: V5Spacing.md),
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: V5Spacing.xs),
              Text(
                'À venir',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
