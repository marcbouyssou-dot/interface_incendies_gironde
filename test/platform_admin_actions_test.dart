import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/mobilization_context.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/platform_administrator_access.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/models/user_display_identity.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_administration_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_runtime.dart';
import 'package:interface_incendies_gironde/services/current_mobilization_provider.dart';
import 'package:interface_incendies_gironde/services/platform_administration_service.dart';

void main() {
  testWidgets('new mobilization is created as a backend draft', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);

    await _tapAction(tester, const Key('platform-create-mobilization'));
    expect(find.text('Préparer la mobilisation'), findsOneWidget);
    await _fillMobilizationForm(
      tester,
      name: 'Canicule Gironde',
      subtitle: 'Dispositif estival',
      contextLabel: 'Canicule',
    );
    await tester.tap(find.byKey(const Key('submit-platform-mobilization')));
    await tester.pumpAndSettle();

    expect(harness.service.createCalls, hasLength(1));
    final draft = harness.service.createCalls.single;
    expect(draft.mobilizationId, 'canicule-gironde-${DateTime.now().year}');
    expect(draft.territoryId, 'gironde');
    expect(draft.contextType, MobilizationContextType.heatwave);
  });

  testWidgets('invalid form payload never reaches the service', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);

    await _tapAction(tester, const Key('platform-create-mobilization'));
    await tester.tap(find.byKey(const Key('submit-platform-mobilization')));
    await tester.pump();

    expect(find.text('Ce champ est obligatoire.'), findsWidgets);
    expect(harness.service.createCalls, isEmpty);
  });

  testWidgets('draft mobilization can be modified', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);

    await _tapAction(
      tester,
      const Key('edit-mobilization-canicule-gironde-2026'),
    );
    final name = find.descendant(
      of: find.byKey(const Key('platform-mobilization-name')),
      matching: find.byType(EditableText),
    );
    await tester.enterText(name, 'Canicule Gironde renforcée');
    await tester.tap(find.byKey(const Key('submit-platform-mobilization')));
    await tester.pumpAndSettle();

    expect(harness.service.updateCalls, hasLength(1));
    expect(
      harness.service.updateCalls.single.mobilizationId,
      'canicule-gironde-2026',
    );
    expect(harness.service.updateCalls.single.name, contains('renforcée'));
  });

  testWidgets('prepared mobilizations use human lifecycle labels', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);

    expect(
      find.text('Mobilisation préparée', skipOffstage: false),
      findsNWidgets(2),
    );
    expect(find.text('Brouillon', skipOffstage: false), findsNothing);
    expect(find.text('Inactive', skipOffstage: false), findsNothing);
  });

  testWidgets('active V5 coordinator can be assigned', (tester) async {
    final harness = _Harness(assignDraftCoordinator: false);
    await harness.pump(tester);

    await _tapAction(
      tester,
      const Key('assign-coordinator-canicule-gironde-2026'),
    );
    await tester.tap(find.byKey(const Key('platform-coordinator-select')));
    await tester.pumpAndSettle();
    expect(find.text('coordinator-001'), findsNothing);
    await tester.tap(find.textContaining('Camille Martin').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm-platform-coordinator-assignment')),
    );
    await tester.pumpAndSettle();

    expect(harness.service.assignmentCalls, [
      ('canicule-gironde-2026', 'coordinator-001'),
    ]);
  });

  testWidgets('coordinator assignment can be removed', (tester) async {
    final harness = _Harness();
    await harness.pump(tester);

    await _tapAction(
      tester,
      const Key('remove-coordinator-canicule-gironde-2026-coordinator-001'),
    );
    await tester.tap(
      find.byKey(const Key('confirm-platform-coordinator-removal')),
    );
    await tester.pumpAndSettle();

    expect(harness.service.removalCalls, [
      ('canicule-gironde-2026', 'coordinator-001'),
    ]);
  });

  testWidgets('activation confirmation includes territory and coordinator', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);

    await _tapAction(
      tester,
      const Key('activate-mobilization-canicule-gironde-2026'),
    );
    expect(find.textContaining('Canicule Gironde'), findsWidgets);
    expect(find.textContaining('Territoire : Gironde'), findsOneWidget);
    expect(
      find.textContaining('Coordination : Camille Martin'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('confirm-platform-activation')));
    await tester.pumpAndSettle();

    expect(harness.service.activationCalls, ['canicule-gironde-2026']);
  });

  testWidgets('activation without coordinator is refused client-side', (
    tester,
  ) async {
    final harness = _Harness(assignDraftCoordinator: false);
    await harness.pump(tester);

    expect(
      find.text('Coordination à compléter', skipOffstage: false),
      findsWidgets,
    );
    expect(
      find.text(
        'Cette mobilisation n’est pas prête à être activée.',
        skipOffstage: false,
      ),
      findsWidgets,
    );
    expect(
      find.text('Aucun Coordinateur affecté', skipOffstage: false),
      findsNothing,
    );

    await _tapAction(
      tester,
      const Key('activate-mobilization-canicule-gironde-2026'),
    );
    await tester.pump();

    expect(
      find.text('Affectez un Coordinateur actif avant l’activation.'),
      findsOneWidget,
    );
    expect(harness.service.activationCalls, isEmpty);
  });

  testWidgets('active mobilization can be deactivated after confirmation', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);

    await _tapAction(tester, const Key('platform-deactivate-mobilization'));
    await tester.tap(find.byKey(const Key('confirm-platform-deactivation')));
    await tester.pumpAndSettle();

    expect(harness.service.deactivationCalls, ['incendies-gironde-2026']);
  });

  testWidgets('draft and inactive can be archived but active cannot', (
    tester,
  ) async {
    final harness = _Harness();
    await harness.pump(tester);

    expect(
      find.byKey(
        const Key('archive-mobilization-incendies-gironde-2026'),
        skipOffstage: false,
      ),
      findsNothing,
    );
    for (final id in ['canicule-gironde-2026', 'inondation-gironde-2025']) {
      await _tapAction(tester, Key('archive-mobilization-$id'));
      await tester.tap(find.byKey(const Key('confirm-platform-archive')));
      await tester.pumpAndSettle();
    }

    expect(harness.service.archiveCalls, [
      'canicule-gironde-2026',
      'inondation-gironde-2025',
    ]);
  });

  testWidgets('callable error is surfaced as a V5 toast', (tester) async {
    final harness = _Harness(
      failure: const PlatformAdministrationException(
        'Cette action n’est plus possible dans l’état actuel.',
      ),
    );
    await harness.pump(tester);

    await _tapAction(
      tester,
      const Key('archive-mobilization-canicule-gironde-2026'),
    );
    await tester.tap(find.byKey(const Key('confirm-platform-archive')));
    await tester.pump();

    expect(
      find.text('Cette action n’est plus possible dans l’état actuel.'),
      findsOneWidget,
    );
  });

  testWidgets('mutation loading prevents double submit', (tester) async {
    final pending = Completer<void>();
    final harness = _Harness(pendingMutation: pending.future);
    await harness.pump(tester);

    await _tapAction(
      tester,
      const Key('archive-mobilization-canicule-gironde-2026'),
    );
    await tester.tap(find.byKey(const Key('confirm-platform-archive')));
    await tester.pump();

    expect(find.byKey(const Key('platform-mutation-loading')), findsOneWidget);
    expect(harness.service.archiveCalls, ['canicule-gironde-2026']);
    expect(
      find.byKey(
        const Key('archive-mobilization-canicule-gironde-2026'),
        skipOffstage: false,
      ),
      findsNothing,
    );

    pending.complete();
    await tester.pumpAndSettle();
    expect(harness.service.archiveCalls, hasLength(1));
  });
}

