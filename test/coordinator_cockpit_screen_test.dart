import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/screens/coordinator_cockpit_screen.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/screens/location_detail_screen.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';

void main() {
  testWidgets(
    'cockpit is the coordinator home and exposes its V2 command flow',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const FireCoordinationApp());
      await tester.pumpAndSettle();

      expect(find.byType(CoordinatorCockpitScreen), findsOneWidget);
      expect(find.text('Situation critique'), findsOneWidget);
      expect(find.text('Gironde'), findsOneWidget);
      expect(find.byKey(const Key('cockpit-refreshed-at')), findsOneWidget);
      expect(find.byKey(const Key('cockpit-filters')), findsOneWidget);
      expect(find.text('Toutes'), findsOneWidget);
      expect(find.text('Critiques'), findsOneWidget);
      expect(find.text('À surveiller'), findsWidgets);
      expect(find.text('Couvertes'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('cockpit-filter-critical'))).height,
        greaterThanOrEqualTo(44),
      );
      expect(find.byKey(const Key('cockpit-operational-map')), findsOneWidget);
      expect(find.byKey(const Key('cockpit-map-counters')), findsOneWidget);
      expect(
        tester
            .getSemantics(find.byKey(const Key('cockpit-map-counters')))
            .label,
        matches(RegExp(r'\d+ établissements, 6 missions, 4 tensions')),
      );
      expect(find.text('3 actions prioritaires'), findsOneWidget);
      expect(find.text('Voir la mission'), findsNWidgets(3));
      expect(
        find.byKey(const Key('cockpit-priority-0-detail')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('cockpit-priority-0-horizon')),
        findsOneWidget,
      );
      await _scrollCockpitUntil(tester, find.text('Alertes'));
      expect(find.text('Alertes'), findsOneWidget);
      expect(find.byKey(const Key('cockpit-alert-0')), findsOneWidget);
      await _scrollCockpitUntil(tester, find.text('Résumé opérationnel'));
      expect(find.text('Résumé opérationnel'), findsOneWidget);
      expect(find.text('missions actives'), findsOneWidget);
      expect(find.text('mission critique'), findsOneWidget);
      expect(find.text('couverture globale'), findsOneWidget);
      expect(find.text('profession la plus tendue'), findsOneWidget);
      await _scrollCockpitUntil(tester, find.text('Activité récente'));
      expect(find.text('Activité récente'), findsOneWidget);
      expect(find.text('Aucune activité récente'), findsOneWidget);
      await _scrollCockpitUntil(tester, find.text('Actions rapides'));
      expect(find.text('Actions rapides'), findsOneWidget);
      expect(find.text('Traiter la priorité'), findsOneWidget);
      expect(find.text('Créer un besoin'), findsOneWidget);
      expect(find.text('Historique'), findsNothing);
      expect(find.text('Recommandations'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
    expect(
      find.byKey(const Key('cockpit-map-selected-location-status')),
      findsOneWidget,
    );
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
        RegExp(r'Centre de Mérignac,.*aucune mission active'),
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

  testWidgets('quick filters update map, tensions and summary together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('cockpit-filter-critical')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('cockpit-filter-critical')))
          .selected,
      isTrue,
    );
    expect(
      tester.getSemantics(find.byKey(const Key('cockpit-map-counters'))).label,
      '1 établissement, 1 mission, 1 tension',
    );
    expect(find.text('1 action prioritaire'), findsOneWidget);
    await _scrollCockpitUntil(tester, find.text('couverture globale'));
    expect(
      find.descendant(
        of: find.byKey(const Key('cockpit-operational-summary')),
        matching: find.text('25 %'),
      ),
      findsOneWidget,
    );

    await _scrollCockpitToStart(tester);
    await tester.tap(find.byKey(const Key('cockpit-filter-watch')));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const Key('cockpit-map-counters'))).label,
      '3 établissements, 3 missions, 3 tensions',
    );
    expect(find.text('3 actions prioritaires'), findsOneWidget);

    await tester.tap(find.byKey(const Key('cockpit-filter-covered')));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const Key('cockpit-map-counters'))).label,
      '1 établissement, 2 missions, 0 tensions',
    );
    expect(find.text('Aucune tension pour ce filtre'), findsOneWidget);
    await _scrollCockpitUntil(tester, find.text('couverture globale'));
    expect(
      find.descendant(
        of: find.byKey(const Key('cockpit-operational-summary')),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('cockpit-operational-summary')),
        matching: find.text('100 %'),
      ),
      findsOneWidget,
    );

    await _scrollCockpitToStart(tester);
    await tester.tap(find.byKey(const Key('cockpit-filter-all')));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byKey(const Key('cockpit-map-counters'))).label,
      matches(RegExp(r'\d+ établissements, 6 missions, 4 tensions')),
    );
  });

  testWidgets(
    'marker load uses a separate badge without shrinking tap targets',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final merignac = places.firstWhere(
        (candidate) => candidate.name == 'Mérignac',
      );
      final langon = places.firstWhere(
        (candidate) => candidate.name == 'Langon',
      );
      CoordinationNeed fixture({
        required String id,
        required ResponsePlace location,
        required int quota,
        required int registered,
      }) => CoordinationNeed(
        id: id,
        locationId: location.id,
        place: location.name,
        group: location.group,
        date: 'demain',
        time: '12:00 — 16:00',
        requiredPhysiotherapists: quota,
        registeredPhysiotherapists: registered,
        requiredPodiatrists: 0,
        registeredPodiatrists: 0,
        equipment: const [],
      );

      await tester.pumpWidget(
        FireCoordinationApp(
          repository: MockCoordinationRepository(
            initialMissions: [
              fixture(
                id: 'merignac-critical',
                location: merignac,
                quota: 4,
                registered: 1,
              ),
              fixture(
                id: 'merignac-covered',
                location: merignac,
                quota: 1,
                registered: 1,
              ),
              fixture(
                id: 'langon-covered',
                location: langon,
                quota: 1,
                registered: 1,
              ),
            ],
            initialLocations: [merignac, langon],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final merignacMarker = find.byKey(
        Key('cockpit-map-point-${merignac.id}'),
      );
      final langonMarker = find.byKey(Key('cockpit-map-point-${langon.id}'));
      expect(tester.getSize(merignacMarker).width, greaterThan(26));
      expect(tester.getSize(langonMarker).width, 26);
      expect(
        find.byKey(Key('cockpit-map-badge-${merignac.id}')),
        findsOneWidget,
      );
      expect(find.byKey(Key('cockpit-map-badge-${langon.id}')), findsNothing);
      expect(
        tester.getSize(find.byKey(Key('cockpit-map-location-${merignac.id}'))),
        const Size.square(44),
      );
      expect(tester.takeException(), isNull);
    },
  );

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
    await _scrollCockpitUntil(tester, find.text('Aucune alerte active'));
    expect(find.byKey(const Key('cockpit-alerts-empty')), findsOneWidget);
    await _scrollCockpitUntil(tester, find.text('Aucune activité récente'));
    expect(find.byKey(const Key('cockpit-activity-empty')), findsOneWidget);
    await _scrollCockpitUntil(tester, find.text('Traiter la priorité'));
    expect(find.text('Aucune tension'), findsOneWidget);
    expect(find.text('Traiter la priorité'), findsOneWidget);
    final action = tester.widget<V5Button>(
      find.byKey(const Key('cockpit-view-mission')),
    );
    expect(action.onPressed, isNull);
  });

  testWidgets('cockpit excludes an active-flagged mission after its end', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final location = places.first;
    final expiredMission = CoordinationNeed(
      id: 'expired-recipe-mission',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: 'hier',
      time: '10:00 — 12:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const [],
      startAt: now.subtract(const Duration(hours: 4)),
      endAt: now.subtract(const Duration(hours: 2)),
      isActive: true,
    );

    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          initialMissions: [expiredMission],
          initialLocations: [location],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Situation maîtrisée'), findsOneWidget);
    expect(find.text('Aucune action urgente'), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const Key('cockpit-map-counters'))).label,
      '1 établissement, 0 missions, 0 tensions',
    );
    expect(tester.takeException(), isNull);
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

  testWidgets('Traiter la priorité opens the most urgent mission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();
    await _scrollCockpitUntil(
      tester,
      find.byKey(const Key('cockpit-view-mission')),
    );
    await tester.tap(find.byKey(const Key('cockpit-view-mission')));
    await tester.pumpAndSettle();

    expect(find.byType(CreateNeedScreen), findsOneWidget);
    expect(find.text('Modifier la mission'), findsOneWidget);
    expect(find.textContaining('Mérignac'), findsWidgets);
  });

  testWidgets('tapping an alert opens its existing mission', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const FireCoordinationApp());
    await tester.pumpAndSettle();
    await _scrollCockpitUntil(tester, find.byKey(const Key('cockpit-alert-0')));
    await tester.tap(find.byKey(const Key('cockpit-alert-0')));
    await tester.pumpAndSettle();

    expect(find.byType(CreateNeedScreen), findsOneWidget);
    expect(find.text('Modifier la mission'), findsOneWidget);
  });

  testWidgets('tapping recent activity opens its existing mission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final location = places.firstWhere(
      (candidate) => candidate.name == 'Mérignac',
    );
    final recentMission = CoordinationNeed(
      id: 'recent-mission',
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: 'demain',
      time: '12:00 — 16:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const [],
      startAt: now.add(const Duration(hours: 2)),
      endAt: now.add(const Duration(hours: 6)),
      createdAt: now.subtract(const Duration(minutes: 8)),
    );

    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          initialMissions: [recentMission],
          initialLocations: [location],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollCockpitUntil(
      tester,
      find.byKey(const Key('cockpit-activity-0')),
    );
    expect(find.text('Mission publiée'), findsOneWidget);
    expect(find.textContaining('Il y a 8 min'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cockpit-activity-0')));
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
      await _scrollCockpitUntil(
        tester,
        find.byKey(const Key('cockpit-map-semantics')),
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
          RegExp(
            r'Centre de Mérignac, état critique, 1 mission active, '
            r'1 tension critique',
          ),
        ),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Recentrer la carte'), findsOneWidget);
      await _scrollCockpitUntil(tester, find.text('Alertes'));
      expect(
        find.bySemanticsLabel(RegExp(r'Mission critique.*Ouvrir la mission')),
        findsWidgets,
      );
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
  for (var attempt = 0; attempt < 16 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _scrollCockpitToStart(WidgetTester tester) async {
  final cockpit = find.byKey(const PageStorageKey('coordinator-cockpit'));
  final scrollable = find.descendant(
    of: cockpit,
    matching: find.byType(Scrollable),
  );
  tester.state<ScrollableState>(scrollable).position.jumpTo(0);
  await tester.pumpAndSettle();
}
