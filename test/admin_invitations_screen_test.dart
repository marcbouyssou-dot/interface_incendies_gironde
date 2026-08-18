import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/admin_invitation.dart';
import 'package:interface_incendies_gironde/models/responsible_account.dart';
import 'package:interface_incendies_gironde/repositories/admin_invitation_repository.dart';
import 'package:interface_incendies_gironde/repositories/admin_invitation_repository_scope.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/live_data_scope.dart';
import 'package:interface_incendies_gironde/repositories/mock_admin_invitation_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/repository_scope.dart';
import 'package:interface_incendies_gironde/repositories/responsible_access_administration_repository.dart';
import 'package:interface_incendies_gironde/screens/admin_invitations_screen.dart';
import 'package:interface_incendies_gironde/widgets/v5_form_system.dart';
import 'package:interface_incendies_gironde/widgets/v5_controls.dart';
import 'package:interface_incendies_gironde/theme/app_theme.dart';

void main() {
  const coordinator = ResponsibleAccess(
    uid: 'coord',
    role: 'coordinator',
    locationIds: {'*'},
    active: true,
  );
  const manager = ResponsibleAccess(
    uid: 'manager',
    role: 'site_manager',
    locationIds: {'merignac'},
    active: true,
  );
  final now = DateTime.now();

  Future<MockCoordinationRepository> pumpApp(
    WidgetTester tester, {
    ResponsibleAccess? access = coordinator,
    AdminInvitationRepository? invitationRepository,
    ResponsibleAccessAdministrationRepository? accessRepository,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockCoordinationRepository(
      responsibleAccess: access,
      adminInvitationRepository:
          invitationRepository ?? MockAdminInvitationRepository(),
      responsibleAccessAdministrationRepository: accessRepository,
    );
    await tester.pumpWidget(
      FireCoordinationApp(
        repository: repository,
        useLegacyCoordinatorShellForTesting: true,
      ),
    );
    await tester.pumpAndSettle();
    if (access?.roles.contains(ResponsibleRole.coordinator) == true) {
      await tester.tap(find.text('Déclarer'));
      await tester.pumpAndSettle();
    }
    return repository;
  }

  Future<void> openInvitations(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('admin-invitations-entry')));
    await tester.pumpAndSettle();
  }

  Future<void> openInvitationForm(WidgetTester tester) async {
    final inviteButton = find.byKey(const Key('invite-admin-button'));
    await tester.ensureVisible(inviteButton);
    await tester.pumpAndSettle();
    await tester.tap(inviteButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('admin-invitation-form')), findsOneWidget);
  }

  Future<void> revealInvitationControl(WidgetTester tester, Key key) async {
    final control = find.byKey(key);
    await tester.scrollUntilVisible(
      control,
      180,
      scrollable: _scrollableInside(const Key('admin-invitation-form')),
    );
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
  }

  Future<void> revealListControl(WidgetTester tester, Key key) async {
    final control = find.byKey(key);
    final scrollable = _scrollableInside(const Key('admin-invitations-list'));
    for (
      var attempt = 0;
      attempt < 8 && control.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(scrollable, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(control);
    await tester.pumpAndSettle();
  }

  Future<void> enterInvitationText(
    WidgetTester tester,
    Key key,
    String text,
  ) async {
    await revealInvitationControl(tester, key);
    final editable = find.descendant(
      of: find.byKey(key),
      matching: find.byType(EditableText),
    );
    expect(editable, findsOneWidget);
    await tester.enterText(editable, text);
  }

  Future<void> tapInvitationControl(WidgetTester tester, Key key) async {
    await revealInvitationControl(tester, key);
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard entry is visible only to an active coordinator', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('admin-invitations-entry')), findsOneWidget);

    await pumpApp(tester, access: manager);
    expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);

    await pumpApp(tester, access: null);
    expect(find.byKey(const Key('admin-invitations-entry')), findsNothing);
  });

  testWidgets('coordinator sees the empty invitation state', (tester) async {
    await pumpApp(tester);
    await openInvitations(tester);

    expect(find.text('Responsables'), findsWidgets);
    expect(find.text('Invitations et accès aux centres'), findsOneWidget);
    expect(find.text('Aucune invitation pour le moment.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'responsible accounts recover after retry while invitations stay visible',
    (tester) async {
      final accessRepository = _FlakyResponsibleAccessRepository();
      final invitationsRepository = MockAdminInvitationRepository(
        initialInvitations: [
          _invitation(
            id: 'pending-visible',
            status: AdminInvitationStatus.pending,
            now: now,
          ),
        ],
        now: () => now,
      );
      addTearDown(invitationsRepository.dispose);
      await pumpApp(
        tester,
        invitationRepository: invitationsRepository,
        accessRepository: accessRepository,
      );
      await openInvitations(tester);

      expect(
        find.byKey(const Key('invitation-card-pending-visible')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('responsible-accounts-section')));
      await tester.pump();
      accessRepository.failFirst();
      await tester.pumpAndSettle();
      expect(
        find.text('Les accès responsables ne sont pas disponibles.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Réessayer'));
      await tester.pumpAndSettle();

      expect(accessRepository.calls, 2);
      expect(
        find.byKey(const Key('responsible-account-manager')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('manage-responsible-manager')),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        find.byKey(const Key('invitation-card-pending-visible')),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('invalid V2 access blocks invitation administration explicitly', (
    tester,
  ) async {
    final repository = _InvalidAccessRepository();
    final liveData = LiveCoordinationData(repository);
    addTearDown(liveData.dispose);

    await tester.pumpWidget(
      RepositoryScope(
        repository: repository,
        child: AdminInvitationRepositoryScope(
          repository: repository.adminInvitationRepository,
          child: LiveCoordinationDataScope(
            data: liveData,
            child: MaterialApp(
              theme: AppTheme.light,
              home: const AdminInvitationsScreen(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configuration d’accès invalide'), findsOneWidget);
    expect(find.byKey(const Key('invite-admin-button')), findsNothing);
    expect(find.text('Aucune invitation pour le moment.'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('list hides accepted invitations and renders unused statuses', (
    tester,
  ) async {
    final invitations = [
      _invitation(
        id: 'pending',
        status: AdminInvitationStatus.pending,
        now: now,
      ),
      _invitation(
        id: 'accepted',
        status: AdminInvitationStatus.accepted,
        now: now,
      ),
      _invitation(
        id: 'expired',
        status: AdminInvitationStatus.expired,
        now: now,
      ),
      _invitation(
        id: 'cancelled',
        status: AdminInvitationStatus.cancelled,
        now: now,
        locationIds: {'missing-location'},
      ),
    ];
    final invitationsRepository = MockAdminInvitationRepository(
      initialInvitations: invitations,
      now: () => now,
    );
    addTearDown(invitationsRepository.dispose);
    await pumpApp(tester, invitationRepository: invitationsRepository);
    await openInvitations(tester);
    await revealListControl(tester, const Key('invitation-card-pending'));

    expect(find.text('En attente'), findsOneWidget);
    expect(find.byKey(const Key('invitation-card-accepted')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('invitation-card-cancelled')),
      250,
      scrollable: _scrollableInside(const Key('admin-invitations-list')),
    );
    expect(find.text('Expirée'), findsOneWidget);
    expect(find.text('Annulée'), findsOneWidget);
    expect(find.text('Renvoyer'), findsOneWidget);
    expect(find.text('Lieu indisponible'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form normalizes email and preserves the responsible name', (
    tester,
  ) async {
    final invitationsRepository = MockAdminInvitationRepository(now: () => now);
    addTearDown(invitationsRepository.dispose);
    await pumpApp(tester, invitationRepository: invitationsRepository);
    await openInvitations(tester);
    await openInvitationForm(tester);

    await enterInvitationText(
      tester,
      const Key('invitation-display-name'),
      '  Camille Martin  ',
    );
    await enterInvitationText(
      tester,
      const Key('invitation-email'),
      ' CAMILLE@EXEMPLE.FR ',
    );
    final location = places.where((place) => place.isOperational).first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('location-search')),
      250,
      scrollable: _scrollableInside(const Key('admin-invitation-form')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(Key('invitation-location-${location.id}')),
      120,
      scrollable: _scrollableInside(const Key('location-selector-list')),
    );
    await tester.tap(find.byKey(Key('invitation-location-${location.id}')));
    await tester.pump();
    expect(find.byKey(const Key('create-admin-invitation')), findsOneWidget);
    await tester.tap(find.byKey(const Key('create-admin-invitation')));
    await tester.pumpAndSettle();

    final created =
        (await invitationsRepository.watchInvitations().first).single;
    expect(created.displayName, '  Camille Martin  ');
    expect(created.email, 'camille@exemple.fr');
    expect(created.role, AdminInvitationDraft.siteManagerRole);
    expect(created.locationIds, {location.id});
    expect(created.status, AdminInvitationStatus.pending);
    expect(
      find.text(
        'Invitation créée. Préparez maintenant le compte pour envoyer '
        'l’e-mail d’activation.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('coordinator invitation has no location restriction', (
    tester,
  ) async {
    final invitationsRepository = MockAdminInvitationRepository(now: () => now);
    addTearDown(invitationsRepository.dispose);
    await pumpApp(tester, invitationRepository: invitationsRepository);
    await openInvitations(tester);
    await openInvitationForm(tester);
    await enterInvitationText(
      tester,
      const Key('invitation-display-name'),
      'Coordination Gironde',
    );
    await enterInvitationText(
      tester,
      const Key('invitation-email'),
      'coord@example.fr',
    );
    await tapInvitationControl(tester, const Key('invitation-role'));
    await tester.tap(find.text('Coordinateur').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-search')), findsNothing);

    await tester.tap(find.byKey(const Key('create-admin-invitation')));
    await tester.pumpAndSettle();
    final created =
        (await invitationsRepository.watchInvitations().first).single;
    expect(created.role, AdminInvitationDraft.coordinatorRole);
    expect(created.locationIds, isEmpty);
  });

  testWidgets(
    'submit action stays visible and follows form validity on iPhone',
    (tester) async {
      await pumpApp(tester);
      await openInvitations(tester);
      await openInvitationForm(tester);

      final submitFinder = find.byKey(const Key('create-admin-invitation'));
      expect(submitFinder, findsOneWidget);
      expect(tester.getRect(submitFinder).bottom, lessThanOrEqualTo(844));
      expect(tester.widget<V5Button>(submitFinder).onPressed, isNull);

      await enterInvitationText(
        tester,
        const Key('invitation-display-name'),
        'Responsable mobile',
      );
      await enterInvitationText(
        tester,
        const Key('invitation-email'),
        'mobile@mobsante.fr',
      );
      await tester.pump();
      expect(tester.widget<V5Button>(submitFinder).onPressed, isNotNull);

      final location = places.where((place) => place.isOperational).first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('location-search')),
        250,
        scrollable: _scrollableInside(const Key('admin-invitation-form')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('invitation-location-${location.id}')));
      await tester.pump();
      expect(tester.widget<V5Button>(submitFinder).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('location-search')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
      await tester.pumpAndSettle();
      expect(submitFinder, findsOneWidget);
      expect(tester.getRect(submitFinder).bottom, lessThanOrEqualTo(544));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('form refuses an email beyond the Firebase Auth boundary', (
    tester,
  ) async {
    await pumpApp(tester);
    await openInvitations(tester);
    await openInvitationForm(tester);
    await enterInvitationText(
      tester,
      const Key('invitation-display-name'),
      'Responsable mobile',
    );
    final submitFinder = find.byKey(const Key('create-admin-invitation'));

    await enterInvitationText(
      tester,
      const Key('invitation-email'),
      '${List.filled(243, 'a').join()}@example.com',
    );
    await tester.pump();
    expect(tester.widget<V5Button>(submitFinder).onPressed, isNotNull);

    await enterInvitationText(
      tester,
      const Key('invitation-email'),
      '${List.filled(244, 'a').join()}@example.com',
    );
    await tester.pump();
    expect(tester.widget<V5Button>(submitFinder).onPressed, isNull);
  });

  testWidgets(
    'invalid local scope never reaches repository and form stays reusable',
    (tester) async {
      final invitationsRepository = MockAdminInvitationRepository(
        now: () => now,
      );
      addTearDown(invitationsRepository.dispose);
      await pumpApp(tester, invitationRepository: invitationsRepository);
      await openInvitations(tester);
      await openInvitationForm(tester);
      await enterInvitationText(
        tester,
        const Key('invitation-display-name'),
        'Responsable récupérable',
      );
      await enterInvitationText(
        tester,
        const Key('invitation-email'),
        'recuperable@mobsante.fr',
      );
      await tester.pump();

      final submitFinder = find.byKey(const Key('create-admin-invitation'));
      final submitButton = tester.widget<V5Button>(submitFinder);
      expect(submitButton.onPressed, isNotNull);
      submitButton.onPressed!();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(
          'Un responsable de site doit être associé à au moins un centre.',
        ),
        findsOneWidget,
      );
      expect(await invitationsRepository.watchInvitations().first, isEmpty);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<V5Button>(submitFinder).onPressed, isNotNull);

      final location = places.where((place) => place.isOperational).first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('location-search')),
        250,
        scrollable: _scrollableInside(const Key('admin-invitation-form')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('invitation-location-${location.id}')));
      await tester.pump();
      await tester.tap(submitFinder);
      await tester.pumpAndSettle();

      expect(
        (await invitationsRepository.watchInvitations().first)
            .single
            .locationIds,
        {location.id},
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('server creation error resets double-submit protection', (
    tester,
  ) async {
    final invitationsRepository = _CreateInvitationRepository(now);
    await pumpApp(tester, invitationRepository: invitationsRepository);
    await openInvitations(tester);
    await openInvitationForm(tester);
    await enterInvitationText(
      tester,
      const Key('invitation-display-name'),
      'Coordination test',
    );
    await enterInvitationText(
      tester,
      const Key('invitation-email'),
      'coord-test@mobsante.fr',
    );
    await tapInvitationControl(tester, const Key('invitation-role'));
    await tester.tap(find.text('Coordinateur').last);
    await tester.pumpAndSettle();

    final submitFinder = find.byKey(const Key('create-admin-invitation'));
    await tester.tap(submitFinder);
    await tester.pump();
    expect(invitationsRepository.calls, 1);
    expect(tester.widget<V5Button>(submitFinder).onPressed, isNull);
    await tester.tap(submitFinder);
    expect(invitationsRepository.calls, 1);

    invitationsRepository.failFirst();
    await tester.pumpAndSettle();
    expect(
      find.text('L’invitation n’a pas pu être créée. Réessayez.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<V5Button>(submitFinder).onPressed, isNotNull);

    await tester.tap(submitFinder);
    await tester.pumpAndSettle();
    expect(invitationsRepository.calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('role and validity choices keep their existing behavior', (
    tester,
  ) async {
    await pumpApp(tester);
    await openInvitations(tester);
    await openInvitationForm(tester);

    await tapInvitationControl(tester, const Key('invitation-expiration'));
    await tester.tap(find.text('14 jours').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<V5SelectField<int>>(
            find.byKey(const Key('invitation-expiration')),
          )
          .value,
      14,
    );
    expect(find.text('14 jours'), findsOneWidget);

    await tapInvitationControl(tester, const Key('invitation-role'));
    await tester.tap(find.text('Coordinateur').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-search')), findsNothing);

    await tapInvitationControl(tester, const Key('invitation-role'));
    await tester.tap(find.text('Responsable').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-search')), findsOneWidget);
    expect(find.text('14 jours'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending invitation can be cancelled after confirmation', (
    tester,
  ) async {
    final repository = MockAdminInvitationRepository(
      initialInvitations: [
        _invitation(
          id: 'pending',
          status: AdminInvitationStatus.pending,
          now: now,
        ),
      ],
      now: () => now,
    );
    addTearDown(repository.dispose);
    await pumpApp(tester, invitationRepository: repository);
    await openInvitations(tester);
    await revealListControl(tester, const Key('cancel-invitation-pending'));
    await tester.tap(find.byKey(const Key('cancel-invitation-pending')));
    await tester.pumpAndSettle();

    expect(find.text('Annuler cette invitation ?'), findsOneWidget);
    await tester.tap(find.text('Annuler l’invitation'));
    await tester.pumpAndSettle();

    expect(
      (await repository.getInvitation('pending'))?.status,
      AdminInvitationStatus.cancelled,
    );
    expect(find.byKey(const Key('cancel-invitation-pending')), findsNothing);
  });

  testWidgets(
    'pending and cancelled cards expose only their lifecycle actions',
    (tester) async {
      final repository = MockAdminInvitationRepository(
        initialInvitations: [
          _invitation(
            id: 'pending',
            status: AdminInvitationStatus.pending,
            now: now,
          ),
          _invitation(
            id: 'cancelled',
            status: AdminInvitationStatus.cancelled,
            now: now,
          ),
        ],
        now: () => now,
      );
      addTearDown(repository.dispose);
      await pumpApp(tester, invitationRepository: repository);
      await openInvitations(tester);
      await revealListControl(tester, const Key('edit-invitation-pending'));

      expect(find.byKey(const Key('edit-invitation-pending')), findsOneWidget);
      expect(
        find.byKey(const Key('cancel-invitation-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resend-invitation-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('delete-invitation-pending')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('invitation-card-cancelled')),
        250,
        scrollable: _scrollableInside(const Key('admin-invitations-list')),
      );
      expect(
        find.byKey(const Key('reactivate-invitation-cancelled')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('edit-invitation-cancelled')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('delete-invitation-cancelled')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resend-invitation-cancelled')),
        findsNothing,
      );
    },
  );

  testWidgets('cancelled invitation can be reactivated with a new expiration', (
    tester,
  ) async {
    final repository = MockAdminInvitationRepository(
      initialInvitations: [
        _invitation(
          id: 'cancelled',
          status: AdminInvitationStatus.cancelled,
          now: now,
        ),
      ],
      now: () => now,
    );
    addTearDown(repository.dispose);
    await pumpApp(tester, invitationRepository: repository);
    await openInvitations(tester);
    await tester.tap(find.byKey(const Key('reactivate-invitation-cancelled')));
    await tester.pumpAndSettle();
    expect(find.text('Réactiver cette invitation ?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-reactivate-invitation')));
    await tester.pumpAndSettle();

    final reactivated = await repository.getInvitation('cancelled');
    expect(reactivated?.status, AdminInvitationStatus.pending);
    expect(reactivated?.expiresAt.isAfter(now), isTrue);
    expect(find.text('Invitation réactivée.'), findsOneWidget);
  });

  testWidgets('unused invitation can be edited without changing its email', (
    tester,
  ) async {
    final repository = MockAdminInvitationRepository(
      initialInvitations: [
        _invitation(
          id: 'cancelled',
          status: AdminInvitationStatus.cancelled,
          now: now,
        ),
      ],
      now: () => now,
    );
    addTearDown(repository.dispose);
    await pumpApp(tester, invitationRepository: repository);
    await openInvitations(tester);
    final editButton = find.byKey(const Key('edit-invitation-cancelled'));
    await tester.ensureVisible(editButton);
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(find.text('Modifier l’invitation'), findsOneWidget);
    expect(find.byKey(const Key('admin-invitation-form')), findsOneWidget);
    await revealInvitationControl(tester, const Key('invitation-email'));
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: find.byKey(const Key('invitation-email')),
              matching: find.byType(EditableText),
            ),
          )
          .readOnly,
      isTrue,
    );
    await enterInvitationText(
      tester,
      const Key('invitation-display-name'),
      'Responsable modifié',
    );
    await tapInvitationControl(tester, const Key('invitation-role'));
    await tester.tap(find.text('Coordinateur').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-admin-invitation')));
    await tester.pumpAndSettle();

    final updated = await repository.getInvitation('cancelled');
    expect(updated?.email, 'cancelled@example.fr');
    expect(updated?.displayName, 'Responsable modifié');
    expect(updated?.role, AdminInvitationDraft.coordinatorRole);
    expect(updated?.locationIds, isEmpty);
    expect(updated?.status, AdminInvitationStatus.cancelled);
  });

  testWidgets('unused invitation deletion requires irreversible confirmation', (
    tester,
  ) async {
    final repository = MockAdminInvitationRepository(
      initialInvitations: [
        _invitation(
          id: 'pending',
          status: AdminInvitationStatus.pending,
          now: now,
        ),
      ],
      now: () => now,
    );
    addTearDown(repository.dispose);
    await pumpApp(tester, invitationRepository: repository);
    await openInvitations(tester);
    await revealListControl(tester, const Key('delete-invitation-pending'));
    await tester.tap(find.byKey(const Key('delete-invitation-pending')));
    await tester.pumpAndSettle();

    expect(
      find.text('Supprimer définitivement cette invitation ?'),
      findsOneWidget,
    );
    expect(find.text('Cette opération est irréversible.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-delete-invitation')));
    await tester.pumpAndSettle();

    expect(await repository.getInvitation('pending'), isNull);
    expect(find.text('Invitation supprimée.'), findsOneWidget);
  });

  testWidgets('resend confirms immediate activation email delivery', (
    tester,
  ) async {
    final repository = _ProvisionInvitationRepository(
      _invitation(
        id: 'pending',
        status: AdminInvitationStatus.pending,
        now: now,
      ),
    );
    await pumpApp(tester, invitationRepository: repository);
    await openInvitations(tester);
    await revealListControl(tester, const Key('resend-invitation-pending'));

    await tester.tap(find.byKey(const Key('resend-invitation-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Renvoyer l’e-mail d’activation ?'), findsOneWidget);
    expect(
      find.textContaining('envoie un nouveau lien d’activation'),
      findsOneWidget,
    );
    expect(find.textContaining('même identifiant'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-resend-invitation')));
    await tester.pump();

    expect(repository.calls, 1);
    expect(repository.resend, isTrue);
    expect(find.text('Envoi…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resend-invitation-pending')));
    expect(repository.calls, 1);

    repository.complete();
    await tester.pumpAndSettle();
    expect(find.text('E-mail d’activation envoyé.'), findsOneWidget);
    expect(find.textContaining('compte activé'), findsNothing);
    expect(find.textContaining('Compte activé'), findsNothing);
  });

  testWidgets('resend error is explicit and keeps the pending action', (
    tester,
  ) async {
    final repository = _ProvisionInvitationRepository(
      _invitation(
        id: 'pending',
        status: AdminInvitationStatus.pending,
        now: now,
      ),
    );
    await pumpApp(tester, invitationRepository: repository);
    await openInvitations(tester);
    await revealListControl(tester, const Key('resend-invitation-pending'));
    await tester.tap(find.byKey(const Key('resend-invitation-pending')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-resend-invitation')));
    await tester.pump();
    repository.fail();
    await tester.pumpAndSettle();

    expect(
      find.text('L’e-mail d’activation n’a pas pu être envoyé.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('resend-invitation-pending')), findsOneWidget);
  });

  testWidgets('invitation listener is stable across rebuilds', (tester) async {
    final repository = _CountingInvitationRepository();
    await pumpApp(tester, invitationRepository: repository);
    await openInvitations(tester);
    expect(repository.watchCalls, 1);

    await tester.binding.setSurfaceSize(const Size(430, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
    expect(repository.watchCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

Finder _scrollableInside(Key key) => find
    .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
    .first;

AdminInvitation _invitation({
  required String id,
  required AdminInvitationStatus status,
  required DateTime now,
  Set<String> locationIds = const {'merignac'},
}) {
  return AdminInvitation(
    id: id,
    email: '$id@example.fr',
    displayName: 'Responsable $id',
    role: AdminInvitationDraft.siteManagerRole,
    locationIds: locationIds,
    createdBy: 'coord',
    createdAt: now,
    expiresAt: now.add(const Duration(days: 7)),
    status: status,
  );
}

class _CountingInvitationRepository implements AdminInvitationRepository {
  int watchCalls = 0;

  @override
  Stream<List<AdminInvitation>> watchInvitations() {
    watchCalls++;
    return Stream.value(const []);
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {}

  @override
  Future<AdminInvitation> createInvitation(AdminInvitationDraft draft) =>
      throw UnimplementedError();

  @override
  Future<AdminInvitation?> getInvitation(String invitationId) async => null;

  @override
  Future<AdminProvisioningResult> provisionInvitation(
    String invitationId, {
    bool resend = false,
  }) async => const AdminProvisioningResult(
    accountProvisioned: true,
    emailDelivery: 'pending',
    alreadyProvisioned: false,
  );

  @override
  Future<void> deleteInvitation(String invitationId) async {}

  @override
  Future<void> reactivateInvitation(
    String invitationId,
    DateTime expiresAt,
  ) async {}

  @override
  Future<AdminInvitation> updateInvitation(
    String invitationId,
    AdminInvitationUpdate update,
  ) => throw UnimplementedError();
}

class _FlakyResponsibleAccessRepository
    implements ResponsibleAccessAdministrationRepository {
  final Completer<List<ResponsibleAccount>> _first = Completer();
  int calls = 0;

  void failFirst() => _first.completeError(
    const ResponsibleAccessAdministrationException('Échec callable contrôlé.'),
  );

  @override
  Future<List<ResponsibleAccount>> listAccounts() {
    calls += 1;
    if (calls == 1) return _first.future;
    return Future.value([
      ResponsibleAccount(
        access: ResponsibleAccess.v2(
          uid: 'manager',
          roles: const [ResponsibleRole.siteManager],
          locationIds: const {'merignac'},
          active: false,
        ),
        email: 'manager@example.test',
      ),
    ]);
  }

  @override
  Future<ResponsibleAccount> updateAccess(ResponsibleAccessUpdate update) =>
      throw UnimplementedError();
}

class _InvalidAccessRepository extends MockCoordinationRepository {
  @override
  Stream<ResponsibleAccess?> watchResponsibleAccess() =>
      Stream<ResponsibleAccess?>.error(
        const ResponsibleAccessFormatException(
          ResponsibleAccessFormatError.invalidRoles,
          'invalid V2 roles',
        ),
      );
}

class _ProvisionInvitationRepository implements AdminInvitationRepository {
  _ProvisionInvitationRepository(this.invitation);

  final AdminInvitation invitation;
  final Completer<AdminProvisioningResult> _completer = Completer();
  int calls = 0;
  bool? resend;

  void complete() => _completer.complete(
    const AdminProvisioningResult(
      accountProvisioned: true,
      emailDelivery: 'sent',
      alreadyProvisioned: false,
    ),
  );

  void fail() => _completer.completeError(StateError('server failed'));

  @override
  Stream<List<AdminInvitation>> watchInvitations() =>
      Stream.value([invitation]);

  @override
  Future<AdminProvisioningResult> provisionInvitation(
    String invitationId, {
    bool resend = false,
  }) {
    calls++;
    this.resend = resend;
    return _completer.future;
  }

  @override
  Future<void> cancelInvitation(String invitationId) async {}

  @override
  Future<AdminInvitation> createInvitation(AdminInvitationDraft draft) =>
      throw UnimplementedError();

  @override
  Future<AdminInvitation?> getInvitation(String invitationId) async =>
      invitation;

  @override
  Future<void> deleteInvitation(String invitationId) async {}

  @override
  Future<void> reactivateInvitation(
    String invitationId,
    DateTime expiresAt,
  ) async {}

  @override
  Future<AdminInvitation> updateInvitation(
    String invitationId,
    AdminInvitationUpdate update,
  ) => throw UnimplementedError();
}

class _CreateInvitationRepository implements AdminInvitationRepository {
  _CreateInvitationRepository(this.now);

  final DateTime now;
  final Completer<AdminInvitation> _firstCreation = Completer();
  int calls = 0;

  void failFirst() => _firstCreation.completeError(StateError('server failed'));

  @override
  Future<AdminInvitation> createInvitation(AdminInvitationDraft draft) {
    calls++;
    if (calls == 1) return _firstCreation.future;
    draft.validate(now: now);
    return Future.value(
      AdminInvitation(
        id: 'created-after-retry',
        email: draft.email,
        displayName: draft.displayName,
        role: draft.role,
        locationIds: Set<String>.unmodifiable(draft.locationIds),
        createdBy: 'coord',
        createdAt: now,
        expiresAt: draft.expiresAt,
        status: AdminInvitationStatus.pending,
      ),
    );
  }

  @override
  Stream<List<AdminInvitation>> watchInvitations() => Stream.value(const []);

  @override
  Future<void> cancelInvitation(String invitationId) async {}

  @override
  Future<AdminInvitation?> getInvitation(String invitationId) async => null;

  @override
  Future<AdminProvisioningResult> provisionInvitation(
    String invitationId, {
    bool resend = false,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteInvitation(String invitationId) async {}

  @override
  Future<void> reactivateInvitation(
    String invitationId,
    DateTime expiresAt,
  ) async {}

  @override
  Future<AdminInvitation> updateInvitation(
    String invitationId,
    AdminInvitationUpdate update,
  ) => throw UnimplementedError();
}
