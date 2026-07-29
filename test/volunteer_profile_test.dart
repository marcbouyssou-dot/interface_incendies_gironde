import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  test(
    'profile professions expose the expected labels and mission support',
    () {
      expect(VolunteerProfession.mk.label, 'Masseur-kinésithérapeute');
      expect(VolunteerProfession.pp.label, 'Pédicure-podologue');
      expect(VolunteerProfession.doctor.label, 'Médecin');
      expect(VolunteerProfession.nurse.label, 'Infirmier / Infirmière');
      expect(
        VolunteerProfession.otherHealthProfessional.label,
        'Autre professionnel de santé',
      );
      expect(
        VolunteerProfession.values.where(
          (profession) => profession.isSupportedByCurrentMission,
        ),
        [VolunteerProfession.mk, VolunteerProfession.pp],
      );
    },
  );

  test(
    'mock profile is absent, persistent, editable and isolated by uid',
    () async {
      final profiles = <String, VolunteerProfile>{};
      final first = MockCoordinationRepository(
        initialMissions: const [],
        initialLocations: const [],
        initialProfiles: profiles,
        volunteerUid: 'uid-a',
      );
      expect(await first.getVolunteerProfile(), isNull);

      await first.saveVolunteerProfile(
        const VolunteerProfile(
          uid: 'uid-a',
          firstName: '  Alice ',
          lastName: ' Martin ',
          phone: ' 0600000000 ',
          email: 'alice@example.fr',
          rpps: ' 10123456789 ',
          cptsId: 'cpts-medoc',
          cptsLabel: ' CPTS Médoc ',
          profession: VolunteerProfession.nurse,
          equipment: [' Stéthoscope '],
        ),
      );
      final created = await first.getVolunteerProfile();
      expect(created?.profession, VolunteerProfession.nurse);
      expect(created?.rpps, '10123456789');
      expect(created?.cptsId, 'cpts-medoc');
      expect(created?.cptsLabel, 'CPTS Médoc');
      expect(created?.createdAt, isNotNull);

      await first.saveVolunteerProfile(
        created!.copyWith(
          phone: '0611111111',
          profession: VolunteerProfession.mk,
        ),
      );
      final updated = await first.getVolunteerProfile();
      expect(updated?.phone, '0611111111');
      expect(updated?.profession, VolunteerProfession.mk);
      expect(updated?.createdAt, created.createdAt);

      final second = MockCoordinationRepository(
        initialMissions: const [],
        initialLocations: const [],
        initialProfiles: profiles,
        volunteerUid: 'uid-b',
      );
      expect(await second.getVolunteerProfile(), isNull);
    },
  );

  test(
    'engagement persists its profile and rejects unsupported professions',
    () async {
      final mission = CoordinationNeed(
        id: 'mission',
        place: 'Site',
        group: TerritorialGroup.medoc,
        date: 'Aujourd’hui',
        time: '08:00 — 12:00',
        endAt: DateTime.now().add(const Duration(hours: 2)),
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
        firstName: ' Alice ',
        lastName: ' Martin ',
        phone: ' 0600000000 ',
        email: ' alice@example.fr ',
        rpps: ' 10123456789 ',
        cptsId: ' cpts-medoc ',
        cptsLabel: ' CPTS Médoc ',
        profession: VolunteerProfession.mk,
        equipment: const [' Table ', 'Table'],
      );
      final profile = await repository.getVolunteerProfile();
      expect(profile?.firstName, 'Alice');
      expect(profile?.email, 'alice@example.fr');
      expect(profile?.rpps, '10123456789');
      expect(profile?.cptsId, 'cpts-medoc');
      expect(profile?.cptsLabel, 'CPTS Médoc');
      expect(profile?.equipment, ['Table']);

      await expectLater(
        repository.createEngagement(
          missionId: mission.id,
          firstName: 'Alice',
          lastName: 'Martin',
          phone: '0600000000',
          email: 'alice@example.fr',
          rpps: '10123456789',
          cptsId: 'cpts-medoc',
          cptsLabel: 'CPTS Médoc',
          profession: VolunteerProfession.doctor,
        ),
        throwsA(isA<RepositoryException>()),
      );
    },
  );

  test('legacy profiles without RPPS or CPTS remain compatible', () async {
    final repository = MockCoordinationRepository(
      initialMissions: const [],
      initialLocations: const [],
      initialProfiles: const {
        'mock-volunteer': VolunteerProfile(
          uid: 'mock-volunteer',
          firstName: 'Alice',
          lastName: 'Martin',
          phone: '0600000000',
          profession: VolunteerProfession.mk,
        ),
      },
    );

    final profile = await repository.getVolunteerProfile();
    expect(profile?.rpps, isNull);
    expect(profile?.cptsId, isNull);
    expect(profile?.cptsLabel, isNull);
  });

  test('new profile writes require email, an 11-digit RPPS and CPTS', () async {
    final repository = MockCoordinationRepository(
      initialMissions: const [],
      initialLocations: const [],
    );
    const base = VolunteerProfile(
      uid: 'mock-volunteer',
      firstName: 'Alice',
      lastName: 'Martin',
      phone: '0600000000',
      email: 'alice@example.fr',
      rpps: '10 123 456 789',
      cptsId: 'cpts-medoc',
      cptsLabel: 'CPTS Médoc',
      profession: VolunteerProfession.mk,
    );

    await repository.saveVolunteerProfile(base);
    expect((await repository.getVolunteerProfile())?.rpps, '10123456789');

    for (final invalid in [
      const VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        rpps: '10123456789',
        cptsId: 'cpts-medoc',
        cptsLabel: 'CPTS Médoc',
        profession: VolunteerProfession.mk,
      ),
      base.copyWith(rpps: '123'),
      const VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        email: 'alice@example.fr',
        rpps: '10123456789',
        profession: VolunteerProfession.mk,
      ),
    ]) {
      await expectLater(
        repository.saveVolunteerProfile(invalid),
        throwsA(isA<RepositoryException>()),
      );
    }
  });
}
