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
          profession: VolunteerProfession.nurse,
          equipment: [' Stéthoscope '],
        ),
      );
      final created = await first.getVolunteerProfile();
      expect(created?.profession, VolunteerProfession.nurse);
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
        profession: VolunteerProfession.mk,
        equipment: const [' Table ', 'Table'],
      );
      final profile = await repository.getVolunteerProfile();
      expect(profile?.firstName, 'Alice');
      expect(profile?.email, 'alice@example.fr');
      expect(profile?.equipment, ['Table']);

      await expectLater(
        repository.createEngagement(
          missionId: mission.id,
          firstName: 'Alice',
          lastName: 'Martin',
          phone: '0600000000',
          profession: VolunteerProfession.doctor,
        ),
        throwsA(isA<RepositoryException>()),
      );
    },
  );
}
