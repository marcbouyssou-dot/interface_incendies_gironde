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

  test(
    'mock site manager can publish only for the assigned location',
    () async {
      final assigned = places.first;
      final forbidden = places[1];
      final repository = MockCoordinationRepository(
        initialMissions: const [],
        initialLocations: [assigned, forbidden],
        responsibleAccess: ResponsibleAccess(
          uid: 'manager',
          role: 'site_manager',
          locationIds: {assigned.id},
          active: true,
        ),
      );

      await repository.createMission(_draftFor(assigned));
      await expectLater(
        repository.createMission(_draftFor(forbidden)),
        throwsA(isA<RepositoryException>()),
      );

      final missions = await repository.watchMissions().first;
      expect(missions, hasLength(1));
      expect(missions.single.locationId, assigned.id);
    },
  );

  test('mock coordinator can publish for every location', () async {
    final repository = MockCoordinationRepository(
      initialMissions: const [],
      initialLocations: places.take(2).toList(),
    );

    await repository.createMission(_draftFor(places.first));
    await repository.createMission(_draftFor(places[1]));

    expect(await repository.watchMissions().first, hasLength(2));
  });

  test(
    'mock MK and PP disengagement decrements only its own counter',
    () async {
      for (final profession in VolunteerProfession.values) {
        final mission = CoordinationNeed(
          id: 'cancel-${profession.name}',
          place: 'Mission',
          group: TerritorialGroup.medoc,
          date: 'Aujourd’hui',
          time: '08:00 — 12:00',
          requiredPhysiotherapists: 1,
          registeredPhysiotherapists: 0,
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
          firstName: 'A',
          lastName: 'B',
          phone: '0600000000',
          profession: profession,
        );
        await repository.cancelEngagement(mission.id);
        final updated = (await repository.watchMissions().first).single;
        expect(updated.registeredPhysiotherapists, 0);
        expect(updated.registeredPodiatrists, 0);
        expect(updated.status, NeedStatus.critical);
        expect(repository.engagements, isEmpty);
        await expectLater(
          repository.cancelEngagement(mission.id),
          throwsA(isA<RepositoryException>()),
        );
      }
    },
  );

  test('mock cancellation preserves counters and hides the mission', () async {
    final repository = MockCoordinationRepository(
      initialMissions: [needs.first],
      initialLocations: const [],
    );
    final before = needs.first.registeredPeople;
    await repository.cancelMission(needs.first.id, ' Vent violent ');

    expect(await repository.watchMissions().first, isEmpty);
    final stored = repository.debugMission(needs.first.id);
    expect(stored?.isCancelled, isTrue);
    expect(stored?.isActive, isFalse);
    expect(stored?.registeredPeople, before);
    expect(stored?.cancellationReason, 'Vent violent');
    await expectLater(
      repository.createEngagement(
        missionId: needs.first.id,
        firstName: 'A',
        lastName: 'B',
        phone: '0600000000',
        profession: VolunteerProfession.mk,
      ),
      throwsA(isA<RepositoryException>()),
    );
  });
}

MissionDraft _draftFor(ResponsePlace location) => MissionDraft(
  location: location,
  startAt: DateTime(2026, 8, 1, 8),
  endAt: DateTime(2026, 8, 1, 12),
  requiredPhysiotherapists: 2,
  requiredPodiatrists: 1,
  equipment: const ['Tables'],
  details: '',
);
