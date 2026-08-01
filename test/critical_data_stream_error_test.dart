import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/administration_dashboard_screen.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/screens/location_detail_screen.dart';
import 'package:interface_incendies_gironde/screens/places_screen.dart';
import 'package:interface_incendies_gironde/screens/slots_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  const coordinator = ResponsibleAccess(
    uid: 'coordinator',
    role: 'coordinator',
    locationIds: {'*'},
    active: true,
  );

  Future<_ControlledCriticalDataRepository> pumpScreen(
    WidgetTester tester,
    Widget screen,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _ControlledCriticalDataRepository();
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);
    addTearDown(repository.disposeControllers);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: LiveCoordinationDataScope(
          data: liveData,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: SafeArea(child: screen)),
          ),
        ),
      ),
    );
    await tester.pump();
    return repository;
  }

  Future<void> pumpEvents(WidgetTester tester) async {
    for (var index = 0; index < 4; index++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('Missions clears stale data and recovers automatically', (
    tester,
  ) async {
    final repository = await pumpScreen(tester, const SlotsScreen());
    repository.emitMissions([_mission('old', 'Ancienne mission')]);
    await tester.pump();
    repository.emitLocations([_location('Ancien centre')]);
    await pumpEvents(tester);

    expect(find.text('ANCIENNE MISSION'), findsOneWidget);

    repository.emitMissionsError(StateError('missions unavailable'));
    await pumpEvents(tester);

    expect(find.text('Missions temporairement indisponibles'), findsOneWidget);
    expect(find.text('ANCIENNE MISSION'), findsNothing);

    repository.emitMissions([_mission('new', 'Nouvelle mission')]);
    await pumpEvents(tester);

    expect(find.text('Missions temporairement indisponibles'), findsNothing);
    expect(find.text('NOUVELLE MISSION'), findsOneWidget);
    expect(find.text('ANCIENNE MISSION'), findsNothing);
  });

  testWidgets('Lieux clears stale data and recovers automatically', (
    tester,
  ) async {
    final repository = await pumpScreen(tester, const PlacesScreen());
    repository.emitLocations([_location('Ancien centre')]);
    await pumpEvents(tester);

    expect(find.text('Ancien centre'), findsOneWidget);

    repository.emitLocationsError(StateError('locations unavailable'));
    await pumpEvents(tester);

    expect(find.text('Informations des centres indisponibles'), findsOneWidget);
    expect(find.text('Ancien centre'), findsNothing);

    repository.emitLocations([_location('Nouveau centre')]);
    await pumpEvents(tester);

    expect(find.text('Informations des centres indisponibles'), findsNothing);
    expect(find.text('Nouveau centre'), findsOneWidget);
    expect(find.text('Ancien centre'), findsNothing);
  });

  testWidgets(
    'location detail never turns a mission error into an empty list',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repository = _ControlledCriticalDataRepository();
      addTearDown(repository.disposeControllers);
      final missions = StreamController<List<CoordinationNeed>>.broadcast(
        sync: true,
      );
      addTearDown(missions.close);

      await _pumpScreenWithRepository(
        tester,
        LocationDetailScreen(
          location: _location('Centre test'),
          missions: missions.stream,
        ),
        repository,
      );
      missions.add([_mission('old', 'Ancienne mission')]);
      await pumpEvents(tester);
      expect(find.byKey(const ValueKey('old')), findsOneWidget);

      missions.addError(StateError('missions unavailable'));
      await pumpEvents(tester);
      expect(
        find.text('Missions temporairement indisponibles'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('old')), findsNothing);

      missions.add([_mission('new', 'Nouvelle mission')]);
      await pumpEvents(tester);
      expect(find.byKey(const ValueKey('new')), findsOneWidget);
      expect(find.byKey(const ValueKey('old')), findsNothing);
    },
  );

  testWidgets(
    'location detail clears its location after a location stream error',
    (tester) async {
      final repository = await pumpScreen(tester, const PlacesScreen());
      repository.emitLocations([_location('Ancien centre')]);
      await pumpEvents(tester);

      await tester.tap(find.byKey(const Key('place-card-site-a')));
      await tester.pump(const Duration(milliseconds: 400));
      repository.emitMissions(const []);
      await pumpEvents(tester);

      expect(find.text('Ancien centre'), findsWidgets);

      repository.emitLocationsError(StateError('locations unavailable'));
      await pumpEvents(tester);

      expect(
        find.byKey(const Key('location-detail-location-unavailable-state')),
        findsOneWidget,
      );
      expect(find.text('Ancien centre'), findsNothing);

      repository.emitLocations([_location('Nouveau centre')]);
      await pumpEvents(tester);

      expect(
        find.byKey(const Key('location-detail-location-unavailable-state')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('location-detail-location-missing-state')),
        findsNothing,
      );
      expect(find.byKey(const Key('location-detail-screen')), findsOneWidget);
      expect(find.text('Nouveau centre'), findsWidgets);
      expect(find.text('Ancien centre'), findsNothing);

      repository.emitMissionsError(StateError('missions unavailable'));
      await pumpEvents(tester);
      expect(
        find.byKey(const Key('location-missions-unavailable-state')),
        findsOneWidget,
      );
      expect(find.text('Nouveau centre'), findsNothing);

      repository.emitLocationsError(StateError('locations unavailable'));
      await pumpEvents(tester);
      expect(
        find.byKey(const Key('location-detail-location-unavailable-state')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('location-missions-unavailable-state')),
        findsNothing,
      );

      repository.emitLocations([_location('Centre récupéré')]);
      await pumpEvents(tester);
      expect(
        find.byKey(const Key('location-missions-unavailable-state')),
        findsOneWidget,
      );
      expect(find.text('Centre récupéré'), findsNothing);

      repository.emitMissions(const []);
      await pumpEvents(tester);
      expect(find.text('Centre récupéré'), findsWidgets);
    },
  );

  testWidgets('create form removes location actions on a location error', (
    tester,
  ) async {
    final repository = await pumpScreen(tester, const CreateNeedScreen());
    repository.emitAccess(coordinator);
    await tester.pump();
    repository.emitLocations([_location('Ancien centre')]);
    await pumpEvents(tester);
    expect(find.byKey(const Key('mission-location')), findsOneWidget);

    repository.emitLocationsError(StateError('locations unavailable'));
    await pumpEvents(tester);
    expect(find.text('Informations des centres indisponibles'), findsOneWidget);
    expect(find.byKey(const Key('mission-location')), findsNothing);
    expect(find.byKey(const Key('publish-mission')), findsNothing);

    repository.emitLocations([_location('Nouveau centre')]);
    await pumpEvents(tester);
    expect(find.byKey(const Key('mission-location')), findsOneWidget);
  });

  testWidgets('administration removes centre actions on a location error', (
    tester,
  ) async {
    final repository = await pumpScreen(
      tester,
      AdministrationDashboardScreen(
        onViewMission: () {},
        onOpenStatistics: () {},
        onRetryAccess: () {},
      ),
    );
    repository.emitAccess(coordinator);
    await tester.pump();
    repository.emitLocations([_location('Ancien centre')]);
    await pumpEvents(tester);
    expect(find.byKey(const Key('administration-create-need')), findsOneWidget);

    repository.emitLocationsError(StateError('locations unavailable'));
    await pumpEvents(tester);
    expect(find.text('Informations des centres indisponibles'), findsOneWidget);
    expect(find.byKey(const Key('administration-create-need')), findsNothing);
    expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);

    repository.emitLocations([_location('Nouveau centre')]);
    await pumpEvents(tester);
    expect(find.byKey(const Key('administration-create-need')), findsOneWidget);
  });
}

