import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

import 'support/verified_professional_profile.dart';

void _expectProfessionalHeader() {
  expect(find.text('MobSanté'), findsOneWidget);
  expect(
    find.text('Le bon professionnel, au bon endroit, au bon moment.'),
    findsOneWidget,
  );
  expect(find.text('Professionnel de santé'), findsOneWidget);
  expect(find.text('Mon profil'), findsOneWidget);
}

void main() {
  testWidgets(
    'top edit action opens the existing editor for an empty profile',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: MockCoordinationRepository(responsibleAccess: null),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();

      _expectProfessionalHeader();
      expect(find.text('Profil à compléter'), findsOneWidget);
      final primary = find.byKey(
        const Key('edit-professional-profile-primary'),
      );
      expect(primary, findsOneWidget);
      expect(primary.hitTestable(), findsOneWidget);
      expect(find.text('Modifier mon profil'), findsOneWidget);
      expect(find.text('Identité professionnelle'), findsOneWidget);
      expect(find.text('Vérification professionnelle'), findsOneWidget);

      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('professional-profile-editor-scroll')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-profile-first-name')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('professional-profile-profession')),
        findsOneWidget,
      );
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.byKey(const Key('edit-professional-address')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const Key('edit-professional-address'))),
        alignment: 0.5,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('edit-professional-address')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('edit-professional-address')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('professional-profile-editor-scroll')),
        findsOneWidget,
      );
    },
  );

  testWidgets('verified identity and existing profile remain intact', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(
          responsibleAccess: null,
          initialProfiles: {'mock-volunteer': verifiedMkProfile()},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    _expectProfessionalHeader();
    expect(find.text('Identité professionnelle'), findsOneWidget);
    expect(find.text('Vérification professionnelle'), findsOneWidget);
    expect(
      find.byKey(const Key('edit-professional-profile-primary')).hitTestable(),
      findsOneWidget,
    );
    expect(find.text('Masseur-kinésithérapeute'), findsOneWidget);
  });

  testWidgets('postal code and city fields align without a counter column', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('edit-professional-profile-primary')),
    );
    await tester.pumpAndSettle();

    final postal = find.byKey(const Key('professional-profile-postal-code'));
    final city = find.byKey(const Key('professional-profile-city'));
    final postalRect = tester.getRect(postal);
    final cityRect = tester.getRect(city);
    expect(postalRect.top, cityRect.top);
    expect(postalRect.right, lessThan(cityRect.left));
    expect(
      tester
          .getRect(
            find.descendant(of: postal, matching: find.byType(TextField)),
          )
          .top,
      tester
          .getRect(find.descendant(of: city, matching: find.byType(TextField)))
          .top,
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: postal, matching: find.byType(TextField)),
          )
          .maxLength,
      isNull,
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: city, matching: find.byType(TextField)),
          )
          .maxLength,
      isNull,
    );

    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpAndSettle();
    final narrowPostal = tester.getRect(postal);
    final narrowCity = tester.getRect(city);
    expect(narrowPostal.left, narrowCity.left);
    expect(narrowPostal.bottom, lessThan(narrowCity.top));
    expect(tester.takeException(), isNull);
  });
}
