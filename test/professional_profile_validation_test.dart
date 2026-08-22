import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/professional_equipment.dart';
import 'package:interface_incendies_gironde/models/professional_profile_validation.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  group('canonical professional identifier validation', () {
    test('accepts valid RPPS and rejects invalid RPPS', () {
      expect(
        isValidProfessionalIdentifier(ProfessionalIdType.rpps, '10123456789'),
        isTrue,
      );
      expect(
        isValidProfessionalIdentifier(
          ProfessionalIdType.rpps,
          '10 123 456 789',
        ),
        isTrue,
      );
      for (final invalid in ['', '123', '1012345678A', '101234567890']) {
        expect(
          isValidProfessionalIdentifier(ProfessionalIdType.rpps, invalid),
          isFalse,
        );
      }
    });

    test('keeps ordinal identifier behavior unchanged', () {
      expect(
        isValidProfessionalIdentifier(ProfessionalIdType.ordinal, ' ORD-123 '),
        isTrue,
      );
      expect(
        isValidProfessionalIdentifier(ProfessionalIdType.ordinal, '   '),
        isFalse,
      );
      expect(
        isValidProfessionalIdentifier(ProfessionalIdType.none, ''),
        isFalse,
      );
    });

    test(
      'an otherwise complete profile with an invalid RPPS is incomplete',
      () {
        const profile = VolunteerProfile(
          uid: 'professional',
          firstName: 'Alice',
          lastName: 'Martin',
          phone: '0600000000',
          email: 'alice@example.fr',
          profession: VolunteerProfession.mk,
          professionalIdType: ProfessionalIdType.rpps,
          professionalIdValue: '123',
        );

        expect(ProfessionalProfileValidation.isComplete(profile), isFalse);
      },
    );
  });

  group('equipment validation', () {
    String? persistenceError(List<String> equipment, String? details) =>
        ProfessionalProfileValidation.persistenceError(
          email: 'alice@example.fr',
          professionalIdType: ProfessionalIdType.rpps,
          professionalIdValue: '10123456789',
          cptsId: null,
          cptsLabel: null,
          equipment: equipment,
          otherEquipmentDetails: details,
        );

    test('other equipment requires details', () {
      expect(
        persistenceError([ProfessionalEquipmentId.otherEquipment], null),
        isNotNull,
      );
      expect(
        persistenceError([
          ProfessionalEquipmentId.otherEquipment,
        ], 'Coussin ergonomique'),
        isNull,
      );
    });

    test('profession-specific equipment requires details', () {
      expect(
        persistenceError([
          ProfessionalEquipmentId.professionSpecificEquipment,
        ], '  '),
        isNotNull,
      );
      expect(
        persistenceError([
          ProfessionalEquipmentId.professionSpecificEquipment,
        ], 'Kit métier'),
        isNull,
      );
    });
  });

  group('engagement profile verification', () {
    test('unchanged verified identity remains verified', () async {
      final repository = _repositoryWithVerifiedProfile();

      final result = await _engage(repository);

      expect(result, EngagementCreationResult.created);
      expect(
        (await repository.getVolunteerProfile())
            ?.hasVerifiedProfessionalIdentity,
        isTrue,
      );
    });

    test('changed RPPS clears every derived verification field', () async {
      final repository = _repositoryWithVerifiedProfile();

      await _engage(repository, rpps: '10987654321');
      final saved = await repository.getVolunteerProfile();

      expect(saved?.verificationStatus, 'unverified');
      expect(saved?.verificationSource, isNull);
      expect(saved?.verifiedFirstName, isNull);
      expect(saved?.verifiedLastName, isNull);
      expect(saved?.verifiedProfessionCode, isNull);
      expect(saved?.verifiedProfessionLabel, isNull);
      expect(saved?.verifiedAt, isNull);
    });

    test(
      'changed profession clears verification without changing workflow',
      () async {
        final repository = _repositoryWithVerifiedProfile(requiredDoctors: 1);

        final result = await _engage(
          repository,
          profession: VolunteerProfession.doctor,
        );
        final saved = await repository.getVolunteerProfile();

        expect(result, EngagementCreationResult.created);
        expect(saved?.profession, VolunteerProfession.doctor);
        expect(saved?.verificationStatus, 'unverified');
        expect(saved?.verifiedAt, isNull);
        expect(
          repository.engagements['validation-mission']?.status,
          EngagementStatus.confirmed,
        );
      },
    );
  });
}

MockCoordinationRepository _repositoryWithVerifiedProfile({
  int requiredDoctors = 0,
}) {
  final mission = CoordinationNeed(
    id: 'validation-mission',
    place: 'Site',
    group: TerritorialGroup.medoc,
    date: 'Aujourd’hui',
    time: '08:00 — 12:00',
    endAt: DateTime.now().add(const Duration(hours: 2)),
    requiredPhysiotherapists: 1,
    registeredPhysiotherapists: 0,
    requiredPodiatrists: 0,
    registeredPodiatrists: 0,
    equipment: const [],
    professionQuotas: ProfessionQuotas([
      const ProfessionQuota(
        professionId: 'physiotherapist',
        required: 1,
        registered: 0,
      ),
      ProfessionQuota(
        professionId: 'physician',
        required: requiredDoctors,
        registered: 0,
      ),
    ]),
  );
  return MockCoordinationRepository(
    initialMissions: [mission],
    initialLocations: const [],
    initialProfiles: {
      'mock-volunteer': VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'MARTIN',
        phone: '0600000000',
        email: 'alice@example.fr',
        profession: VolunteerProfession.mk,
        rpps: '10123456789',
        professionalIdType: ProfessionalIdType.rpps,
        professionalIdValue: '10123456789',
        verificationStatus: 'verified',
        verificationSource: 'ans_rpps',
        verifiedFirstName: 'Alice',
        verifiedLastName: 'MARTIN',
        verifiedProfessionCode: '70',
        verifiedProfessionLabel: 'Masseur-Kinésithérapeute',
        verifiedAt: DateTime(2026, 8, 22),
      ),
    },
  );
}

Future<EngagementCreationResult> _engage(
  MockCoordinationRepository repository, {
  String rpps = '10123456789',
  VolunteerProfession profession = VolunteerProfession.mk,
}) => repository.createEngagement(
  missionId: 'validation-mission',
  firstName: 'Alice',
  lastName: 'MARTIN',
  phone: '0600000000',
  email: 'alice@example.fr',
  professionalIdType: ProfessionalIdType.rpps,
  professionalIdValue: rpps,
  profession: profession,
);
