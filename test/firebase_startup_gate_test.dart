import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/config/app_identity.dart';
import 'package:interface_incendies_gironde/firebase_startup_gate.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/splash_screen.dart';

void main() {
  testWidgets('startup displays one animated identity while work is pending', (
    tester,
  ) async {
    final pending = Completer<CoordinationRepository>();

    await tester.pumpWidget(FirebaseStartupGate(startup: () => pending.future));
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
    final animatedIdentity = find.byKey(const Key('splash-animated-identity'));
    expect(animatedIdentity, findsOneWidget);
    expect(
      find.descendant(
        of: animatedIdentity,
        matching: find.byKey(const Key('splash-pictogram')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: animatedIdentity,
        matching: find.byKey(const Key('splash-product-name')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: animatedIdentity,
        matching: find.byKey(const Key('splash-mobilization-subtitle')),
      ),
      findsOneWidget,
    );

    pending.complete(MockCoordinationRepository.instance);
    await tester.pump(AppIdentity.splashRevealDuration);
    await tester.pumpAndSettle();
    expect(find.byType(SplashScreen), findsNothing);
  });

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
