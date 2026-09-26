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

    testWidgets(
      'profile without email: banner is not green, gap is named, summary flags it',
      (tester) async {
        final repository = MockCoordinationRepository(
          responsibleAccess: null,
          initialMissions: [_mission()],
          initialLocations: const [],
          initialProfiles: const {'mock-volunteer': _noEmailProfile},
        );
        await _openSheet(tester, repository);

        expect(
          find.byKey(const Key('professional-identifier-ready')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('engagement-profile-incomplete')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('engagement-gap-email')), findsOneWidget);
        expect(find.byKey(const Key('engagement-gap-phone')), findsNothing);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('À renseigner'), findsOneWidget);
        expect(find.text('Compléter mon profil'), findsOneWidget);
        expect(find.text('Modifier mes informations'), findsNothing);
      },
    );

    testWidgets(
      'profile without email → confirm → the error is visible inside the sheet '
      'and nothing is written',
      (tester) async {
        final repository = MockCoordinationRepository(
          responsibleAccess: null,
          initialMissions: [_mission()],
          initialLocations: const [],
          initialProfiles: const {'mock-volunteer': _noEmailProfile},
        );
        await _openSheet(tester, repository);
        await _tapConfirm(tester);

        final error = find.byKey(const Key('registration-submit-error'));
        _expectVisibleInsideSheet(tester, error);
        expect(
          find.descendant(
            of: error,
            matching: find.textContaining('Email valide'),
          ),
          findsOneWidget,
        );
        expect(find.byType(SnackBar), findsNothing);
        expect(repository.engagements, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'summary without phone and email shows both as to be filled in',
      (tester) async {
        final repository = MockCoordinationRepository(
          responsibleAccess: null,
          initialMissions: [_mission()],
          initialLocations: const [],
          initialProfiles: const {
            'mock-volunteer': VolunteerProfile(
              uid: 'mock-volunteer',
              firstName: 'Test',
              lastName: 'iPhone',
              phone: '',
              profession: VolunteerProfession.otherHealthProfessional,
              professionalIdType: ProfessionalIdType.none,
              professionalIdValue: '',
            ),
          },
        );
        await _openSheet(tester, repository);

        expect(find.byKey(const Key('engagement-gap-phone')), findsOneWidget);
        expect(find.byKey(const Key('engagement-gap-email')), findsOneWidget);
        expect(find.text('À renseigner'), findsNWidgets(2));
        expect(find.text('Compléter mon profil'), findsOneWidget);
      },
    );

    testWidgets('typing the missing email turns the banner green live', (
      tester,
    ) async {
      final repository = MockCoordinationRepository(
        responsibleAccess: null,
        initialMissions: [_mission()],
        initialLocations: const [],
        initialProfiles: const {'mock-volunteer': _noEmailProfile},
      );
      await _openSheet(tester, repository);

      await tester.tap(find.text('Compléter mon profil'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('engagement-profile-incomplete')),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'test.iphone@example.fr',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('professional-identifier-ready')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('engagement-profile-incomplete')),
        findsNothing,
      );

      await _tapConfirm(tester);
      expect(find.byKey(const Key('registration-submit-error')), findsNothing);
      expect(repository.engagements, isNotEmpty);
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

  group('registration sheet — validation errors while editing', () {
    Finder field(String label) => find.widgetWithText(TextFormField, label);

    FormFieldState<String> stateOf(WidgetTester tester, String label) =>
        tester.state<FormFieldState<String>>(field(label));

    Future<MockCoordinationRepository> openWithoutEmail(
      WidgetTester tester,
    ) async {
      final repository = MockCoordinationRepository(
        responsibleAccess: null,
        initialMissions: [_mission()],
        initialLocations: const [],
        initialProfiles: const {'mock-volunteer': _noEmailProfile},
      );
      await _openSheet(tester, repository);
      await _tapConfirm(tester);
      await tester.ensureVisible(field('Email'));
      await tester.pumpAndSettle();
      return repository;
    }

    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(field('Email'), text);
      await tester.pumpAndSettle();
    }

    testWidgets(
      'profile without email → Confirmer → "Champ requis" → typing a valid '
      'email clears the stale error and the banner becomes ready',
      (tester) async {
        final repository = await openWithoutEmail(tester);

        expect(stateOf(tester, 'Email').errorText, 'Champ requis');
        expect(find.text('Champ requis'), findsOneWidget);
        expect(
          find.byKey(const Key('engagement-profile-incomplete')),
          findsOneWidget,
        );

        // Same keystroke-by-keystroke path as on the iPhone.
        await type(tester, 'm');
        expect(stateOf(tester, 'Email').errorText, 'Email invalide');
        await type(tester, 'marc');
        expect(stateOf(tester, 'Email').errorText, 'Email invalide');
        await type(tester, 'marc@example');
        expect(
          stateOf(tester, 'Email').errorText,
          'Email invalide',
          reason: 'an incomplete address must stay flagged while typing',
        );
        expect(
          find.byKey(const Key('professional-identifier-ready')),
          findsNothing,
        );

        await type(tester, 'marc@example.fr');
        final email = stateOf(tester, 'Email');
        expect(email.value, 'marc@example.fr');
        expect(
          tester.widget<TextFormField>(field('Email')).controller?.text,
          'marc@example.fr',
        );
        expect(email.errorText, isNull);
        expect(find.text('Champ requis'), findsNothing);
        expect(find.text('Email invalide'), findsNothing);
        expect(
          find.byKey(const Key('professional-identifier-ready')),
          findsOneWidget,
        );
        expect(find.text('Profil prêt à participer'), findsOneWidget);
        expect(
          find.byKey(const Key('engagement-profile-incomplete')),
          findsNothing,
        );
        expect(repository.engagements, isEmpty);
      },
    );

    testWidgets('an invalid email stays in error and is never cleared', (
      tester,
    ) async {
      final repository = await openWithoutEmail(tester);

      await type(tester, 'm');
      await type(tester, 'abc');

      expect(stateOf(tester, 'Email').errorText, 'Email invalide');
      expect(find.text('Email invalide'), findsOneWidget);
      expect(
        find.byKey(const Key('professional-identifier-ready')),
        findsNothing,
      );
      expect(find.byKey(const Key('engagement-gap-email')), findsOneWidget);

      // Losing focus does not clear it either.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(stateOf(tester, 'Email').errorText, 'Email invalide');
      expect(repository.engagements, isEmpty);
    });

    testWidgets('valid and untouched fields never show a stray error', (
      tester,
    ) async {
      await openWithoutEmail(tester);

      // Only the email was missing: the other prefilled fields stay clean.
      expect(stateOf(tester, 'Prénom').errorText, isNull);
      expect(stateOf(tester, 'Nom').errorText, isNull);
      expect(stateOf(tester, 'Téléphone').errorText, isNull);
      expect(find.text('Téléphone trop court'), findsNothing);

      await type(tester, 'm');
      await type(tester, 'marc@example.fr');

      expect(stateOf(tester, 'Prénom').errorText, isNull);
      expect(stateOf(tester, 'Nom').errorText, isNull);
      expect(stateOf(tester, 'Téléphone').errorText, isNull);
      expect(find.text('Champ requis'), findsNothing);
    });

    testWidgets('after the correction, Confirmer creates the engagement', (
      tester,
    ) async {
      final repository = await openWithoutEmail(tester);
      await type(tester, 'm');
      await type(tester, 'marc@example.fr');
      expect(repository.engagements, isEmpty);

      await _tapConfirm(tester);

      expect(repository.engagements, isNotEmpty);
      expect(find.byKey(const Key('registration-submit-error')), findsNothing);
    });
  });
}
