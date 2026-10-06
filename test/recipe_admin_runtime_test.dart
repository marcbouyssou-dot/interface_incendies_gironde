import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/app_entry.dart';
import 'package:interface_incendies_gironde/dev/role_preview.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/operational_scope.dart';
import 'package:interface_incendies_gironde/repositories/recipe_admin_runtime.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_actors_screen.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_profile_screen.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_shell.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/services/platform_administration_service.dart';

void main() {
  testWidgets('recipe entry wires the synthetic Admin runtime', (tester) async {
    if (!recipeModeEnabled) return;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MobSanteEntry(uri: Uri.parse('/mobsante-r01r02/')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-preview-banner')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('role-preview-banner-option-administrator')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const Key('role-preview-banner-option-administrator')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlatformAdminShell), findsOneWidget);
    expect(
      tester
          .widget<PlatformAdminShell>(find.byType(PlatformAdminShell))
          .administrationService
          .isAvailable,
      isTrue,
    );
  });

  testWidgets('non-recipe entry does not install Admin recipe service', (
    tester,
  ) async {
    if (recipeModeEnabled) return;
    await tester.pumpWidget(MobSanteEntry(uri: Uri.parse('/')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-preview-banner')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('role-preview-banner-option-administrator')),
      findsNothing,
    );
  });

  test(
    'recipe Admin reads synthetic data and mutates only local memory',
    () async {
      final runtime = RecipeAdminRuntime();
      expect(
        await runtime.platformAdministrationReadRepository
            .watchCurrentAdministrator()
            .first,
        isNull,
      );
      expect(runtime.platformAdministrationService.isAvailable, isTrue);
      expect(
        runtime.platformAdministrationService.currentUserEmail,
        'admin-recette@example.invalid',
      );
      expect(
        () => runtime.platformAdministrationService.activateMobilization(
          'missing',
        ),
        throwsA(isA<Exception>()),
      );
      final operations = await runtime.operationReadRepository
          .watchOperations()
          .first;
      final mobilizations = await runtime.platformReadRepository
          .watchMobilizations()
          .first;
      final actors = await runtime.platformActorReadRepository.loadDirectory();
      expect(operations.single.id, 'recipe-operation');
      expect(mobilizations.single.id, 'recipe-mobilization');
      expect(actors.coordinators.single.uid, 'recipe-coordinator');
      expect(
        await RecipeAdminCoordinationRepository()
            .watchAllActiveMissions()
            .first,
        hasLength(1),
      );
    },
  );

  test('recipe operation and assignment reset with a new runtime', () async {
    final runtime = RecipeAdminRuntime();
    final draft = OperationAdministrationDraft(
      operationId: 'recipe-created',
      name: 'Opération locale',
      type: OperationType.exercise,
      startAt: DateTime(2030, 6, 20),
      scopeRefs: const [
        OperationalScopeRef(
          kind: OperationalScopeKind.territory,
          id: 'gironde',
        ),
      ],
    );
    await runtime.platformAdministrationService.createOperation(draft);
    expect(
      (await runtime.operationReadRepository.watchOperations().first).map(
        (item) => item.id,
      ),
      contains('recipe-created'),
    );
    await runtime.platformAdministrationService.setOperationCoordinator(
      operationId: 'recipe-operation',
      uid: 'recipe-coordinator',
    );
    expect(
      (await runtime.operationReadRepository
              .watchOperation('recipe-operation')
              .first)
          ?.coordinatorUid,
      'recipe-coordinator',
    );
    expect(
      await runtime.platformAdministrationReadRepository
          .watchMobilizationCoordinators('recipe-mobilization')
          .first,
      hasLength(1),
    );
    final reloaded = RecipeAdminRuntime();
    expect(
      (await reloaded.operationReadRepository.watchOperations().first).map(
        (item) => item.id,
      ),
      isNot(contains('recipe-created')),
    );
    expect(
      (await reloaded.operationReadRepository
              .watchOperation('recipe-operation')
              .first)
          ?.coordinatorUid,
      isNull,
    );
  });

  testWidgets(
    'recipe RECETTE switches into and out of the existing Admin shell',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: RecipeAdminCoordinationRepository(),
          platformRuntime: RecipeAdminRuntime(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CoordinatorShell), findsOneWidget);

      Future<void> select(RolePreviewMode mode) async {
        await tester.tap(find.byKey(const Key('role-preview-banner')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('role-preview-banner-option-administrator')),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(Key('role-preview-banner-option-${mode.name}')),
        );
        await tester.pumpAndSettle();
      }

      await select(RolePreviewMode.professional);
      expect(find.byType(ProfessionalShell), findsOneWidget);
      await select(RolePreviewMode.administrator);
      expect(find.byType(PlatformAdminShell), findsOneWidget);
      expect(
        find.byKey(const Key('mobsante-journey-title-administrator')),
        findsOneWidget,
      );
      expect(find.text('Exercice de recette'), findsWidgets);
      expect(
        find.byKey(const Key('platform-admin-bottom-navigation')),
        findsOneWidget,
      );

      await tester.tap(find.text('Acteurs').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('platform-admin-actors-title')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('mobsante-journey-title-administrator')),
        findsOneWidget,
      );
      final recipeActor = find.byKey(
        const Key('professional-recipe-professional'),
      );
      await tester.scrollUntilVisible(
        recipeActor,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Professionnel de recette'), findsWidgets);
      await Scrollable.ensureVisible(
        tester.element(recipeActor),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(recipeActor);
      await tester.pumpAndSettle();
      expect(find.byType(PlatformProfessionalDetailScreen), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(PlatformProfessionalDetailScreen), findsNothing);

      await tester.tap(find.text('Statistiques').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mobsante-journey-title-administrator')),
        findsOneWidget,
      );
      await tester.tap(find.text('Historique').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mobsante-journey-title-administrator')),
        findsOneWidget,
      );
      await tester.tap(find.text('Plus').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('mobsante-journey-title-administrator')),
        findsOneWidget,
      );

      final profile = find.byKey(const Key('platform-admin-profile'));
      await tester.ensureVisible(profile);
      await tester.tap(profile);
      await tester.pumpAndSettle();
      expect(find.byType(PlatformAdminProfileScreen), findsOneWidget);
      expect(find.text('Mon profil'), findsOneWidget);
      await tester.tap(find.byKey(const Key('platform-admin-profile-back')));
      await tester.pumpAndSettle();
      expect(find.byType(PlatformAdminProfileScreen), findsNothing);
      expect(find.byKey(const Key('platform-admin-sign-out')), findsOneWidget);

      await select(RolePreviewMode.coordinator);
      expect(find.byType(CoordinatorShell), findsOneWidget);
      await select(RolePreviewMode.administrator);
      expect(find.byType(PlatformAdminShell), findsOneWidget);
      await select(RolePreviewMode.automatic);
      expect(find.byType(CoordinatorShell), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('existing Admin form creates a visible in-memory operation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final runtime = RecipeAdminRuntime();
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: RecipeAdminCoordinationRepository(),
        platformRuntime: runtime,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('role-preview-banner')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('role-preview-banner-option-administrator')),
    );
    await tester.pumpAndSettle();
    final create = find.byKey(const Key('create-platform-operation'));
    expect(tester.widget<Widget>(create), isNotNull);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle opération'), findsWidgets);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('platform-operation-name')),
        matching: find.byType(TextFormField),
      ),
      'Exercice local R10B',
    );
    await tester.tap(find.byKey(const Key('platform-operation-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercice').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('operation-scope-gironde')),
    );
    await tester.tap(find.byKey(const Key('operation-scope-gironde')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-platform-operation')));
    await tester.pumpAndSettle();
    expect(find.text('Exercice local R10B'), findsWidgets);
    expect(
      (await runtime.operationReadRepository.watchOperations().first).where(
        (item) => item.name == 'Exercice local R10B',
      ),
      hasLength(1),
    );
  });
}
