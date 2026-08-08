import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/widgets/common.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';

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

  Future<void> selectNavigationTab(WidgetTester tester, int index) async {
    final navigation = tester.widget<V5BottomBar>(find.byType(V5BottomBar));
    navigation.onDestinationSelected(index);
    for (var attempt = 0; attempt < 6; attempt++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder cancellationAction() => find.byType(MissionCancellationButton);

  Future<void> revealSituationContent(
    WidgetTester tester,
    Finder target,
  ) async {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
  }

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
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: repository,
        useLegacyCoordinatorShellForTesting: true,
      ),
    );
    await tester.pumpAndSettle();
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
      final siteManagerJourney =
          initialAccess?.roles.contains(ResponsibleRole.siteManager) == true &&
          initialAccess?.roles.contains(ResponsibleRole.coordinator) != true;
      await selectNavigationTab(tester, siteManagerJourney ? 1 : 2);
      if (initialAccess?.hasPrivilegedAccess == true &&
          initialAccess?.uid == createdBy) {
        await revealSituationContent(tester, cancellationAction());
      }
    } else {
      await selectNavigationTab(tester, 2);
    }
    return repository;
  }

  void expectNoPrivilegedSituationContent() {
    expect(cancellationAction(), findsNothing);
    expect(
      find.byKey(const Key('engagement-menu-ui-mission_volunteer')),
      findsNothing,
    );
    expect(find.text('MK • En attente'), findsNothing);
  }

  Future<void> pumpAccessUpdate(WidgetTester tester) async {
    for (var index = 0; index < 6; index++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
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
    expect(find.byKey(const PageStorageKey('coordination')), findsNothing);
    expectNoPrivilegedSituationContent();
  });

  testWidgets(
    'coordinator access is removed on error and restored on recovery',
    (tester) async {
      final repository = await pumpSituation(
        tester,
        initialAccess: coordinator,
      );

      expect(
        tester.widget<V5BottomBar>(find.byType(V5BottomBar)).selectedIndex,
        2,
      );
      expect(cancellationAction(), findsOneWidget);
      expect(
        find.byKey(const Key('engagement-menu-ui-mission_volunteer')),
        findsOneWidget,
      );

      repository.emitError(StateError('permission unavailable'));
      await pumpAccessUpdate(tester);

      expect(find.text('Accès temporairement indisponible'), findsOneWidget);
      expect(find.byKey(const PageStorageKey('coordination')), findsNothing);
      expectNoPrivilegedSituationContent();

      repository.emit(coordinator);
      await pumpAccessUpdate(tester);
      await revealSituationContent(tester, cancellationAction());

      expect(find.text('Accès temporairement indisponible'), findsNothing);
      expect(
        tester.widget<V5BottomBar>(find.byType(V5BottomBar)).selectedIndex,
        2,
      );
      expect(cancellationAction(), findsOneWidget);
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

    expect(cancellationAction(), findsOneWidget);
    expect(
      find.byKey(const Key('engagement-menu-ui-mission_volunteer')),
      findsNothing,
    );

    repository.emitError(StateError('network unavailable'));
    await pumpAccessUpdate(tester);

    expect(
      find.text('Les besoins sont temporairement indisponibles.'),
      findsOneWidget,
    );
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
    expect(cancellationAction(), findsOneWidget);

    repository.emit(
      const ResponsibleAccess(
        uid: 'coordinator',
        role: 'coordinator',
        locationIds: {'*'},
        active: false,
      ),
    );
    await pumpAccessUpdate(tester);

    expect(find.byKey(const PageStorageKey('coordination')), findsOneWidget);
    expectNoPrivilegedSituationContent();

    repository.emit(coordinator);
    await pumpAccessUpdate(tester);
    await revealSituationContent(tester, cancellationAction());
    expect(cancellationAction(), findsOneWidget);

    repository.emit(null);
    await pumpAccessUpdate(tester);

    expect(find.byType(ProfessionalShell), findsOneWidget);
    expect(find.byKey(const PageStorageKey('coordination')), findsNothing);
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
    expect(cancellationAction(), findsOneWidget);

    repository.emit(
      const ResponsibleAccess(
        uid: 'manager',
        role: 'site_manager',
        locationIds: {'other-site'},
        active: true,
      ),
    );
    await pumpAccessUpdate(tester);

    expect(
      find.byKey(const PageStorageKey('responsible-needs')),
      findsOneWidget,
    );
    expectNoPrivilegedSituationContent();
  });

  testWidgets('stream error remains safe across tabs and later recovers', (
    tester,
  ) async {
    final repository = await pumpSituation(tester, initialAccess: coordinator);

    repository.emitError(StateError('temporarily unavailable'));
    await pumpAccessUpdate(tester);
    expect(find.text('Accès temporairement indisponible'), findsOneWidget);

    await selectNavigationTab(tester, 3);
    await selectNavigationTab(tester, 2);
    await tester.pump();

    expect(find.text('Accès temporairement indisponible'), findsOneWidget);
    expectNoPrivilegedSituationContent();

    repository.emit(coordinator);
    await pumpAccessUpdate(tester);
    await revealSituationContent(tester, cancellationAction());
    expect(find.text('Accès temporairement indisponible'), findsNothing);
    expect(cancellationAction(), findsOneWidget);
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

  Future<_ControlledSituationDataRepository> pumpDataSituation(
    WidgetTester tester, {
    required ResponsibleAccess? access,
    Object? missionError,
    Object? locationError,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _ControlledSituationDataRepository();
    addTearDown(repository.disposeControllers);
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: repository,
        useLegacyCoordinatorShellForTesting: true,
      ),
    );
    await tester.pump();
    if (missionError == null) {
      repository.emitMissions([
        _situationMission('old', 'Ancienne mission', createdBy: access?.uid),
      ]);
    } else {
      repository.emitMissionsError(missionError);
    }
    await tester.pump();
    if (locationError == null) {
      repository.emitLocations([_situationLocation('Ancien centre')]);
    } else {
      repository.emitLocationsError(locationError);
    }
    await tester.pump();
    repository.emitAccess(access);
    await pumpAccessUpdate(tester);
    final siteManagerJourney =
        access?.roles.contains(ResponsibleRole.siteManager) == true &&
        access?.roles.contains(ResponsibleRole.coordinator) != true;
    await selectNavigationTab(tester, siteManagerJourney ? 1 : 2);
    if (missionError == null &&
        locationError == null &&
        access?.hasPrivilegedAccess == true) {
      await revealSituationContent(tester, cancellationAction());
    }
    return repository;
  }

  void expectNoStaleSituation() {
    expect(find.text('Ancienne mission'), findsNothing);
    expect(find.text('Ancien centre'), findsNothing);
    expect(find.text('COUVERTURE'), findsNothing);
    expect(cancellationAction(), findsNothing);
    expect(
      find.byKey(const Key('engagement-menu-old_volunteer')),
      findsNothing,
    );
  }

  testWidgets('initial mission error replaces the spinner with a safe state', (
    tester,
  ) async {
    await pumpDataSituation(
      tester,
      access: coordinator,
      missionError: StateError('missions unavailable'),
    );

    expect(find.text('Situation temporairement indisponible'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expectNoStaleSituation();
  });

  testWidgets('mission error clears old data and a new value recovers', (
    tester,
  ) async {
    final repository = await pumpDataSituation(tester, access: coordinator);
    expect(find.text('Ancienne mission'), findsOneWidget);
    expect(cancellationAction(), findsOneWidget);

    repository.emitMissionsError(StateError('missions unavailable'));
    await pumpAccessUpdate(tester);

    expect(find.text('Situation temporairement indisponible'), findsOneWidget);
    expectNoStaleSituation();

    repository.emitMissions([_situationMission('new', 'Nouvelle mission')]);
    await pumpAccessUpdate(tester);
    await revealSituationContent(tester, find.byKey(const ValueKey('new')));

    expect(find.text('Situation temporairement indisponible'), findsNothing);
    expect(find.text('Nouvelle mission'), findsOneWidget);
    expect(find.text('Ancienne mission'), findsNothing);
  });

  testWidgets('initial location error has an explicit closed state', (
    tester,
  ) async {
    await pumpDataSituation(
      tester,
      access: coordinator,
      locationError: StateError('locations unavailable'),
    );

    expect(find.text('Informations des centres indisponibles'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expectNoStaleSituation();
  });

  testWidgets('location error clears old data and a new value recovers', (
    tester,
  ) async {
    final repository = await pumpDataSituation(tester, access: coordinator);
    expect(find.text('Caserne SDIS'), findsOneWidget);

    repository.emitLocationsError(StateError('locations unavailable'));
    await pumpAccessUpdate(tester);

    expect(find.text('Informations des centres indisponibles'), findsOneWidget);
    expect(find.text('Caserne SDIS'), findsNothing);
    expectNoStaleSituation();

    repository.emitLocations([
      _situationLocation('Centre actualisé', type: ResponsePlaceType.redCross),
    ]);
    await pumpAccessUpdate(tester);
    await revealSituationContent(tester, find.text('Croix-Rouge'));

    expect(find.text('Informations des centres indisponibles'), findsNothing);
    expect(find.text('Croix-Rouge'), findsOneWidget);
    expect(find.text('Caserne SDIS'), findsNothing);
  });

  testWidgets('simultaneous data errors deterministically prefer missions', (
    tester,
  ) async {
    await pumpDataSituation(
      tester,
      access: coordinator,
      missionError: StateError('missions unavailable'),
      locationError: StateError('locations unavailable'),
    );

    expect(find.text('Situation temporairement indisponible'), findsOneWidget);
    expect(find.text('Informations des centres indisponibles'), findsNothing);
    expectNoStaleSituation();
  });

  testWidgets('mission error remains closed across tabs and then recovers', (
    tester,
  ) async {
    final repository = await pumpDataSituation(tester, access: coordinator);
    repository.emitMissionsError(StateError('missions unavailable'));
    await pumpAccessUpdate(tester);

    await selectNavigationTab(tester, 3);
    await selectNavigationTab(tester, 2);
    await tester.pump();

    expect(find.text('Situation temporairement indisponible'), findsOneWidget);
    expectNoStaleSituation();

    repository.emitMissions([_situationMission('new', 'Nouvelle mission')]);
    await pumpAccessUpdate(tester);
    await revealSituationContent(tester, find.byKey(const ValueKey('new')));
    expect(find.text('Nouvelle mission'), findsOneWidget);
  });

  testWidgets('coordinator and manager actions disappear on data errors', (
    tester,
  ) async {
    final coordinatorRepository = await pumpDataSituation(
      tester,
      access: coordinator,
    );
    expect(cancellationAction(), findsOneWidget);
    coordinatorRepository.emitMissionsError(StateError('missions unavailable'));
    await pumpAccessUpdate(tester);
    expectNoStaleSituation();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final managerRepository = await pumpDataSituation(tester, access: manager);
    expect(cancellationAction(), findsOneWidget);
    managerRepository.emitLocationsError(StateError('locations unavailable'));
    await pumpAccessUpdate(tester);
    expectNoStaleSituation();

    managerRepository.emitLocations([
      _situationLocation('Centre manager actualisé'),
    ]);
    await pumpAccessUpdate(tester);
    await revealSituationContent(tester, cancellationAction());
    expect(cancellationAction(), findsOneWidget);
    expect(find.text('Ancien centre'), findsNothing);
  });

  testWidgets('revocation and sign-out stay closed with data errors', (
    tester,
  ) async {
    final repository = await pumpDataSituation(tester, access: coordinator);
    repository.emitAccess(
      const ResponsibleAccess(
        uid: 'coordinator',
        role: 'coordinator',
        locationIds: {'*'},
        active: false,
      ),
    );
    repository.emitMissionsError(StateError('missions unavailable'));
    await pumpAccessUpdate(tester);
    expectNoStaleSituation();

    repository.emitAccess(null);
    repository.emitLocationsError(StateError('locations unavailable'));
    await pumpAccessUpdate(tester);
    expectNoStaleSituation();
  });

  testWidgets(
    'site manager scope loss combined with a location error is safe',
    (tester) async {
      final repository = await pumpDataSituation(tester, access: manager);
      expect(cancellationAction(), findsOneWidget);

      repository.emitAccess(
        const ResponsibleAccess(
          uid: 'manager',
          role: 'site_manager',
          locationIds: {'other-site'},
          active: true,
        ),
      );
      repository.emitLocationsError(StateError('locations unavailable'));
      await pumpAccessUpdate(tester);

      expect(
        find.text('Les besoins sont temporairement indisponibles.'),
        findsOneWidget,
      );
      expectNoStaleSituation();

      repository.emitLocations([
        _situationLocation('Centre non autorisé actualisé'),
      ]);
      await pumpAccessUpdate(tester);

      expect(
        find.text('Les besoins sont temporairement indisponibles.'),
        findsNothing,
      );
      expect(find.text('Ancienne mission'), findsNothing);
      expect(cancellationAction(), findsNothing);
    },
  );
}

CoordinationNeed _situationMission(
  String id,
  String place, {
  String? createdBy = 'coordinator',
}) => CoordinationNeed(
  id: id,
  locationId: 'site-a',
  place: place,
  group: TerritorialGroup.medoc,
  date: 'Aujourd’hui',
  time: '08:00 — 12:00',
  requiredPhysiotherapists: 2,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  equipment: const [],
  createdBy: createdBy,
);

ResponsePlace _situationLocation(
  String name, {
  ResponsePlaceType type = ResponsePlaceType.sdisStation,
}) => ResponsePlace(
  id: 'site-a',
  name: name,
  type: type,
  group: TerritorialGroup.medoc,
  activeNeeds: 1,
);

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

class _ControlledSituationDataRepository extends MockCoordinationRepository {
  final _missions = StreamController<List<CoordinationNeed>>.broadcast(
    sync: true,
  );
  final _locations = StreamController<List<ResponsePlace>>.broadcast(
    sync: true,
  );
  final _access = StreamController<ResponsibleAccess?>.broadcast(sync: true);

  @override
  Stream<List<CoordinationNeed>> watchMissions() => _missions.stream;

  @override
  Stream<List<ResponsePlace>> watchLocations() => _locations.stream;

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() => _access.stream;

  void emitMissions(List<CoordinationNeed> value) => _missions.add(value);

  void emitMissionsError(Object error) =>
      _missions.addError(error, StackTrace.current);

  void emitLocations(List<ResponsePlace> value) => _locations.add(value);

  void emitLocationsError(Object error) =>
      _locations.addError(error, StackTrace.current);

  void emitAccess(ResponsibleAccess? value) => _access.add(value);

  Future<void> disposeControllers() async {
    await _missions.close();
    await _locations.close();
    await _access.close();
  }
}
