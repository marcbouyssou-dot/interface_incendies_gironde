import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/mobilization_context.dart';
import 'package:interface_incendies_gironde/models/platform_administrator_access.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/models/user_display_identity.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_administration_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_runtime.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_shell.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_more_screen.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/services/current_mobilization_provider.dart';
import 'package:interface_incendies_gironde/services/platform_administration_service.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';

void main() {
  test('platform authority and coordinator assignment are parsed strictly', () {
    final administrator = PlatformAdministratorAccess.fromMap(
      uid: 'platform-admin',
      data: const {'active': true},
    );
    final assignment = MobilizationCoordinatorAssignment.fromMap(
      id: 'mobilization-1_coordinator-1',
      data: const {
        'uid': 'coordinator-1',
        'mobilizationId': 'mobilization-1',
        'role': 'coordinator',
        'active': true,
      },
    );

    expect(administrator.active, isTrue);
    expect(assignment.active, isTrue);
    expect(
      const ActivePlatformCoordinator(
        uid: 'technical-coordinator-uid',
      ).displayIdentity.displayName,
      'Coordinateur',
    );
    expect(
      () => MobilizationCoordinatorAssignment.fromMap(
        id: 'incoherent',
        data: const {
          'uid': 'coordinator-1',
          'mobilizationId': 'mobilization-1',
          'role': 'coordinator',
          'active': true,
        },
      ),
      throwsFormatException,
    );
  });

  testWidgets('a non-admin never sees the platform shell', (tester) async {
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
        platformRuntime: _runtime(administrator: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlatformAdminShell), findsNothing);
    expect(find.byType(ProfessionalShell), findsOneWidget);

    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
        platformRuntime: _runtime(
          administrator: const PlatformAdministratorAccess(
            uid: 'inactive-platform-admin',
            active: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlatformAdminShell), findsNothing);
  });

  testWidgets('an active platform administrator is routed to its shell', (
    tester,
  ) async {
    await _pumpPlatformAdmin(tester);

    expect(find.byType(PlatformAdminShell), findsOneWidget);
    expect(find.byKey(const Key('platform-admin-shell')), findsOneWidget);
    expect(find.byType(ProfessionalShell), findsNothing);
    expect(find.text('Administration plateforme'), findsOneWidget);
  });

  testWidgets('the active mobilization and territory are displayed', (
    tester,
  ) async {
    await _pumpPlatformAdmin(tester);

    expect(find.byKey(const Key('active-mobilization-card')), findsOneWidget);
    expect(find.text('Incendies Gironde'), findsWidgets);
    expect(find.text('Incendie'), findsOneWidget);
    expect(find.text('Gironde · 33'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Activée le'), findsOneWidget);
    expect(find.byKey(const Key('platform-activation-date')), findsOneWidget);

    for (final key in [
      'platform-create-mobilization',
      'platform-deactivate-mobilization',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
      expect(tester.widget<V5Button>(find.byKey(Key(key))).onPressed, isNull);
    }
  });

  testWidgets('absence of an active mobilization has a dedicated state', (
    tester,
  ) async {
    await _pumpPlatformAdmin(
      tester,
      contextStream: Stream<MobilizationContext?>.value(null),
      hasActiveMobilization: false,
    );

    expect(
      find.byKey(const Key('platform-no-active-mobilization')),
      findsOneWidget,
    );
    expect(find.text('Aucune mobilisation active'), findsOneWidget);
  });

  testWidgets('assigned coordinator and active state are displayed', (
    tester,
  ) async {
    await _pumpPlatformAdmin(tester);

    expect(find.byKey(const Key('platform-coordination-card')), findsOneWidget);
    expect(find.text('Camille Martin'), findsOneWidget);
    expect(find.text('Coordinateur · Périmètre départemental'), findsOneWidget);
    expect(find.text('coordinator-user-12345'), findsNothing);
    expect(find.text('Actif'), findsOneWidget);
  });

  testWidgets('loading and read errors have explicit states', (tester) async {
    final pending = StreamController<MobilizationContext?>();
    addTearDown(pending.close);
    await _pumpPlatformAdmin(
      tester,
      contextStream: pending.stream,
      settle: false,
    );
    await tester.pump();

    expect(
      find.byKey(const Key('platform-mobilization-loading')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('platform-loading-indicator')), findsOneWidget);

    pending.addError(StateError('indisponible'));
    await tester.pump();

    expect(
      find.byKey(const Key('platform-mobilization-error')),
      findsOneWidget,
    );
    expect(find.text('Lecture de la plateforme impossible'), findsOneWidget);
  });

  testWidgets('secondary navigation exposes clean coming-soon states', (
    tester,
  ) async {
    await _pumpPlatformAdmin(tester);

    final navigation = tester.widget<V5BottomBar>(
      find.byKey(const Key('platform-admin-bottom-navigation')),
    );
    expect(navigation.destinations, hasLength(4));
    expect(navigation.destinations.map((destination) => destination.label), [
      'Mobilisation',
      'Territoires',
      'Coordinateurs',
      'Plus',
    ]);

    for (final label in ['Territoires', 'Coordinateurs']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(find.text('À venir'), findsOneWidget);
    }

    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();
    expect(find.byType(PlatformAdminMoreScreen), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  testWidgets('platform sign-out confirmation can be cancelled', (
    tester,
  ) async {
    final repository = _RecordingCoordinationRepository();
    await _pumpPlatformAdmin(tester, repository: repository);

    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();
    final signOut = find.byKey(const Key('platform-admin-sign-out'));
    expect(signOut, findsOneWidget);
    expect(tester.getSize(signOut).height, greaterThanOrEqualTo(44));

    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(find.text('Se déconnecter ?'), findsOneWidget);

    await tester.tap(find.text('Annuler').last);
    await tester.pumpAndSettle();
    expect(repository.signOutCalls, 0);
    expect(find.byType(PlatformAdminShell), findsOneWidget);
  });

  testWidgets(
    'confirmed platform sign-out runs once and opens authentication',
    (tester) async {
      final repository = _RecordingCoordinationRepository();
      await _pumpPlatformAdmin(tester, repository: repository);

      await tester.tap(find.text('Plus').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('platform-admin-sign-out')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('confirm-platform-admin-sign-out'));
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(find.byType(PlatformAdminShell), findsNothing);
      expect(
        find.byKey(const Key('platform-admin-authentication')),
        findsOneWidget,
      );
      expect(find.byType(ResponsibleLogin), findsOneWidget);
      expect(find.text('Se connecter'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the admin shell supports semantics and 200 percent text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await _pumpPlatformAdmin(tester);

    final mobilizationTab = find.bySemanticsLabel('Mobilisation');
    expect(mobilizationTab, findsWidgets);
    expect(
      tester.getSize(mobilizationTab.first).height,
      greaterThanOrEqualTo(44),
    );
    expect(find.byKey(const Key('platform-admin-question')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<void> _pumpPlatformAdmin(
  WidgetTester tester, {
  MockCoordinationRepository? repository,
  Stream<MobilizationContext?>? contextStream,
  bool hasActiveMobilization = true,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    FireCoordinationApp(
      repository:
          repository ?? MockCoordinationRepository(responsibleAccess: null),
      platformRuntime: _runtime(
        administrator: const PlatformAdministratorAccess(
          uid: 'platform-admin',
          active: true,
        ),
        contextStream:
            contextStream ??
            Stream<MobilizationContext?>.value(
              const MobilizationContext(
                mobilizationId: 'incendies-gironde-2026',
                territoryId: 'gironde',
                status: MobilizationStatus.active,
              ),
            ),
        hasActiveMobilization: hasActiveMobilization,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

class _RecordingCoordinationRepository extends MockCoordinationRepository {
  _RecordingCoordinationRepository() : super(responsibleAccess: null);

  int signOutCalls = 0;

  @override
  Future<void> signOutResponsible() async {
    signOutCalls++;
  }
}

PlatformRuntime _runtime({
  required PlatformAdministratorAccess? administrator,
  Stream<MobilizationContext?>? contextStream,
  bool hasActiveMobilization = true,
}) {
  return _FakePlatformRuntime(
    platformRepository: _FakePlatformReadRepository(
      activeMobilization: hasActiveMobilization ? _activeMobilization : null,
    ),
    currentMobilizationProvider: _FakeMobilizationProvider(
      contextStream ?? Stream<MobilizationContext?>.value(null),
    ),
    administrationRepository: _FakeAdministrationReadRepository(
      administrator: administrator,
      assignments: const [
        MobilizationCoordinatorAssignment(
          id: 'incendies-gironde-2026_coordinator-user-12345',
          uid: 'coordinator-user-12345',
          mobilizationId: 'incendies-gironde-2026',
          active: true,
          identity: UserDisplayIdentity(
            uid: 'coordinator-user-12345',
            displayName: 'Camille Martin',
            professionLabel: 'Coordinateur',
            organizationLabel: 'Périmètre départemental',
          ),
        ),
      ],
    ),
  );
}

final _activeMobilization = Mobilization(
  id: 'incendies-gironde-2026',
  territoryId: 'gironde',
  name: 'Incendies Gironde',
  subtitle: 'Incendies Gironde',
  contextType: MobilizationContextType.fire,
  status: MobilizationStatus.active,
  createdBy: 'platform-admin',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 10),
  activatedBy: 'platform-admin',
  activatedAt: DateTime.utc(2026, 8, 10),
  schemaVersion: 1,
);

final _gironde = Territory(
  id: 'gironde',
  name: 'Gironde',
  code: '33',
  active: true,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 10),
);

class _FakePlatformRuntime implements PlatformRuntime {
  const _FakePlatformRuntime({
    required this.platformRepository,
    required this.currentMobilizationProvider,
    required this.administrationRepository,
  });

  @override
  PlatformReadRepository get platformReadRepository => platformRepository;

  final PlatformReadRepository platformRepository;

  @override
  final MobilizationContextProvider currentMobilizationProvider;

  final PlatformAdministrationReadRepository administrationRepository;

  @override
  PlatformAdministrationReadRepository
  get platformAdministrationReadRepository => administrationRepository;

  @override
  PlatformAdministrationService get platformAdministrationService =>
      const NoPlatformAdministrationService();
}

class _FakeMobilizationProvider implements MobilizationContextProvider {
  const _FakeMobilizationProvider(this.contextStream);

  final Stream<MobilizationContext?> contextStream;

  @override
  Stream<String?> watchActiveMobilizationId() =>
      contextStream.map((context) => context?.mobilizationId);

  @override
  Stream<MobilizationContext?> watchContext() => contextStream;
}

class _FakePlatformReadRepository implements PlatformReadRepository {
  const _FakePlatformReadRepository({required this.activeMobilization});

  final Mobilization? activeMobilization;

  @override
  Stream<Mobilization?> watchActiveMobilization() =>
      Stream<Mobilization?>.value(activeMobilization);

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) => Stream<List<Mobilization>>.value(
    activeMobilization == null ? const [] : [activeMobilization!],
  );

  @override
  Stream<String?> watchPlatformConfig() =>
      Stream<String?>.value(activeMobilization?.id);

  @override
  Stream<List<Territory>> watchTerritories() =>
      Stream<List<Territory>>.value([_gironde]);
}

class _FakeAdministrationReadRepository
    implements PlatformAdministrationReadRepository {
  const _FakeAdministrationReadRepository({
    required this.administrator,
    required this.assignments,
  });

  final PlatformAdministratorAccess? administrator;
  final List<MobilizationCoordinatorAssignment> assignments;

  @override
  Stream<List<ActivePlatformCoordinator>> watchActiveCoordinators() =>
      Stream<List<ActivePlatformCoordinator>>.value(
        assignments
            .where((assignment) => assignment.active)
            .map((assignment) => ActivePlatformCoordinator(uid: assignment.uid))
            .toList(growable: false),
      );

  @override
  Stream<PlatformAdministratorAccess?> watchCurrentAdministrator() =>
      Stream<PlatformAdministratorAccess?>.value(administrator);

  @override
  Stream<List<MobilizationCoordinatorAssignment>> watchMobilizationCoordinators(
    String mobilizationId,
  ) => Stream<List<MobilizationCoordinatorAssignment>>.value(
    assignments
        .where((assignment) => assignment.mobilizationId == mobilizationId)
        .toList(growable: false),
  );
}
