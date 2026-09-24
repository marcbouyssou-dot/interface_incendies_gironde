import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/dev/role_preview.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/screens/development_settings_screen.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/screens/responsible_shell.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    MockCoordinationRepository repository,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
  }

  Future<void> selectViaBanner(WidgetTester tester, RolePreviewMode mode) async {
    await tester.tap(find.byKey(const Key('role-preview-banner')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('role-preview-banner-option-${mode.name}')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'role preview banner switches shells in 1-2 taps and returns to automatic',
    (tester) async {
      final repository = MockCoordinationRepository(responsibleAccess: null);
      await pumpApp(tester, repository);

      // 1) starts on the real automatic journey (no access => Professional).
      expect(find.byType(ProfessionalShell), findsOneWidget);
      expect(find.text('MODE RECETTE · Parcours : Professionnel'), findsOneWidget);

      // 2) one tap on the banner + one tap on an option = shell switches.
      await selectViaBanner(tester, RolePreviewMode.coordinator);
      expect(find.byType(CoordinatorShell), findsOneWidget);
      expect(find.byType(ProfessionalShell), findsNothing);
      expect(find.text('MODE RECETTE · Parcours : Coordinateur'), findsOneWidget);

      await selectViaBanner(tester, RolePreviewMode.responsible);
      expect(find.byType(ResponsibleShell), findsOneWidget);
      expect(find.byType(CoordinatorShell), findsNothing);
      expect(find.text('MODE RECETTE · Parcours : Responsable'), findsOneWidget);

      // 3) back to Automatique restores the real (unmodified) journey.
      await selectViaBanner(tester, RolePreviewMode.automatic);
      expect(find.byType(ProfessionalShell), findsOneWidget);
      expect(find.byType(ResponsibleShell), findsNothing);
      expect(find.text('MODE RECETTE · Parcours : Professionnel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'role preview banner never elevates a real site manager and never edits real access',
    (tester) async {
      final repository = MockCoordinationRepository(
        responsibleAccess: const ResponsibleAccess(
          uid: 'manager',
          role: ResponsibleRole.siteManager,
          locationIds: {'site-a'},
          active: true,
        ),
      );
      await pumpApp(tester, repository);

      // Real access => automatic journey is Responsible.
      expect(find.byType(ResponsibleShell), findsOneWidget);

      await selectViaBanner(tester, RolePreviewMode.coordinator);

      // The shell displayed changes, but nothing privileged leaks through:
      // the real ResponsibleAccess is still a plain site manager underneath.
      expect(find.byType(CoordinatorShell), findsOneWidget);
      expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);
      expect(find.byKey(const Key('admin-locations-entry')), findsNothing);

      // Proof the real access was never mutated: returning to Automatique
      // resolves back to Responsible, not to whatever was last previewed.
      await selectViaBanner(tester, RolePreviewMode.automatic);
      expect(find.byType(ResponsibleShell), findsOneWidget);
      expect(find.byType(CoordinatorShell), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'role preview banner and the existing settings selector share the same controller',
    (tester) async {
      final repository = MockCoordinationRepository(responsibleAccess: null);
      await pumpApp(tester, repository);

      await selectViaBanner(tester, RolePreviewMode.coordinator);
      expect(find.byType(CoordinatorShell), findsOneWidget);

      // Reach the pre-existing dev settings dropdown through the normal
      // Coordinator navigation and confirm it reflects the SAME mode the
      // banner just set — one RolePreviewController, two entry points.
      await tester.tap(find.text('Plus'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-development-settings')));
      await tester.pumpAndSettle();

      final dropdown = tester.widget<DropdownButtonFormField<RolePreviewMode>>(
        find.byKey(const Key('role-preview-selector')),
      );
      expect(dropdown.initialValue, RolePreviewMode.coordinator);

      final context = tester.element(find.byType(DevelopmentSettingsScreen));
      expect(RolePreviewScope.of(context).mode, RolePreviewMode.coordinator);
      expect(tester.takeException(), isNull);
    },
  );
}
