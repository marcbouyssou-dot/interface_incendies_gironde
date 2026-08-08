import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/coordinator/territory_view_data.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/brand_mark.dart';
import 'package:interface_incendies_gironde/widgets/responsible_mission_card.dart';
import 'package:interface_incendies_gironde/widgets/territory_components.dart';

void main() {
  testWidgets('quota steppers expose actions, values and a 44 point target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final center = places.firstWhere(
      (place) => place.isOperational && place.isEnabled,
    );
    final repository = MockCoordinationRepository(
      responsibleAccess: ResponsibleAccess(
        uid: 'a11y-manager',
        role: ResponsibleRole.siteManager,
        locationIds: {center.id},
        active: true,
      ),
      initialLocations: [center],
    );

    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('responsible-create-need')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('nurse-add')));
    await tester.pumpAndSettle();

    final add = find.bySemanticsLabel('Ajouter un infirmier');
    final remove = find.bySemanticsLabel('Retirer un infirmier');
    expect(tester.getSemantics(add).value, '0 infirmiers demandés');
    expect(tester.getSemantics(remove).value, '0 infirmiers demandés');
    expect(
      tester.getSize(find.byKey(const Key('nurse-add'))),
      const Size(44, 44),
    );

    await tester.tap(add);
    await tester.pump();
    expect(tester.getSemantics(add).value, '1 infirmier demandé');
    expect(tester.getSemantics(remove).value, '1 infirmier demandé');
    semantics.dispose();
  });

  testWidgets(
    'need form exposes its global validation error as a live region',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final center = places.firstWhere(
        (place) => place.isOperational && place.isEnabled,
      );
      final repository = MockCoordinationRepository(
        responsibleAccess: ResponsibleAccess(
          uid: 'a11y-manager',
          role: ResponsibleRole.siteManager,
          locationIds: {center.id},
          active: true,
        ),
        initialLocations: [center],
      );

      await tester.pumpWidget(FireCoordinationApp(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('responsible-create-need')));
      await tester.pumpAndSettle();
      await _scrollIntoView(tester, find.byKey(const Key('publish-mission')));
      await tester.tap(find.byKey(const Key('publish-mission')));
      await tester.pumpAndSettle();

      final error = tester.getSemantics(
        find.bySemanticsLabel('Erreur : Choisissez une date.'),
      );
      expect(error.flagsCollection.isLiveRegion, isTrue);
      semantics.dispose();
    },
  );

  testWidgets('responsible and coordinator cards expose summaries and state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final need = needs.first;
    const sector = TerritorySectorViewData(
      group: TerritorialGroup.bordeauxMetropole,
      status: TerritoryOperationalStatus.critical,
      centerCount: 3,
      activeNeeds: 2,
      uncoveredNeeds: 1,
      nextDeadline: 'Demain à 8 heures',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: [
              ResponsibleMissionCard(
                need: need,
                tone: ResponsibleMissionTone.urgent,
                statusLabel: 'Urgent',
              ),
              const SectorStatusCard(sector: sector),
            ],
          ),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp(r'Besoin pour .*État : Urgent')),
      findsOneWidget,
    );
    final progress = tester.getSemantics(
      find.bySemanticsLabel('Progression du besoin'),
    );
    expect(progress.value, contains('poste'));
    expect(
      find.bySemanticsLabel(
        RegExp(r'Secteur Bordeaux Métropole.*État : Critique'),
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('brand mark exposes MobSanté exactly once', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandMark())),
    );

    expect(find.bySemanticsLabel('MobSanté'), findsOneWidget);
    expect(find.bySemanticsLabel('Logo MobSanté'), findsNothing);
    expect(find.bySemanticsLabel('Symbole de mobilisation'), findsNothing);
    final logo = tester.getSemantics(find.bySemanticsLabel('MobSanté'));
    expect(logo.flagsCollection.isImage, isTrue);
    semantics.dispose();
  });
}

Future<void> _scrollIntoView(WidgetTester tester, Finder target) async {
  final form = find.byKey(const PageStorageKey('create'));
  for (var attempt = 0; attempt < 10; attempt++) {
    if (tester.getCenter(target).dy < 800) return;
    await tester.drag(form, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
}
