import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  test('mock engagements update mission counters and status streams', () async {
    final repository = MockCoordinationRepository(
      initialMissions: [needs.first],
      initialLocations: const [],
    );
    final emissions = <List<CoordinationNeed>>[];
    final initialEmission = Completer<void>();
    final updatedEmission = Completer<void>();
    final subscription = repository.watchMissions().listen((missions) {
      emissions.add(missions);
      if (emissions.length == 1) initialEmission.complete();
      if (emissions.length == 2) updatedEmission.complete();
    });
    await initialEmission.future;

    await repository.createEngagement(
      missionId: needs.first.id,
      firstName: 'Jeanne',
      lastName: 'Martin',
      phone: '0600000000',
      email: ' jeanne@example.fr ',
      profession: VolunteerProfession.mk,
    );
    await updatedEmission.future;

    expect(emissions, hasLength(2));
    expect(emissions.last.single.registeredPhysiotherapists, 2);
    expect(emissions.last.single.coverage, greaterThan(needs.first.coverage));
    expect(repository.volunteers.single.firstName, 'Jeanne');
    expect(repository.volunteers.single.email, 'jeanne@example.fr');
    await subscription.cancel();
  });

  test('mock engagements can move a mission to complete', () async {
    final mission = CoordinationNeed(
      id: 'almost-complete',
      place: 'Mission test',
      group: TerritorialGroup.southGironde,
      date: 'Aujourd’hui',
      time: '08:00 — 12:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 1,
      requiredPodiatrists: 1,
      registeredPodiatrists: 0,
      equipment: const [],
    );
    final repository = MockCoordinationRepository(
      initialMissions: [mission],
      initialLocations: const [],
    );

    await repository.createEngagement(
      missionId: mission.id,
      firstName: 'Sam',
      lastName: 'Dupont',
      phone: '0611111111',
      profession: VolunteerProfession.pp,
    );
    final updated = await repository.watchMissions().first;

    expect(updated.single.status, NeedStatus.complete);
    expect(repository.volunteers.single.email, isNull);
  });

  test('a created mock mission is emitted immediately by the stream', () async {
    final repository = MockCoordinationRepository(
      initialMissions: const [],
      initialLocations: [places.first],
    );
    final emissions = <List<CoordinationNeed>>[];
    final subscription = repository.watchMissions().listen(emissions.add);
    await Future<void>.delayed(Duration.zero);

    await repository.createMission(
      MissionDraft(
        location: places.first,
        startAt: DateTime(2026, 7, 30, 22),
        endAt: DateTime(2026, 7, 31, 2),
        requiredPhysiotherapists: 2,
        requiredPodiatrists: 1,
        equipment: const ['Tables'],
        details: '',
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(emissions.last, hasLength(1));
    expect(emissions.last.single.place, places.first.name);
    expect(emissions.last.single.time, '22:00 — 02:00');
    await subscription.cancel();
  });
}
