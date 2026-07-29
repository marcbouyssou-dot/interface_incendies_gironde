import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

void main() {
  CoordinationNeed mission() => const CoordinationNeed(
    id: 'ui-mission',
    locationId: 'site-a',
    place: 'Site A',
    group: TerritorialGroup.medoc,
    date: 'Aujourd’hui',
    time: '08:00 — 12:00',
    requiredPhysiotherapists: 2,
    registeredPhysiotherapists: 0,
    requiredPodiatrists: 0,
    registeredPodiatrists: 0,
    equipment: [],
  );

  Future<void> pumpApp(
    WidgetTester tester,
    MockCoordinationRepository repository,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
  }

  testWidgets('disengagement is visible only after engagement and confirmed', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
    );
    await pumpApp(tester, repository);
    expect(find.text('Me désengager'), findsNothing);

    await repository.createEngagement(
      missionId: 'ui-mission',
      firstName: 'A',
      lastName: 'B',
      phone: '0600000000',
      profession: VolunteerProfession.mk,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Me désengager').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.text('✓ JE SUIS ENGAGÉ'), findsOneWidget);

    await tester.tap(find.text('Me désengager'));
    await tester.pumpAndSettle();
    expect(find.text('Se désengager de cette mission ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repository.engagements, hasLength(1));

    await tester.tap(find.text('Me désengager'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-engagement')));
    await tester.pumpAndSettle();
    expect(repository.engagements, isEmpty);
    expect(
      find.text('Votre désengagement a bien été enregistré.'),
      findsOneWidget,
    );
  });

  testWidgets('authorized manager cancellation requires confirmation', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
    );
    await pumpApp(tester, repository);
    await tester.scrollUntilVisible(
      find.text('Annuler ce besoin').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler ce besoin').first);
    await tester.pumpAndSettle();
    expect(find.text('Annuler ce besoin ?'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('cancellation-reason')),
      ' Vent violent ',
    );
    await tester.tap(find.byKey(const Key('confirm-cancel-mission')));
    await tester.pumpAndSettle();
    expect(repository.debugMission('ui-mission')?.isCancelled, isTrue);
  });

  testWidgets('cancellation action follows site manager location rights', (
    tester,
  ) async {
    final unauthorized = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
      responsibleAccess: const ResponsibleAccess(
        uid: 'manager',
        role: 'site_manager',
        locationIds: {'other-site'},
        active: true,
      ),
    );
    await pumpApp(tester, unauthorized);
    expect(find.text('Annuler ce besoin'), findsNothing);

    final authorized = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
      responsibleAccess: const ResponsibleAccess(
        uid: 'manager',
        role: 'site_manager',
        locationIds: {'site-a'},
        active: true,
      ),
    );
    await tester.pumpWidget(FireCoordinationApp(repository: authorized));
    await tester.pumpAndSettle();
    expect(find.text('Annuler ce besoin'), findsWidgets);
  });
}
