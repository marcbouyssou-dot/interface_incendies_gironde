import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/config/app_identity.dart';
import 'package:interface_incendies_gironde/screens/about_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';
import 'package:interface_incendies_gironde/widgets/v5_secondary_navigation.dart';

void main() {
  test('PWA metadata uses MobSanté consistently', () {
    final manifest =
        jsonDecode(File('web/manifest.json').readAsStringSync())
            as Map<String, dynamic>;
    final index = File('web/index.html').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();

    expect(manifest['name'], AppIdentity.productName);
    expect(manifest['short_name'], 'MobSanté');
    expect(index, contains('name="application-name" content="MobSanté"'));
    expect(
      index,
      contains('name="apple-mobile-web-app-title" content="MobSanté"'),
    );
    expect(index, isNot(contains('content="Recup33"')));
    expect(index, contains('<title>MobSanté — Incendies Gironde</title>'));
    expect(pubspec, contains('version: ${AppIdentity.version}'));
  });

  testWidgets('Flutter application exposes the MobSanté title', (tester) async {
    await tester.pumpWidget(
      const FireCoordinationApp(useLegacyCoordinatorShellForTesting: true),
    );

    final application = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(application.title, AppIdentity.productName);
    expect(application.title, isNot(AppIdentity.technicalName));
  });

  testWidgets('About content is factual, provisional and responsive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const AboutScreen()),
    );

    expect(find.text('MobSanté'), findsOneWidget);
    expect(
      find.text('Interface de mobilisation des professionnels de santé'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Outil facilitant la coordination des professionnels de santé '
        'mobilisés auprès des centres et sites d’intervention.',
      ),
      findsOneWidget,
    );
    expect(find.text('Version ${AppIdentity.version}'), findsOneWidget);
    expect(find.text('Confidentialité'), findsOneWidget);
    expect(find.text('Mentions légales'), findsOneWidget);
    expect(find.text(AppIdentity.designerCredit), findsOneWidget);
    expect(
      find.textContaining('application officielle de l’URPS'),
      findsNothing,
    );
    expect(find.textContaining('édité par l’URPS'), findsNothing);
    expect(find.textContaining('conforme RGPD'), findsNothing);

    await tester.tap(find.text('Confidentialité'));
    await tester.pumpAndSettle();
    expect(find.text(AboutScreen.dataUseNotice), findsOneWidget);
    expect(find.text(AboutScreen.provisionalLegalNotice), findsOneWidget);

    await tester.tap(find.text('Confidentialité'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mentions légales'));
    await tester.pumpAndSettle();
    expect(find.text(AboutScreen.provisionalLegalNotice), findsOneWidget);

    final credit = tester.widget<Text>(find.byKey(const Key('design-credit')));
    expect(credit.style?.fontSize, 12);
    expect(credit.style?.fontWeight, FontWeight.w400);
    expect(tester.takeException(), isNull);
  });

  test('active identity surfaces contain no obsolete visible branding', () {
    final activeFiles = [
      'lib/screens/splash_screen.dart',
      'lib/app.dart',
      'lib/screens/places_screen.dart',
      'lib/screens/about_screen.dart',
      'web/index.html',
      'web/manifest.json',
    ].map((path) => File(path).readAsStringSync()).join('\n');

    for (final obsolete in [
      'InterfaceRecup33',
      'Interface Récup',
      'Interface Recup',
      'Recup33',
      'MobSante',
      'Mob Santé',
      'Version RC1',
      'MB — VP URPS MK NA',
    ]) {
      expect(activeFiles, isNot(contains(obsolete)));
    }
    expect(AppIdentity.technicalName, 'InterfaceRecup33');
    expect(
      File('lib/app_entry.dart').readAsStringSync(),
      contains('class MobSanteEntry'),
    );
  });

  testWidgets('Plus opens About and the back action returns to Plus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const FireCoordinationApp(useLegacyCoordinatorShellForTesting: true),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-entry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('about-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-screen')), findsOneWidget);

    await tester.tap(find.byType(V5BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('about-entry')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
