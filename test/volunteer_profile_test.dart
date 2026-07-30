import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/professional_equipment.dart';
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
      expect(VolunteerProfession.values, hasLength(5));
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

  test('engagement persists its professional profile', () async {
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
    expect(profile?.equipment, [ProfessionalEquipmentId.massageTable]);
  });

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

  test('free historical equipment remains readable and persistable', () async {
    final repository = MockCoordinationRepository(
      initialMissions: const [],
      initialLocations: const [],
      initialProfiles: const {
        'mock-volunteer': VolunteerProfile(
          uid: 'mock-volunteer',
          firstName: 'Alice',
          lastName: 'Martin',
          phone: '0600000000',
          email: 'alice@example.fr',
          professionalIdType: ProfessionalIdType.none,
          professionalIdValue: '',
          profession: VolunteerProfession.doctor,
          equipment: [' Sac historique '],
        ),
      },
    );

    final legacy = await repository.getVolunteerProfile();
    expect(legacy?.equipment, ['Sac historique']);
    await repository.saveVolunteerProfile(legacy!);
    expect((await repository.getVolunteerProfile())?.equipment, [
      'Sac historique',
    ]);
  });

  test('profile validates modular identifiers and optional CPTS', () async {
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
    final legacySaved = await repository.getVolunteerProfile();
    expect(legacySaved?.rpps, '10123456789');
    expect(legacySaved?.effectiveProfessionalIdType, ProfessionalIdType.rpps);

    await repository.saveVolunteerProfile(
      const VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        email: 'alice@example.fr',
        professionalIdType: ProfessionalIdType.ordinal,
        professionalIdValue: '  ORD-123  ',
        profession: VolunteerProfession.mk,
      ),
    );
    final ordinal = await repository.getVolunteerProfile();
    expect(ordinal?.professionalIdType, ProfessionalIdType.ordinal);
    expect(ordinal?.professionalIdValue, 'ORD-123');
    expect(ordinal?.cptsId, isNull);
    expect(ordinal?.cptsLabel, isNull);

    await repository.saveVolunteerProfile(
      const VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        email: 'alice@example.fr',
        professionalIdType: ProfessionalIdType.none,
        professionalIdValue: '',
        profession: VolunteerProfession.mk,
      ),
    );
    expect(
      (await repository.getVolunteerProfile())?.effectiveProfessionalIdType,
      ProfessionalIdType.none,
    );

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
        professionalIdType: ProfessionalIdType.ordinal,
        professionalIdValue: '',
        profession: VolunteerProfession.mk,
      ),
      const VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        email: 'alice@example.fr',
        professionalIdType: ProfessionalIdType.none,
        professionalIdValue: 'unexpected',
        profession: VolunteerProfession.mk,
      ),
      const VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        email: 'alice@example.fr',
        professionalIdType: ProfessionalIdType.none,
        cptsId: 'cpts-medoc',
        profession: VolunteerProfession.mk,
      ),
    ]) {
      await expectLater(
        repository.saveVolunteerProfile(invalid),
        throwsA(isA<RepositoryException>()),
      );
    }
  });

  test(
    'other equipment details are required and persisted separately',
    () async {
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
        professionalIdType: ProfessionalIdType.none,
        professionalIdValue: '',
        profession: VolunteerProfession.mk,
        equipment: [ProfessionalEquipmentId.otherEquipment],
      );

      await expectLater(
        repository.saveVolunteerProfile(base),
        throwsA(isA<RepositoryException>()),
      );

      await repository.saveVolunteerProfile(
        base.copyWith(otherEquipmentDetails: '  Coussin ergonomique  '),
      );
      final saved = await repository.getVolunteerProfile();
      expect(saved?.equipment, [ProfessionalEquipmentId.otherEquipment]);
      expect(saved?.otherEquipmentDetails, 'Coussin ergonomique');
    },
  );

  test(
    'profession-specific equipment also requires details in Mock persistence',
    () async {
      final repository = MockCoordinationRepository(
        initialMissions: const [],
        initialLocations: const [],
      );
      const profile = VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        email: 'alice@example.fr',
        professionalIdType: ProfessionalIdType.none,
        professionalIdValue: '',
        profession: VolunteerProfession.otherHealthProfessional,
        equipment: [ProfessionalEquipmentId.professionSpecificEquipment],
      );

      await expectLater(
        repository.saveVolunteerProfile(profile),
        throwsA(isA<RepositoryException>()),
      );
      await repository.saveVolunteerProfile(
        profile.copyWith(otherEquipmentDetails: 'Kit métier'),
      );
      expect((await repository.getVolunteerProfile())?.equipment, [
        ProfessionalEquipmentId.professionSpecificEquipment,
      ]);
    },
  );
}
