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
  test('recipe switcher availability follows debug and explicit recipe mode', () {
    expect(
      shouldShowRecipeSwitcher(isDebugBuild: true, recipeModeEnabled: false),
      isTrue,
    );
    expect(
      shouldShowRecipeSwitcher(isDebugBuild: false, recipeModeEnabled: true),
      isTrue,
    );
    expect(
      shouldShowRecipeSwitcher(isDebugBuild: false, recipeModeEnabled: false),
      isFalse,
    );
    expect(showRecipeSwitcher, isTrue);
  });

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

  Future<void> selectViaBanner(
    WidgetTester tester,
    RolePreviewMode mode,
  ) async {
    await tester.tap(find.byKey(const Key('role-preview-banner')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(Key('role-preview-banner-option-${mode.name}')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'compact RECETTE tab switches among the three review journeys',
    (tester) async {
      final repository = MockCoordinationRepository(responsibleAccess: null);
      await pumpApp(tester, repository);

      // 1) starts on the real automatic journey (no access => Professional).
      expect(find.byType(ProfessionalShell), findsOneWidget);
      expect(
        find.text('RECETTE'),
        findsOneWidget,
      );
      final semantics = tester.getSemantics(
        find.byKey(const Key('role-preview-banner')),
      );
      expect(semantics.label, 'Changer le parcours de prévisualisation');
      expect(semantics.value, 'Parcours actuel : Professionnel');
      expect(semantics.flagsCollection.isButton, isTrue);

      await tester.tap(find.byKey(const Key('role-preview-banner')));
      await tester.pumpAndSettle();
      for (final mode in const [
        RolePreviewMode.professional,
        RolePreviewMode.responsible,
        RolePreviewMode.coordinator,
      ]) {
        expect(
          find.byKey(Key('role-preview-banner-option-${mode.name}')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const Key('role-preview-banner-option-automatic')),
        findsNothing,
      );
      expect(find.text('Administrateur de plateforme'), findsNothing);
      Navigator.of(tester.element(find.text('Coordinateur'))).pop();
      await tester.pumpAndSettle();

      // 2) one tap on the banner + one tap on an option = shell switches.
      await selectViaBanner(tester, RolePreviewMode.coordinator);
      expect(find.byType(CoordinatorShell), findsOneWidget);
      expect(find.byType(ProfessionalShell), findsNothing);
      expect(
        find.text('RECETTE'),
        findsOneWidget,
      );

      await selectViaBanner(tester, RolePreviewMode.responsible);
      expect(find.byType(ResponsibleShell), findsOneWidget);
      expect(find.byType(CoordinatorShell), findsNothing);
      expect(
        find.text('RECETTE'),
        findsOneWidget,
      );

      // 3) Professional is the explicit return path in the compact picker.
      await selectViaBanner(tester, RolePreviewMode.professional);
      expect(find.byType(ProfessionalShell), findsOneWidget);
      expect(find.byType(ResponsibleShell), findsNothing);
      expect(
        find.text('RECETTE'),
        findsOneWidget,
      );
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

      // The explicit Responsable preview still resolves through the untouched
      // real site-manager access and never grants coordinator capabilities.
      await selectViaBanner(tester, RolePreviewMode.responsible);
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
