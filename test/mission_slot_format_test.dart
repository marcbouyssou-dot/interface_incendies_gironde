import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/firestore_mission_mapper.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/engagement_confirmation_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/utils/french_date_time.dart';
import 'package:interface_incendies_gironde/utils/mission_timing.dart';
import 'package:interface_incendies_gironde/widgets/responsible_mission_card.dart';

CoordinationNeed _need(DateTime start, DateTime end) => CoordinationNeed(
  id: 'slot-mission',
  place: 'Centre fictif de Langon',
  group: TerritorialGroup.medoc,
  date: FrenchDateTime.date(start),
  time: FrenchDateTime.timeRange(start, end),
  startAt: start,
  endAt: end,
  requiredPhysiotherapists: 0,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  professionQuotas: ProfessionQuotas.fromMaps(
    requiredByProfession: const {'other_health_professional': 1},
    registeredByProfession: const {},
  ),
  equipment: const [],
);

void main() {
  group('missionTemporalState uses the local civil day', () {
    final midday = DateTime(2026, 9, 28, 12);

    test('today remains current after the slot has ended', () {
      expect(
        missionTemporalState(
          _need(DateTime(2026, 9, 28, 8), DateTime(2026, 9, 28, 10)),
          now: midday,
        ),
        MissionTemporalState.current,
      );
    });

    test('yesterday is past', () {
      expect(
        missionTemporalState(
          _need(DateTime(2026, 9, 27, 8), DateTime(2026, 9, 27, 18)),
          now: midday,
        ),
        MissionTemporalState.past,
      );
    });

    test('the day before yesterday is past', () {
      expect(
        missionTemporalState(
          _need(DateTime(2026, 9, 26, 8), DateTime(2026, 9, 26, 18)),
          now: midday,
        ),
        MissionTemporalState.past,
      );
    });

    test('tomorrow is upcoming', () {
      expect(
        missionTemporalState(
          _need(DateTime(2026, 9, 29, 8), DateTime(2026, 9, 29, 18)),
          now: midday,
        ),
        MissionTemporalState.upcoming,
      );
    });

    test('a multi-day slot including today is current', () {
      expect(
        missionTemporalState(
          _need(DateTime(2026, 9, 27, 8), DateTime(2026, 9, 29, 18)),
          now: midday,
        ),
        MissionTemporalState.current,
      );
    });

    test('a completed multi-day slot is past', () {
      expect(
        missionTemporalState(
          _need(DateTime(2026, 9, 25, 8), DateTime(2026, 9, 27, 18)),
          now: midday,
        ),
        MissionTemporalState.past,
      );
    });

    test('classification changes at the local day boundary', () {
      final mission = _need(
        DateTime(2026, 9, 29, 8),
        DateTime(2026, 9, 29, 18),
      );

      expect(
        missionTemporalState(mission, now: DateTime(2026, 9, 28, 23, 59)),
        MissionTemporalState.upcoming,
      );
      expect(
        missionTemporalState(mission, now: DateTime(2026, 9, 29, 0, 1)),
        MissionTemporalState.current,
      );
    });
  });

  group('FrenchDateTime.timeRange', () {
    test('same day keeps the compact clock range', () {
      expect(
        FrenchDateTime.timeRange(
          DateTime(2026, 9, 26, 8),
          DateTime(2026, 9, 26, 12, 30),
        ),
        '08:00 — 12:30',
      );
    });

    test(
      'a slot ending two days later names the end day (Saturday to Monday)',
      () {
        expect(
          FrenchDateTime.timeRange(
            DateTime(2026, 9, 26, 16, 59),
            DateTime(2026, 9, 28, 16, 59),
          ),
          '16:59 — lun. 28 sept., 16:59',
        );
      },
    );

    test('a slot ending the next morning is not read as same-day', () {
      expect(
        FrenchDateTime.timeRange(
          DateTime(2026, 9, 26, 22),
          DateTime(2026, 9, 27),
        ),
        '22:00 — dim. 27 sept., 00:00',
      );
    });

    test('month change spells the new month', () {
      expect(
        FrenchDateTime.timeRange(
          DateTime(2026, 9, 30, 20),
          DateTime(2026, 10, 2, 8),
        ),
        '20:00 — ven. 2 oct., 08:00',
      );
    });

    test('year change spells the new year', () {
      expect(
        FrenchDateTime.timeRange(
          DateTime(2026, 12, 31, 22),
          DateTime(2027, 1, 1, 6),
        ),
        '22:00 — ven. 1 janv. 2027, 06:00',
      );
    });

    test('the start date is still given separately by date()', () {
      expect(
        FrenchDateTime.date(DateTime(2026, 9, 26, 16, 59)),
        'samedi 26 septembre 2026',
      );
    });
  });

  test(
    'the Firestore mapper uses the shared formatter without touching times',
    () {
      final start = DateTime(2026, 9, 26, 16, 59);
      final end = DateTime(2026, 9, 28, 16, 59);
      final need = FirestoreMissionMapper.fromFirestore(
        id: 'm',
        data: {
          'startAt': Timestamp.fromDate(start),
          'endAt': Timestamp.fromDate(end),
          'locationName': 'Centre fictif de Langon',
          'mobilizationId': 'mob',
        },
      );
      expect(need.date, 'samedi 26 septembre 2026');
      expect(need.time, '16:59 — lun. 28 sept., 16:59');
      expect(need.startAt, start);
      expect(need.endAt, end);
    },
  );

  for (final size in const [Size(390, 844), Size(320, 568)]) {
    group('multi-day slot at ${size.width.toInt()}px', () {
      final start = DateTime.now().subtract(const Duration(minutes: 5));
      final end = start.add(const Duration(days: 2));

      Future<void> setSize(WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
      }

      testWidgets('Professional list, sheet and confirmation do not overflow', (
        tester,
      ) async {
        await setSize(tester);
        final need = _need(start, end);
        final repository = MockCoordinationRepository(
          responsibleAccess: null,
          initialMissions: [need],
          initialLocations: const [],
          initialProfiles: const {
            'mock-volunteer': VolunteerProfile(
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
            ),
          },
        );
        await tester.pumpWidget(FireCoordinationApp(repository: repository));
        await tester.pumpAndSettle();
        expect(find.textContaining(need.time), findsWidgets);
        expect(tester.takeException(), isNull);

        final action = find.text('Je me mobilise').first;
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final confirm = find.text('CONFIRMER MA PARTICIPATION');
        await tester.ensureVisible(confirm);
        await tester.pumpAndSettle();
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.text('Merci !'), findsOneWidget);
        expect(find.text('Votre engagement est confirmé.'), findsOneWidget);
        expect(find.textContaining(need.time), findsWidgets);
        expect(tester.takeException(), isNull);

        Navigator.of(tester.element(find.text('Merci !'))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Engagements'));
        await tester.pumpAndSettle();
        expect(find.text('AUJOURD’HUI'), findsOneWidget);
        expect(find.textContaining(need.time), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('confirmation screen and Responsible card do not overflow', (
        tester,
      ) async {
        await setSize(tester);
        final need = _need(start, end);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: EngagementConfirmationScreen(
              need: need,
              profession: VolunteerProfession.otherHealthProfessional,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(need.time, skipOffstage: false), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ResponsibleMissionCard(
                  need: need,
                  tone: ResponsibleMissionTone.attention,
                  statusLabel: 'Renforts nécessaires',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(need.time), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
