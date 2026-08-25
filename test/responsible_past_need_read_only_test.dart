import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/health_profession.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/responsible_needs_screen.dart';
import 'package:interface_incendies_gironde/screens/responsible_published_needs.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/utils/mission_timing.dart';

void main() {
  CoordinationNeed mission({
    required String id,
    required DateTime startAt,
    required DateTime endAt,
    ProfessionQuotas? quotas,
  }) {
    final location = places.first;
    return CoordinationNeed(
      id: id,
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: '25/08/2026',
      time: '08:00 — 12:00',
      startAt: startAt,
      endAt: endAt,
      requiredPhysiotherapists: 4,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 4,
      registeredPodiatrists: 0,
      professionQuotas: quotas,
      equipment: const [],
      createdBy: 'manager',
    );
  }

  ProfessionQuotas historicalQuotas() => ProfessionQuotas.fromMaps(
    requiredByProfession: const {
      HealthProfessionId.physiotherapist: 4,
      HealthProfessionId.podiatrist: 4,
      HealthProfessionId.physician: 4,
      HealthProfessionId.nurse: 4,
      HealthProfessionId.otherHealthProfessional: 4,
    },
    registeredByProfession: const {},
  );

  Future<void> pumpNeeds(
    WidgetTester tester, {
    required List<CoordinationNeed> missions,
    required VoidCallback onOpenTeam,
  }) async {
    final location = places.first;
    final repository = MockCoordinationRepository(
      initialMissions: missions,
      initialLocations: [location],
      responsibleAccess: ResponsibleAccess.v2(
        uid: 'manager',
        roles: const [ResponsibleRole.siteManager],
        locationIds: {location.id},
        active: true,
      ),
    );
    final liveData = LiveCoordinationData(repository);
    final publishedNeeds = ResponsiblePublishedNeeds();
    addTearDown(liveData.dispose);
    addTearDown(publishedNeeds.dispose);

    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: MaterialApp(
          theme: AppTheme.light,
          home: LiveCoordinationDataScope(
            data: liveData,
            child: Scaffold(
              body: SafeArea(
                child: ResponsibleNeedsScreen(
                  publishedNeeds: publishedNeeds,
                  onOpenTeam: onOpenTeam,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('future and active-today needs keep the edit action', (
    tester,
  ) async {
    final now = DateTime.now();
    await pumpNeeds(
      tester,
      missions: [
        mission(
          id: 'today',
          startAt: now.subtract(const Duration(hours: 1)),
          endAt: now.add(const Duration(hours: 1)),
        ),
        mission(
          id: 'future',
          startAt: now.add(const Duration(days: 1)),
          endAt: now.add(const Duration(days: 1, hours: 4)),
        ),
      ],
      onOpenTeam: () {},
    );

    expect(
      find.byKey(const Key('responsible-edit-need-today')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('responsible-edit-need-future')),
      findsOneWidget,
    );
  });

  testWidgets(
    'past need is read-only while quotas and team action stay available',
    (tester) async {
      final now = DateTime.now();
      var teamOpenCount = 0;
      await pumpNeeds(
        tester,
        missions: [
          mission(
            id: 'past',
            startAt: now.subtract(const Duration(hours: 5)),
            endAt: now.subtract(const Duration(hours: 1)),
            quotas: historicalQuotas(),
          ),
        ],
        onOpenTeam: () => teamOpenCount++,
      );

      await tester.tap(find.byKey(const Key('responsible-needs-filter-past')));
      await tester.pumpAndSettle();

      final card = find.byKey(const Key('responsible-need-past'));
      expect(card, findsOneWidget);
      expect(find.byKey(const Key('responsible-edit-need-past')), findsNothing);
      expect(
        find.descendant(of: card, matching: find.text('0 / 4')),
        findsNWidgets(5),
      );
      final teamAction = find.byKey(const Key('responsible-view-team-past'));
      expect(teamAction, findsOneWidget);
      await tester.tap(teamAction);
      expect(teamOpenCount, 1);
    },
  );

  test('past boundary uses the shared mission timing primitive', () {
    final boundary = DateTime(2026, 8, 25, 12);
    final beforeBoundary = mission(
      id: 'before-boundary',
      startAt: boundary.subtract(const Duration(hours: 2)),
      endAt: boundary.subtract(const Duration(microseconds: 1)),
    );
    final atBoundary = mission(
      id: 'at-boundary',
      startAt: boundary.subtract(const Duration(hours: 2)),
      endAt: boundary,
    );
    final afterBoundary = mission(
      id: 'after-boundary',
      startAt: boundary.subtract(const Duration(hours: 2)),
      endAt: boundary.add(const Duration(microseconds: 1)),
    );

    expect(isMissionPast(beforeBoundary, now: boundary), isTrue);
    expect(isMissionPast(atBoundary, now: boundary), isTrue);
    expect(isMissionPast(afterBoundary, now: boundary), isFalse);
  });
}
