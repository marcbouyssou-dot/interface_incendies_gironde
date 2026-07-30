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

void main() {
  Future<void> pumpIPhone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ready application enters the shell without a fixed splash delay',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const FireCoordinationApp());

      expect(find.byType(AppShell), findsOneWidget);
    },
  );

  testWidgets('brand mark uses the optimized interface asset', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandMark(size: 92))),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image as AssetImage;
    expect(provider.assetName, BrandMark.officialAssetPath);
    expect(provider.assetName, isNot(contains('logo_hd.png')));
  });

  testWidgets('missions render immediately without overflow at iPhone width', (
    tester,
  ) async {
    await pumpIPhone(tester);
    expect(find.text('MobSanté'), findsOneWidget);
    expect(find.text('Incendies Gironde'), findsOneWidget);
    expect(find.text('64 % de couverture'), findsOneWidget);
    expect(find.text('MÉRIGNAC'), findsOneWidget);
    expect(find.text('❤️ JE M’ENGAGE'), findsOneWidget);
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
          location: location,
        ),
      ),
    );

    expect(find.text('Merci !'), findsOneWidget);
    expect(find.text('Votre engagement est confirmé.'), findsOneWidget);
    expect(find.text('Elle est en attente de validation.'), findsNothing);
    expect(find.text(needs.first.place), findsOneWidget);
    expect(find.text(location!.verifiedAddress!), findsOneWidget);
    expect(find.text(needs.first.time), findsOneWidget);
    expect(find.text('Retour aux interventions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('engagement form includes enriched professional fields', (
    tester,
  ) async {
    await pumpIPhone(tester);
    await tester.scrollUntilVisible(
      find.text('❤️ JE M’ENGAGE'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('❤️ JE M’ENGAGE').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('❤️ JE M’ENGAGE').first);
    await tester.pumpAndSettle();

    expect(find.text('Profession'), findsOneWidget);
    expect(find.text('Prénom'), findsOneWidget);
    expect(find.text('Nom'), findsOneWidget);
    expect(find.text('Téléphone'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Email (facultatif)'), findsNothing);
    expect(find.text('Identifiant professionnel'), findsOneWidget);
    expect(find.text('Aucun identifiant'), findsOneWidget);
    expect(find.text('Numéro RPPS'), findsNothing);
    expect(find.text('CPTS'), findsOneWidget);
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

    for (final label in ['Déclarer', 'Situation', 'Plus', 'Missions']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$label must fit at 390 px',
      );
    }

    expect(find.text('MobSanté'), findsOneWidget);
  });

  testWidgets('tabs are lazy and shared streams are created only once', (
    tester,
  ) async {
    final repository = _CountingRepository();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();

    expect(repository.missionFactories, 1);
    expect(repository.locationFactories, 1);
    expect(repository.accessFactories, 0);
    expect(find.text('SITUATION'), findsNothing);
    expect(find.text('URPS MK Nouvelle-Aquitaine'), findsNothing);

    await tester.tap(find.text('Critiques'));
    await tester.pumpAndSettle();
    expect(repository.missionFactories, 1);
    expect(
      repository.volunteerEngagementFactories.values.every(
        (count) => count == 1,
      ),
      isTrue,
    );

    await tester.tap(find.text('Situation').last);
    await tester.pumpAndSettle();
    expect(find.text('SITUATION'), findsOneWidget);
    expect(repository.missionFactories, 1);
    expect(repository.accessFactories, 1);
    expect(
      repository.missionEngagementFactories.values.every((count) => count == 1),
      isTrue,
    );

    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();
    expect(repository.locationFactories, 1);

    await tester.tap(find.text('Déclarer').last);
    await tester.pumpAndSettle();
    expect(repository.locationFactories, 1);
    expect(repository.accessFactories, 1);

    await tester.tap(find.text('Missions').last);
    await tester.pumpAndSettle();
    expect(find.text('PARC DES EXPOSITIONS DE BORDEAUX'), findsNothing);
    expect(repository.missionFactories, 1);
    expect(repository.locationFactories, 1);
    expect(repository.accessFactories, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('slot filters update visible cards', (tester) async {
    await pumpIPhone(tester);
    await tester.tap(find.text('Critiques'));
    await tester.pumpAndSettle();

    expect(find.text('MÉRIGNAC'), findsOneWidget);
    expect(find.text('PARC DES EXPOSITIONS DE BORDEAUX'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('places can be filtered by territorial group', (tester) async {
    await pumpIPhone(tester);
    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();

    expect(find.text('URPS MK Nouvelle-Aquitaine'), findsOneWidget);
    expect(find.text('Version RC1'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('slots-territorial-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sites partenaires').last);
    await tester.pumpAndSettle();

    expect(find.text('PARC DES EXPOSITIONS DE BORDEAUX'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('CROIX-ROUGE BORDEAUX'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CROIX-ROUGE BORDEAUX'), findsOneWidget);
    expect(find.text('MÉRIGNAC'), findsNothing);
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
