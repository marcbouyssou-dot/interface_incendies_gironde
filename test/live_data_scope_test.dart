import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  test(
    'volunteer engagement streams are cached and indexed by mission',
    () async {
      final repository = _ControlledEngagementRepository();
      final data = LiveCoordinationData(repository);
      final missionA = <EngagementInfo?>[];
      final missionB = <EngagementInfo?>[];
      final firstA = data.watchMyEngagement('mission-a').listen(missionA.add);
      final firstB = data.watchMyEngagement('mission-b').listen(missionB.add);

      repository.emit('mission-a', null);
      repository.emit(
        'mission-b',
        const EngagementInfo(
          missionId: 'mission-b',
          volunteerId: 'mock-volunteer',
          profession: VolunteerProfession.mk,
          status: EngagementStatus.confirmed,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.factories, {'mission-a': 1, 'mission-b': 1});
      expect(missionA, [null]);
      expect(missionB.single?.status, EngagementStatus.confirmed);

      repository.emit(
        'mission-a',
        const EngagementInfo(
          missionId: 'mission-a',
          volunteerId: 'mock-volunteer',
          profession: VolunteerProfession.pp,
          status: EngagementStatus.cancelled,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final replayedA = await data.watchMyEngagement('mission-a').first;
      expect(replayedA?.status, EngagementStatus.cancelled);
      expect(repository.factories['mission-a'], 1);

      repository.emit(
        'mission-a',
        const EngagementInfo(
          missionId: 'mission-a',
          volunteerId: 'mock-volunteer',
          profession: VolunteerProfession.pp,
          status: EngagementStatus.confirmed,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(missionA.last?.status, EngagementStatus.confirmed);

      await firstA.cancel();
      await firstB.cancel();
      await data.dispose();
      await repository.disposeControllers();
    },
  );

  test(
    'responsible access errors are replayed and cleared after recovery',
    () async {
      final repository = _ControlledAccessRepository();
      final data = LiveCoordinationData(repository);
      final firstErrors = <Object>[];
      final firstValues = <ResponsibleAccess?>[];
      final firstSubscription = data.watchResponsibleAccess().listen(
        firstValues.add,
        onError: firstErrors.add,
      );
      const invalidAccess = ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidLocationIds,
        'invalid V2 scope',
      );

      const initial = ResponsibleAccess(
        uid: 'initial-coordinator',
        role: 'coordinator',
        locationIds: {'*'},
        active: true,
      );
      repository.emit(initial);
      await Future<void>.delayed(Duration.zero);

      repository.emitError(invalidAccess);
      await Future<void>.delayed(Duration.zero);

      final replayedErrors = <Object>[];
      final replayedValues = <ResponsibleAccess?>[];
      final secondSubscription = data.watchResponsibleAccess().listen(
        replayedValues.add,
        onError: replayedErrors.add,
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.factories, 1);
      expect(firstValues, [initial]);
      expect(firstErrors, [invalidAccess]);
      expect(replayedErrors, [invalidAccess]);
      expect(replayedValues, isEmpty);

      const recovered = ResponsibleAccess(
        uid: 'coordinator',
        role: 'coordinator',
        locationIds: {'*'},
        active: true,
      );
      repository.emit(recovered);
      await Future<void>.delayed(Duration.zero);

      expect(firstValues, [initial, recovered]);
      expect(replayedValues, [recovered]);

      await firstSubscription.cancel();
      await secondSubscription.cancel();
      await data.dispose();
      await repository.disposeController();
    },
  );

  test('mission errors are replayed and cleared after recovery', () async {
    final repository = _ControlledDataRepository();
    final data = LiveCoordinationData(repository);
    final firstValues = <List<CoordinationNeed>>[];
    final firstErrors = <Object>[];
    final firstSubscription = data.watchMissions().listen(
      firstValues.add,
      onError: firstErrors.add,
    );

    repository.emitMissions([_mission('old-mission', 'Ancienne mission')]);
    await Future<void>.delayed(Duration.zero);
    final error = StateError('missions unavailable');
    repository.emitMissionsError(error);
    await Future<void>.delayed(Duration.zero);

    final replayedValues = <List<CoordinationNeed>>[];
    final replayedErrors = <Object>[];
    final secondSubscription = data.watchMissions().listen(
      replayedValues.add,
      onError: replayedErrors.add,
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.missionFactories, 1);
    expect(firstValues.single.single.id, 'old-mission');
    expect(firstErrors, [error]);
    expect(replayedValues, isEmpty);
    expect(replayedErrors, [error]);

    repository.emitMissions([_mission('new-mission', 'Nouvelle mission')]);
    await Future<void>.delayed(Duration.zero);

    expect(firstValues.last.single.id, 'new-mission');
    expect(replayedValues.single.single.id, 'new-mission');

    await firstSubscription.cancel();
    await secondSubscription.cancel();
    await data.dispose();
    await repository.disposeControllers();
  });

  test('location errors stay independent and recover with new data', () async {
    final repository = _ControlledDataRepository();
    final data = LiveCoordinationData(repository);
    final missionValues = <List<CoordinationNeed>>[];
    final locationValues = <List<ResponsePlace>>[];
    final locationErrors = <Object>[];
    final missionSubscription = data.watchMissions().listen(missionValues.add);
    final locationSubscription = data.watchLocations().listen(
      locationValues.add,
      onError: locationErrors.add,
    );

    repository.emitMissions([_mission('mission-a', 'Mission A')]);
    repository.emitLocations([_location('site-a', 'Ancien centre')]);
    await Future<void>.delayed(Duration.zero);
    final error = StateError('locations unavailable');
    repository.emitLocationsError(error);
    await Future<void>.delayed(Duration.zero);

    final replayedValues = <List<ResponsePlace>>[];
    final replayedErrors = <Object>[];
    final replayedSubscription = data.watchLocations().listen(
      replayedValues.add,
      onError: replayedErrors.add,
    );
    await Future<void>.delayed(Duration.zero);

    expect(repository.locationFactories, 1);
    expect(locationValues.single.single.name, 'Ancien centre');
    expect(locationErrors, [error]);
    expect(replayedValues, isEmpty);
    expect(replayedErrors, [error]);
    expect(missionValues.single.single.id, 'mission-a');

    repository.emitLocations([_location('site-a', 'Nouveau centre')]);
    await Future<void>.delayed(Duration.zero);

    expect(locationValues.last.single.name, 'Nouveau centre');
    expect(replayedValues.single.single.name, 'Nouveau centre');
    expect(missionValues, hasLength(1));

    await missionSubscription.cancel();
    await locationSubscription.cancel();
    await replayedSubscription.cancel();
    await data.dispose();
    await repository.disposeControllers();
  });
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

ResponsePlace _location(String id, String name) => ResponsePlace(
  id: id,
  name: name,
  type: ResponsePlaceType.sdisStation,
  group: TerritorialGroup.medoc,
  activeNeeds: 1,
);

class _ControlledEngagementRepository extends MockCoordinationRepository {
  final Map<String, StreamController<EngagementInfo?>> _controllers = {};
  final Map<String, int> factories = {};

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) {
    factories.update(missionId, (count) => count + 1, ifAbsent: () => 1);
    return _controllers
        .putIfAbsent(
          missionId,
          () => StreamController<EngagementInfo?>.broadcast(sync: true),
        )
        .stream;
  }

  void emit(String missionId, EngagementInfo? engagement) {
    _controllers[missionId]!.add(engagement);
  }

  Future<void> disposeControllers() async {
    for (final controller in _controllers.values) {
      await controller.close();
    }
  }
}

class _ControlledAccessRepository extends MockCoordinationRepository {
  final _controller = StreamController<ResponsibleAccess?>.broadcast(
    sync: true,
  );
  int factories = 0;

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() {
    factories++;
    return _controller.stream;
  }

  void emit(ResponsibleAccess access) => _controller.add(access);

  void emitError(Object error) => _controller.addError(error);

  Future<void> disposeController() => _controller.close();
}

class _ControlledDataRepository extends MockCoordinationRepository {
  final _missions = StreamController<List<CoordinationNeed>>.broadcast(
    sync: true,
  );
  final _locations = StreamController<List<ResponsePlace>>.broadcast(
    sync: true,
  );
  int missionFactories = 0;
  int locationFactories = 0;

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    missionFactories++;
    return _missions.stream;
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    locationFactories++;
    return _locations.stream;
  }

  void emitMissions(List<CoordinationNeed> value) => _missions.add(value);

  void emitMissionsError(Object error) =>
      _missions.addError(error, StackTrace.current);

  void emitLocations(List<ResponsePlace> value) => _locations.add(value);

  void emitLocationsError(Object error) =>
      _locations.addError(error, StackTrace.current);

  Future<void> disposeControllers() async {
    await _missions.close();
    await _locations.close();
  }
}
