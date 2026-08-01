import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  const coordinator = ResponsibleAccess(
    uid: 'coordinator',
    role: 'coordinator',
    locationIds: {'*'},
    active: true,
  );
  const manager = ResponsibleAccess(
    uid: 'manager',
    role: 'site_manager',
    locationIds: {'site-a'},
    active: true,
  );

  Future<_ControlledSituationRepository> pumpSituation(
    WidgetTester tester, {
    ResponsibleAccess? initialAccess,
    bool emitInitialAccess = true,
    String createdBy = 'coordinator',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _ControlledSituationRepository(
      initialAccess: initialAccess,
      emitInitialAccess: emitInitialAccess,
      createdBy: createdBy,
    );
    addTearDown(repository.disposeAccess);
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Situation').last);
    for (
      var attempt = 0;
      attempt < 5 && repository.accessFactories == 0;
      attempt++
    ) {
      await tester.pump();
    }
    expect(repository.accessFactories, 1);
    if (emitInitialAccess) {
      repository.emit(initialAccess);
      await tester.pumpAndSettle();
    }
    return repository;
  }

  void expectNoPrivilegedSituationContent() {
    expect(find.text('Annuler ce besoin'), findsNothing);
    expect(
      find.byKey(const Key('engagement-menu-ui-mission_volunteer')),
      findsNothing,
    );
    expect(find.text('MK • En attente'), findsNothing);
  }

  Future<void> pumpAccessUpdate(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('initial generic access error fails closed without spinner', (
    tester,
  ) async {
    final repository = await pumpSituation(tester, emitInitialAccess: false);

    repository.emitError(StateError('firestore unavailable'));
    await pumpAccessUpdate(tester);

    expect(find.text('Accès temporairement indisponible'), findsOneWidget);
    expect(find.text('Configuration d’accès invalide'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('SITUATION'), findsNothing);
    expectNoPrivilegedSituationContent();
  });

  testWidgets(
    'coordinator access is removed on error and restored on recovery',
    (tester) async {
      final repository = await pumpSituation(
        tester,
        initialAccess: coordinator,
      );

      expect(find.text('SITUATION'), findsOneWidget);
      expect(find.text('Annuler ce besoin'), findsOneWidget);
      expect(
        find.byKey(const Key('engagement-menu-ui-mission_volunteer')),
        findsOneWidget,
      );

      repository.emitError(StateError('permission unavailable'));
      await pumpAccessUpdate(tester);

      expect(find.text('Accès temporairement indisponible'), findsOneWidget);
      expect(find.text('SITUATION'), findsNothing);
      expectNoPrivilegedSituationContent();

      repository.emit(coordinator);
      await pumpAccessUpdate(tester);

      expect(find.text('Accès temporairement indisponible'), findsNothing);
      expect(find.text('SITUATION'), findsOneWidget);
      expect(find.text('Annuler ce besoin'), findsOneWidget);
      expect(
        find.byKey(const Key('engagement-menu-ui-mission_volunteer')),
        findsOneWidget,
      );
    },
  );

  testWidgets('site manager scope is removed on a subsequent stream error', (
    tester,
  ) async {
    final repository = await pumpSituation(
      tester,
      initialAccess: manager,
      createdBy: 'manager',
    );

    expect(find.text('Annuler ce besoin'), findsOneWidget);
    expect(
      find.byKey(const Key('engagement-menu-ui-mission_volunteer')),
      findsNothing,
    );

    repository.emitError(StateError('network unavailable'));
    await pumpAccessUpdate(tester);

    expect(find.text('Accès temporairement indisponible'), findsOneWidget);
    expect(find.text('Site A'), findsNothing);
    expectNoPrivilegedSituationContent();
  });

  testWidgets('malformed access has a distinct fail-closed state', (
    tester,
  ) async {
    final repository = await pumpSituation(tester, emitInitialAccess: false);

    repository.emitError(
      const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidRoles,
        'invalid roles',
      ),
    );
    await pumpAccessUpdate(tester);

    expect(find.text('Configuration d’accès invalide'), findsOneWidget);
    expect(find.text('Accès temporairement indisponible'), findsNothing);
    expectNoPrivilegedSituationContent();
  });

  testWidgets('revocation and sign-out immediately remove privileged actions', (
    tester,
  ) async {
    final repository = await pumpSituation(tester, initialAccess: coordinator);
    expect(find.text('Annuler ce besoin'), findsOneWidget);

    repository.emit(
      const ResponsibleAccess(
        uid: 'coordinator',
        role: 'coordinator',
        locationIds: {'*'},
        active: false,
      ),
    );
    await pumpAccessUpdate(tester);

    expect(find.text('SITUATION'), findsOneWidget);
    expectNoPrivilegedSituationContent();

    repository.emit(coordinator);
    await pumpAccessUpdate(tester);
    expect(find.text('Annuler ce besoin'), findsOneWidget);

    repository.emit(null);
    await pumpAccessUpdate(tester);

    expect(find.text('SITUATION'), findsOneWidget);
    expectNoPrivilegedSituationContent();
  });

  testWidgets('site manager scope removal immediately hides mission actions', (
    tester,
  ) async {
    final repository = await pumpSituation(
      tester,
      initialAccess: manager,
      createdBy: 'manager',
    );
    expect(find.text('Annuler ce besoin'), findsOneWidget);

    repository.emit(
      const ResponsibleAccess(
        uid: 'manager',
        role: 'site_manager',
        locationIds: {'other-site'},
        active: true,
      ),
    );
    await pumpAccessUpdate(tester);

    expect(find.text('SITUATION'), findsOneWidget);
    expectNoPrivilegedSituationContent();
  });

  testWidgets('stream error remains safe across tabs and later recovers', (
    tester,
  ) async {
    final repository = await pumpSituation(tester, initialAccess: coordinator);

    repository.emitError(StateError('temporarily unavailable'));
    await pumpAccessUpdate(tester);
    expect(find.text('Accès temporairement indisponible'), findsOneWidget);

    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Situation').last);
    await tester.pump();

    expect(find.text('Accès temporairement indisponible'), findsOneWidget);
    expectNoPrivilegedSituationContent();

    repository.emit(coordinator);
    await pumpAccessUpdate(tester);
    expect(find.text('Accès temporairement indisponible'), findsNothing);
    expect(find.text('Annuler ce besoin'), findsOneWidget);
  });

  testWidgets(
    'error after revocation never restores the previous coordinator',
    (tester) async {
      final repository = await pumpSituation(
        tester,
        initialAccess: coordinator,
      );

      repository.emit(null);
      await pumpAccessUpdate(tester);
      expectNoPrivilegedSituationContent();

      repository.emitError(StateError('stream unavailable after sign-out'));
      await pumpAccessUpdate(tester);

      expect(find.text('Accès temporairement indisponible'), findsOneWidget);
      expectNoPrivilegedSituationContent();
    },
  );
}

class _ControlledSituationRepository extends MockCoordinationRepository {
  _ControlledSituationRepository({
    required this.initialAccess,
    required this.emitInitialAccess,
    required String createdBy,
  }) : super(
         initialMissions: [
           CoordinationNeed(
             id: 'ui-mission',
             locationId: 'site-a',
             place: 'Site A',
             group: TerritorialGroup.medoc,
             date: 'Aujourd’hui',
             time: '08:00 — 12:00',
             requiredPhysiotherapists: 2,
             registeredPhysiotherapists: 0,
             requiredPodiatrists: 0,
             registeredPodiatrists: 0,
             equipment: const [],
             createdBy: createdBy,
           ),
         ],
         initialLocations: const [
           ResponsePlace(
             id: 'site-a',
             name: 'Site A',
             type: ResponsePlaceType.sdisStation,
             group: TerritorialGroup.medoc,
             activeNeeds: 1,
           ),
         ],
         initialEngagements: const [
           EngagementInfo(
             missionId: 'ui-mission',
             volunteerId: 'volunteer',
             profession: VolunteerProfession.mk,
             status: EngagementStatus.pending,
           ),
         ],
         responsibleAccess: initialAccess,
       );

  final ResponsibleAccess? initialAccess;
  final bool emitInitialAccess;
  final _access = StreamController<ResponsibleAccess?>.broadcast(sync: true);
  int accessFactories = 0;

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() {
    accessFactories++;
    return _access.stream;
  }

  void emit(ResponsibleAccess? access) => _access.add(access);

  void emitError(Object error) => _access.addError(error, StackTrace.current);

  Future<void> disposeAccess() => _access.close();
}
