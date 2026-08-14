import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/professional_equipment.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/engagement_confirmation_screen.dart';
import 'package:interface_incendies_gironde/widgets/common.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';

void main() {
  const cancellationLabel = 'Annuler mon engagement pour cette mission';

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
    createdBy: 'mock-coordinator',
  );

  CoordinationNeed sixProfessionMission() => CoordinationNeed(
    id: 'six-profession-mission',
    locationId: 'site-a',
    place: 'Site A',
    group: TerritorialGroup.medoc,
    date: 'Aujourd’hui',
    time: '08:00 — 12:00',
    requiredPhysiotherapists: 1,
    registeredPhysiotherapists: 0,
    requiredPodiatrists: 1,
    registeredPodiatrists: 0,
    professionQuotas: ProfessionQuotas.fromMaps(
      requiredByProfession: const {
        'physiotherapist': 1,
        'podiatrist': 1,
        'physician': 1,
        'nurse': 1,
        'veterinarian': 1,
        'other_health_professional': 1,
      },
      registeredByProfession: const {},
    ),
    equipment: const [],
    createdBy: 'mock-coordinator',
  );

  Future<void> pumpApp(
    WidgetTester tester,
    MockCoordinationRepository repository, {
    bool settle = true,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: repository,
        useLegacyCoordinatorShellForTesting: true,
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
    }
  }

  Future<void> fillRequiredProfessionalFields(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'a@example.fr',
    );
    await tester.ensureVisible(find.byKey(const Key('professional-id-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('professional-id-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('RPPS').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('professional-id-value')),
      '10123456789',
    );
    await tester.ensureVisible(find.byKey(const Key('cpts-choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cpts-choice')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Renseigner une CPTS').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nom de la CPTS'),
      'CPTS Médoc',
    );
  }

  Future<void> openEngagementForm(WidgetTester tester) async {
    final action = find.text('Je me mobilise');
    final missionScroll = find
        .descendant(
          of: find.byType(CustomScrollView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(action, 300, scrollable: missionScroll);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  Future<void> selectNavigationTab(WidgetTester tester, int index) async {
    final navigation = tester.widget<V5BottomBar>(find.byType(V5BottomBar));
    navigation.onDestinationSelected(index);
    await tester.pumpAndSettle();
  }

  Finder pageScroll() => find
      .descendant(
        of: find.byType(CustomScrollView).first,
        matching: find.byType(Scrollable),
      )
      .first;

  testWidgets('new engagement shows confirmed state and disengagement', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
    );
    await pumpApp(tester, repository);
    expect(find.text(cancellationLabel), findsNothing);

    await repository.createEngagement(
      missionId: 'ui-mission',
      firstName: 'A',
      lastName: 'B',
      phone: '0600000000',
      email: 'a@example.fr',
      rpps: '10123456789',
      cptsId: 'cpts-medoc',
      cptsLabel: 'CPTS Médoc',
      profession: VolunteerProfession.mk,
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(cancellationLabel).first,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.text('Participation confirmée'), findsOneWidget);
    expect(find.text('✓ JE SUIS ENGAGÉ'), findsNothing);
    expect(find.text('Confirmé'), findsOneWidget);

    await tester.tap(find.text(cancellationLabel));
    await tester.pumpAndSettle();
    expect(find.text('Annuler mon engagement ?'), findsOneWidget);
    expect(find.text('Mission : Site A'), findsOneWidget);
    expect(find.text('Date : Aujourd’hui'), findsOneWidget);
    expect(
      find.textContaining('vous ne serez plus compté parmi les professionnels'),
      findsOneWidget,
    );
    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(repository.engagements, hasLength(1));

    await tester.tap(find.text(cancellationLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-engagement')));
    await tester.pumpAndSettle();
    expect(
      repository.engagements['ui-mission']?.status,
      EngagementStatus.cancelled,
    );
    expect(repository.debugMission('ui-mission')?.isActive, isTrue);
    expect(repository.debugMission('ui-mission')?.isCancelled, isFalse);
    expect(find.text('Je me mobilise à nouveau'), findsOneWidget);
    expect(find.text('✓ JE SUIS ENGAGÉ'), findsNothing);
    expect(find.text(cancellationLabel), findsNothing);
    expect(find.text('Je ne suis plus disponible'), findsNothing);
    expect(
      find.text('Votre désengagement a bien été enregistré.'),
      findsOneWidget,
    );
  });

  for (final (status, label, subtitle) in [
    (EngagementStatus.pending, 'Finaliser ma participation', null),
    (EngagementStatus.confirmed, 'Participation confirmée', null),
    (
      EngagementStatus.standby,
      'Renfort disponible',
      'Vous serez contacté si nécessaire.',
    ),
    (EngagementStatus.cancelled, 'Je me mobilise à nouveau', null),
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
      expect(find.text('Je me mobilise'), findsNothing);
      if (subtitle != null) {
        expect(find.text(subtitle), findsOneWidget);
      }
      expect(
        find.text(cancellationLabel),
        status == EngagementStatus.cancelled ? findsNothing : findsOneWidget,
      );
      if (status == EngagementStatus.cancelled) {
        await tester.ensureVisible(find.text('Je me mobilise à nouveau'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Je me mobilise à nouveau'));
        await tester.pumpAndSettle();
        expect(find.text('CONFIRMER MA PARTICIPATION'), findsOneWidget);
      }
    });
  }

  testWidgets('public mission card only exposes volunteer cancellation', (
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

    expect(find.text(cancellationLabel), findsOneWidget);
    expect(find.text('Je ne suis plus disponible'), findsNothing);
    expect(find.text('Annuler ce besoin'), findsNothing);
  });

  testWidgets(
    'waiting engagement status never displays the engagement action',
    (tester) async {
      final repository = _EngagementUiRepository(
        mission: mission(),
        engagementStream: Stream<EngagementInfo?>.multi((_) {}),
      );

      await pumpApp(tester, repository, settle: false);

      expect(find.text('Je me mobilise'), findsNothing);
      expect(find.byType(V5ActivityIndicator), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
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

    expect(
      find.text('Mobilisation temporairement indisponible'),
      findsOneWidget,
    );
    expect(find.text('Je me mobilise'), findsNothing);
  });

  testWidgets('covered profession is disabled in the engagement form', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
    );
    await pumpApp(tester, repository);
    await openEngagementForm(tester);

    final mkTile = tester.widget<RadioListTile<VolunteerProfession>>(
      find.widgetWithText(
        RadioListTile<VolunteerProfession>,
        'Masseur-kinésithérapeute',
      ),
    );
    final ppTile = tester.widget<RadioListTile<VolunteerProfession>>(
      find.widgetWithText(
        RadioListTile<VolunteerProfession>,
        'Pédicure-podologue',
      ),
    );
    expect(mkTile.enabled, isTrue);
    expect(ppTile.enabled, isFalse);
    expect(find.text('Aucun besoin disponible'), findsNWidgets(5));
  });

  testWidgets('all six professions are selectable without iPhone overflow', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialMissions: [sixProfessionMission()],
      initialLocations: const [],
    );
    await pumpApp(tester, repository);
    final missionScroll = find
        .descendant(
          of: find.byType(CustomScrollView).first,
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Je me mobilise'),
      300,
      scrollable: missionScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Je me mobilise'));
    await tester.pumpAndSettle();

    for (final label in [
      'Masseur-kinésithérapeute',
      'Pédicure-podologue',
      'Médecin',
      'Infirmier / Infirmière',
      'Vétérinaire',
      'Autre professionnel de santé',
    ]) {
      expect(
        find.descendant(
          of: find.byType(RadioGroup<VolunteerProfession>),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }

    final expectedEquipment = {
      VolunteerProfession.mk: ProfessionalEquipmentId.massageTable,
      VolunteerProfession.pp: ProfessionalEquipmentId.adaptedSeat,
      VolunteerProfession.doctor: ProfessionalEquipmentId.stethoscope,
      VolunteerProfession.nurse: ProfessionalEquipmentId.dressingEquipment,
      VolunteerProfession.veterinarian:
          ProfessionalEquipmentId.veterinaryExaminationKit,
      VolunteerProfession.otherHealthProfessional:
          ProfessionalEquipmentId.professionSpecificEquipment,
    };
    for (final entry in expectedEquipment.entries) {
      final profession = entry.key;
      final choice = find.byKey(Key('profession-${profession.canonicalId}'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pump();
      expect(
        tester
            .widget<RadioGroup<VolunteerProfession>>(
              find.byType(RadioGroup<VolunteerProfession>),
            )
            .groupValue,
        profession,
      );
      expect(
        find.byKey(Key('equipment-${entry.value}')),
        findsOneWidget,
        reason: '${profession.label} doit afficher son matériel à 390 px',
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('existing profile is summarized then can be edited prefilled', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
      initialProfiles: const {
        'mock-volunteer': VolunteerProfile(
          uid: 'mock-volunteer',
          firstName: 'Alice',
          lastName: 'Martin',
          phone: '0600000000',
          email: 'alice@example.fr',
          rpps: '10123456789',
          cptsId: 'cpts-medoc',
          cptsLabel: 'CPTS Médoc',
          profession: VolunteerProfession.mk,
          equipment: ['Table'],
        ),
      },
    );
    await pumpApp(tester, repository);
    await openEngagementForm(tester);

    expect(find.text('Alice Martin'), findsOneWidget);
    expect(find.text('Masseur-kinésithérapeute'), findsAtLeastNWidgets(1));
    expect(find.text('0600000000'), findsOneWidget);
    expect(find.text('Modifier mes informations'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('CONFIRMER MA PARTICIPATION'), findsOneWidget);

    await tester.tap(find.text('Modifier mes informations'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(6));
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'Prénom'))
          .controller
          ?.text,
      'Alice',
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('professional-id-value')))
          .controller
          ?.text,
      '10123456789',
    );
    expect(find.text('Identifiant CPTS'), findsNothing);
    expect(
      tester
          .widget<TextFormField>(
            find.widgetWithText(TextFormField, 'Nom de la CPTS'),
          )
          .controller
          ?.text,
      'CPTS Médoc',
    );
  });

  testWidgets('professional id, optional CPTS and equipment are modular', (
    tester,
  ) async {
    final repository = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
    );
    await pumpApp(tester, repository);
    await openEngagementForm(tester);

    expect(find.text('Aucun identifiant'), findsOneWidget);
    expect(find.text('Aucune'), findsOneWidget);
    for (final equipment in [
      'Table de massage',
      'Crèmes / huiles de massage',
      'Pistolet de massage',
      'Bottes de pressothérapie',
      'Autre matériel',
    ]) {
      expect(find.text(equipment), findsOneWidget);
    }
    expect(find.byKey(const Key('professional-id-value')), findsNothing);
    expect(find.byKey(const Key('other-equipment-details')), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(
        const Key('equipment-${ProfessionalEquipmentId.otherEquipment}'),
      ),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(
      find.byKey(
        const Key('equipment-${ProfessionalEquipmentId.otherEquipment}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('other-equipment-details')), findsOneWidget);
  });

  testWidgets(
    'profession change preserves incompatible and free historical equipment',
    (tester) async {
      final repository = MockCoordinationRepository(
        initialMissions: [sixProfessionMission()],
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
            profession: VolunteerProfession.mk,
            equipment: ['Table de massage', 'Pistolet de massage', 'Sac libre'],
          ),
        },
      );
      await pumpApp(tester, repository);
      await openEngagementForm(tester);
      await tester.tap(find.text('Compléter mon profil'));
      await tester.pumpAndSettle();

      final doctor = find.byKey(const Key('profession-physician'));
      await tester.ensureVisible(doctor);
      await tester.tap(doctor);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key(
            'equipment-${ProfessionalEquipmentId.bloodPressureMonitor}',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('equipment-${ProfessionalEquipmentId.massageTable}'),
        ),
        findsNothing,
      );
      expect(
        find.byKey(
          const Key('legacy-equipment-${ProfessionalEquipmentId.massageTable}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('legacy-equipment-Sac libre')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('legacy-equipment-Sac libre')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('legacy-equipment-Sac libre')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('legacy-equipment-Sac libre')), findsNothing);

      final mk = find.byKey(const Key('profession-physiotherapist'));
      await tester.ensureVisible(mk);
      await tester.tap(mk);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          const Key('equipment-${ProfessionalEquipmentId.massageTable}'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('legacy-equipment-${ProfessionalEquipmentId.massageTable}'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'profession-specific equipment requests details without iPhone overflow',
    (tester) async {
      final repository = MockCoordinationRepository(
        initialMissions: [sixProfessionMission()],
        initialLocations: const [],
      );
      await pumpApp(tester, repository);
      await openEngagementForm(tester);

      final otherProfession = find.byKey(
        const Key('profession-other_health_professional'),
      );
      await tester.ensureVisible(otherProfession);
      await tester.tap(otherProfession);
      await tester.pumpAndSettle();
      final specificEquipment = find.byKey(
        const Key(
          'equipment-${ProfessionalEquipmentId.professionSpecificEquipment}',
        ),
      );
      await tester.ensureVisible(specificEquipment);
      await tester.tap(specificEquipment);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('other-equipment-details')), findsOneWidget);
      await tester.ensureVisible(find.text('CONFIRMER MA PARTICIPATION'));
      expect(tester.takeException(), isNull);
    },
  );

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
    await openEngagementForm(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'A');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'B');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone'),
      '0600000000',
    );
    await fillRequiredProfessionalFields(tester);
    final submit = find.text('CONFIRMER MA PARTICIPATION');
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
    await openEngagementForm(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Prénom'), 'A');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nom'), 'B');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Téléphone'),
      '0600000000',
    );
    await fillRequiredProfessionalFields(tester);
    final submit = find.text('CONFIRMER MA PARTICIPATION');
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
    expect(find.text('Annuler ce besoin'), findsNothing);
    await selectNavigationTab(tester, 2);
    await tester.scrollUntilVisible(
      find.text('Annuler ce besoin'),
      200,
      scrollable: pageScroll(),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Annuler ce besoin').first);
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
    await selectNavigationTab(tester, 2);
    final menu = find.byKey(const Key('engagement-menu-ui-mission_volunteer'));
    await tester.scrollUntilVisible(menu, 200, scrollable: pageScroll());
    await tester.pumpAndSettle();
    await tester.ensureVisible(menu);
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

  testWidgets('cancellation action is reserved to the mission creator', (
    tester,
  ) async {
    final unauthorized = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
      responsibleAccess: const ResponsibleAccess(
        uid: 'other-manager',
        role: 'site_manager',
        locationIds: {'other-site'},
        active: true,
      ),
    );
    await pumpApp(tester, unauthorized);
    await selectNavigationTab(tester, 1);
    expect(find.byType(MissionCancellationButton), findsNothing);

    final authorized = MockCoordinationRepository(
      initialMissions: [mission()],
      initialLocations: const [],
      responsibleAccess: const ResponsibleAccess(
        uid: 'mock-coordinator',
        role: 'site_manager',
        locationIds: {'site-a'},
        active: true,
      ),
    );
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: authorized,
        useLegacyCoordinatorShellForTesting: true,
      ),
    );
    await tester.pumpAndSettle();
    await selectNavigationTab(tester, 0);
    expect(find.byType(MissionCancellationButton), findsNothing);
    await selectNavigationTab(tester, 1);
    expect(find.byType(MissionCancellationButton), findsWidgets);
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
    String? rpps,
    ProfessionalIdType? professionalIdType,
    String? professionalIdValue,
    String? cptsId,
    String? cptsLabel,
    required VolunteerProfession profession,
    List<String> equipment = const [],
    String? otherEquipmentDetails,
  }) async {
    createCalls++;
    return completion == null ? result : completion!.future;
  }
}
