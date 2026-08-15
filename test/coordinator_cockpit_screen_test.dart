import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/screens/coordinator_cockpit_screen.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';

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
    expect(find.text('Gironde'), findsOneWidget);
    expect(find.text('4 tensions prioritaires'), findsOneWidget);
    expect(find.byKey(const Key('cockpit-operational-map')), findsOneWidget);
    expect(find.text('Tensions prioritaires'), findsOneWidget);
    expect(find.text('Voir la mission'), findsNWidgets(3));
    await _scrollCockpitUntil(tester, find.text('Résumé opérationnel'));
    expect(find.text('Résumé opérationnel'), findsOneWidget);
    expect(find.text('Couverture globale'), findsOneWidget);
    expect(find.text('Missions critiques'), findsOneWidget);
    expect(find.text('Profession en tension'), findsOneWidget);
    await _scrollCockpitUntil(tester, find.text('Actions rapides'));
    expect(find.text('Actions rapides'), findsOneWidget);
    expect(find.text('Voir mission'), findsOneWidget);
    expect(find.text('Créer un besoin'), findsOneWidget);
    expect(find.text('Historique'), findsNothing);
    expect(find.text('Recommandations'), findsNothing);
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
        find.bySemanticsLabel(RegExp(r'Gironde.*tensions prioritaires')),
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
    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollCockpitUntil(WidgetTester tester, Finder target) async {
  final scrollable = find.byKey(const PageStorageKey('coordinator-cockpit'));
  for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(scrollable, const Offset(0, -360));
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}
