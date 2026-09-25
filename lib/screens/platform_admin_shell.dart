import 'package:flutter/material.dart';

import '../models/need.dart';
import '../platform_admin/operation_coordinator_view_data.dart';
import '../repositories/operation_coordinator_read_repository.dart';
import '../repositories/platform_actor_read_repository.dart';
import '../repositories/platform_administration_read_repository.dart';
import '../repositories/platform_admin_statistics_read_repository.dart';
import '../repositories/platform_admin_history_read_repository.dart';
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
import 'platform_admin_actors_screen.dart';
import 'platform_admin_operations_screen.dart';
import 'platform_admin_more_screen.dart';
import 'platform_admin_statistics_screen.dart';
import 'platform_admin_history_screen.dart';

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
    this.locationStream,
    this.actorRepository = const NoPlatformActorReadRepository(),
    this.initialIndex = 0,
  }) : assert(initialIndex >= 0 && initialIndex < 5);

  final PlatformReadRepository platformRepository;
  final MobilizationContextProvider mobilizationProvider;
  final PlatformAdministrationReadRepository administrationRepository;
  final PlatformAdministrationService administrationService;
  final Future<void> Function() onSignOut;
  final OperationReadRepository? operationRepository;
  final MultiMobilizationCoordinationReadRepository? missionRepository;
  final Stream<List<ResponsePlace>>? locationStream;
  final PlatformActorReadRepository actorRepository;
  final int initialIndex;

  @override
  State<PlatformAdminShell> createState() => _PlatformAdminShellState();
}

class _PlatformAdminShellState extends State<PlatformAdminShell> {
  late int _currentIndex;
  final List<Widget?> _screens = List<Widget?>.filled(5, null);

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
              locationStream: widget.locationStream,
              operationCoordinatorDataSource:
                  RepositoryOperationCoordinatorViewDataSource(
                    repository:
                        widget.administrationRepository
                            is OperationCoordinatorReadRepository
                        ? widget.administrationRepository
                              as OperationCoordinatorReadRepository
                        : const NoOperationCoordinatorReadRepository(),
                  ),
              actorRepository: widget.actorRepository,
            ),
    1 => PlatformAdminActorsScreen(repository: widget.actorRepository),
    2 => PlatformAdminStatisticsScreen(
      dataSource: RepositoryPlatformAdminStatisticsDataSource(
        platformRepository: widget.platformRepository,
        operationRepository: widget.operationRepository,
        missionRepository: widget.missionRepository,
      ),
    ),
    3 => PlatformAdminHistoryScreen(
      dataSource: RepositoryPlatformAdminHistoryDataSource(
        platformRepository: widget.platformRepository,
        operationRepository: widget.operationRepository,
        missionRepository: widget.missionRepository,
      ),
    ),
    4 => PlatformAdminMoreScreen(
      onSignOut: widget.onSignOut,
      administrationService: widget.administrationService,
    ),
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
    final shell = Scaffold(
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
    final service = widget.administrationService;
    if (service is! PlatformAdministrationSessionProvider) return shell;
    final sessionProvider = service as PlatformAdministrationSessionProvider;
    return ValueListenableBuilder<PlatformAdministrationSessionState>(
      valueListenable: sessionProvider.sessionState,
      child: shell,
      builder: (context, session, child) {
        final expired = session == PlatformAdministrationSessionState.expired;
        return Stack(
          fit: StackFit.expand,
          children: [
            AbsorbPointer(absorbing: expired, child: child),
            if (expired)
              _PlatformAdminExpiredSession(onReconnect: widget.onSignOut),
          ],
        );
      },
    );
  }
}

class _PlatformAdminExpiredSession extends StatefulWidget {
  const _PlatformAdminExpiredSession({required this.onReconnect});

  final Future<void> Function() onReconnect;

  @override
  State<_PlatformAdminExpiredSession> createState() =>
      _PlatformAdminExpiredSessionState();
}

class _PlatformAdminExpiredSessionState
    extends State<_PlatformAdminExpiredSession> {
  bool _reconnecting = false;

  Future<void> _reconnect() async {
    if (_reconnecting) return;
    setState(() => _reconnecting = true);
    try {
      await widget.onReconnect();
    } finally {
      if (mounted) setState(() => _reconnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.v5Colors;
    return ColoredBox(
      key: const Key('platform-admin-session-expired'),
      color: colors.canvas.withValues(alpha: 0.94),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(V5Spacing.xl),
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              label: 'Session administrateur expirée',
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(V5Spacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_clock_outlined,
                          color: colors.danger,
                          size: 36,
                        ),
                        const SizedBox(height: V5Spacing.md),
                        Text(
                          'Votre session a expiré',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: V5Spacing.sm),
                        Text(
                          'Reconnectez-vous pour reprendre les actions '
                          'd’administration.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: colors.textSecondary),
                        ),
                        const SizedBox(height: V5Spacing.xl),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const Key('platform-admin-reconnect'),
                            onPressed: _reconnecting ? null : _reconnect,
                            icon: const Icon(Icons.login_outlined),
                            label: Text(
                              _reconnecting ? 'Reconnexion…' : 'Se reconnecter',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
