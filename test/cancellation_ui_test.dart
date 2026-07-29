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

  testWidgets('pending engagement shows its badge and disengagement', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
    );
    await pumpApp(tester, repository);
    expect(find.text('Annuler mon engagement'), findsNothing);

    await repository.createEngagement(
      missionId: 'ui-mission',
      firstName: 'A',
      lastName: 'B',
      phone: '0600000000',
      profession: VolunteerProfession.mk,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Annuler mon engagement').first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.text('DEMANDE ENVOYÉE'), findsOneWidget);
    expect(find.text('✓ JE SUIS ENGAGÉ'), findsNothing);
    expect(find.text('En attente'), findsOneWidget);

    await tester.tap(find.text('Annuler mon engagement'));
    await tester.pumpAndSettle();
    expect(find.text('Se désengager de cette mission ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repository.engagements, hasLength(1));

    await tester.tap(find.text('Annuler mon engagement'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-engagement')));
    await tester.pumpAndSettle();
    expect(
      repository.engagements['ui-mission']?.status,
      EngagementStatus.cancelled,
    );
    expect(repository.debugMission('ui-mission')?.isActive, isTrue);
    expect(repository.debugMission('ui-mission')?.isCancelled, isFalse);
    expect(find.text('PARTICIPATION ANNULÉE'), findsOneWidget);
    expect(find.text('✓ JE SUIS ENGAGÉ'), findsNothing);
    expect(find.text('Annuler mon engagement'), findsNothing);
    expect(
      find.text('Votre désengagement a bien été enregistré.'),
      findsOneWidget,
    );
  });

  for (final (status, label, subtitle) in [
    (EngagementStatus.confirmed, 'PARTICIPATION CONFIRMÉE', null),
    (EngagementStatus.standby, 'RENFORT', 'Vous serez contacté si nécessaire.'),
    (EngagementStatus.cancelled, 'PARTICIPATION ANNULÉE', null),
  ]) {
    testWidgets('volunteer cancellation visibility for ${status.name}', (
      tester,
    ) async {
      final engagement = EngagementInfo(
        missionId: 'ui-mission',
        volunteerId: 'mock-volunteer',
        profession: VolunteerProfession.mk,
        status: status,
      );
      final repository = MockCoordinationRepository(
        initialMissions: [mission()],
        initialLocations: const [],
        initialEngagements: [engagement],
      );
      repository.engagements['ui-mission'] = engagement;
      await pumpApp(tester, repository);

      expect(find.text(label), findsOneWidget);
      expect(find.text(status.label), findsOneWidget);
      expect(find.text('✓ JE SUIS ENGAGÉ'), findsNothing);
      if (subtitle != null) {
        expect(find.text(subtitle), findsOneWidget);
      }
      expect(
        find.text('Annuler mon engagement'),
        status == EngagementStatus.cancelled ? findsNothing : findsOneWidget,
      );
    });
  }

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

  testWidgets('coordinator confirms an engagement from the situation card', (
    tester,
  ) async {
    const engagement = EngagementInfo(
      missionId: 'ui-mission',
      volunteerId: 'volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.pending,
    );
    final repository = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
      initialEngagements: const [engagement],
    );
    await pumpApp(tester, repository);
    await tester.tap(find.text('Situation').last);
    await tester.pumpAndSettle();
    final menu = find.byKey(const Key('engagement-menu-ui-mission_volunteer'));
    await tester.scrollUntilVisible(
      menu,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer').last);
    await tester.pumpAndSettle();

    expect(
      repository.missionEngagements.single.status,
      EngagementStatus.confirmed,
    );
    expect(find.text('MK • Confirmé'), findsOneWidget);
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
