import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/engagement_confirmation_screen.dart';
import 'package:interface_incendies_gironde/screens/app_shell.dart';
import 'package:interface_incendies_gironde/widgets/brand_mark.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';

void main() {
  Future<void> pumpIPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const FireCoordinationApp(useLegacyCoordinatorShellForTesting: true),
    );
    await tester.pumpAndSettle();
  }

  Future<void> selectNavigationTab(WidgetTester tester, int index) async {
    final navigation = tester.widget<V5BottomBar>(find.byType(V5BottomBar));
    navigation.onDestinationSelected(index);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ready application enters the shell without a fixed splash delay',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const FireCoordinationApp(useLegacyCoordinatorShellForTesting: true),
      );

      expect(find.byType(AppShell), findsOneWidget);
    },
  );

  testWidgets('brand mark uses the optimized interface asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandMark(size: 92))),
    );

    final image = tester
        .widgetList<Image>(find.byType(Image))
        .firstWhere(
          (candidate) =>
              candidate.image is AssetImage &&
              (candidate.image as AssetImage).assetName ==
                  BrandMark.officialAssetPath,
        );
    final provider = image.image as AssetImage;
    expect(provider.assetName, BrandMark.officialAssetPath);
    expect(provider.assetName, isNot(contains('logo_hd.png')));
  });

  testWidgets('missions render immediately without overflow at iPhone width', (
    tester,
  ) async {
    await pumpIPhone(tester);
    expect(find.text('Où aider aujourd’hui ?'), findsOneWidget);
    expect(
      find.text('Une mission prioritaire attend encore des renforts.'),
      findsOneWidget,
    );
    expect(find.text('Mérignac'), findsOneWidget);
    expect(find.text('Je me mobilise'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('engagement confirmation shows mission details', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final location = responsePlaceForNeed(needs.first, places);
    await tester.pumpWidget(
      MaterialApp(
        home: EngagementConfirmationScreen(
          need: needs.first,
          profession: VolunteerProfession.mk,
          location: location,
        ),
      ),
    );

    expect(find.text('Merci !'), findsOneWidget);
    expect(find.text('Votre engagement est confirmé.'), findsOneWidget);
    expect(find.text('Elle est en attente de validation.'), findsNothing);
    expect(find.text(needs.first.place), findsOneWidget);
    expect(find.text(needs.first.date), findsOneWidget);
    expect(find.text(location!.verifiedAddress!), findsOneWidget);
    expect(find.text(needs.first.time), findsOneWidget);
    expect(find.text('Masseur-kinésithérapeute'), findsOneWidget);
    expect(find.text('Retour aux missions'), findsOneWidget);
    expect(find.text('Retour aux interventions'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('engagement confirmation explains missing equipment', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const missionWithoutEquipment = CoordinationNeed(
      id: 'mission-without-equipment',
      place: 'Centre de secours',
      group: TerritorialGroup.medoc,
      date: 'mardi 12 août',
      time: '08:00 — 12:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: [],
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: EngagementConfirmationScreen(
          need: missionWithoutEquipment,
          profession: VolunteerProfession.nurse,
        ),
      ),
    );

    expect(find.text('mardi 12 août'), findsOneWidget);
    expect(
      find.text(VolunteerProfession.nurse.label, skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.text('Aucun matériel demandé', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('engagement form includes enriched professional fields', (
    tester,
  ) async {
    await pumpIPhone(tester);
    await tester.scrollUntilVisible(
      find.text('Je me mobilise'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Je me mobilise').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Je me mobilise').first);
    await tester.pumpAndSettle();

    expect(find.text('Profession'), findsOneWidget);
    expect(find.text('Prénom'), findsOneWidget);
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Email (facultatif)'), findsNothing);
    expect(find.text('Identifiant professionnel *'), findsOneWidget);
    expect(find.text('Aucun identifiant'), findsOneWidget);
    expect(find.text('Numéro RPPS *'), findsNothing);
    expect(find.byKey(const Key('cpts-choice')), findsOneWidget);
    expect(find.text('Aucune'), findsOneWidget);
    expect(find.text('Identifiant CPTS'), findsNothing);
    expect(find.text('Matériel que je peux apporter'), findsOneWidget);
    expect(find.text('Table de massage'), findsOneWidget);
    expect(find.text('Autre matériel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all main screens are reachable without overflow', (
    tester,
  ) async {
    await pumpIPhone(tester);

    final navigation = tester.widget<V5BottomBar>(find.byType(V5BottomBar));
    expect(navigation.destinations, hasLength(4));

    for (final entry in [
      (1, 'Déclarer'),
      (2, 'Statistiques'),
      (3, 'Plus'),
      (0, 'Missions'),
    ]) {
      final (index, label) = entry;
      expect(
        find.descendant(
          of: find.byType(V5BottomBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
      await selectNavigationTab(tester, index);
      expect(
        tester.takeException(),
        isNull,
        reason: '$label must fit at 390 px',
      );
    }

    expect(find.text('Où aider aujourd’hui ?'), findsOneWidget);
  });

  testWidgets('tabs are lazy and shared streams are created only once', (
    tester,
  ) async {
    final repository = _CountingRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FireCoordinationApp(
        repository: repository,
        useLegacyCoordinatorShellForTesting: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(repository.missionFactories, 1);
    expect(repository.locationFactories, 1);
    expect(repository.accessFactories, 1);
    expect(find.text('SITUATION'), findsNothing);
    expect(find.text('URPS MK Nouvelle-Aquitaine'), findsNothing);

    if (find.text('Prioritaires').evaluate().isEmpty) {
      await tester.tap(
        find.byKey(const Key('toggle-advanced-mission-filters')),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Prioritaires'));
    await tester.pumpAndSettle();
    expect(repository.missionFactories, 1);
    expect(
      repository.volunteerEngagementFactories.values.every(
        (count) => count == 1,
      ),
      isTrue,
    );

    await selectNavigationTab(tester, 2);
    expect(find.text('SITUATION'), findsOneWidget);
    expect(repository.missionFactories, 1);
    expect(repository.accessFactories, 1);
    expect(
      repository.missionEngagementFactories.values.every((count) => count == 1),
      isTrue,
    );

    await selectNavigationTab(tester, 3);
    expect(repository.locationFactories, 1);

    await selectNavigationTab(tester, 1);
    expect(repository.locationFactories, 1);
    expect(repository.accessFactories, 1);

    await selectNavigationTab(tester, 0);
    expect(find.text('Parc des Expositions de Bordeaux'), findsNothing);
    expect(repository.missionFactories, 1);
    expect(repository.locationFactories, 1);
    expect(repository.accessFactories, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'invalid V2 access blocks Situation without a permanent spinner',
    (tester) async {
      final repository = _InvalidResponsibleAccessRepository();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        FireCoordinationApp(
          repository: repository,
          useLegacyCoordinatorShellForTesting: true,
        ),
      );
      await tester.pumpAndSettle();
      await selectNavigationTab(tester, 2);

      expect(find.text('Configuration d’accès invalide'), findsOneWidget);
      expect(find.text('SITUATION'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(needs.first.place), findsNothing);
    },
  );

  testWidgets('slot filters update visible cards', (tester) async {
    await pumpIPhone(tester);
    if (find.text('Prioritaires').evaluate().isEmpty) {
      await tester.tap(
        find.byKey(const Key('toggle-advanced-mission-filters')),
      );
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Prioritaires'));
    await tester.pumpAndSettle();

    expect(find.text('Mérignac'), findsOneWidget);
    expect(find.text('Parc des Expositions de Bordeaux'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('places can be filtered by territorial group', (tester) async {
    await pumpIPhone(tester);
    await selectNavigationTab(tester, 3);

    expect(find.text('Lieux'), findsOneWidget);
    expect(find.text('DISPOSITIF TERRITORIAL'), findsOneWidget);
    expect(find.text('Version RC1'), findsNothing);
    await tester.tap(find.byKey(const Key('places-territorial-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Médoc').last);
    await tester.pumpAndSettle();

    expect(find.text('Castelnau-de-Médoc'), findsOneWidget);
    expect(find.text('Bordeaux Bastide'), findsNothing);
    expect(find.text('7 lieux référencés'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slots can be filtered by territorial group', (tester) async {
    await pumpIPhone(tester);
    await tester.tap(find.byKey(const Key('reset-mission-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('slots-territorial-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sites partenaires').last);
    await tester.pumpAndSettle();

    expect(find.text('Parc des Expositions de Bordeaux'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Croix-Rouge Bordeaux'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Croix-Rouge Bordeaux'), findsOneWidget);
    expect(find.text('Mérignac'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _CountingRepository extends MockCoordinationRepository {
  int missionFactories = 0;
  int locationFactories = 0;
  int accessFactories = 0;
  final Map<String, int> volunteerEngagementFactories = {};
  final Map<String, int> missionEngagementFactories = {};

  @override
  Stream<List<CoordinationNeed>> watchMissions() {
    missionFactories++;
    return super.watchMissions();
  }

  @override
  Stream<List<ResponsePlace>> watchLocations() {
    locationFactories++;
    return super.watchLocations();
  }

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() {
    accessFactories++;
    return super.watchResponsibleAccess();
  }

  @override
  Stream<EngagementInfo?> watchMyEngagement(String missionId) {
    volunteerEngagementFactories.update(
      missionId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    return super.watchMyEngagement(missionId);
  }

  @override
  Stream<List<EngagementInfo>> watchMissionEngagements(String missionId) {
    missionEngagementFactories.update(
      missionId,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
    return super.watchMissionEngagements(missionId);
  }
}

class _InvalidResponsibleAccessRepository extends MockCoordinationRepository {
  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() =>
      Stream<ResponsibleAccess?>.error(
        const ResponsibleAccessFormatException(
          ResponsibleAccessFormatError.invalidLocationIds,
          'invalid V2 scope',
        ),
      );
}
