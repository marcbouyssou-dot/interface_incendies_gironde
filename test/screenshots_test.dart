import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester, {String? tab}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const FireCoordinationApp(useLegacyCoordinatorShellForTesting: true),
    );
    await tester.pumpAndSettle();
    if (tab != null) {
      await tester.tap(find.widgetWithText(NavigationDestination, tab));
      await tester.pumpAndSettle();
    }
  }

  final screens = <String, String?>{
    'accueil': null,
    'declarer_besoin': 'Déclarer',
    'coordination': 'Statistiques',
    'lieux': 'Plus',
  };

  for (final entry in screens.entries) {
    testWidgets('capture ${entry.key}', (tester) async {
      await pumpScreen(tester, tab: entry.value);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../screenshots/${entry.key}.png'),
      );
    });
  }
}
