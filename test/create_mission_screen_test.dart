import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/app_notification.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/profession_quotas.dart';
import 'package:interface_incendies_gironde/models/volunteer_profile.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/services/professional_verification_service.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_admin_invitation_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_location_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_responsible_access_administration_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/utils/french_date_time.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';
import 'package:interface_incendies_gironde/widgets/v5_form_system.dart';

void main() {
  Future<void> pumpForm(
    WidgetTester tester,
    CoordinationRepository repository, {
    CoordinationNeed? mission,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: LiveCoordinationDataScope(
          data: liveData,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SafeArea(child: CreateNeedScreen(mission: mission)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> chooseLocation(WidgetTester tester) async {
    final field = find.byKey(const Key('mission-location'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(places.first.name).last);
    await tester.pumpAndSettle();
  }

  Future<void> chooseDate(WidgetTester tester) async {
    final field = find.byKey(const Key('mission-date'));
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseTime(
    WidgetTester tester,
    Key fieldKey,
    String expected,
  ) async {
    final field = find.byKey(fieldKey);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text(expected), findsOneWidget);
  }

  Future<void> chooseTimeValue(
    WidgetTester tester,
    Key fieldKey,
    int hour,
  ) async {
    final field = find.byKey(fieldKey);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker))
        .onDateTimeChanged(DateTime(2026, 8, 3, hour));
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
  }

  Future<void> incrementQuota(WidgetTester tester, String professionId) async {
    final button = find.byKey(Key('$professionId-add'));
    await tester.scrollUntilVisible(
      button,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
  }

  Future<void> bringIntoTapArea(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 16; attempt++) {
      final centerY = tester.getCenter(finder).dy;
      if (centerY >= 80 && centerY <= 760) return;
      await tester.drag(
        find.byKey(const PageStorageKey('create')),
        Offset(0, centerY < 80 ? 360 : -360),
      );
      await tester.pumpAndSettle();
    }
    fail('Le contrôle reste hors écran : $finder');
  }

  Future<void> selectEquipment(
    WidgetTester tester,
    String professionId,
    String equipmentId,
  ) async {
    final profession = find.byKey(
      Key('mission-equipment-profession-$professionId'),
    );
    await bringIntoTapArea(tester, profession);
    await tester.tap(profession);
    await tester.pumpAndSettle();
    final equipment = find.byKey(Key('mission-equipment-$equipmentId'));
    await bringIntoTapArea(tester, equipment);
    await tester.tap(equipment);
    await tester.pumpAndSettle();
  }

  Future<void> completeRequiredFields(
    WidgetTester tester, {
    bool selectLocation = true,
    bool addQuota = true,
  }) async {
    if (selectLocation) await chooseLocation(tester);
    await chooseDate(tester);
    await chooseTime(tester, const Key('mission-start-time'), '08:00');
    await chooseTime(tester, const Key('mission-end-time'), '12:00');
    if (addQuota) {
      await incrementQuota(tester, 'physiotherapist');
    }
  }

  Future<void> revealReviewButton(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.byKey(const Key('review-mission')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openReview(WidgetTester tester) async {
    await revealReviewButton(tester);
    final button = find.byKey(const Key('review-mission'));
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> publishReviewedNeed(WidgetTester tester) async {
    await openReview(tester);
    final button = find.byKey(const Key('publish-mission'));
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.descendant(
        of: find.byKey(const Key('need-review')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> choosePriority(
    WidgetTester tester,
    NeedPriority priority,
  ) async {
    final field = find.byKey(const Key('mission-priority'));
    await tester.scrollUntilVisible(
      field,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(priority.label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('date and both time pickers open and retain their choices', (
    tester,
  ) async {
    await pumpForm(tester, _MissionRepository());
    await chooseDate(tester);
    final today = DateTime.now();
    expect(find.text(FrenchDateTime.date(today)), findsOneWidget);

    await chooseTime(tester, const Key('mission-start-time'), '08:00');
    await chooseTime(tester, const Key('mission-end-time'), '12:00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('publication refuses a missing location', (tester) async {
    final repository = _MissionRepository();
    await pumpForm(tester, repository);
    await revealReviewButton(tester);
    await tester.tap(find.byKey(const Key('review-mission')));
    await tester.pump();

    expect(find.text('Choisissez un lieu d’intervention.'), findsOneWidget);
    expect(repository.calls, 0);
  });

  testWidgets('publication refuses two zero quotas', (tester) async {
    final repository = _MissionRepository();
    await pumpForm(tester, repository);
    await completeRequiredFields(tester, addQuota: false);
    await revealReviewButton(tester);
    await tester.tap(find.byKey(const Key('review-mission')));
    await tester.pump();

    expect(
      find.text('Indiquez au moins un professionnel nécessaire.'),
      findsOneWidget,
    );
    expect(repository.calls, 0);
  });

  testWidgets('publication refuses an end time before the start time', (
    tester,
  ) async {
    final repository = _MissionRepository();
    await pumpForm(tester, repository);
    await chooseLocation(tester);
    await chooseDate(tester);
    await chooseTimeValue(tester, const Key('mission-start-time'), 12);
    await chooseTimeValue(tester, const Key('mission-end-time'), 8);
    await incrementQuota(tester, 'physiotherapist');
    await revealReviewButton(tester);
    await tester.tap(find.byKey(const Key('review-mission')));
    await tester.pump();

    expect(
      find.text('L’heure de fin doit être postérieure à l’heure de début.'),
      findsOneWidget,
    );
    expect(repository.calls, 0);
  });

  testWidgets(
    'repository is called once and confirmation waits for the write',
    (tester) async {
      final repository = _MissionRepository(pending: true);
      await pumpForm(tester, repository);

      expect(find.text('Exprimer un besoin'), findsOneWidget);
      expect(
        tester
            .widgetList<V5Section>(find.byType(V5Section))
            .map((section) => section.title),
        [
          '1. De quoi avez-vous besoin ?',
          '3. Où ?',
          '4. Quand ?',
          '5. Priorité',
          '6. Matériel à apporter',
          'Matériel disponible sur site',
        ],
      );
      expect(find.text('2. Combien ?'), findsOneWidget);

      await completeRequiredFields(tester);
      await openReview(tester);

      expect(repository.calls, 0);
      expect(find.text('Résumé du besoin'), findsOneWidget);
      expect(find.text('Publier le besoin'), findsOneWidget);
      await tester.tap(find.byKey(const Key('edit-need-from-review')));
      await tester.pumpAndSettle();
      expect(find.text('Exprimer un besoin'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(repository.calls, 0);

      await openReview(tester);
      await tester.tap(find.byKey(const Key('publish-mission')));
      await tester.pump();

      expect(repository.calls, 1);
      expect(repository.lastDraft?.priority, NeedPriority.standard);
      expect(find.text('Publication…'), findsOneWidget);
      expect(find.text('Votre besoin est publié.'), findsNothing);
      final button = tester.widget<V5Button>(
        find.byKey(const Key('publish-mission')),
      );
      expect(button.onPressed, isNull);

      repository.complete();
      await tester.pumpAndSettle();
      expect(find.text('Votre besoin est publié.'), findsOneWidget);
      expect(find.text(places.first.name), findsWidgets);
      expect(find.text('Masseur-kinésithérapeute'), findsOneWidget);
      expect(find.text('En attente de diffusion'), findsOneWidget);
    },
  );

  testWidgets(
    'a new need keeps independent profession quotas through publication',
    (tester) async {
      final repository = _MissionRepository();
      await pumpForm(tester, repository);

      expect(find.text('1. De quoi avez-vous besoin ?'), findsOneWidget);
      expect(find.text('2. Combien ?'), findsOneWidget);
      expect(find.text('Masseur-kinésithérapeute'), findsOneWidget);
      expect(find.text('Pédicure-podologue'), findsOneWidget);
      expect(find.text('Médecin'), findsOneWidget);
      expect(find.text('Infirmier'), findsOneWidget);
      expect(find.text('Vétérinaire'), findsOneWidget);
      expect(find.text('Autre professionnel de santé'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(6));
      expect(
        find.text('Définissez un nombre indépendant pour chaque profession.'),
        findsOneWidget,
      );

      await completeRequiredFields(tester, addQuota: false);
      await incrementQuota(tester, 'physiotherapist');
      await incrementQuota(tester, 'physiotherapist');
      await incrementQuota(tester, 'nurse');
      await incrementQuota(tester, 'physician');

      expect(
        tester.getSemantics(find.byKey(const Key('physiotherapist-add'))).value,
        '2 masseur-kinésithérapeutes demandés',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('nurse-add'))).value,
        '1 infirmier demandé',
      );
      expect(
        tester.getSemantics(find.byKey(const Key('physician-add'))).value,
        '1 médecin demandé',
      );

      await openReview(tester);
      expect(
        find.text('Masseur-kinésithérapeute, Médecin, Infirmier'),
        findsOneWidget,
      );
      expect(find.text('4'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('publish-mission')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('publish-mission')));
      await tester.pumpAndSettle();

      expect(repository.calls, 1);
      expect(repository.lastDraft?.requiredByProfession, {
        'physiotherapist': 2,
        'podiatrist': 0,
        'physician': 1,
        'nurse': 1,
        'veterinarian': 0,
        'other_health_professional': 0,
      });
      expect(find.text('Votre besoin est publié.'), findsOneWidget);
      expect(
        find.text('Masseur-kinésithérapeute, Médecin, Infirmier'),
        findsOneWidget,
      );
      expect(find.text('4'), findsOneWidget);
    },
  );

  testWidgets(
    'adding another profession retains compatible selected equipment',
    (tester) async {
      final repository = _MissionRepository();
      await pumpForm(tester, repository);
      await completeRequiredFields(tester);

      final massageTable = find.byKey(
        const Key('mission-equipment-massage_table'),
      );
      await tester.ensureVisible(massageTable);
      await tester.pumpAndSettle();
      await tester.tap(massageTable);
      await tester.pumpAndSettle();

      final nurseAdd = find.byKey(const Key('nurse-add'));
      await tester.ensureVisible(nurseAdd);
      await tester.pumpAndSettle();
      await tester.tap(nurseAdd);
      await tester.pump();
      await publishReviewedNeed(tester);

      expect(repository.lastDraft?.requiredByProfession['physiotherapist'], 1);
      expect(repository.lastDraft?.requiredByProfession['nurse'], 1);
      expect(repository.lastDraft?.equipment, contains('Table de massage'));
    },
  );

  testWidgets(
    'MK, nurse, and physician equipment survive switching and publication',
    (tester) async {
      final repository = _MissionRepository();
      await pumpForm(tester, repository);
      await completeRequiredFields(tester, addQuota: false);
      await incrementQuota(tester, 'physiotherapist');
      await incrementQuota(tester, 'physiotherapist');
      await incrementQuota(tester, 'nurse');
      await incrementQuota(tester, 'physician');

      await selectEquipment(tester, 'physiotherapist', 'massage_table');
      await selectEquipment(tester, 'nurse', 'dressing_equipment');
      await selectEquipment(tester, 'physician', 'stethoscope');
      final mkTab = find.byKey(
        const Key('mission-equipment-profession-physiotherapist'),
      );
      await bringIntoTapArea(tester, mkTab);
      await tester.tap(mkTab);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<V5ChoiceChip>(
              find.byKey(const Key('mission-equipment-massage_table')),
            )
            .selected,
        isTrue,
      );

      await openReview(tester);
      expect(find.text('Matériel à apporter'), findsOneWidget);
      for (final label in [
        '• Table de massage',
        '• Stéthoscope',
        '• Matériel de pansement',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final publish = find.byKey(const Key('publish-mission'));
      await tester.scrollUntilVisible(
        publish,
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('need-review')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(publish);
      await tester.pumpAndSettle();

      expect(repository.lastDraft?.requiredByProfession['physiotherapist'], 2);
      expect(repository.lastDraft?.requiredByProfession['nurse'], 1);
      expect(repository.lastDraft?.requiredByProfession['physician'], 1);
      expect(repository.lastDraft?.equipmentByProfession, {
        'physiotherapist': ['massage_table'],
        'physician': ['stethoscope'],
        'nurse': ['dressing_equipment'],
      });
      expect(repository.lastDraft?.equipment, [
        'Table de massage',
        'Stéthoscope',
        'Matériel de pansement',
      ]);
      expect(find.text('Votre besoin est publié.'), findsOneWidget);
    },
  );

  testWidgets('zeroing nurse quota removes only nurse equipment', (
    tester,
  ) async {
    final repository = _MissionRepository();
    await pumpForm(tester, repository);
    await completeRequiredFields(tester, addQuota: false);
    await incrementQuota(tester, 'physiotherapist');
    await incrementQuota(tester, 'nurse');
    await selectEquipment(tester, 'physiotherapist', 'massage_table');
    await selectEquipment(tester, 'nurse', 'dressing_equipment');
    final remove = find.byKey(const Key('nurse-remove'));
    await bringIntoTapArea(tester, remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await publishReviewedNeed(tester);
    expect(repository.lastDraft?.equipmentByProfession, {
      'physiotherapist': ['massage_table'],
    });
    expect(repository.lastDraft?.equipment, ['Table de massage']);
  });

  testWidgets(
    'form and review distinguish site inventory from equipment to bring',
    (tester) async {
      final original = places.first;
      final location = ResponsePlace(
        id: original.id,
        name: original.name,
        type: original.type,
        group: original.group,
        activeNeeds: original.activeNeeds,
        availableEquipment: const ['stethoscope'],
      );
      await pumpForm(tester, _MissionRepository(locations: [location]));
      await completeRequiredFields(tester);
      final siteItem = find.text('• Stéthoscope');
      await tester.scrollUntilVisible(
        siteItem,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('6. Matériel à apporter'), findsOneWidget);
      expect(find.text('Matériel disponible sur site'), findsOneWidget);
      await openReview(tester);
      expect(find.text('Matériel disponible sur site'), findsOneWidget);
      expect(find.text('• Stéthoscope'), findsOneWidget);
    },
  );

  testWidgets(
    'confirmation displays saved site snapshot after an inventory change',
    (tester) async {
      final original = places.first;
      final location = ResponsePlace(
        id: original.id,
        name: original.name,
        type: original.type,
        group: original.group,
        activeNeeds: original.activeNeeds,
        availableEquipment: const ['stethoscope'],
      );
      final repository = _ConcurrentSiteChangeRepository(location);
      await pumpForm(tester, repository);
      await completeRequiredFields(tester, selectLocation: false);
      await openReview(tester);
      expect(find.text('• Stéthoscope'), findsOneWidget);
      final publish = find.byKey(const Key('publish-mission'));
      await tester.scrollUntilVisible(
        publish,
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('need-review')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(publish);
      await tester.pumpAndSettle();
      expect(repository.createCalls, 1);
      expect(repository.lastDraft?.location.availableEquipment, [
        'stethoscope',
      ]);
      expect(repository.savedMission?.availableEquipmentOnSite, [
        'massage_table',
      ]);
      expect(find.text('Votre besoin est publié.'), findsOneWidget);
      expect(find.text('• Table de massage'), findsOneWidget);
      expect(find.text('• Stéthoscope'), findsNothing);
    },
  );

  testWidgets('publication persists the selected priority', (tester) async {
    final repository = _MissionRepository();
    await pumpForm(tester, repository);

    expect(find.text(NeedPriority.standard.label), findsOneWidget);
    await choosePriority(tester, NeedPriority.urgent);
    await completeRequiredFields(tester);
    await publishReviewedNeed(tester);

    expect(repository.calls, 1);
    expect(repository.lastDraft?.priority, NeedPriority.urgent);
    expect(find.text(NeedPriority.urgent.label), findsOneWidget);
  });

  testWidgets('repository errors remain on the form and are explicit', (
    tester,
  ) async {
    final repository = _MissionRepository(error: true);
    await pumpForm(tester, repository);
    await completeRequiredFields(tester);
    await publishReviewedNeed(tester);

    expect(
      find.text('La mission n’a pas pu être publiée. Réessayez.'),
      findsOneWidget,
    );
    expect(find.text('Votre besoin est publié.'), findsNothing);
    expect(repository.calls, 1);
  });

  testWidgets('site manager sees the prefilled location without a selector', (
    tester,
  ) async {
    final merignac = places.singleWhere(
      (location) => location.name == 'Mérignac',
    );
    final repository = _MissionRepository(
      access: ResponsibleAccess(
        uid: 'manager-merignac',
        role: 'site_manager',
        locationIds: {merignac.id},
        active: true,
      ),
      locations: [merignac, places.first],
    );
    await pumpForm(tester, repository);

    expect(find.text('Exprimer un besoin'), findsOneWidget);
    expect(find.byKey(const Key('mission-location-locked')), findsOneWidget);
    expect(find.byKey(const Key('mission-location')), findsNothing);
    expect(find.text('Mérignac'), findsWidgets);
    expect(find.text(places.first.name), findsNothing);

    await completeRequiredFields(tester, selectLocation: false);
    await publishReviewedNeed(tester);

    expect(repository.calls, 1);
    expect(repository.lastDraft?.location.id, merignac.id);
  });

  testWidgets('coordinator can select any location', (tester) async {
    final repository = _MissionRepository(
      locations: [
        places.singleWhere((place) => place.name == 'Bordeaux Benauge'),
        places.singleWhere((place) => place.name == 'Bordeaux Bastide'),
      ],
    );
    await pumpForm(tester, repository);

    expect(find.byKey(const Key('mission-location')), findsOneWidget);
    expect(find.byKey(const Key('mission-location-locked')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('mission-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('mission-location')));
    await tester.pumpAndSettle();
    expect(find.text('Bordeaux Bastide'), findsOneWidget);
    expect(find.text('Bordeaux Benauge'), findsNothing);
  });

  testWidgets('invalid V2 access blocks the mission form explicitly', (
    tester,
  ) async {
    final repository = _MissionRepository(
      accessError: const ResponsibleAccessFormatException(
        ResponsibleAccessFormatError.invalidLocationIds,
        'invalid V2 scope',
      ),
    );

    await pumpForm(tester, repository);

    expect(find.text('Configuration d’accès invalide'), findsOneWidget);
    expect(find.byKey(const Key('publish-mission')), findsNothing);
    expect(find.byKey(const Key('mission-location')), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('cumulative coordinator retains the global location selector', (
    tester,
  ) async {
    final operational = places
        .where((location) => location.isOperational)
        .take(2)
        .toList(growable: false);
    final repository = _MissionRepository(
      access: ResponsibleAccess.v2(
        uid: 'cumulative',
        roles: const ['coordinator', 'site_manager'],
        locationIds: {operational.first.id},
        active: true,
      ),
      locations: operational,
    );
    await pumpForm(tester, repository);

    expect(find.byKey(const Key('mission-location')), findsOneWidget);
    expect(find.byKey(const Key('mission-location-locked')), findsNothing);
    final selector = tester.widget<V5SelectField<String>>(
      find.byKey(const Key('mission-location')),
    );
    expect(selector.options.map((item) => item.value), [
      operational[0].id,
      operational[1].id,
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'multi-site manager selector contains only authorized locations',
    (tester) async {
      final operational = places
          .where((location) => location.isOperational)
          .take(3)
          .toList(growable: false);
      final allowed = operational.take(2).toList(growable: false);
      final denied = operational[2];
      final repository = _MissionRepository(
        access: ResponsibleAccess.v2(
          uid: 'multi-manager',
          roles: const ['site_manager'],
          locationIds: allowed.map((location) => location.id).toSet(),
          active: true,
        ),
        locations: [...allowed, denied],
      );
      await pumpForm(tester, repository);

      expect(find.byKey(const Key('mission-location')), findsOneWidget);
      expect(find.byKey(const Key('mission-location-locked')), findsNothing);
      final selector = tester.widget<V5SelectField<String>>(
        find.byKey(const Key('mission-location')),
      );
      expect(selector.options.map((item) => item.value), [
        allowed[0].id,
        allowed[1].id,
      ]);
      expect(selector.options.any((item) => item.value == denied.id), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  test('an earlier or equal end time is invalid', () {
    for (final endMinutes in [2 * 60, 22 * 60]) {
      expect(
        () => MissionSchedule.fromLocal(
          date: DateTime(2026, 7, 30),
          startMinutes: 22 * 60,
          endMinutes: endMinutes,
        ),
        throwsA(isA<FormatException>()),
      );
    }
  });

  testWidgets('edit mode pre-fills the mission and updates it once', (
    tester,
  ) async {
    final location = places.first;
    final start = DateTime.now().add(const Duration(days: 1));
    final mission = CoordinationNeed(
      id: 'mission-to-edit',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: '03/08/2026',
      time: '08:00 — 12:00',
      startAt: DateTime(start.year, start.month, start.day, 8),
      endAt: DateTime(start.year, start.month, start.day, 12),
      requiredPhysiotherapists: 2,
      registeredPhysiotherapists: 1,
      requiredPodiatrists: 1,
      registeredPodiatrists: 0,
      equipment: const ['Tables', 'Huiles'],
      details: 'Consigne initiale',
      priority: NeedPriority.crisis,
      createdBy: 'another-manager',
    );
    final repository = _MissionRepository(locations: [location]);
    await pumpForm(tester, repository, mission: mission);

    expect(find.text('Modifier la mission'), findsOneWidget);
    expect(find.text('Enregistrer les modifications'), findsOneWidget);
    expect(find.text(location.name), findsWidgets);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Consigne initiale'), findsOneWidget);
    expect(find.text(NeedPriority.crisis.label), findsOneWidget);
    expect(find.byKey(const Key('publish-mission')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();

    expect(repository.updateCalls, 1);
    expect(repository.calls, 0);
    expect(repository.updatedMissionId, mission.id);
    expect(repository.lastDraft?.location.id, location.id);
    expect(repository.lastDraft?.requiredPhysiotherapists, 2);
    expect(repository.lastDraft?.priority, NeedPriority.crisis);
    expect(repository.lastDraft?.equipment, ['Tables', 'Huiles']);
    expect(repository.lastDraft?.equipmentByProfession, isNull);
    expect(find.text('Mission mise à jour.'), findsOneWidget);
  });

  testWidgets('editing a contextual mission retains equipment groups', (
    tester,
  ) async {
    final location = places.first;
    final start = DateTime.now().add(const Duration(days: 2));
    final mission = CoordinationNeed(
      id: 'contextual-mission-to-edit',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: 'À venir',
      time: '08:00 — 12:00',
      startAt: DateTime(start.year, start.month, start.day, 8),
      endAt: DateTime(start.year, start.month, start.day, 12),
      requiredPhysiotherapists: 2,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      professionQuotas: ProfessionQuotas.fromMaps(
        requiredByProfession: const {
          'physiotherapist': 2,
          'nurse': 1,
          'physician': 1,
        },
        registeredByProfession: const {},
      ),
      equipment: const [
        'Table de massage',
        'Stéthoscope',
        'Matériel de pansement',
      ],
      equipmentByProfession: const {
        'physiotherapist': ['massage_table'],
        'physician': ['stethoscope'],
        'nurse': ['dressing_equipment'],
      },
    );
    final repository = _MissionRepository(locations: [location]);
    await pumpForm(tester, repository, mission: mission);
    final mkTab = find.byKey(
      const Key('mission-equipment-profession-physiotherapist'),
    );
    await tester.ensureVisible(mkTab);
    await tester.tap(mkTab);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<V5ChoiceChip>(
            find.byKey(const Key('mission-equipment-massage_table')),
          )
          .selected,
      isTrue,
    );
    final update = find.byKey(const Key('update-mission'));
    await tester.ensureVisible(update);
    await tester.pumpAndSettle();
    await tester.tap(update);
    await tester.pumpAndSettle();
    expect(repository.updateCalls, 1);
    expect(
      repository.lastDraft?.equipmentByProfession,
      mission.equipmentByProfession,
    );
    expect(repository.lastDraft?.equipment, mission.equipment);
  });

  testWidgets('return from edit mode closes the form without writing', (
    tester,
  ) async {
    final location = places.first;
    final start = DateTime.now().add(const Duration(days: 1));
    final mission = CoordinationNeed(
      id: 'mission-cancel-edit',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: '03/08/2026',
      time: '08:00 — 12:00',
      startAt: DateTime(start.year, start.month, start.day, 8),
      endAt: DateTime(start.year, start.month, start.day, 12),
      requiredPhysiotherapists: 2,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 1,
      registeredPodiatrists: 0,
      equipment: const ['Tables', 'Huiles'],
      details: 'Consigne conservée',
    );
    final repository = _MissionRepository(locations: [location]);
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: MaterialApp(
          home: LiveCoordinationDataScope(
            data: liveData,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => openMissionEditor(context, mission),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();

    expect(find.text('Modifier la mission'), findsOneWidget);
    expect(find.text(location.name), findsWidgets);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('12:00'), findsOneWidget);
    expect(find.text('Consigne conservée'), findsOneWidget);
    expect(repository.updateCalls, 0);
    expect(repository.calls, 0);

    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();

    expect(find.text('Ouvrir'), findsOneWidget);
    expect(find.text('Modifier la mission'), findsNothing);
    expect(repository.updateCalls, 0);
    expect(repository.calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit mode refuses a quota below registered counters', (
    tester,
  ) async {
    final location = places.first;
    final start = DateTime.now().add(const Duration(days: 1));
    final mission = CoordinationNeed(
      id: 'mission-with-engagements',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: '03/08/2026',
      time: '08:00 — 12:00',
      startAt: DateTime(start.year, start.month, start.day, 8),
      endAt: DateTime(start.year, start.month, start.day, 12),
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 1,
      requiredPodiatrists: 1,
      registeredPodiatrists: 0,
      equipment: const [],
    );
    final repository = _MissionRepository(locations: [location]);
    await pumpForm(tester, repository, mission: mission);
    await tester.scrollUntilVisible(
      find.byKey(const Key('physiotherapist-remove')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.byKey(const Key('physiotherapist-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('physiotherapist-remove')));
    await tester.ensureVisible(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update-mission')));
    await tester.pump();

    expect(
      find.text(
        'Le besoin ne peut pas être inférieur aux engagements confirmés.',
      ),
      findsOneWidget,
    );
    expect(repository.updateCalls, 0);
  });

  testWidgets('edit mode exposes the exact outside-scope error', (
    tester,
  ) async {
    final location = places.first;
    final start = DateTime.now().add(const Duration(days: 1));
    final mission = CoordinationNeed(
      id: 'mission-outside-scope',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: '03/08/2026',
      time: '08:00 — 12:00',
      startAt: DateTime(start.year, start.month, start.day, 8),
      endAt: DateTime(start.year, start.month, start.day, 12),
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const [],
    );
    final repository = _MissionRepository(
      locations: [location],
      updateError: const RepositoryException(
        'Vous ne pouvez modifier que les missions de vos centres.',
      ),
    );
    await pumpForm(tester, repository, mission: mission);
    await tester.ensureVisible(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('update-mission')));
    await tester.pumpAndSettle();

    expect(
      find.text('Vous ne pouvez modifier que les missions de vos centres.'),
      findsOneWidget,
    );
  });
}

class _MissionRepository implements CoordinationRepository {
  _MissionRepository({
    this.pending = false,
    this.error = false,
    this.updateError,
    this.accessError,
    this.access = _coordinatorAccess,
    List<ResponsePlace>? locations,
  }) : locations = locations ?? [places.first];

  final bool pending;
  final bool error;
  final Object? accessError;
  final RepositoryException? updateError;
  final ResponsibleAccess access;
  final List<ResponsePlace> locations;
  final Completer<String> _completer = Completer<String>();

  @override
  Future<CoordinationNeed?> getMission(String missionId) async => null;

  @override
  Future<void> updateSiteEquipment(
    String locationId,
    List<String> equipmentIds,
  ) async {}

  @override
  Stream<List<AppNotification>> watchNotifications() => Stream.value(const []);

  @override
  Future<void> setNotificationRead(
    String notificationId, {
    required bool read,
  }) async {}

  @override
  Stream<NotificationPreferences> watchNotificationPreferences() =>
      Stream.value(const NotificationPreferences());

  @override
  Future<void> saveNotificationPreferences(
    NotificationPreferences preferences,
  ) async {}

  @override
  Future<void> registerPushSubscription(
    PushSubscriptionRegistration registration,
  ) async {}

  @override
  Future<void> disablePushSubscription(String installationId) async {}
  int calls = 0;
  int updateCalls = 0;
  String? updatedMissionId;
  MissionDraft? lastDraft;
  @override
  final adminInvitationRepository = MockAdminInvitationRepository();
  @override
  final locationAdministrationRepository =
      MockLocationAdministrationRepository();
  @override
  final responsibleAccessAdministrationRepository =
      MockResponsibleAccessAdministrationRepository();

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) =>
      Stream.value(null);

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) =>
      Stream.value(const []);

  @override
  Future<void> updateEngagementStatus({
    required String missionId,
    required String volunteerId,
    required EngagementStatus status,
  }) async {}

  @override
  Future<void> cancelEngagement(String missionId) async {}

  @override
  Future<void> cancelMission(String missionId, String? reason) async {}

  @override
  Future<void> updateMission(String missionId, MissionDraft draft) async {
    updateCalls++;
    updatedMissionId = missionId;
    lastDraft = draft;
    if (updateError != null) throw updateError!;
  }

  @override
  Future<VolunteerProfile?> getVolunteerProfile() async => null;

  @override
  Future<void> saveVolunteerProfile(VolunteerProfile profile) async {}

  @override
  Future<VolunteerProfile> confirmProfessionalRpps(
    ProfessionalVerificationResult verification,
  ) => throw UnimplementedError();

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() =>
      accessError == null ? Stream.value(access) : Stream.error(accessError!);

  @override
  Future<ResponsibleAccess> signInResponsible({
    required String email,
    required String password,
  }) async => access;

  static const _coordinatorAccess = ResponsibleAccess(
    uid: 'test-manager',
    role: 'coordinator',
    locationIds: {'*'},
    active: true,
  );

  @override
  Future<void> signOutResponsible() async {}

  void complete() {
    if (!_completer.isCompleted) _completer.complete('created-mission');
  }

  @override
  Future<String> createMission(MissionDraft draft) {
    calls++;
    lastDraft = draft;
    if (error) return Future.error(StateError('write failed'));
    if (pending) return _completer.future;
    return Future.value('created-mission');
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() => Stream.value(locations);

  @override
  Stream<List<CoordinationNeed>> watchMissions() =>
      const Stream<List<CoordinationNeed>>.empty();

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
  }) async => EngagementCreationResult.created;
}

class _ConcurrentSiteChangeRepository extends MockCoordinationRepository {
  _ConcurrentSiteChangeRepository(ResponsePlace location)
    : super(
        initialMissions: const [],
        initialLocations: [location],
        responsibleAccess: ResponsibleAccess(
          uid: 'site-manager-snapshot',
          role: ResponsibleRole.siteManager,
          locationIds: {location.id},
          active: true,
        ),
      );

  int createCalls = 0;
  MissionDraft? lastDraft;
  CoordinationNeed? savedMission;

  @override
  Future<String> createMission(MissionDraft draft) async {
    createCalls++;
    lastDraft = draft;
    await updateSiteEquipment(draft.location.id, const ['massage_table']);
    final id = await super.createMission(draft);
    savedMission = await getMission(id);
    return id;
  }
}
