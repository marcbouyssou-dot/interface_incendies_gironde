import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/screens/privacy_policy_screen.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  Future<void> pumpPrivacyPolicy(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PrivacyPolicyScreen()));
    await tester.pumpAndSettle();
  }

  for (final size in const [
    Size(320, 568), // narrow mobile
    Size(390, 844), // standard mobile
  ]) {
    testWidgets('privacy policy renders without overflow at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      await pumpPrivacyPolicy(tester, size);

      expect(find.byKey(const Key('privacy-policy-screen')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'describes a multi-Action platform without a global Gironde organizer',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const PrivacyPolicyScreen()),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.textContaining('MobSanté peut accueillir plusieurs'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(
        find.textContaining('MobSanté peut accueillir plusieurs'),
        findsOneWidget,
      );
      expect(find.textContaining('Incendies Gironde'), findsNothing);
      expect(find.textContaining('URPS MK'), findsNothing);
    },
  );

  testWidgets(
    'does not present CSV export as a self-service feature for professionals',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light, home: const PrivacyPolicyScreen()),
      );
      await tester.pumpAndSettle();
      // The "Durées de conservation" section sits below the fold at this
      // viewport height; scroll it into the built tree before asserting on
      // its content.
      await tester.scrollUntilVisible(
        find.textContaining('ne sont pas un export individuel'),
        300,
        scrollable: find.byType(Scrollable),
      );

      expect(
        find.textContaining('Les exports CSV sont générés à la demande'),
        findsNothing,
      );
      expect(
        find.textContaining('ne sont pas un export individuel'),
        findsOneWidget,
      );
    },
  );
}
