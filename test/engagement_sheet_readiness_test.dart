import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/professional_equipment.dart';
import 'package:interface_incendies_gironde/models/professional_profile_validation.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

CoordinationNeed _mission({String id = 'readiness-mission'}) =>
    CoordinationNeed(
      id: id,
      place: 'Centre fictif de Langon',
      group: TerritorialGroup.medoc,
      date: 'Aujourd’hui',
      time: '16:59 — 16:59',
      startAt: DateTime.now(),
      endAt: DateTime.now().add(const Duration(hours: 48)),
      requiredPhysiotherapists: 0,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      professionQuotas: ProfessionQuotas.fromMaps(
        requiredByProfession: const {
          'physiotherapist': 1,
          'other_health_professional': 1,
        },
        registeredByProfession: const {},
      ),
      equipment: const [],
    );

const _noEmailProfile = VolunteerProfile(
  uid: 'mock-volunteer',
  firstName: 'Test',
  lastName: 'iPhone',
  phone: '0600000000',
  profession: VolunteerProfession.otherHealthProfessional,
  professionalIdType: ProfessionalIdType.none,
  professionalIdValue: '',
);

const _completeProfile = VolunteerProfile(
  uid: 'mock-volunteer',
  firstName: 'Test',
  lastName: 'iPhone',
  phone: '0600000000',
  email: 'test.iphone@example.fr',
  profession: VolunteerProfession.otherHealthProfessional,
  professionalIdType: ProfessionalIdType.none,
  professionalIdValue: '',
  professionalAddressLine1: '10 rue de la Santé',
  professionalPostalCode: '33000',
  professionalCity: 'Bordeaux',
);

class _FailingRepository extends MockCoordinationRepository {
  _FailingRepository({
    required this.error,
    super.initialMissions,
    super.initialProfiles,
  }) : super(responsibleAccess: null, initialLocations: const []);

  final Object error;
  int calls = 0;

  @override
  Future<EngagementCreationResult> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    String? rpps,
    ProfessionalIdType? professionalIdType,
    String? professionalIdValue,
    String? cptsId,
    String? cptsLabel,
    required VolunteerProfession profession,
    List<String> equipment = const [],
    String? otherEquipmentDetails,
  }) async {
    calls++;
    throw error;
  }
}

Future<void> _openSheet(
  WidgetTester tester,
  MockCoordinationRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(FireCoordinationApp(repository: repository));
  await tester.pumpAndSettle();
  final action = find.text('Je me mobilise').first;
  await tester.ensureVisible(action);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _tapConfirm(WidgetTester tester) async {
  final confirm = find.text('CONFIRMER MA PARTICIPATION');
  await tester.ensureVisible(confirm);
  await tester.pumpAndSettle();
  await tester.tap(confirm);
  await tester.pumpAndSettle();
}

void _expectVisibleInsideSheet(WidgetTester tester, Finder error) {
  expect(error, findsOneWidget);
  expect(
    error.hitTestable(),
    findsOneWidget,
    reason: 'error must not be hidden',
  );
  final rect = tester.getRect(error);
  final sheet = tester.getRect(find.byType(BottomSheet).first);
  expect(
    sheet.contains(rect.center),
    isTrue,
    reason: 'error must live in the sheet',
  );
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(844));
}

