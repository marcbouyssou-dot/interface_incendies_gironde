import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/engagement_confirmation_screen.dart';

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
    MockCoordinationRepository repository, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    }
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
    expect(find.text('JE M’ENGAGE À NOUVEAU'), findsOneWidget);
    expect(find.text('✓ JE SUIS ENGAGÉ'), findsNothing);
    expect(find.text('Annuler mon engagement'), findsNothing);
    expect(
      find.text('Votre désengagement a bien été enregistré.'),
      findsOneWidget,
    );
  });

  for (final (status, label, subtitle) in [
    (EngagementStatus.pending, 'DEMANDE ENVOYÉE', null),
    (EngagementStatus.confirmed, 'PARTICIPATION CONFIRMÉE', null),
    (EngagementStatus.standby, 'RENFORT', 'Vous serez contacté si nécessaire.'),
    (EngagementStatus.cancelled, 'JE M’ENGAGE À NOUVEAU', null),
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
      expect(find.text('❤️ JE M’ENGAGE'), findsNothing);
      if (subtitle != null) {
        expect(find.text(subtitle), findsOneWidget);
      }
      expect(
        find.text('Annuler mon engagement'),
        status == EngagementStatus.cancelled ? findsNothing : findsOneWidget,
      );
      if (status == EngagementStatus.cancelled) {
        await tester.ensureVisible(find.text('JE M’ENGAGE À NOUVEAU'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('JE M’ENGAGE À NOUVEAU'));
        await tester.pumpAndSettle();
        expect(find.text('Confirmer mon inscription'), findsOneWidget);
      }
    });
  }

  testWidgets('volunteer and administrative cancellation stay distinct', (
    tester,
  ) async {
    const engagement = EngagementInfo(
      missionId: 'ui-mission',
      volunteerId: 'mock-volunteer',
      profession: VolunteerProfession.mk,
      status: EngagementStatus.pending,
    );
    final repository = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
      initialEngagements: const [engagement],
    );
    repository.engagements['ui-mission'] = engagement;

    await pumpApp(tester, repository);

    expect(find.text('Annuler mon engagement'), findsOneWidget);
    expect(find.text('Annuler ce besoin'), findsOneWidget);
  });

  testWidgets(
    'waiting engagement status never displays the engagement action',
    (tester) async {
      final engagementStream = StreamController<EngagementInfo?>();
      addTearDown(engagementStream.close);
      final repository = _EngagementUiRepository(
        mission: mission(),
        engagementStream: engagementStream.stream,
      );

      await pumpApp(tester, repository, settle: false);

      expect(find.text('❤️ JE M’ENGAGE'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    },
  );

  testWidgets('engagement stream error never displays the engagement action', (
    tester,
  ) async {
    final repository = _EngagementUiRepository(
      mission: mission(),
      engagementStream: Stream<EngagementInfo?>.error(
        StateError('Firestore unavailable'),
      ),
    );

    await pumpApp(tester, repository);

    expect(find.text('Statut indisponible'), findsOneWidget);
    expect(find.text('❤️ JE M’ENGAGE'), findsNothing);
  });

  testWidgets('double submission invokes createEngagement only once', (
    tester,
  ) async {
    final completion = Completer<EngagementCreationResult>();
    final repository = _EngagementUiRepository(
      mission: mission(),
      engagementStream: Stream.value(null),
      completion: completion,
    );
    await pumpApp(tester, repository);
    await tester.ensureVisible(find.text('❤️ JE M’ENGAGE'));
    await tester.tap(find.text('❤️ JE M’ENGAGE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'A');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'B');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone'),
      '0600000000',
    );
    final submit = find.text('Confirmer mon inscription');
    await tester.ensureVisible(submit);

    await tester.tap(submit);
    await tester.tap(submit, warnIfMissed: false);
    await tester.pump();

    expect(repository.createCalls, 1);

    completion.complete(EngagementCreationResult.created);
    await tester.pumpAndSettle();
    expect(find.byType(EngagementConfirmationScreen), findsOneWidget);
  });

  testWidgets('idempotent confirmation displays its business message', (
    tester,
  ) async {
    final repository = _EngagementUiRepository(
      mission: mission(),
      engagementStream: Stream.value(null),
      result: EngagementCreationResult.alreadyConfirmed,
    );
    await pumpApp(tester, repository);
    await tester.ensureVisible(find.text('❤️ JE M’ENGAGE'));
    await tester.tap(find.text('❤️ JE M’ENGAGE'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'A');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'B');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone'),
      '0600000000',
    );
    final submit = find.text('Confirmer mon inscription');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text('Votre participation est déjà confirmée.'),
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

class _EngagementUiRepository extends MockCoordinationRepository {
  _EngagementUiRepository({
    required CoordinationNeed mission,
    required this.engagementStream,
    this.completion,
    this.result = EngagementCreationResult.created,
  }) : super(initialMissions: [mission], initialLocations: const []);

  final Stream<EngagementInfo?> engagementStream;
  final Completer<EngagementCreationResult>? completion;
  final EngagementCreationResult result;
  int createCalls = 0;

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) =>
      engagementStream;

  @override
  Future<EngagementCreationResult> createEngagement({
    required String missionId,
    required String firstName,
    required String lastName,
    required String phone,
    String? email,
    required VolunteerProfession profession,
  }) async {
    createCalls++;
    return completion == null ? result : completion!.future;
  }
}