Future<void> _fillMobilizationForm(
  WidgetTester tester, {
  required String name,
  required String subtitle,
  required String contextLabel,
}) async {
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('platform-mobilization-name')),
      matching: find.byType(EditableText),
    ),
    name,
  );
  await tester.enterText(
    find.descendant(
      of: find.byKey(const Key('platform-mobilization-subtitle')),
      matching: find.byType(EditableText),
    ),
    subtitle,
  );
  await tester.tap(find.byKey(const Key('platform-mobilization-territory')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gironde · 33').last);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('platform-mobilization-context')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(contextLabel).last);
  await tester.pumpAndSettle();
}

Future<void> _tapAction(WidgetTester tester, Key key) async {
  final finder = find.byKey(key, skipOffstage: false);
  await tester.scrollUntilVisible(
    finder,
    260,
    scrollable: find.descendant(
      of: find.byKey(const PageStorageKey('platform-admin-mobilization')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _Harness {
  _Harness({
    this.assignDraftCoordinator = true,
    this.failure,
    this.pendingMutation,
  });

  final bool assignDraftCoordinator;
  final PlatformAdministrationException? failure;
  final Future<void>? pendingMutation;
  late final _RecordingPlatformService service = _RecordingPlatformService(
    failure: failure,
    pendingMutation: pendingMutation,
  );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
        platformRuntime: _ActionsRuntime(
          platformReadRepository: const _ActionsPlatformReadRepository(),
          currentMobilizationProvider: const _ActionsMobilizationProvider(),
          readRepository: _ActionsAdministrationReadRepository(
            assignDraftCoordinator: assignDraftCoordinator,
          ),
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

class _ActionsRuntime implements PlatformRuntime {
  const _ActionsRuntime({
    required this.platformReadRepository,
    required this.currentMobilizationProvider,
    required this.readRepository,
    required this.service,
  });

  @override
  final PlatformReadRepository platformReadRepository;

  @override
  final MobilizationContextProvider currentMobilizationProvider;

  final PlatformAdministrationReadRepository readRepository;
  final PlatformAdministrationService service;

  @override
  PlatformAdministrationReadRepository
  get platformAdministrationReadRepository => readRepository;

  @override
  PlatformAdministrationService get platformAdministrationService => service;
}

class _ActionsMobilizationProvider implements MobilizationContextProvider {
  const _ActionsMobilizationProvider();

  @override
  Stream<String?> watchActiveMobilizationId() =>
      Stream<String?>.value(_active.id);

  @override
  Stream<MobilizationContext?> watchContext() =>
      Stream<MobilizationContext?>.value(
        MobilizationContext.fromMobilization(_active),
      );
}

class _ActionsPlatformReadRepository implements PlatformReadRepository {
  const _ActionsPlatformReadRepository();

  @override
  Stream<Mobilization?> watchActiveMobilization() =>
      Stream<Mobilization?>.value(_active);

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) => Stream<List<Mobilization>>.value(
    includeInactive ? [_active, _draft, _inactive] : [_active],
  );

  @override
  Stream<String?> watchPlatformConfig() => Stream<String?>.value(_active.id);

  @override
  Stream<List<Territory>> watchTerritories() =>
      Stream<List<Territory>>.value([_gironde]);
}

class _ActionsAdministrationReadRepository
    implements PlatformAdministrationReadRepository {
  const _ActionsAdministrationReadRepository({
    required this.assignDraftCoordinator,
  });

  final bool assignDraftCoordinator;

  @override
  Stream<List<ActivePlatformCoordinator>> watchActiveCoordinators() =>
      Stream<List<ActivePlatformCoordinator>>.value(const [
        ActivePlatformCoordinator(
          uid: 'coordinator-001',
          identity: _coordinatorIdentity,
        ),
      ]);

  @override
  Stream<PlatformAdministratorAccess?> watchCurrentAdministrator() =>
      Stream<PlatformAdministratorAccess?>.value(
        const PlatformAdministratorAccess(uid: 'admin', active: true),
      );

  @override
  Stream<List<MobilizationCoordinatorAssignment>> watchMobilizationCoordinators(
    String mobilizationId,
  ) {
    if (mobilizationId == _active.id) {
      return Stream<List<MobilizationCoordinatorAssignment>>.value([
        _assignment(_active.id),
      ]);
    }
    if (mobilizationId == _draft.id && assignDraftCoordinator) {
      return Stream<List<MobilizationCoordinatorAssignment>>.value([
        _assignment(_draft.id),
      ]);
    }
    return Stream<List<MobilizationCoordinatorAssignment>>.value(const []);
  }
}

class _RecordingPlatformService implements PlatformAdministrationService {
  _RecordingPlatformService({this.failure, this.pendingMutation});

  final PlatformAdministrationException? failure;
  final Future<void>? pendingMutation;
  final List<MobilizationAdministrationDraft> createCalls = [];
  final List<MobilizationAdministrationDraft> updateCalls = [];
  final List<String> activationCalls = [];
  final List<String> deactivationCalls = [];
  final List<String> archiveCalls = [];
  final List<(String, String)> assignmentCalls = [];
  final List<(String, String)> removalCalls = [];
  final List<(String, String)> operationCoordinatorCalls = [];

  @override
  bool get isAvailable => true;

  Future<void> _complete() async {
    if (failure != null) throw failure!;
    final pending = pendingMutation;
    if (pending != null) await pending;
  }

  @override
  Future<void> activateMobilization(String mobilizationId) async {
    activationCalls.add(mobilizationId);
    await _complete();
  }

  @override
  Future<void> archiveMobilization(String mobilizationId) async {
    archiveCalls.add(mobilizationId);
    await _complete();
  }

  @override
  Future<void> assignMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  }) async {
    assignmentCalls.add((mobilizationId, uid));
    await _complete();
  }

  @override
  Future<void> createMobilization(MobilizationAdministrationDraft draft) async {
    createCalls.add(draft);
    await _complete();
  }

  @override
  Future<void> createOperation(OperationAdministrationDraft draft) async =>
      _complete();

  @override
  Future<void> deactivateMobilization(String mobilizationId) async {
    deactivationCalls.add(mobilizationId);
    await _complete();
  }

  @override
  Future<void> removeMobilizationCoordinator({
    required String mobilizationId,
    required String uid,
  }) async {
    removalCalls.add((mobilizationId, uid));
    await _complete();
  }

  @override
  Future<void> setOperationCoordinator({
    required String operationId,
    required String uid,
  }) async {
    operationCoordinatorCalls.add((operationId, uid));
    await _complete();
  }

  @override
  Future<void> updateMobilization(MobilizationAdministrationDraft draft) async {
    updateCalls.add(draft);
    await _complete();
  }

  @override
  Future<void> updateOperation(OperationAdministrationDraft draft) async =>
      _complete();

  @override
  Future<void> transitionOperation(
    String operationId,
    OperationStatus targetStatus,
  ) async => _complete();
}

MobilizationCoordinatorAssignment _assignment(String mobilizationId) =>
    MobilizationCoordinatorAssignment(
      id: '${mobilizationId}_coordinator-001',
      uid: 'coordinator-001',
      mobilizationId: mobilizationId,
      active: true,
      identity: _coordinatorIdentity,
    );

const _coordinatorIdentity = UserDisplayIdentity(
  uid: 'coordinator-001',
  displayName: 'Camille Martin',
  professionLabel: 'Coordinateur',
  organizationLabel: 'Périmètre départemental',
);

final _active = _mobilization(
  id: 'incendies-gironde-2026',
  name: 'Incendies Gironde',
  status: MobilizationStatus.active,
);
final _draft = _mobilization(
  id: 'canicule-gironde-2026',
  name: 'Canicule Gironde',
  status: MobilizationStatus.draft,
  contextType: MobilizationContextType.heatwave,
);
final _inactive = _mobilization(
  id: 'inondation-gironde-2025',
  name: 'Inondation Gironde',
  status: MobilizationStatus.inactive,
  contextType: MobilizationContextType.flood,
);

Mobilization _mobilization({
  required String id,
  required String name,
  required MobilizationStatus status,
  MobilizationContextType contextType = MobilizationContextType.fire,
}) => Mobilization(
  id: id,
  territoryId: 'gironde',
  name: name,
  subtitle: name,
  contextType: contextType,
  status: status,
  createdBy: 'admin',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 10),
  activatedBy: status == MobilizationStatus.active ? 'admin' : null,
  activatedAt: status == MobilizationStatus.active
      ? DateTime.utc(2026, 8, 10)
      : null,
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
