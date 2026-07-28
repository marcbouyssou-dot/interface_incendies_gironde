import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
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
      profession: VolunteerProfession.mk,
    );
    await updatedEmission.future;

    expect(emissions, hasLength(2));
    expect(emissions.last.single.registeredPhysiotherapists, 2);
    expect(emissions.last.single.coverage, greaterThan(needs.first.coverage));
    expect(repository.volunteers.single.firstName, 'Jeanne');
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
  });
}
