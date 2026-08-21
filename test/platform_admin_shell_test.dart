import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/mobilization.dart';
import 'package:interface_incendies_gironde/models/mobilization_context.dart';
import 'package:interface_incendies_gironde/models/need.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/operational_scope.dart';
import 'package:interface_incendies_gironde/models/platform_administrator_access.dart';
import 'package:interface_incendies_gironde/models/responsible_account.dart';
import 'package:interface_incendies_gironde/models/territory.dart';
import 'package:interface_incendies_gironde/models/user_display_identity.dart';
import 'package:interface_incendies_gironde/perspective/cross_role_perspective.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/operation_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_administration_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/platform_runtime.dart';
import 'package:interface_incendies_gironde/repositories/read_only_preview_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_responsible_access_administration_repository.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_shell.dart';
import 'package:interface_incendies_gironde/screens/platform_admin_more_screen.dart';
import 'package:interface_incendies_gironde/screens/platform_operation_form_dialog.dart';
import 'package:interface_incendies_gironde/screens/professional_shell.dart';
import 'package:interface_incendies_gironde/screens/responsible_shell.dart';
import 'package:interface_incendies_gironde/screens/coordinator_shell.dart';
import 'package:interface_incendies_gironde/screens/create_need_screen.dart';
import 'package:interface_incendies_gironde/services/current_mobilization_provider.dart';
import 'package:interface_incendies_gironde/services/accessible_mobilizations_provider.dart';
import 'package:interface_incendies_gironde/services/operational_context_provider.dart';
import 'package:interface_incendies_gironde/services/platform_administration_service.dart';
import 'package:interface_incendies_gironde/widgets/v5_bottom_navigation.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';
import 'package:interface_incendies_gironde/widgets/perspective_switcher.dart';