Future<void> _pumpScreenWithRepository(
  WidgetTester tester,
  Widget screen,
  _ControlledCriticalDataRepository repository,
) async {
  final liveData = LiveCoordinationData(repository);
  addTearDown(liveData.dispose);
  await tester.pumpWidget(
    RepositoryScope(
      repository: repository,
      child: LiveCoordinationDataScope(
        data: liveData,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: SafeArea(child: screen)),
        ),
      ),
    ),
  );
  await tester.pump();
}

CoordinationNeed _mission(String id, String place) => CoordinationNeed(
  id: id,
  locationId: 'site-a',
  place: place,
  group: TerritorialGroup.medoc,
  date: 'Aujourd’hui',
  time: '08:00 — 12:00',
  requiredPhysiotherapists: 1,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  equipment: const [],
);

ResponsePlace _location(String name) => ResponsePlace(
  id: 'site-a',
  name: name,
  type: ResponsePlaceType.sdisStation,
  group: TerritorialGroup.medoc,
  activeNeeds: 1,
);

class _ControlledCriticalDataRepository extends MockCoordinationRepository {
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

  void emitMissionsError(Object error) => _missions.addError(error);

  void emitLocations(List<ResponsePlace> value) => _locations.add(value);

  void emitLocationsError(Object error) => _locations.addError(error);

  void emitAccess(ResponsibleAccess? value) => _access.add(value);

  Future<void> disposeControllers() async {
    await _missions.close();
    await _locations.close();
    await _access.close();
  }
}
