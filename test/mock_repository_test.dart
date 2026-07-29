import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  test('mock confirmed engagement increments its mission counter', () async {
    final repository = MockCoordinationRepository(
      initialMissions: [needs.first.copyWith(createdBy: 'mock-coordinator')],
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

    final result = await repository.createEngagement(
      missionId: needs.first.id,
      firstName: 'Jeanne',
      lastName: 'Martin',
      phone: '0600000000',
      email: ' jeanne@example.fr ',
      rpps: '10123456789',
      cptsId: 'cpts-medoc',
      cptsLabel: 'CPTS Médoc',
      profession: VolunteerProfession.mk,
    );
    await updatedEmission.future;

    expect(emissions, hasLength(2));
    expect(
      emissions.last.single.registeredPhysiotherapists,
      needs.first.registeredPhysiotherapists + 1,
    );
    expect(emissions.last.single.coverage, greaterThan(needs.first.coverage));
    expect(repository.volunteers.single.firstName, 'Jeanne');
    expect(repository.volunteers.single.email, 'jeanne@example.fr');
    expect(result, EngagementCreationResult.created);
    await subscription.cancel();
  });

  test('mock confirmed engagement completes a covered mission', () async {
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

    final result = await repository.createEngagement(
      missionId: mission.id,
      firstName: 'Sam',
      lastName: 'Dupont',
      phone: '0611111111',
      email: 'sam@example.fr',
      rpps: '10123456789',
      cptsId: 'cpts-medoc',
      cptsLabel: 'CPTS Médoc',
      profession: VolunteerProfession.pp,
    );
    final updated = await repository.watchMissions().first;

    expect(updated.single.status, NeedStatus.complete);
    expect(updated.single.registeredPodiatrists, 1);
    expect(repository.volunteers.single.email, 'sam@example.fr');
    expect(result, EngagementCreationResult.created);
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

  test('a new mock engagement starts confirmed', () async {
    final mission = needs.first;
    final repository = MockCoordinationRepository(
      initialMissions: [mission],
      initialLocations: const [],
      initialEngagements: const [],
    );

    final result = await repository.createEngagement(
      missionId: mission.id,
      firstName: 'A',
      lastName: 'B',
      phone: '0600000000',
      email: 'a@example.fr',
      rpps: '10123456789',
      cptsId: 'cpts-medoc',
      cptsLabel: 'CPTS Médoc',
      profession: VolunteerProfession.mk,
    );

    expect(
      repository.engagements[mission.id]?.status,
      EngagementStatus.confirmed,
    );
    expect(result, EngagementCreationResult.created);
  });

  test(
    'mock reengages a cancelled volunteer as confirmed with its counter',
    () async {
      final createdAt = DateTime(2026, 7, 20, 9);
      final mission = CoordinationNeed(
        id: 'reengagement',
        place: 'Mission test',
        group: TerritorialGroup.medoc,
        date: 'Aujourd’hui',
        time: '08:00 — 12:00',
        endAt: DateTime.now().add(const Duration(hours: 2)),
        requiredPhysiotherapists: 2,
        registeredPhysiotherapists: 1,
        requiredPodiatrists: 1,
        registeredPodiatrists: 0,
        equipment: const [],
      );
      final cancelled = EngagementInfo(
        missionId: mission.id,
        volunteerId: 'mock-volunteer',
        profession: VolunteerProfession.mk,
        status: EngagementStatus.cancelled,
        createdAt: createdAt,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission],
        initialLocations: const [],
        initialEngagements: [cancelled],
      );
      repository.engagements[mission.id] = cancelled;

      final result = await repository.createEngagement(
        missionId: mission.id,
        firstName: 'Jeanne',
        lastName: 'Martin',
        phone: '0600000000',
        email: 'jeanne@example.fr',
        rpps: '10123456789',
        cptsId: 'cpts-medoc',
        cptsLabel: 'CPTS Médoc',
        profession: VolunteerProfession.pp,
      );

      final engagement = repository.engagements[mission.id]!;
      final storedMission = repository.debugMission(mission.id)!;
      expect(engagement.status, EngagementStatus.confirmed);
      expect(engagement.profession, VolunteerProfession.pp);
      expect(engagement.createdAt, createdAt);
      expect(result, EngagementCreationResult.reactivated);
      expect(storedMission.registeredPhysiotherapists, 1);
      expect(storedMission.registeredPodiatrists, 1);
      expect(
        repository.missionEngagements
            .where(
              (candidate) =>
                  candidate.missionId == mission.id &&
                  candidate.volunteerId == 'mock-volunteer',
            )
            .single
            .status,
        EngagementStatus.confirmed,
      );
    },
  );

  test('mock returns idempotent active and legacy engagements', () async {
    for (final (status, expected) in const [
      (EngagementStatus.confirmed, EngagementCreationResult.alreadyConfirmed),
      (EngagementStatus.standby, EngagementCreationResult.alreadyStandby),
    ]) {
      final mission = CoordinationNeed(
        id: 'duplicate-${status.name}',
        place: 'Mission test',
        group: TerritorialGroup.medoc,
        date: 'Aujourd’hui',
        time: '08:00 — 12:00',
        endAt: DateTime.now().add(const Duration(hours: 2)),
        requiredPhysiotherapists: 1,
        registeredPhysiotherapists: 0,
        requiredPodiatrists: 0,
        registeredPodiatrists: 0,
        equipment: const [],
      );
      final existing = EngagementInfo(
        missionId: mission.id,
        volunteerId: 'mock-volunteer',
        profession: VolunteerProfession.mk,
        status: status,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission],
        initialLocations: const [],
        initialEngagements: [existing],
      );
      repository.engagements[mission.id] = existing;

      final result = await repository.createEngagement(
        missionId: mission.id,
        firstName: 'A',
        lastName: 'B',
        phone: '0600000000',
        email: 'a@example.fr',
        rpps: '10123456789',
        cptsId: 'cpts-medoc',
        cptsLabel: 'CPTS Médoc',
        profession: VolunteerProfession.mk,
      );
      expect(result, expected);
      expect(repository.engagements, hasLength(1));
      expect(repository.missionEngagements, hasLength(1));
      expect(repository.debugMission(mission.id)?.registeredPeople, 0);
    }

    const legacy = EngagementInfo(
      missionId: 'legacy',
      volunteerId: 'mock-volunteer',
      profession: VolunteerProfession.mk,
    );
    expect(legacy.status, EngagementStatus.confirmed);
  });

  test(
    'mock promotes a historical pending engagement without a duplicate',
    () async {
      final mission = CoordinationNeed(
        id: 'historical-pending',
        place: 'Mission test',
        group: TerritorialGroup.medoc,
        date: 'Aujourd’hui',
        time: '08:00 — 12:00',
        endAt: DateTime.now().add(const Duration(hours: 2)),
        requiredPhysiotherapists: 1,
        registeredPhysiotherapists: 0,
        requiredPodiatrists: 0,
        registeredPodiatrists: 0,
        equipment: const [],
      );
      const existing = EngagementInfo(
        missionId: 'historical-pending',
        volunteerId: 'mock-volunteer',
        profession: VolunteerProfession.mk,
        status: EngagementStatus.pending,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission],
        initialLocations: const [],
        initialEngagements: const [existing],
      );
      repository.engagements[mission.id] = existing;

      final result = await repository.createEngagement(
        missionId: mission.id,
        firstName: 'A',
        lastName: 'B',
        phone: '0600000000',
        email: 'a@example.fr',
        rpps: '10123456789',
        cptsId: 'cpts-medoc',
        cptsLabel: 'CPTS Médoc',
        profession: VolunteerProfession.mk,
      );

      expect(result, EngagementCreationResult.reactivated);
      expect(repository.engagements, hasLength(1));
      expect(repository.missionEngagements, hasLength(1));
      expect(
        repository.engagements[mission.id]?.status,
        EngagementStatus.confirmed,
      );
      expect(repository.debugMission(mission.id)?.registeredPeople, 1);
    },
  );

  test('mock refuses an engagement owned by another volunteer', () async {
    final mission = CoordinationNeed(
      id: 'wrong-owner',
      place: 'Mission test',
      group: TerritorialGroup.medoc,
      date: 'Aujourd’hui',
      time: '08:00 — 12:00',
      endAt: DateTime.now().add(const Duration(hours: 2)),
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const [],
    );
    const existing = EngagementInfo(
      missionId: 'wrong-owner',
      volunteerId: 'another-volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.pending,
    );
    final repository = MockCoordinationRepository(
      initialMissions: [mission],
      initialLocations: const [],
      initialEngagements: const [existing],
    );
    repository.engagements[mission.id] = existing;

    await expectLater(
      repository.createEngagement(
        missionId: mission.id,
        firstName: 'A',
        lastName: 'B',
        phone: '0600000000',
        email: 'a@example.fr',
        rpps: '10123456789',
        cptsId: 'cpts-medoc',
        cptsLabel: 'CPTS Médoc',
        profession: VolunteerProfession.mk,
      ),
      throwsA(isA<RepositoryException>()),
    );
  });

  test('a pending engagement does not increment mission counters', () {
    expect(EngagementStatus.pending.incrementsCountersOnCreation, isFalse);
  });

  test(
    'mock refuses a new engagement when its profession quota is reached',
    () async {
      for (final profession in VolunteerProfession.values.where(
        (value) => value.isSupportedByCurrentMission,
      )) {
        final mission = CoordinationNeed(
          id: 'pending-full-${profession.name}',
          place: 'Mission complète',
          group: TerritorialGroup.medoc,
          date: 'Aujourd’hui',
          time: '08:00 — 12:00',
          endAt: DateTime.now().add(const Duration(hours: 2)),
          requiredPhysiotherapists: 1,
          registeredPhysiotherapists: 1,
          requiredPodiatrists: 1,
          registeredPodiatrists: 1,
          equipment: const [],
        );
        final repository = MockCoordinationRepository(
          initialMissions: [mission],
          initialLocations: const [],
          initialEngagements: const [],
        );

        await expectLater(
          repository.createEngagement(
            missionId: mission.id,
            firstName: 'A',
            lastName: 'B',
            phone: '0600000000',
            email: 'a@example.fr',
            rpps: '10123456789',
            cptsId: 'cpts-medoc',
            cptsLabel: 'CPTS Médoc',
            profession: profession,
          ),
          throwsA(
            isA<RepositoryException>().having(
              (error) => error.message,
              'message',
              'Ce besoin est désormais couvert pour votre profession.',
            ),
          ),
        );
        final unchanged = repository.debugMission(mission.id)!;
        expect(unchanged.registeredPhysiotherapists, 1);
        expect(unchanged.registeredPodiatrists, 1);
        expect(repository.engagements, isEmpty);
        expect(repository.volunteers, isEmpty);
      }
    },
  );

  test('missing engagement status remains compatible as confirmed', () {
    const legacy = EngagementInfo(
      missionId: 'legacy',
      volunteerId: 'volunteer',
      profession: VolunteerProfession.mk,
    );

    expect(legacy.status, EngagementStatus.confirmed);
    expect(legacy.status.label, 'Confirmé');
  });

  test('mock coordinator moves a pending engagement to confirmed', () async {
    final mission = CoordinationNeed(
      id: 'mission-status',
      place: 'Mission',
      group: TerritorialGroup.medoc,
      date: 'Demain',
      time: '08:00 — 12:00',
      endAt: DateTime.now().add(const Duration(hours: 2)),
      requiredPhysiotherapists: 0,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 2,
      registeredPodiatrists: 1,
      equipment: const [],
    );
    const engagement = EngagementInfo(
      missionId: 'mission-status',
      volunteerId: 'volunteer-status',
      profession: VolunteerProfession.pp,
      status: EngagementStatus.pending,
    );
    final repository = MockCoordinationRepository(
      initialMissions: [mission],
      initialLocations: const [],
      initialEngagements: const [engagement],
    );

    await repository.updateEngagementStatus(
      missionId: engagement.missionId,
      volunteerId: engagement.volunteerId,
      status: EngagementStatus.confirmed,
    );
    expect(
      repository.missionEngagements.single.status,
      EngagementStatus.confirmed,
    );
  });

  test('mock confirmed MK and PP move to standby exactly once', () async {
    for (final profession in VolunteerProfession.values.where(
      (value) => value.isSupportedByCurrentMission,
    )) {
      final mission = CoordinationNeed(
        id: 'standby-${profession.name}',
        place: 'Mission',
        group: TerritorialGroup.medoc,
        date: 'Demain',
        time: '08:00 — 12:00',
        startAt: DateTime.now().add(const Duration(hours: 1)),
        endAt: DateTime.now().add(const Duration(hours: 2)),
        requiredPhysiotherapists: 2,
        registeredPhysiotherapists: profession == VolunteerProfession.mk
            ? 1
            : 0,
        requiredPodiatrists: 2,
        registeredPodiatrists: profession == VolunteerProfession.pp ? 1 : 0,
        equipment: const [],
      );
      final engagement = EngagementInfo(
        missionId: mission.id,
        volunteerId: 'volunteer',
        profession: profession,
        status: EngagementStatus.confirmed,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission],
        initialLocations: const [],
        initialEngagements: [engagement],
      );

      await repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: engagement.volunteerId,
        status: EngagementStatus.standby,
      );
      final updatedMission = repository.debugMission(mission.id)!;
      expect(updatedMission.registeredPhysiotherapists, 0);
      expect(updatedMission.registeredPodiatrists, 0);
      expect(
        repository.missionEngagements.single.status,
        EngagementStatus.standby,
      );

      await expectLater(
        repository.updateEngagementStatus(
          missionId: mission.id,
          volunteerId: engagement.volunteerId,
          status: EngagementStatus.standby,
        ),
        throwsA(isA<RepositoryException>()),
      );
      expect(repository.debugMission(mission.id)!.registeredPeople, 0);
    }
  });

  test('mock standby transition refuses a zero profession counter', () async {
    const mission = CoordinationNeed(
      id: 'standby-zero',
      place: 'Mission',
      group: TerritorialGroup.medoc,
      date: 'Demain',
      time: '08:00 — 12:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: [],
    );
    const engagement = EngagementInfo(
      missionId: 'standby-zero',
      volunteerId: 'volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.confirmed,
    );
    final repository = MockCoordinationRepository(
      initialMissions: const [mission],
      initialLocations: const [],
      initialEngagements: const [engagement],
    );

    await expectLater(
      repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: engagement.volunteerId,
        status: EngagementStatus.standby,
      ),
      throwsA(isA<RepositoryException>()),
    );
    expect(repository.debugMission(mission.id)!.registeredPeople, 0);
    expect(
      repository.missionEngagements.single.status,
      EngagementStatus.confirmed,
    );
  });

  test('mock confirmed MK and PP are cancelled exactly once', () async {
    for (final profession in VolunteerProfession.values.where(
      (value) => value.isSupportedByCurrentMission,
    )) {
      final mission = CoordinationNeed(
        id: 'cancel-status-${profession.name}',
        place: 'Mission',
        group: TerritorialGroup.medoc,
        date: 'Demain',
        time: '08:00 — 12:00',
        endAt: DateTime.now().add(const Duration(hours: 2)),
        requiredPhysiotherapists: 2,
        registeredPhysiotherapists: profession == VolunteerProfession.mk
            ? 1
            : 0,
        requiredPodiatrists: 2,
        registeredPodiatrists: profession == VolunteerProfession.pp ? 1 : 0,
        equipment: const [],
      );
      final engagement = EngagementInfo(
        missionId: mission.id,
        volunteerId: 'volunteer',
        profession: profession,
        status: EngagementStatus.confirmed,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission],
        initialLocations: const [],
        initialEngagements: [engagement],
      );

      await repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: engagement.volunteerId,
        status: EngagementStatus.cancelled,
      );
      expect(repository.debugMission(mission.id)!.registeredPeople, 0);
      expect(
        repository.missionEngagements.single.status,
        EngagementStatus.cancelled,
      );

      await expectLater(
        repository.updateEngagementStatus(
          missionId: mission.id,
          volunteerId: engagement.volunteerId,
          status: EngagementStatus.cancelled,
        ),
        throwsA(isA<RepositoryException>()),
      );
      expect(repository.debugMission(mission.id)!.registeredPeople, 0);
    }
  });

  test('mock cancellation refuses a zero profession counter', () async {
    const mission = CoordinationNeed(
      id: 'cancel-status-zero',
      place: 'Mission',
      group: TerritorialGroup.medoc,
      date: 'Demain',
      time: '08:00 — 12:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: [],
    );
    const engagement = EngagementInfo(
      missionId: 'cancel-status-zero',
      volunteerId: 'volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.confirmed,
    );
    final repository = MockCoordinationRepository(
      initialMissions: const [mission],
      initialLocations: const [],
      initialEngagements: const [engagement],
    );

    await expectLater(
      repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: engagement.volunteerId,
        status: EngagementStatus.cancelled,
      ),
      throwsA(isA<RepositoryException>()),
    );
    expect(repository.debugMission(mission.id)!.registeredPeople, 0);
    expect(
      repository.missionEngagements.single.status,
      EngagementStatus.confirmed,
    );
  });

  test('mock standby MK and PP return to confirmed exactly once', () async {
    for (final profession in VolunteerProfession.values.where(
      (value) => value.isSupportedByCurrentMission,
    )) {
      final mission = CoordinationNeed(
        id: 'confirm-standby-${profession.name}',
        place: 'Mission',
        group: TerritorialGroup.medoc,
        date: 'Demain',
        time: '08:00 — 12:00',
        endAt: DateTime.now().add(const Duration(hours: 2)),
        requiredPhysiotherapists: 2,
        registeredPhysiotherapists: 0,
        requiredPodiatrists: 2,
        registeredPodiatrists: 0,
        equipment: const [],
      );
      final engagement = EngagementInfo(
        missionId: mission.id,
        volunteerId: 'volunteer',
        profession: profession,
        status: EngagementStatus.standby,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission],
        initialLocations: const [],
        initialEngagements: [engagement],
      );

      await repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: engagement.volunteerId,
        status: EngagementStatus.confirmed,
      );
      final updatedMission = repository.debugMission(mission.id)!;
      expect(
        updatedMission.registeredPhysiotherapists,
        profession == VolunteerProfession.mk ? 1 : 0,
      );
      expect(
        updatedMission.registeredPodiatrists,
        profession == VolunteerProfession.pp ? 1 : 0,
      );

      await expectLater(
        repository.updateEngagementStatus(
          missionId: mission.id,
          volunteerId: engagement.volunteerId,
          status: EngagementStatus.confirmed,
        ),
        throwsA(isA<RepositoryException>()),
      );
      expect(repository.debugMission(mission.id)!.registeredPeople, 1);
    }
  });

  test('mock standby confirmation refuses a reached quota', () async {
    const mission = CoordinationNeed(
      id: 'confirm-standby-full',
      place: 'Mission',
      group: TerritorialGroup.medoc,
      date: 'Demain',
      time: '08:00 — 12:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 1,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: [],
    );
    const engagement = EngagementInfo(
      missionId: 'confirm-standby-full',
      volunteerId: 'volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.standby,
    );
    final repository = MockCoordinationRepository(
      initialMissions: const [mission],
      initialLocations: const [],
      initialEngagements: const [engagement],
    );

    await expectLater(
      repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: engagement.volunteerId,
        status: EngagementStatus.confirmed,
      ),
      throwsA(isA<RepositoryException>()),
    );
    expect(repository.debugMission(mission.id)!.registeredPeople, 1);
    expect(
      repository.missionEngagements.single.status,
      EngagementStatus.standby,
    );
  });

  test('mock pending MK and PP move to standby without counters', () async {
    for (final profession in VolunteerProfession.values.where(
      (value) => value.isSupportedByCurrentMission,
    )) {
      final mission = CoordinationNeed(
        id: 'pending-standby-${profession.name}',
        place: 'Mission',
        group: TerritorialGroup.medoc,
        date: 'Demain',
        time: '08:00 — 12:00',
        endAt: DateTime.now().add(const Duration(hours: 2)),
        requiredPhysiotherapists: 3,
        registeredPhysiotherapists: 1,
        requiredPodiatrists: 3,
        registeredPodiatrists: 1,
        equipment: const [],
      );
      final engagement = EngagementInfo(
        missionId: mission.id,
        volunteerId: 'volunteer',
        profession: profession,
        status: EngagementStatus.pending,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission],
        initialLocations: const [],
        initialEngagements: [engagement],
      );

      await repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: engagement.volunteerId,
        status: EngagementStatus.standby,
      );
      final updatedMission = repository.debugMission(mission.id)!;
      expect(updatedMission.registeredPhysiotherapists, 1);
      expect(updatedMission.registeredPodiatrists, 1);
      expect(
        repository.missionEngagements.single.status,
        EngagementStatus.standby,
      );

      await expectLater(
        repository.updateEngagementStatus(
          missionId: mission.id,
          volunteerId: engagement.volunteerId,
          status: EngagementStatus.standby,
        ),
        throwsA(isA<RepositoryException>()),
      );
      expect(repository.debugMission(mission.id)!.registeredPeople, 2);
    }
  });

  test('mock pending MK and PP are cancelled without counters', () async {
    for (final profession in VolunteerProfession.values.where(
      (value) => value.isSupportedByCurrentMission,
    )) {
      final mission = CoordinationNeed(
        id: 'pending-cancelled-${profession.name}',
        place: 'Mission',
        group: TerritorialGroup.medoc,
        date: 'Demain',
        time: '08:00 — 12:00',
        endAt: DateTime.now().add(const Duration(hours: 2)),
        requiredPhysiotherapists: 3,
        registeredPhysiotherapists: 1,
        requiredPodiatrists: 3,
        registeredPodiatrists: 1,
        equipment: const [],
      );
      final engagement = EngagementInfo(
        missionId: mission.id,
        volunteerId: 'volunteer',
        profession: profession,
        status: EngagementStatus.pending,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission],
        initialLocations: const [],
        initialEngagements: [engagement],
      );

      await repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: engagement.volunteerId,
        status: EngagementStatus.cancelled,
      );
      final updatedMission = repository.debugMission(mission.id)!;
      expect(updatedMission.registeredPhysiotherapists, 1);
      expect(updatedMission.registeredPodiatrists, 1);
      expect(
        repository.missionEngagements.single.status,
        EngagementStatus.cancelled,
      );

      await expectLater(
        repository.updateEngagementStatus(
          missionId: mission.id,
          volunteerId: engagement.volunteerId,
          status: EngagementStatus.cancelled,
        ),
        throwsA(isA<RepositoryException>()),
      );
      expect(repository.debugMission(mission.id)!.registeredPeople, 2);
    }
  });

  test('mock standby MK and PP are cancelled without counters', () async {
    for (final profession in VolunteerProfession.values.where(
      (value) => value.isSupportedByCurrentMission,
    )) {
      final mission = CoordinationNeed(
        id: 'standby-cancelled-${profession.name}',
        place: 'Mission',
        group: TerritorialGroup.medoc,
        date: 'Demain',
        time: '08:00 — 12:00',
        endAt: DateTime.now().add(const Duration(hours: 2)),
        requiredPhysiotherapists: 3,
        registeredPhysiotherapists: 1,
        requiredPodiatrists: 3,
        registeredPodiatrists: 1,
        equipment: const [],
      );
      final engagement = EngagementInfo(
        missionId: mission.id,
        volunteerId: 'volunteer',
        profession: profession,
        status: EngagementStatus.standby,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission],
        initialLocations: const [],
        initialEngagements: [engagement],
      );

      await repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: engagement.volunteerId,
        status: EngagementStatus.cancelled,
      );
      final updatedMission = repository.debugMission(mission.id)!;
      expect(updatedMission.registeredPhysiotherapists, 1);
      expect(updatedMission.registeredPodiatrists, 1);
      expect(
        repository.missionEngagements.single.status,
        EngagementStatus.cancelled,
      );

      await expectLater(
        repository.updateEngagementStatus(
          missionId: mission.id,
          volunteerId: engagement.volunteerId,
          status: EngagementStatus.cancelled,
        ),
        throwsA(isA<RepositoryException>()),
      );
      expect(repository.debugMission(mission.id)!.registeredPeople, 2);
    }
  });

  test('legacy status-less MK moves to standby with one decrement', () async {
    final mission = CoordinationNeed(
      id: 'legacy-mk',
      place: 'Mission',
      group: TerritorialGroup.medoc,
      date: 'Demain',
      time: '08:00 — 12:00',
      endAt: DateTime.now().add(const Duration(hours: 2)),
      requiredPhysiotherapists: 2,
      registeredPhysiotherapists: 1,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const [],
    );
    const legacyEngagement = EngagementInfo(
      missionId: 'legacy-mk',
      volunteerId: 'legacy-volunteer',
      profession: VolunteerProfession.mk,
    );
    final repository = MockCoordinationRepository(
      initialMissions: [mission],
      initialLocations: const [],
      initialEngagements: const [legacyEngagement],
    );

    await repository.updateEngagementStatus(
      missionId: mission.id,
      volunteerId: legacyEngagement.volunteerId,
      status: EngagementStatus.standby,
    );
    expect(repository.debugMission(mission.id)!.registeredPeople, 0);

    await expectLater(
      repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: legacyEngagement.volunteerId,
        status: EngagementStatus.standby,
      ),
      throwsA(isA<RepositoryException>()),
    );
    expect(repository.debugMission(mission.id)!.registeredPeople, 0);
  });

  test('legacy status-less PP is cancelled with one decrement', () async {
    final mission = CoordinationNeed(
      id: 'legacy-pp',
      place: 'Mission',
      group: TerritorialGroup.medoc,
      date: 'Demain',
      time: '08:00 — 12:00',
      endAt: DateTime.now().add(const Duration(hours: 2)),
      requiredPhysiotherapists: 0,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 2,
      registeredPodiatrists: 1,
      equipment: const [],
    );
    const legacyEngagement = EngagementInfo(
      missionId: 'legacy-pp',
      volunteerId: 'legacy-volunteer',
      profession: VolunteerProfession.pp,
    );
    final repository = MockCoordinationRepository(
      initialMissions: [mission],
      initialLocations: const [],
      initialEngagements: const [legacyEngagement],
    );

    await repository.updateEngagementStatus(
      missionId: mission.id,
      volunteerId: legacyEngagement.volunteerId,
      status: EngagementStatus.cancelled,
    );
    expect(repository.debugMission(mission.id)!.registeredPeople, 0);

    await expectLater(
      repository.updateEngagementStatus(
        missionId: mission.id,
        volunteerId: legacyEngagement.volunteerId,
        status: EngagementStatus.cancelled,
      ),
      throwsA(isA<RepositoryException>()),
    );
    expect(repository.debugMission(mission.id)!.registeredPeople, 0);
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

  group('mock volunteer disengagement', () {
    for (final initialStatus in const [
      EngagementStatus.pending,
      EngagementStatus.standby,
      EngagementStatus.confirmed,
    ]) {
      test('$initialStatus follows its counter rule for MK and PP', () async {
        for (final profession in VolunteerProfession.values.where(
          (value) => value.isSupportedByCurrentMission,
        )) {
          final counts = initialStatus == EngagementStatus.confirmed ? 1 : 0;
          final mission = CoordinationNeed(
            id: 'cancel-${initialStatus.name}-${profession.name}',
            place: 'Mission',
            group: TerritorialGroup.medoc,
            date: 'Aujourd’hui',
            time: '08:00 — 12:00',
            endAt: DateTime.now().add(const Duration(hours: 2)),
            requiredPhysiotherapists: 1,
            registeredPhysiotherapists: profession == VolunteerProfession.mk
                ? counts
                : 0,
            requiredPodiatrists: 1,
            registeredPodiatrists: profession == VolunteerProfession.pp
                ? counts
                : 0,
            equipment: const [],
          );
          final engagement = EngagementInfo(
            missionId: mission.id,
            volunteerId: 'mock-volunteer',
            profession: profession,
            status: initialStatus,
          );
          final repository = MockCoordinationRepository(
            initialMissions: [mission],
            initialLocations: const [],
            initialEngagements: [engagement],
          );
          repository.engagements[mission.id] = engagement;

          await repository.cancelEngagement(mission.id);

          final updated = repository.debugMission(mission.id)!;
          expect(updated.registeredPhysiotherapists, 0);
          expect(updated.registeredPodiatrists, 0);
          expect(
            repository.engagements[mission.id]?.status,
            EngagementStatus.cancelled,
          );
          expect(
            repository.missionEngagements.single.status,
            EngagementStatus.cancelled,
          );
          await expectLater(
            repository.cancelEngagement(mission.id),
            throwsA(isA<RepositoryException>()),
          );
          expect(repository.debugMission(mission.id)!.registeredPeople, 0);
        }
      });
    }

    test(
      'legacy status-less engagement is confirmed and decremented once',
      () async {
        for (final profession in VolunteerProfession.values.where(
          (value) => value.isSupportedByCurrentMission,
        )) {
          final mission = CoordinationNeed(
            id: 'legacy-cancel-${profession.name}',
            place: 'Mission',
            group: TerritorialGroup.medoc,
            date: 'Aujourd’hui',
            time: '08:00 — 12:00',
            endAt: DateTime.now().add(const Duration(hours: 2)),
            requiredPhysiotherapists: 1,
            registeredPhysiotherapists: profession == VolunteerProfession.mk
                ? 1
                : 0,
            requiredPodiatrists: 1,
            registeredPodiatrists: profession == VolunteerProfession.pp ? 1 : 0,
            equipment: const [],
          );
          final historicalEngagement = EngagementInfo(
            missionId: mission.id,
            volunteerId: 'mock-volunteer',
            profession: profession,
          );
          final repository = MockCoordinationRepository(
            initialMissions: [mission],
            initialLocations: const [],
            initialEngagements: [historicalEngagement],
          );
          repository.engagements[mission.id] = historicalEngagement;

          await repository.cancelEngagement(mission.id);
          expect(repository.debugMission(mission.id)!.registeredPeople, 0);
          expect(
            repository.engagements[mission.id]?.status,
            EngagementStatus.cancelled,
          );

          await expectLater(
            repository.cancelEngagement(mission.id),
            throwsA(isA<RepositoryException>()),
          );
          expect(repository.debugMission(mission.id)!.registeredPeople, 0);
        }
      },
    );
  });

  test('mock cancellation preserves counters and hides the mission', () async {
    final repository = MockCoordinationRepository(
      initialMissions: [needs.first.copyWith(createdBy: 'mock-coordinator')],
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
        email: 'a@example.fr',
        rpps: '10123456789',
        cptsId: 'cpts-medoc',
        cptsLabel: 'CPTS Médoc',
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