void main() {
  test(
    'operation preview context is immutable and cleared on admin return',
    () {
      final mobilizationIds = {'mob-1'};
      final locationIds = {'location-1'};
      final context = CrossRoleOperationContext(
        operationId: 'operation-1',
        operationName: 'Opération 1',
        mobilizationIds: mobilizationIds,
        locationIds: locationIds,
      );
      mobilizationIds.add('mob-outside');
      locationIds.add('location-outside');
      final controller = CrossRolePerspectiveController();
      addTearDown(controller.dispose);

      controller.showCoordinatorForOperation(context);
      expect(controller.perspective, CrossRolePerspective.coordinator);
      expect(controller.operationContext, same(context));
      expect(context.mobilizationIds, {'mob-1'});
      expect(context.locationIds, {'location-1'});
      expect(
        () => context.mobilizationIds.add('blocked'),
        throwsUnsupportedError,
      );

      controller.showActualRole();
      expect(controller.perspective, CrossRolePerspective.actual);
      expect(controller.operationContext, isNull);
    },
  );

  test(
    'read-only preview repository clamps reads and rejects mutations',
    () async {
      final firstLocation = places.first;
      final secondLocation = places[1];
      final repository = _MultiPreviewRepository(
        missions: [
          _previewMission(firstLocation),
          _otherPreviewMission(secondLocation),
        ],
        location: firstLocation,
        locations: [firstLocation, secondLocation],
      );
      final readOnly = ReadOnlyPreviewCoordinationRepository(
        repository,
        operationContext: CrossRoleOperationContext(
          operationId: _previewOperation.id,
          operationName: _previewOperation.name,
          mobilizationIds: {_previewMobilization.id},
          locationIds: {firstLocation.id},
        ),
      );

      expect(
        await readOnly.watchMissions().first,
        everyElement(
          isA<CoordinationNeed>().having(
            (mission) => mission.mobilizationId,
            'mobilizationId',
            _previewMobilization.id,
          ),
        ),
      );
      expect(await readOnly.watchLocations().first, [same(firstLocation)]);
      await expectLater(
        readOnly.cancelMission('mission-preview', null),
        throwsA(isA<RepositoryException>()),
      );
      await expectLater(
        readOnly.signOutResponsible(),
        throwsA(isA<RepositoryException>()),
      );
      expect(repository.mutationCalls, 0);
    },
  );

  testWidgets('read-only guard follows contextual preview onto pushed routes', (
    tester,
  ) async {
    final location = places.first;
    final repository = _MultiPreviewRepository(
      missions: [_previewMission(location)],
      location: location,
    );
    final previewContext = CrossRoleOperationContext(
      operationId: _previewOperation.id,
      operationName: _previewOperation.name,
      mobilizationIds: {_previewMobilization.id},
      locationIds: {location.id},
    );
    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: CrossRolePerspectiveScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const Key('activate-context-preview'),
                      onPressed: () => CrossRolePerspectiveScope.of(
                        context,
                      ).showProfessionalForOperation(previewContext),
                      child: const Text('Prévisualiser'),
                    ),
                    TextButton(
                      key: const Key('push-preview-route'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (routeContext) => Scaffold(
                            body: TextButton(
                              key: const Key('attempt-preview-mutation'),
                              onPressed: () async {
                                try {
                                  await RepositoryScope.of(
                                    routeContext,
                                  ).cancelMission('mission-preview', null);
                                } on RepositoryException {
                                  // The route must retain the read-only guard.
                                }
                              },
                              child: const Text('Modifier'),
                            ),
                          ),
                        ),
                      ),
                      child: const Text('Ouvrir'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('activate-context-preview')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('push-preview-route')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attempt-preview-mutation')));
    await tester.pump();

    expect(repository.mutationCalls, 0);
    expect(tester.takeException(), isNull);
  });

  test('platform authority and coordinator assignment are parsed strictly', () {
    final administrator = PlatformAdministratorAccess.fromMap(
      uid: 'platform-admin',
      data: const {'active': true},
    );
    final assignment = MobilizationCoordinatorAssignment.fromMap(
      id: 'mobilization-1_coordinator-1',
      data: const {
        'uid': 'coordinator-1',
        'mobilizationId': 'mobilization-1',
        'role': 'coordinator',
        'active': true,
      },
    );

    expect(administrator.active, isTrue);
    expect(assignment.active, isTrue);
    expect(
      const ActivePlatformCoordinator(
        uid: 'technical-coordinator-uid',
      ).displayIdentity.displayName,
      'Coordinateur',
    );
    expect(
      () => MobilizationCoordinatorAssignment.fromMap(
        id: 'incoherent',
        data: const {
          'uid': 'coordinator-1',
          'mobilizationId': 'mobilization-1',
          'role': 'coordinator',
          'active': true,
        },
      ),
      throwsFormatException,
    );
  });

  testWidgets('a non-admin never sees the platform shell', (tester) async {
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
        platformRuntime: _runtime(administrator: null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlatformAdminShell), findsNothing);
    expect(find.byType(ProfessionalShell), findsOneWidget);
    expect(find.byType(PlatformAdminPerspectiveSection), findsNothing);
    expect(find.text('Prévisualiser un parcours'), findsNothing);

    await tester.pumpWidget(
      FireCoordinationApp(
        repository: MockCoordinationRepository(responsibleAccess: null),
        platformRuntime: _runtime(
          administrator: const PlatformAdministratorAccess(
            uid: 'inactive-platform-admin',
            active: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlatformAdminShell), findsNothing);
  });

  testWidgets('an active platform administrator is routed to its shell', (
    tester,
  ) async {
    await _pumpPlatformAdmin(tester);

    expect(find.byType(PlatformAdminShell), findsOneWidget);
    expect(find.byKey(const Key('platform-admin-shell')), findsOneWidget);
    expect(find.byType(ProfessionalShell), findsNothing);
    expect(find.text('Administrateur'), findsOneWidget);
    expect(find.text('Préparez et pilotez les mobilisations.'), findsOneWidget);
  });

  testWidgets(
    'an expired admin session closes forms, blocks actions and reconnects',
    (tester) async {
      final session = PlatformAdministrationSessionController();
      addTearDown(session.dispose);
      final service = _SessionAdministrationService(session);
      final repository = _RecordingCoordinationRepository(
        initialLocations: [places.first],
      );
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: repository,
          platformRuntime: _MultiPreviewRuntime(administrationService: service),
        ),
      );
      await tester.pumpAndSettle();

      final create = find.byKey(const Key('create-platform-operation'));
      expect(create.hitTestable(), findsOneWidget);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.byType(PlatformOperationFormDialog), findsOneWidget);

      session.markExpired();
      await tester.pumpAndSettle();

      expect(find.byType(PlatformOperationFormDialog), findsNothing);
      expect(
        find.byKey(const Key('platform-admin-session-expired')),
        findsOneWidget,
      );
      expect(find.text('Votre session a expiré'), findsOneWidget);
      expect(find.text('Se reconnecter'), findsOneWidget);
      expect(create.hitTestable(), findsNothing);
      expect(service.createOperationCalls, 0);

      await tester.tap(find.byKey(const Key('platform-admin-reconnect')));
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(
        find.byKey(const Key('platform-admin-authentication')),
        findsOneWidget,
      );
      expect(find.byType(ResponsibleLogin), findsOneWidget);
    },
  );

  testWidgets('the active mobilization and territory are displayed', (
    tester,
  ) async {
    await _pumpPlatformAdmin(tester);

    expect(find.byKey(const Key('active-mobilization-card')), findsOneWidget);
    expect(find.text('Incendies Gironde'), findsOneWidget);
    expect(find.text('Incendie'), findsOneWidget);
    expect(find.text('Gironde · 33'), findsOneWidget);
    expect(find.text('Mobilisation active'), findsWidgets);
    expect(find.text('Active'), findsNothing);
    expect(find.text('Brouillon'), findsNothing);
    expect(find.text('Inactive'), findsNothing);
    expect(find.text('Activée le'), findsOneWidget);
    expect(find.byKey(const Key('platform-preparation-state')), findsOneWidget);
    expect(find.byKey(const Key('platform-territory-card')), findsOneWidget);
    expect(find.byKey(const Key('platform-activation-date')), findsOneWidget);
    expect(find.textContaining('fonctions backend sécurisées'), findsNothing);

    final activeMobilization = find.byKey(
      const Key('active-mobilization-card'),
    );
    final preparationState = find.byKey(
      const Key('platform-preparation-state'),
    );
    final coordinator = find.byKey(const Key('platform-coordination-card'));
    final territory = find.byKey(const Key('platform-territory-card'));
    final actions = find.byKey(const Key('platform-primary-actions'));
    expect(
      tester.getTopLeft(activeMobilization).dy,
      lessThan(tester.getTopLeft(preparationState).dy),
    );
    expect(
      tester.getTopLeft(preparationState).dy,
      lessThan(tester.getTopLeft(coordinator).dy),
    );
    expect(
      tester.getTopLeft(coordinator).dy,
      lessThan(tester.getTopLeft(territory).dy),
    );
    expect(
      tester.getTopLeft(territory).dy,
      lessThan(tester.getTopLeft(actions).dy),
    );

    for (final key in [
      'platform-create-mobilization',
      'platform-deactivate-mobilization',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
      expect(tester.widget<V5Button>(find.byKey(Key(key))).onPressed, isNull);
    }
  });

  testWidgets('absence of an active mobilization has a dedicated state', (
    tester,
  ) async {
    await _pumpPlatformAdmin(
      tester,
      contextStream: Stream<MobilizationContext?>.value(null),
      hasActiveMobilization: false,
    );

    expect(
      find.byKey(const Key('platform-no-active-mobilization')),
      findsOneWidget,
    );
    expect(find.text('Aucune mobilisation active'), findsOneWidget);
  });

  testWidgets('assigned coordinator and active state are displayed', (
    tester,
  ) async {
    await _pumpPlatformAdmin(tester);

    expect(find.byKey(const Key('platform-coordination-card')), findsOneWidget);
    expect(find.text('Camille Martin'), findsOneWidget);
    expect(find.text('Coordinateur · Périmètre départemental'), findsOneWidget);
    expect(find.text('coordinator-user-12345'), findsNothing);
    expect(find.text('Actif'), findsOneWidget);
  });

  testWidgets('missing coordination is explicit', (tester) async {
    await _pumpPlatformAdmin(tester, assignments: const []);

    expect(find.text('Coordination à compléter'), findsOneWidget);
    expect(find.textContaining('Affectez un Coordinateur'), findsOneWidget);
    expect(find.text('Aucun coordinateur affecté'), findsNothing);
  });

  testWidgets('loading and read errors have explicit states', (tester) async {
    final pending = StreamController<MobilizationContext?>();
    addTearDown(pending.close);
    await _pumpPlatformAdmin(
      tester,
      contextStream: pending.stream,
      settle: false,
    );
    await tester.pump();

    expect(
      find.byKey(const Key('platform-mobilization-loading')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('platform-loading-indicator')), findsOneWidget);

    pending.addError(StateError('indisponible'));
    await tester.pump();

    expect(
      find.byKey(const Key('platform-mobilization-error')),
      findsOneWidget,
    );
    expect(find.text('Lecture de la plateforme impossible'), findsOneWidget);
  });

  testWidgets('admin navigation exposes only useful destinations', (
    tester,
  ) async {
    await _pumpPlatformAdmin(tester);

    final navigation = tester.widget<V5BottomBar>(
      find.byKey(const Key('platform-admin-bottom-navigation')),
    );
    expect(navigation.destinations, hasLength(3));
    expect(navigation.destinations.map((destination) => destination.label), [
      'Opérations',
      'Acteurs',
      'Plus',
    ]);
    expect(find.text('Territoires'), findsNothing);
    expect(find.text('Coordinateurs'), findsNothing);
    expect(find.text('À venir'), findsNothing);

    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();
    expect(find.byType(PlatformAdminMoreScreen), findsOneWidget);
    expect(find.text('Se déconnecter'), findsOneWidget);
  });

  testWidgets('only an admin can preview and leave all four journeys', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _RecordingCoordinationRepository(
      initialLocations: [places.first],
    );
    await _pumpPlatformAdmin(tester, repository: repository);

    Future<void> openMore() async {
      await tester.tap(find.text('Plus').last);
      await tester.pumpAndSettle();
    }

    Future<void> preview({
      required Key option,
      required String title,
      required Type shell,
    }) async {
      await tester.ensureVisible(find.byKey(option));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(option));
      await tester.pumpAndSettle();
      if (find
          .byKey(const Key('responsible-center-picker'))
          .evaluate()
          .isNotEmpty) {
        await tester.tap(
          find
              .descendant(
                of: find.byKey(const Key('responsible-center-picker')),
                matching: find.byType(ListTile),
              )
              .first,
        );
        await tester.pumpAndSettle();
      }
      expect(find.byType(shell), findsOneWidget);
      expect(find.text('Prévisualisation $title'), findsOneWidget);
      expect(find.text('Votre rôle : Administrateur'), findsNothing);
      expect(find.text('Retour Administrateur'), findsOneWidget);
      expect(
        tester
            .getSize(find.byKey(const Key('cross-role-preview-banner')))
            .height,
        lessThanOrEqualTo(52),
      );
      expect(repository.signOutCalls, 0);
      expect(repository.lastObservedAccess, isNull);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('exit-cross-role-preview')));
      await tester.pumpAndSettle();
      expect(find.byType(PlatformAdminShell), findsOneWidget);
    }

    await openMore();
    expect(find.byType(PlatformAdminPerspectiveSection), findsOneWidget);
    expect(find.byKey(const Key('perspective-professional')), findsOneWidget);
    expect(find.byKey(const Key('perspective-responsible')), findsOneWidget);
    expect(find.byKey(const Key('perspective-coordinator')), findsOneWidget);
    expect(find.byKey(const Key('perspective-platform-admin')), findsOneWidget);
    await preview(
      option: const Key('perspective-professional'),
      title: 'Professionnel',
      shell: ProfessionalShell,
    );

    await openMore();
    await preview(
      option: const Key('perspective-responsible'),
      title: 'Responsable',
      shell: ResponsibleShell,
    );

    await openMore();
    await preview(
      option: const Key('perspective-coordinator'),
      title: 'Coordinateur',
      shell: CoordinatorShell,
    );
  });

  testWidgets(
    'admin previews load every coordinator and responsible destination without context leaks',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final location = places.first;
      final mission = _previewMission(location);
      final accountsRepository = _RecordingAccountsRepository();
      final repository = _MultiPreviewRepository(
        missions: [mission],
        location: location,
        accountsRepository: accountsRepository,
        denyAdministrativeScopedReads: true,
      );
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: repository,
          platformRuntime: _MultiPreviewRuntime(),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> openAdminPerspective(Key key) async {
        await tester.tap(find.text('Plus').last);
        await tester.pumpAndSettle();
        final option = find.byKey(key);
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tester.tap(option);
        await tester.pumpAndSettle();
      }

      await openAdminPerspective(const Key('perspective-coordinator'));
      expect(
        find.byKey(const PageStorageKey('coordinator-cockpit')),
        findsOneWidget,
      );
      expect(find.text('Prévisualisation Coordinateur'), findsOneWidget);
      expect(repository.allActiveRequests, greaterThan(0));
      expect(repository.mobilizationRequests, isEmpty);
      expect(
        find.text('Le cockpit opérationnel est temporairement indisponible.'),
        findsNothing,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('coordinator-bottom-navigation')),
          matching: find.text('Territoire'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(
        find.byKey(const PageStorageKey('coordinator-territory')),
        findsOneWidget,
      );

      await tester.tap(find.text('Acteurs').last);
      await tester.pumpAndSettle();
      expect(accountsRepository.listCalls, 1);
      expect(
        find.byKey(const PageStorageKey('coordinator-actors')),
        findsOneWidget,
      );

      await tester.tap(find.text('Plus').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump();
      expect(
        find.byKey(const PageStorageKey('coordinator-more')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('administration-statistics')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('coordinator-global-dashboard')),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exit-cross-role-preview')));
      await tester.pumpAndSettle();

      await openAdminPerspective(const Key('perspective-responsible'));
      expect(find.byKey(const Key('responsible-home')), findsOneWidget);
      expect(find.text('Prévisualisation Responsable'), findsOneWidget);
      await tester.tap(find.text('Besoins').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const PageStorageKey('responsible-needs')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('mission-operation-context-${mission.mobilizationId}')),
        findsOneWidget,
      );
      await tester.tap(find.text('Équipe').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const PageStorageKey('responsible-team')),
        findsOneWidget,
      );
      await tester.tap(find.text('Profil').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const PageStorageKey('responsible-profile')),
        findsOneWidget,
      );
      expect(find.text(location.name), findsWidgets);
      expect(find.text('Tous les centres — accès Coordinateur'), findsNothing);
      expect(repository.locationRequests, isEmpty);
      expect(
        find.text('Le planning est temporairement indisponible.'),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('exit-cross-role-preview')));
      await tester.pumpAndSettle();

      await openAdminPerspective(const Key('perspective-professional'));
      expect(find.byType(ProfessionalShell), findsOneWidget);
      expect(find.text('Prévisualisation Professionnel'), findsOneWidget);
      expect(find.text('Votre rôle : Administrateur'), findsNothing);
      await tester.tap(find.byKey(const Key('exit-cross-role-preview')));
      await tester.pumpAndSettle();

      await openAdminPerspective(const Key('perspective-coordinator'));
      expect(
        find.byKey(const PageStorageKey('coordinator-cockpit')),
        findsOneWidget,
      );
      expect(repository.allActiveRequests, greaterThan(1));
      expect(repository.mobilizationRequests, isEmpty);
      expect(find.text('Tous les centres — accès Coordinateur'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'operation previews clamp all journeys and return to the real admin role',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final firstLocation = places.first;
      final secondLocation = places[1];
      final outsideLocation = places[2];
      final firstMission = _previewMission(firstLocation);
      final secondMission = _secondPreviewMission(secondLocation);
      final outsideMission = _otherPreviewMission(outsideLocation);
      final repository = _MultiPreviewRepository(
        missions: [firstMission, secondMission, outsideMission],
        location: firstLocation,
        locations: [firstLocation, secondLocation, outsideLocation],
      );
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: repository,
          platformRuntime: _MultiPreviewRuntime(
            mobilizations: [_previewMobilization, _otherPreviewMobilization],
            operations: [_previewOperation, _otherPreviewOperation],
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<void> openOperation() async {
        final operation = find.byKey(
          const Key('platform-operation-operation-preview'),
        );
        await tester.scrollUntilVisible(
          operation,
          260,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(operation);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('operation-future-journeys')),
          260,
          scrollable: find.byType(Scrollable).first,
        );
      }

      Future<void> preview({
        required Key key,
        required String role,
        required Type shell,
      }) async {
        await openOperation();
        await tester.ensureVisible(find.byKey(key));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(key));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        if (find
            .byKey(const Key('responsible-center-picker'))
            .evaluate()
            .isNotEmpty) {
          await tester.tap(find.text(firstLocation.name).last);
          await tester.pumpAndSettle();
        }
        expect(find.byType(shell), findsOneWidget);
        expect(
          find.text('Prévisualisation $role · ${_previewOperation.name}'),
          findsOneWidget,
        );
        expect(find.text(outsideLocation.name), findsNothing);
        if (shell == ResponsibleShell) {
          expect(find.text(secondLocation.name), findsNothing);
          expect(find.text(firstLocation.name), findsWidgets);
        }
        expect(repository.lastObservedAccess, isNull);

        await tester.tap(find.byKey(const Key('exit-cross-role-preview')));
        await tester.pumpAndSettle();
        expect(find.byType(PlatformAdminShell), findsOneWidget);
        expect(find.text('Retour Administrateur'), findsNothing);
      }

      await preview(
        key: const Key('future-view-as-responsible'),
        role: 'Responsable',
        shell: ResponsibleShell,
      );
      await preview(
        key: const Key('future-view-as-professional'),
        role: 'Professionnel',
        shell: ProfessionalShell,
      );
      await preview(
        key: const Key('future-view-as-coordinator'),
        role: 'Coordinateur',
        shell: CoordinatorShell,
      );

      expect(repository.mutationCalls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'firebase-like preview failures keep simple UI copy and log the exact stream',
    (tester) async {
      final messages = <String>[];
      final previousDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) messages.add(message);
      };
      try {
        final location = places.first;
        await tester.pumpWidget(
          FireCoordinationApp(
            repository: _MultiPreviewRepository(
              missions: [_previewMission(location)],
              location: location,
              failProfessionalMissionRead: true,
            ),
            platformRuntime: _MultiPreviewRuntime(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plus').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('perspective-coordinator')),
        );
        await tester.tap(find.byKey(const Key('perspective-coordinator')));
        await tester.pumpAndSettle();

        expect(
          find.text('Le cockpit opérationnel est temporairement indisponible.'),
          findsOneWidget,
        );
        expect(find.textContaining('permission-denied'), findsNothing);
        expect(
          messages.any(
            (message) =>
                message.contains(
                  'Cockpit Coordinateur indisponible [missions]',
                ) &&
                message.contains('permission-denied'),
          ),
          isTrue,
        );
      } finally {
        debugPrint = previousDebugPrint;
      }
    },
  );

  testWidgets(
    'admin perspective stays readable at 390x844 with 200 percent text, dark mode and reduced motion',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearPlatformBrightnessTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final location = places.first;
      await tester.pumpWidget(
        FireCoordinationApp(
          repository: _MultiPreviewRepository(
            missions: [_previewMission(location)],
            location: location,
          ),
          platformRuntime: _MultiPreviewRuntime(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plus').last);
      await tester.pumpAndSettle();
      final option = find.byKey(const Key('perspective-coordinator'));
      await tester.ensureVisible(option);
      await tester.drag(
        find.byKey(const PageStorageKey('platform-admin-more')),
        const Offset(0, -180),
      );
      await tester.pumpAndSettle();
      await tester.tap(option);
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.byType(CoordinatorShell))).brightness,
        Brightness.dark,
      );
      expect(
        MediaQuery.of(
          tester.element(find.byType(CoordinatorShell)),
        ).disableAnimations,
        isTrue,
      );
      expect(
        find.byKey(const PageStorageKey('coordinator-cockpit')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.byKey(const Key('cross-role-preview-banner'))),
        isNotNull,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets('platform sign-out confirmation can be cancelled', (
    tester,
  ) async {
    final repository = _RecordingCoordinationRepository();
    await _pumpPlatformAdmin(tester, repository: repository);

    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();
    final signOut = find.byKey(const Key('platform-admin-sign-out'));
    expect(signOut, findsOneWidget);
    expect(tester.getSize(signOut).height, greaterThanOrEqualTo(44));

    await tester.tap(signOut);
    await tester.pumpAndSettle();
    expect(find.text('Se déconnecter ?'), findsOneWidget);

    await tester.tap(find.text('Annuler').last);
    await tester.pumpAndSettle();
    expect(repository.signOutCalls, 0);
    expect(find.byType(PlatformAdminShell), findsOneWidget);
  });

  testWidgets(
    'confirmed platform sign-out runs once and opens authentication',
    (tester) async {
      final repository = _RecordingCoordinationRepository();
      await _pumpPlatformAdmin(tester, repository: repository);

      await tester.tap(find.text('Plus').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('platform-admin-sign-out')));
      await tester.pumpAndSettle();
      final confirm = find.byKey(const Key('confirm-platform-admin-sign-out'));
      expect(confirm, findsOneWidget);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(repository.signOutCalls, 1);
      expect(find.byType(PlatformAdminShell), findsNothing);
      expect(
        find.byKey(const Key('platform-admin-authentication')),
        findsOneWidget,
      );
      expect(find.byType(ResponsibleLogin), findsOneWidget);
      expect(find.text('Se connecter'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the admin shell supports semantics and 200 percent text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await _pumpPlatformAdmin(tester);

    final mobilizationTab = find.bySemanticsLabel('Opérations');
    expect(mobilizationTab, findsWidgets);
    expect(
      tester.getSize(mobilizationTab.first).height,
      greaterThanOrEqualTo(44),
    );
    expect(find.byKey(const Key('platform-admin-question')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Plus').last);
    await tester.pumpAndSettle();
    final professionalPreview = find.byKey(
      const Key('perspective-professional'),
    );
    await tester.ensureVisible(professionalPreview);
    await tester.drag(
      find.byKey(const PageStorageKey('platform-admin-more')),
      const Offset(0, -160),
    );
    await tester.pumpAndSettle();
    await tester.tap(professionalPreview);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('cross-role-preview-banner')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<void> _pumpPlatformAdmin(
  WidgetTester tester, {
  MockCoordinationRepository? repository,
  Stream<MobilizationContext?>? contextStream,
  bool hasActiveMobilization = true,
  List<MobilizationCoordinatorAssignment>? assignments,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    FireCoordinationApp(
      repository:
          repository ?? MockCoordinationRepository(responsibleAccess: null),
      platformRuntime: _runtime(
        administrator: const PlatformAdministratorAccess(
          uid: 'platform-admin',
          active: true,
        ),
        contextStream:
            contextStream ??
            Stream<MobilizationContext?>.value(
              const MobilizationContext(
                mobilizationId: 'incendies-gironde-2026',
                territoryId: 'gironde',
                status: MobilizationStatus.active,
              ),
            ).asBroadcastStream(),
        hasActiveMobilization: hasActiveMobilization,
        assignments: assignments,
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

class _RecordingCoordinationRepository extends MockCoordinationRepository {
  _RecordingCoordinationRepository({super.initialLocations})
    : super(responsibleAccess: null);

  int signOutCalls = 0;
  ResponsibleAccess? lastObservedAccess;

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() async* {
    lastObservedAccess = null;
    yield lastObservedAccess;
  }

  @override
  Future<void> signOutResponsible() async {
    signOutCalls++;
  }
}

class _MultiPreviewRepository extends MockCoordinationRepository
    implements MultiMobilizationCoordinationReadRepository {
  _MultiPreviewRepository({
    required List<CoordinationNeed> missions,
    required ResponsePlace location,
    List<ResponsePlace>? locations,
    MockResponsibleAccessAdministrationRepository? accountsRepository,
    this.denyAdministrativeScopedReads = false,
    this.failProfessionalMissionRead = false,
  }) : _missions = List.unmodifiable(missions),
       super(
         initialMissions: missions,
         initialLocations: locations ?? [location],
         responsibleAccess: null,
         responsibleAccessAdministrationRepository: accountsRepository,
       );

  final List<CoordinationNeed> _missions;
  final bool denyAdministrativeScopedReads;
  final bool failProfessionalMissionRead;
  int allActiveRequests = 0;
  final List<Set<String>> mobilizationRequests = [];
  final List<Set<String>> locationRequests = [];
  ResponsibleAccess? lastObservedAccess;
  int mutationCalls = 0;

  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() async* {
    lastObservedAccess = null;
    yield lastObservedAccess;
  }

  @override
  Future<String> createMission(MissionDraft draft) async {
    mutationCalls++;
    return 'unexpected-mission';
  }

  @override
  Future<void> updateMission(String missionId, MissionDraft draft) async {
    mutationCalls++;
  }

  @override
  Future<void> cancelMission(String missionId, String? reason) async {
    mutationCalls++;
  }

  @override
  Stream<List<CoordinationNeed>> watchAllActiveMissions() {
    allActiveRequests++;
    if (failProfessionalMissionRead) return _permissionDenied();
    return Stream.value(_missions);
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForLocations(Set<String> ids) {
    locationRequests.add(Set.of(ids));
    if (denyAdministrativeScopedReads) return _permissionDenied();
    return Stream.value(
      _missions.where((mission) => ids.contains(mission.locationId)).toList(),
    );
  }

  @override
  Stream<List<CoordinationNeed>> watchMissionsForMobilizations(
    Set<String> ids,
  ) {
    mobilizationRequests.add(Set.of(ids));
    if (denyAdministrativeScopedReads) return _permissionDenied();
    return Stream.value(
      _missions
          .where((mission) => ids.contains(mission.mobilizationId))
          .toList(),
    );
  }

  Stream<List<CoordinationNeed>> _permissionDenied() => Stream.error(
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    StackTrace.current,
  );
}

class _RecordingAccountsRepository
    extends MockResponsibleAccessAdministrationRepository {
  int listCalls = 0;

  @override
  Future<List<ResponsibleAccount>> listAccounts() async {
    listCalls++;
    return super.listAccounts();
  }
}

PlatformRuntime _runtime({
  required PlatformAdministratorAccess? administrator,
  Stream<MobilizationContext?>? contextStream,
  bool hasActiveMobilization = true,
  List<MobilizationCoordinatorAssignment>? assignments,
}) {
  return _FakePlatformRuntime(
    platformRepository: _FakePlatformReadRepository(
      activeMobilization: hasActiveMobilization ? _activeMobilization : null,
    ),
    currentMobilizationProvider: _FakeMobilizationProvider(
      contextStream ?? Stream<MobilizationContext?>.value(null),
    ),
    administrationRepository: _FakeAdministrationReadRepository(
      administrator: administrator,
      assignments:
          assignments ??
          const [
            MobilizationCoordinatorAssignment(
              id: 'incendies-gironde-2026_coordinator-user-12345',
              uid: 'coordinator-user-12345',
              mobilizationId: 'incendies-gironde-2026',
              active: true,
              identity: UserDisplayIdentity(
                uid: 'coordinator-user-12345',
                displayName: 'Camille Martin',
                professionLabel: 'Coordinateur',
                organizationLabel: 'Périmètre départemental',
              ),
            ),
          ],
    ),
  );
}

final _activeMobilization = Mobilization(
  id: 'incendies-gironde-2026',
  territoryId: 'gironde',
  name: 'Incendies Gironde',
  subtitle: 'Incendies Gironde',
  contextType: MobilizationContextType.fire,
  status: MobilizationStatus.active,
  createdBy: 'platform-admin',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 10),
  activatedBy: 'platform-admin',
  activatedAt: DateTime.utc(2026, 8, 10),
  schemaVersion: 1,
);

final _previewMobilization = Mobilization(
  id: 'mobilization-preview',
  operationId: 'operation-preview',
  territoryId: 'gironde',
  name: 'Mobilisation de prévisualisation',
  subtitle: 'Gironde',
  contextType: MobilizationContextType.other,
  status: MobilizationStatus.active,
  createdBy: 'platform-admin',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 10),
  activatedBy: 'platform-admin',
  activatedAt: DateTime.utc(2026, 8, 10),
  schemaVersion: 2,
);

final _previewOperation = Operation(
  id: 'operation-preview',
  name: 'Opération de prévisualisation',
  type: OperationType.exercise,
  status: OperationStatus.active,
  startAt: DateTime.utc(2026, 8, 1),
  scopeRefs: const [
    OperationalScopeRef(kind: OperationalScopeKind.territory, id: 'gironde'),
  ],
  createdBy: 'platform-admin',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedBy: 'platform-admin',
  updatedAt: DateTime.utc(2026, 8, 10),
  schemaVersion: 1,
);

final _otherPreviewMobilization = Mobilization(
  id: 'mobilization-other-operation',
  operationId: 'operation-other',
  territoryId: 'gironde',
  name: 'Mobilisation hors contexte',
  subtitle: 'Autre opération',
  contextType: MobilizationContextType.other,
  status: MobilizationStatus.active,
  createdBy: 'platform-admin',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 10),
  activatedBy: 'platform-admin',
  activatedAt: DateTime.utc(2026, 8, 10),
  schemaVersion: 2,
);

final _otherPreviewOperation = Operation(
  id: 'operation-other',
  name: 'Opération hors contexte',
  type: OperationType.exercise,
  status: OperationStatus.active,
  startAt: DateTime.utc(2026, 8, 2),
  scopeRefs: const [
    OperationalScopeRef(kind: OperationalScopeKind.territory, id: 'gironde'),
  ],
  createdBy: 'platform-admin',
  createdAt: DateTime.utc(2026, 8, 1),
  updatedBy: 'platform-admin',
  updatedAt: DateTime.utc(2026, 8, 10),
  schemaVersion: 1,
);

CoordinationNeed _previewMission(ResponsePlace location) => CoordinationNeed(
  id: 'mission-preview',
  mobilizationId: _previewMobilization.id,
  locationId: location.id,
  place: location.name,
  group: location.group,
  date: 'demain',
  time: '12:00 — 16:00',
  requiredPhysiotherapists: 1,
  registeredPhysiotherapists: 0,
  requiredPodiatrists: 0,
  registeredPodiatrists: 0,
  equipment: const [],
  startAt: DateTime.utc(2026, 8, 20, 12),
  updatedAt: DateTime.utc(2026, 8, 18, 12),
);

CoordinationNeed _secondPreviewMission(ResponsePlace location) =>
    CoordinationNeed(
      id: 'mission-preview-second-center',
      mobilizationId: _previewMobilization.id,
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: 'demain',
      time: '16:00 — 20:00',
      requiredPhysiotherapists: 1,
      registeredPhysiotherapists: 1,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const [],
      startAt: DateTime.utc(2026, 8, 20, 16),
      updatedAt: DateTime.utc(2026, 8, 18, 12),
    );

CoordinationNeed _otherPreviewMission(ResponsePlace location) =>
    CoordinationNeed(
      id: 'mission-other-operation',
      mobilizationId: _otherPreviewMobilization.id,
      locationId: location.id,
      place: location.name,
      group: location.group,
      date: 'après-demain',
      time: '09:00 — 12:00',
      requiredPhysiotherapists: 2,
      registeredPhysiotherapists: 0,
      requiredPodiatrists: 0,
      registeredPodiatrists: 0,
      equipment: const [],
      startAt: DateTime.utc(2026, 8, 21, 9),
      updatedAt: DateTime.utc(2026, 8, 18, 12),
    );

final _gironde = Territory(
  id: 'gironde',
  name: 'Gironde',
  code: '33',
  active: true,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 10),
);

class _FakePlatformRuntime implements PlatformRuntime {
  const _FakePlatformRuntime({
    required this.platformRepository,
    required this.currentMobilizationProvider,
    required this.administrationRepository,
  });

  @override
  PlatformReadRepository get platformReadRepository => platformRepository;

  final PlatformReadRepository platformRepository;

  @override
  final MobilizationContextProvider currentMobilizationProvider;

  final PlatformAdministrationReadRepository administrationRepository;

  @override
  PlatformAdministrationReadRepository
  get platformAdministrationReadRepository => administrationRepository;

  @override
  PlatformAdministrationService get platformAdministrationService =>
      const NoPlatformAdministrationService();
}

class _MultiPreviewRuntime
    implements PlatformRuntime, MultiOperationPlatformRuntime {
  _MultiPreviewRuntime({
    PlatformAdministrationService? administrationService,
    List<Mobilization>? mobilizations,
    List<Operation>? operations,
  }) : _platformRepository = _FakePlatformReadRepository(
         activeMobilization: _previewMobilization,
         mobilizations: mobilizations ?? [_previewMobilization],
       ),
       _administrationRepository = const _FakeAdministrationReadRepository(
         administrator: PlatformAdministratorAccess(
           uid: 'platform-admin',
           active: true,
         ),
         assignments: [],
       ),
       _administrationService =
           administrationService ?? const NoPlatformAdministrationService(),
       _operationRepository = _PreviewOperationRepository(
         operations ?? [_previewOperation],
       );

  final _FakePlatformReadRepository _platformRepository;
  final _FakeAdministrationReadRepository _administrationRepository;
  final PlatformAdministrationService _administrationService;
  final OperationReadRepository _operationRepository;

  @override
  PlatformReadRepository get platformReadRepository => _platformRepository;

  @override
  MobilizationContextProvider get currentMobilizationProvider =>
      _FakeMobilizationProvider(
        Stream.value(
          MobilizationContext(
            mobilizationId: _previewMobilization.id,
            territoryId: _previewMobilization.territoryId,
            status: _previewMobilization.status,
          ),
        ),
      );

  @override
  PlatformAdministrationReadRepository
  get platformAdministrationReadRepository => _administrationRepository;

  @override
  PlatformAdministrationService get platformAdministrationService =>
      _administrationService;

  @override
  OperationReadRepository get operationReadRepository => _operationRepository;

  @override
  AccessibleMobilizationsProvider get accessibleMobilizationsProvider =>
      const _UnavailableAccessibleMobilizations();

  @override
  OperationalContextProvider get operationalContextProvider =>
      const _UnavailableOperationalContextProvider();
}

class _SessionAdministrationService extends NoPlatformAdministrationService
    implements PlatformAdministrationSessionProvider {
  _SessionAdministrationService(this.sessionState);

  @override
  final PlatformAdministrationSessionController sessionState;

  int createOperationCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<void> createOperation(OperationAdministrationDraft draft) async {
    if (sessionState.value == PlatformAdministrationSessionState.expired) {
      throw const PlatformAdministrationException(
        'Votre session a expiré. Reconnectez-vous.',
      );
    }
    createOperationCalls++;
  }
}

class _PreviewOperationRepository implements OperationReadRepository {
  const _PreviewOperationRepository(this.operations);

  final List<Operation> operations;

  @override
  Stream<Operation?> watchOperation(String operationId) => Stream.value(
    operations.where((operation) => operation.id == operationId).firstOrNull,
  );

  @override
  Stream<List<Operation>> watchOperations({Set<OperationStatus>? statuses}) =>
      Stream.value(
        operations
            .where(
              (operation) =>
                  statuses == null || statuses.contains(operation.status),
            )
            .toList(growable: false),
      );
}

class _UnavailableAccessibleMobilizations
    implements AccessibleMobilizationsProvider {
  const _UnavailableAccessibleMobilizations();

  @override
  Stream<List<Mobilization>> watchAccessibleMobilizations() =>
      const Stream.empty();
}

class _UnavailableOperationalContextProvider
    implements OperationalContextProvider {
  const _UnavailableOperationalContextProvider();

  @override
  Stream<OperationalMissionContext?> watchForMobilization(
    String mobilizationId,
  ) => const Stream.empty();
}

class _FakeMobilizationProvider implements MobilizationContextProvider {
  const _FakeMobilizationProvider(this.contextStream);

  final Stream<MobilizationContext?> contextStream;

  @override
  Stream<String?> watchActiveMobilizationId() =>
      contextStream.map((context) => context?.mobilizationId);

  @override
  Stream<MobilizationContext?> watchContext() => contextStream;
}

class _FakePlatformReadRepository implements PlatformReadRepository {
  const _FakePlatformReadRepository({
    required this.activeMobilization,
    this.mobilizations = const [],
  });

  final Mobilization? activeMobilization;
  final List<Mobilization> mobilizations;

  @override
  Stream<Mobilization?> watchActiveMobilization() =>
      Stream<Mobilization?>.value(activeMobilization);

  @override
  Stream<List<Mobilization>> watchMobilizations({
    String? territoryId,
    bool includeInactive = false,
  }) => Stream<List<Mobilization>>.multi(
    (controller) => controller.add(
      mobilizations.isNotEmpty
          ? mobilizations
          : activeMobilization == null
          ? const []
          : [activeMobilization!],
    ),
  );

  @override
  Stream<String?> watchPlatformConfig() =>
      Stream<String?>.value(activeMobilization?.id);

  @override
  Stream<List<Territory>> watchTerritories() =>
      Stream<List<Territory>>.value([_gironde]);
}

class _FakeAdministrationReadRepository
    implements PlatformAdministrationReadRepository {
  const _FakeAdministrationReadRepository({
    required this.administrator,
    required this.assignments,
  });

  final PlatformAdministratorAccess? administrator;
  final List<MobilizationCoordinatorAssignment> assignments;

  @override
  Stream<List<ActivePlatformCoordinator>> watchActiveCoordinators() =>
      Stream<List<ActivePlatformCoordinator>>.value(
        assignments
            .where((assignment) => assignment.active)
            .map((assignment) => ActivePlatformCoordinator(uid: assignment.uid))
            .toList(growable: false),
      );

  @override
  Stream<PlatformAdministratorAccess?> watchCurrentAdministrator() =>
      Stream<PlatformAdministratorAccess?>.value(administrator);

  @override
  Stream<List<MobilizationCoordinatorAssignment>> watchMobilizationCoordinators(
    String mobilizationId,
  ) => Stream<List<MobilizationCoordinatorAssignment>>.value(
    assignments
        .where((assignment) => assignment.mobilizationId == mobilizationId)
        .toList(growable: false),
  );
}
