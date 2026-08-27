import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/screens/diagnostic_push_registration_screen.dart';
import 'package:interface_incendies_gironde/screens/professional_profile_screen.dart';

void main() {
  testWidgets('Diagnostic Push button is present', (tester) async {
    await _pumpProfileScreen(tester);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-diagnostic-push')),
      400,
      scrollable: scrollable,
    );

    expect(find.byKey(const Key('open-diagnostic-push')), findsOneWidget);
    expect(find.text('Diagnostic Push'), findsOneWidget);
  });

  testWidgets('Diagnostic Push button opens the Push diagnostic screen', (
    tester,
  ) async {
    await _pumpProfileScreen(tester);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-diagnostic-push')),
      400,
      scrollable: scrollable,
    );

    final button = find.byKey(const Key('open-diagnostic-push'));
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(find.byType(DiagnosticPushRegistrationScreen), findsOneWidget);
  });

  testWidgets('Diagnostic Push and development settings buttons coexist', (
    tester,
  ) async {
    await _pumpProfileScreen(tester);

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-diagnostic-push')),
      400,
      scrollable: scrollable,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('open-development-settings')),
      400,
      scrollable: scrollable,
    );

    // Flutter widget tests always run with kDebugMode == true. Release
    // visibility is therefore guaranteed structurally by keeping the
    // Diagnostic Push button outside the kDebugMode block in the source.
    expect(find.byKey(const Key('open-diagnostic-push')), findsOneWidget);
    expect(find.byKey(const Key('open-development-settings')), findsOneWidget);
  });
}

Future<void> _pumpProfileScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    RepositoryScope(
      repository: MockCoordinationRepository(),
      child: MaterialApp(
        home: ProfessionalProfileScreen(
          onOpenResponsibleAccess: () {},
          onOpenSettings: () {},
          onOpenNotifications: () {},
          onSignOut: () async {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