void main() {
  group('engagement readiness — single definition', () {
    List<EngagementProfileGap> gaps({
      String first = 'Alice',
      String last = 'Martin',
      String phone = '0600000000',
      String? email = 'alice@example.fr',
      VolunteerProfession profession =
          VolunteerProfession.otherHealthProfessional,
      ProfessionalIdType type = ProfessionalIdType.none,
      String value = '',
      List<String> equipment = const [],
      String? details,
      String? cptsLabel,
      String? address = '10 rue de la Santé',
      String? postalCode = '33000',
      String? city = 'Bordeaux',
    }) => ProfessionalProfileValidation.engagementGaps(
      firstName: first,
      lastName: last,
      phone: phone,
      email: email,
      profession: profession,
      professionalIdType: type,
      professionalIdValue: value,
      equipment: equipment,
      otherEquipmentDetails: details,
      cptsLabel: cptsLabel,
      professionalAddressLine1: address,
      professionalPostalCode: postalCode,
      professionalCity: city,
    );

    test('a complete profile has no gap', () {
      expect(gaps(), isEmpty);
    });

    test('each missing piece is reported on its own', () {
      expect(gaps(first: ' '), [EngagementProfileGap.firstName]);
      expect(gaps(last: ''), [EngagementProfileGap.lastName]);
      expect(gaps(phone: ''), [EngagementProfileGap.phone]);
      expect(gaps(email: null), [EngagementProfileGap.email]);
      expect(gaps(email: 'pas-un-email'), [EngagementProfileGap.email]);
      expect(gaps(profession: VolunteerProfession.mk), [
        EngagementProfileGap.professionalIdentifier,
      ]);
      expect(
        gaps(equipment: [ProfessionalEquipmentId.otherEquipment], details: ' '),
        [EngagementProfileGap.equipmentDetails],
      );
      expect(gaps(cptsLabel: 'x' * 161), [EngagementProfileGap.cptsLabel]);
      expect(gaps(address: null), [EngagementProfileGap.professionalAddress]);
      expect(gaps(postalCode: null), [EngagementProfileGap.professionalPostalCode]);
      expect(gaps(city: null), [EngagementProfileGap.professionalCity]);
    });

    test('identifier rules stay profession-aware and never relaxed', () {
      expect(
        gaps(
          profession: VolunteerProfession.mk,
          type: ProfessionalIdType.rpps,
          value: '10123456789',
        ),
        isEmpty,
      );
      expect(
        gaps(
          profession: VolunteerProfession.mk,
          type: ProfessionalIdType.rpps,
          value: '123',
        ),
        [EngagementProfileGap.professionalIdentifier],
      );
      expect(
        gaps(
          profession: VolunteerProfession.veterinarian,
          type: ProfessionalIdType.none,
        ),
        [EngagementProfileGap.professionalIdentifier],
      );
    });

    test('isComplete is defined by the same gaps', () {
      expect(
        ProfessionalProfileValidation.isComplete(_completeProfile),
        isTrue,
      );
      expect(
        ProfessionalProfileValidation.isComplete(_noEmailProfile),
        isFalse,
      );
      expect(ProfessionalProfileValidation.isComplete(null), isFalse);
    });

    test('no gap guarantees createEngagement is not refused for the profile '
        '(readiness is a superset of the repository validation)', () async {
      final professions = VolunteerProfession.values;
      final identifiers = <(ProfessionalIdType, String)>[
        (ProfessionalIdType.none, ''),
        (ProfessionalIdType.rpps, '10123456789'),
        (ProfessionalIdType.rpps, '123'),
        (ProfessionalIdType.ordinal, 'ORD-1'),
        (ProfessionalIdType.ordinal, ''),
      ];
      final emails = <String?>[null, '', 'pas-un-email', 'a@example.fr'];
      final phones = ['', '0600000000'];
      var exercised = 0;
      for (final profession in professions) {
        for (final (type, value) in identifiers) {
          for (final email in emails) {
            for (final phone in phones) {
              final missing = ProfessionalProfileValidation.engagementGaps(
                firstName: 'Alice',
                lastName: 'Martin',
                phone: phone,
                email: email,
                profession: profession,
                professionalIdType: type,
                professionalIdValue: value,
                professionalAddressLine1: '10 rue de la Santé',
                professionalPostalCode: '33000',
                professionalCity: 'Bordeaux',
              );
              if (missing.isNotEmpty) continue;
              exercised++;
              final mission = _mission(id: 'm-$exercised');
              final repository = MockCoordinationRepository(
                responsibleAccess: null,
                initialMissions: [
                  mission.copyWith(
                    professionQuotas: ProfessionQuotas.fromMaps(
                      requiredByProfession: {profession.canonicalId!: 1},
                      registeredByProfession: const {},
                    ),
                  ),
                ],
                initialLocations: const [],
              );
              await expectLater(
                repository.createEngagement(
                  missionId: mission.id,
                  firstName: 'Alice',
                  lastName: 'Martin',
                  phone: phone,
                  email: email,
                  professionalIdType: type,
                  professionalIdValue: value,
                  profession: profession,
                ),
                completion(EngagementCreationResult.created),
                reason:
                    '$profession/$type/"$value"/$email must be accepted '
                    'when readiness reports no gap',
              );
            }
          }
        }
      }
      expect(exercised, greaterThan(5));
    });
  });

  group('registration sheet', () {
    testWidgets('a complete profile shows the green banner and no gap', (
      tester,
    ) async {
      final repository = MockCoordinationRepository(
        responsibleAccess: null,
        initialMissions: [_mission()],
        initialLocations: const [],
        initialProfiles: const {'mock-volunteer': _completeProfile},
      );
      await _openSheet(tester, repository);

      expect(
        find.byKey(const Key('professional-identifier-ready')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('engagement-profile-incomplete')),
        findsNothing,
      );
      expect(find.text('Modifier mes informations'), findsOneWidget);
      expect(find.byKey(const Key('profile-summary-email')), findsOneWidget);
      expect(find.text('test.iphone@example.fr'), findsOneWidget);
      expect(find.text('0600000000'), findsOneWidget);
    });

    testWidgets('an RPPS profession never offers an ordinal alternative', (
      tester,
    ) async {
      const rppsProfile = VolunteerProfile(
        uid: 'mock-volunteer',
        firstName: 'Alice',
        lastName: 'Martin',
        phone: '0600000000',
        email: 'alice@example.fr',
        profession: VolunteerProfession.mk,
        professionalIdType: ProfessionalIdType.rpps,
        professionalIdValue: '10123456789',
        professionalAddressLine1: '10 rue de la Santé',
        professionalPostalCode: '33000',
        professionalCity: 'Bordeaux',
      );
      final repository = MockCoordinationRepository(
        responsibleAccess: null,
        initialMissions: [_mission()],
        initialLocations: const [],
        initialProfiles: const {'mock-volunteer': rppsProfile},
      );
      await _openSheet(tester, repository);
      await tester.tap(find.text('Modifier mes informations'));
      await tester.pumpAndSettle();

      final selector = find.byKey(const Key('professional-id-type'));
      await tester.ensureVisible(selector);
      await tester.tap(selector);
      await tester.pumpAndSettle();

      expect(find.text('RPPS'), findsWidgets);
      expect(find.text('Numéro ordinal'), findsNothing);
    });

    testWidgets(
      'a repository refusal is shown in the sheet, not in a SnackBar',
      (tester) async {
        final repository = _FailingRepository(
          error: const RepositoryException('Ce besoin est désormais couvert.'),
          initialMissions: [_mission()],
          initialProfiles: const {'mock-volunteer': _completeProfile},
        );
        await _openSheet(tester, repository);
        await _tapConfirm(tester);

        final error = find.byKey(const Key('registration-submit-error'));
        _expectVisibleInsideSheet(tester, error);
        expect(
          find.descendant(
            of: error,
            matching: find.text('Ce besoin est désormais couvert.'),
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(repository.calls, 1);
        expect(find.text('CONFIRMER MA PARTICIPATION'), findsOneWidget);
      },
    );

    testWidgets('an unexpected failure shows a generic in-sheet message', (
      tester,
    ) async {
      final repository = _FailingRepository(
        error: StateError('boom'),
        initialMissions: [_mission()],
        initialProfiles: const {'mock-volunteer': _completeProfile},
      );
      await _openSheet(tester, repository);
      await _tapConfirm(tester);

      final error = find.byKey(const Key('registration-submit-error'));
      _expectVisibleInsideSheet(tester, error);
      expect(
        find.descendant(
          of: error,
          matching: find.text(
            'L’inscription n’a pas pu être enregistrée. Réessayez.',
          ),
        ),
        findsOneWidget,
      );
    });
  });
}
