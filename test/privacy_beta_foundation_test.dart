import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/config/patient_data_guidance.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/screens/information_consent_screen.dart';
import 'package:interface_incendies_gironde/screens/legal_notice_screen.dart';
import 'package:interface_incendies_gironde/screens/platform_mobilization_form_dialog.dart';
import 'package:interface_incendies_gironde/screens/platform_operation_form_dialog.dart';
import 'package:interface_incendies_gironde/widgets/common.dart';

void main() {
  test('global legal and privacy copy has no legacy Action or organizer', () {
    final copy = [
      'lib/screens/privacy_policy_screen.dart',
      'lib/screens/legal_notice_screen.dart',
      'lib/screens/information_consent_screen.dart',
      'lib/screens/about_screen.dart',
    ].map((path) => File(path).readAsStringSync()).join('\n');
    expect(copy, isNot(contains('Incendies Gironde')));
    expect(copy, isNot(contains('URPS MK Nouvelle-Aquitaine')));
    expect(copy, isNot(contains('SELARLU')));
  });

  testWidgets(
    'legal information separates platform hosting from Action organizer',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: LegalNoticeScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Marc Bouyssou, en nom personnel'), findsOneWidget);
      expect(find.textContaining('Rue Combe Maurette'), findsOneWidget);
      expect(find.text('05 55 27 96 51'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Contact hébergeur'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Hébergement du client Web'), findsOneWidget);
      expect(find.textContaining('Netlify, Inc.'), findsOneWidget);
      expect(find.text('support@netlify.com'), findsOneWidget);
      expect(find.text('Comptes et données'), findsOneWidget);
      expect(find.text('Organisateur d’une Action'), findsOneWidget);
      expect(find.textContaining('Éditeur de l’application'), findsNothing);
      expect(find.textContaining('URPS MK Nouvelle-Aquitaine'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('legal information remains scrollable at 320x568', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LegalNoticeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Marc Bouyssou, en nom personnel'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Contact hébergeur'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('support@netlify.com'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('information text describes multiple Actions', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: InformationConsentScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('différentes organisations'), findsOneWidget);
    expect(find.textContaining('Incendies Gironde'), findsNothing);
  });

  testWidgets('Beta CGU remain readable and navigable on a compact iPhone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: InformationConsentScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Conditions d’utilisation'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Acceptation des CGU'),
      300,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Acceptation des CGU'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operation context warns against patient data', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PlatformOperationFormDialog(territories: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(PatientDataGuidance.warning), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobilization subtitle warns against patient data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PlatformMobilizationFormDialog(territories: [])),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(PatientDataGuidance.warning), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mission cancellation reason warns against patient data', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MissionCancellationButton(need: needs.first)),
      ),
    );
    await tester.tap(find.byKey(Key('cancel-mission-${needs.first.id}')));
    await tester.pumpAndSettle();
    expect(find.text(PatientDataGuidance.warning), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
