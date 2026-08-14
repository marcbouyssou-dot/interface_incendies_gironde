import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/config/app_identity.dart';
import 'package:interface_incendies_gironde/firebase_startup_gate.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/app_shell.dart';
import 'package:interface_incendies_gironde/screens/splash_screen.dart';

void main() {
  testWidgets('ready startup keeps the composed splash for 900 ms', (
    tester,
  ) async {
    expect(AppIdentity.splashRevealDuration, const Duration(milliseconds: 900));
    await tester.pumpWidget(
      FirebaseStartupGate(
        startup: () async => MockCoordinationRepository.instance,
        splashPreparation: (_) async {},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 899));
    expect(find.byType(SplashScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('startup keeps one complete identity while work is pending', (
    tester,
  ) async {
    final pending = Completer<CoordinationRepository>();

    await tester.pumpWidget(
      FirebaseStartupGate(
        startup: () => pending.future,
        splashPreparation: (_) async {},
      ),
    );
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(
      find.byKey(const Key('verify-professional-rpps')),
      findsNothing,
      reason: 'Le service RPPS ne doit pas être accessible avant App Check.',
    );
    final splashImage = tester
        .widgetList<Image>(find.byType(Image))
        .firstWhere(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName ==
                  AppIdentity.pictogramAsset,
        );
    expect(
      (splashImage.image as AssetImage).assetName,
      AppIdentity.pictogramAsset,
    );
    expect(find.text('InterfaceRecup33'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final composedIdentity = find.byKey(const Key('splash-composed-identity'));
    expect(composedIdentity, findsOneWidget);
    expect(
      find.descendant(
        of: composedIdentity,
        matching: find.byKey(const Key('splash-pictogram')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: composedIdentity,
        matching: find.byKey(const Key('splash-product-name')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: composedIdentity,
        matching: find.byKey(const Key('splash-mobilization-subtitle')),
      ),
      findsOneWidget,
    );

    pending.complete(MockCoordinationRepository.instance);
    await tester.pump(AppIdentity.splashRevealDuration);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets(
    'startup waits for one complete splash frame before entering AppShell',
    (tester) async {
      final visuals = Completer<void>();

      await tester.pumpWidget(
        FirebaseStartupGate(
          startup: () async => MockCoordinationRepository.instance,
          splashPreparation: (_) => visuals.future,
        ),
      );
      await tester.pump(AppIdentity.splashRevealDuration);

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(
        tester
            .widget<Visibility>(
              find.byKey(const Key('splash-composed-identity')),
            )
            .visible,
        isFalse,
      );

      visuals.complete();
      await tester.pump();
      await tester.pump();

      final identity = find.byKey(const Key('splash-composed-identity'));
      expect(tester.widget<Visibility>(identity).visible, isTrue);
      expect(
        find.descendant(
          of: identity,
          matching: find.byKey(const Key('splash-pictogram')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: identity,
          matching: find.byKey(const Key('splash-product-name')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: identity,
          matching: find.byKey(const Key('splash-mobilization-subtitle')),
        ),
        findsOneWidget,
      );
      expect(find.byType(AppShell), findsNothing);

      await tester.pumpAndSettle();
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(AppShell), findsOneWidget);
      await tester.pump();
      expect(find.byType(AppShell), findsOneWidget);
    },
  );

  testWidgets('a startup failure replaces the spinner with a retry state', (
    tester,
  ) async {
    var attempts = 0;
    Future<CoordinationRepository> fail() async {
      attempts++;
      throw StateError('Firestore unavailable');
    }

    await tester.pumpWidget(FirebaseStartupGate(startup: fail));
    await tester.pumpAndSettle();
    await tester.pump(AppIdentity.splashRevealDuration);

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Connexion sécurisée impossible. Réessayez.'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(AppIdentity.splashRevealDuration);
    expect(attempts, 2);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
