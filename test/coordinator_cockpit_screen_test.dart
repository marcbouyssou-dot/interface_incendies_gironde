import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/screens/coordinator_cockpit_screen.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/screens/location_detail_screen.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';

void main() {
  testWidgets('cockpit is the coordinator home and keeps its V1 scope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorCockpitScreen), findsOneWidget);
    expect(find.text('Situation critique'), findsOneWidget);
    expect(find.text('Gironde'), findsOneWidget);
    expect(find.byKey(const Key('cockpit-refreshed-at')), findsOneWidget);
    expect(find.byKey(const Key('cockpit-operational-map')), findsOneWidget);
    expect(find.byKey(const Key('cockpit-map-counters')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('cockpit-map-counters'))).label,
      matches(RegExp(r'\d+ établissements, 6 missions, 4 tensions')),
    );
    expect(find.text('3 actions prioritaires'), findsOneWidget);
    expect(find.text('Voir la mission'), findsNWidgets(3));
    await _scrollCockpitUntil(tester, find.text('Résumé opérationnel'));
    expect(find.text('Résumé opérationnel'), findsOneWidget);
    expect(find.text('missions couvertes'), findsOneWidget);
    expect(find.text('mission critique'), findsOneWidget);
    expect(find.text('profession la plus tendue'), findsOneWidget);
    await _scrollCockpitUntil(tester, find.text('Actions rapides'));
    expect(find.text('Actions rapides'), findsOneWidget);
    expect(find.text('Traiter la priorité'), findsOneWidget);
    expect(find.text('Créer un besoin'), findsOneWidget);
    expect(find.text('Historique'), findsNothing);
    expect(find.text('Recommandations'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a mission center opens its card then its situation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('cockpit-map-location-bordeauxMetropole-mérignac')),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('cockpit-map-selection-card')), findsOneWidget);
    expect(
      find.byKey(const Key('cockpit-map-selected-location-name')),
      findsOneWidget,
    );
    expect(find.textContaining('mission active'), findsOneWidget);
    expect(find.textContaining('de couverture'), findsOneWidget);
    expect(find.textContaining('Prochaine échéance'), findsOneWidget);
    expect(find.textContaining('Profession en tension'), findsOneWidget);
    expect(find.text('Voir la situation'), findsOneWidget);
    expect(find.byType(CreateNeedScreen), findsNothing);

    await tester.tap(find.byKey(const Key('cockpit-map-view-location')));
    await tester.pumpAndSettle();

    expect(find.byType(LocationDetailScreen), findsOneWidget);
    expect(find.byKey(const Key('location-detail-screen')), findsOneWidget);
  });

  testWidgets('a center without a mission exposes only its existing detail', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final location = places.firstWhere(
      (candidate) => candidate.name == 'Mérignac',
    );
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          initialMissions: const [],
          initialLocations: [location],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.bySemanticsLabel(
        RegExp(r'Centre de Mérignac, aucune mission active'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('cockpit-map-selected-location-name')),
          )
          .data,
      'Mérignac',
    );
    expect(find.text('Aucune mission active'), findsOneWidget);
    expect(find.text('Voir le centre'), findsOneWidget);
    expect(find.text('Voir la situation'), findsNothing);
    expect(find.textContaining('de couverture'), findsNothing);

    await tester.tap(find.byKey(const Key('cockpit-map-view-location')));
    await tester.pumpAndSettle();

    expect(find.byType(LocationDetailScreen), findsOneWidget);
    expect(find.text('Aucun besoin en cours pour ce lieu.'), findsOneWidget);
  });

  testWidgets('map supports bounded pinch, pan and animated recentering', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    final viewerFinder = find.byKey(
      const Key('cockpit-map-interactive-viewer'),
    );
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(viewer.minScale, 1);
    expect(viewer.maxScale, 3);
    expect(viewer.boundaryMargin, EdgeInsets.zero);
    expect(viewer.constrained, isTrue);
    expect(viewer.panEnabled, isTrue);
    expect(viewer.scaleEnabled, isTrue);
    expect(viewer.trackpadScrollCausesScale, isTrue);

    await _pinchMap(tester, viewerFinder);
    await tester.pumpAndSettle();
    final zoomed = tester.widget<InteractiveViewer>(viewerFinder);
    final zoomedScale = zoomed.transformationController!.value
        .getMaxScaleOnAxis();
    expect(zoomedScale, greaterThan(1));
    expect(zoomedScale, lessThanOrEqualTo(3));

    final beforePan = zoomed.transformationController!.value.getTranslation();
    await tester.drag(viewerFinder, const Offset(64, 30));
    await tester.pumpAndSettle();
    final afterPan = zoomed.transformationController!.value.getTranslation();
    expect(afterPan.x != beforePan.x || afterPan.y != beforePan.y, isTrue);

    await tester.tap(find.byKey(const Key('cockpit-map-recenter')));
    await tester.pumpAndSettle();
    final recentered = zoomed.transformationController!.value;
    expect(recentered.getMaxScaleOnAxis(), closeTo(1, 0.001));
    expect(recentered.getTranslation().x, closeTo(0, 0.001));
    expect(recentered.getTranslation().y, closeTo(0, 0.001));
  });

  testWidgets('covered territory states that no action is urgent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          initialMissions: const [],
          initialLocations: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Situation maîtrisée'), findsOneWidget);
    expect(find.text('Aucune action urgente'), findsOneWidget);
    expect(
      find.text('Le territoire est actuellement couvert.'),
      findsOneWidget,
    );
    await _scrollCockpitUntil(tester, find.text('Traiter la priorité'));
    expect(find.text('Aucune tension'), findsOneWidget);
    expect(find.text('Traiter la priorité'), findsOneWidget);
    final action = tester.widget<V5Button>(
      find.byKey(const Key('cockpit-view-mission')),
    );
    expect(action.onPressed, isNull);
  });

  testWidgets('priority action opens the selected existing mission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('cockpit-priority-0-view')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cockpit-priority-0-view')));
    await tester.pumpAndSettle();

    expect(find.byType(CreateNeedScreen), findsOneWidget);
    expect(find.text('Modifier la mission'), findsOneWidget);
  });

  testWidgets('cockpit keeps a focused operational width on large screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    final mapSize = tester.getSize(
      find.byKey(const Key('cockpit-operational-map')),
    );
    expect(mapSize.width, lessThanOrEqualTo(760));
    expect(mapSize.height, 320);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cockpit supports compact dynamic type, dark mode and VoiceOver',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
      });

      await tester.pumpWidget(const FireCoordinationApp());
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'Situation critique.*Gironde')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'Carte opérationnelle de Gironde')),
        findsOneWidget,
      );
      expect(
        tester.element(find.byType(CoordinatorCockpitScreen)).v5Colors,
        V5Colors.dark,
      );
      expect(
        find.bySemanticsLabel(
          RegExp(r'Centre de Mérignac, 1 mission active, 1 tension critique'),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Recentrer la carte'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('cockpit remains immediate when motion is reduced', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: FireCoordinationApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CoordinatorCockpitScreen), findsOneWidget);
    final viewerFinder = find.byKey(
      const Key('cockpit-map-interactive-viewer'),
    );
    await _pinchMap(tester, viewerFinder);
    final viewer = tester.widget<InteractiveViewer>(viewerFinder);
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );
    await tester.tap(find.byKey(const Key('cockpit-map-recenter')));
    await tester.pump();
    expect(
      viewer.transformationController!.value.getMaxScaleOnAxis(),
      closeTo(1, 0.001),
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pinchMap(WidgetTester tester, Finder viewer) async {
  final center = tester.getCenter(viewer);
  final first = await tester.startGesture(
    center + const Offset(-24, 0),
    pointer: 1,
  );
  final second = await tester.startGesture(
    center + const Offset(24, 0),
    pointer: 2,
  );
  await first.moveTo(center + const Offset(-74, 0));
  await second.moveTo(center + const Offset(74, 0));
  await tester.pump();
  await first.up();
  await second.up();
  await tester.pump();
}

Future<void> _scrollCockpitUntil(WidgetTester tester, Finder target) async {
  final scrollable = find.byKey(const PageStorageKey('coordinator-cockpit'));
  for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}
