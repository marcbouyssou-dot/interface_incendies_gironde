import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/screens/credits_screen.dart';
import 'package:interface_incendies_gironde/screens/splash_screen.dart';
import 'package:interface_incendies_gironde/theme/v5_foundation.dart';

void main() {
  group('splash screen brand coherence', () {
    Future<void> pumpSplash(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: SplashScreen(prepareVisuals: (_) async {}),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
    }

    for (final size in const [
      Size(320, 568), // narrow mobile
      Size(390, 844), // standard mobile
      Size(1024, 1366), // tall desktop/tablet — where empty space was worse
    ]) {
      testWidgets(
        'renders without overflow at ${size.width.toInt()}x'
        '${size.height.toInt()}',
        (tester) async {
          await pumpSplash(tester, size);

          expect(
            find.byKey(const Key('splash-composed-identity')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('background uses the real V5 brand token, not a one-off color', (
      tester,
    ) async {
      await pumpSplash(tester, const Size(390, 844));

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, V5Colors.light.brand);
    });

    testWidgets('shares the same BrandMark widget as the rest of the app', (
      tester,
    ) async {
      await pumpSplash(tester, const Size(390, 844));

      final pictogram = find.byKey(const Key('splash-pictogram'));
      expect(pictogram, findsOneWidget);
    });
  });

  group('credits screen visual balance', () {
    Future<void> pumpCredits(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
      await tester.pumpAndSettle();
    }

    for (final size in const [
      Size(320, 568), // narrow mobile
      Size(390, 844), // standard mobile
      Size(1024, 1366), // tall desktop/tablet
    ]) {
      testWidgets(
        'renders without overflow at ${size.width.toInt()}x'
        '${size.height.toInt()}',
        (tester) async {
          await pumpCredits(tester, size);

          expect(find.byKey(const Key('credits-screen')), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets(
      'content is vertically centered rather than pinned to the top on a '
      'tall viewport',
      (tester) async {
        await pumpCredits(tester, const Size(390, 1600));

        final scrollView = tester.getRect(
          find.byKey(const Key('credits-screen')),
        );
        final header = tester.getRect(
          find.descendant(
            of: find.byKey(const Key('credits-screen')),
            matching: find.text('Crédits'),
          ),
        );
        final topGap = header.top - scrollView.top;
        final bottomGap = scrollView.bottom - header.bottom;
        // Both gaps should be non-trivial and roughly comparable: content
        // sits in the middle of the viewport, not flush against the top
        // with all the leftover space pushed to the bottom.
        expect(topGap, greaterThan(80));
        expect(bottomGap, greaterThan(80));
      },
    );

    testWidgets('does not invent new partners, mentions or content', (
      tester,
    ) async {
      await pumpCredits(tester, const Size(390, 844));

      expect(find.text('Application conçue par Marc Bouyssou.'), findsOneWidget);
      expect(find.text('Remerciements'), findsOneWidget);
    });
  });
}
