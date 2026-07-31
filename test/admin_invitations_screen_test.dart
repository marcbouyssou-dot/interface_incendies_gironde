import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/app.dart';
import 'package:interface_incendies_gironde/data/mock_data.dart';
import 'package:interface_incendies_gironde/models/admin_invitation.dart';
import 'package:interface_incendies_gironde/repositories/admin_invitation_repository.dart';
import 'package:interface_incendies_gironde/repositories/coordination_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_admin_invitation_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_coordination_repository.dart';

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
  final now = DateTime(2026, 7, 30, 12);

  Future<MockCoordinationRepository> pumpApp(
    WidgetTester tester, {
    ResponsibleAccess? access = coordinator,
    AdminInvitationRepository? invitationRepository,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockCoordinationRepository(
      responsibleAccess: access,
      adminInvitationRepository:
          invitationRepository ?? MockAdminInvitationRepository(),
    );
    await tester.pumpWidget(FireCoordinationApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Déclarer'));
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> openInvitations(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('admin-invitations-entry')));
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

  testWidgets('list renders all statuses and unavailable locations', (
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

    expect(find.text('En attente'), findsOneWidget);
    expect(find.text('Compte préparé'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('invitation-card-cancelled')),
      250,
      scrollable: _scrollableInside(const Key('admin-invitations-list')),
    );
    expect(find.text('Expirée'), findsOneWidget);
    expect(find.text('Annulée'), findsOneWidget);
    expect(find.text('Préparer le compte'), findsOneWidget);
    expect(find.text('Lieu indisponible'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('form normalizes and creates a site manager invitation', (
    tester,
  ) async {
    final invitationsRepository = MockAdminInvitationRepository(now: () => now);
    addTearDown(invitationsRepository.dispose);
    await pumpApp(tester, invitationRepository: invitationsRepository);
    await openInvitations(tester);
    await tester.tap(find.byKey(const Key('invite-admin-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('invitation-display-name')),
      '  Camille Martin  ',
    );
    await tester.enterText(
      find.byKey(const Key('invitation-email')),
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
    expect(created.displayName, 'Camille Martin');
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
    await tester.tap(find.byKey(const Key('invite-admin-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('invitation-display-name')),
      'Coordination Gironde',
    );
    await tester.enterText(
      find.byKey(const Key('invitation-email')),
      'coord@example.fr',
    );
    await tester.tap(find.byKey(const Key('invitation-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coordinateur départemental').last);
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
      await tester.tap(find.byKey(const Key('invite-admin-button')));
      await tester.pumpAndSettle();

      final submitFinder = find.byKey(const Key('create-admin-invitation'));
      expect(submitFinder, findsOneWidget);
      expect(tester.getRect(submitFinder).bottom, lessThanOrEqualTo(844));
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      await tester.enterText(
        find.byKey(const Key('invitation-display-name')),
        'Responsable mobile',
      );
      await tester.enterText(
        find.byKey(const Key('invitation-email')),
        'mobile@mobsante.fr',
      );
      await tester.pump();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);

      final location = places.where((place) => place.isOperational).first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('location-search')),
        250,
        scrollable: _scrollableInside(const Key('admin-invitation-form')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('invitation-location-${location.id}')));
      await tester.pump();
      expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('location-search')));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(() => tester.view.viewInsets = FakeViewPadding.zero);
      await tester.pumpAndSettle();
      expect(submitFinder, findsOneWidget);
      expect(tester.getRect(submitFinder).bottom, lessThanOrEqualTo(544));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('role and validity choices keep their existing behavior', (
    tester,
  ) async {
    await pumpApp(tester);
    await openInvitations(tester);
    await tester.tap(find.byKey(const Key('invite-admin-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('invitation-expiration')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('14 jours').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownButtonFormField<int>>(
            find.byKey(const Key('invitation-expiration')),
          )
          .initialValue,
      14,
    );
    expect(find.text('14 jours'), findsOneWidget);

    await tester.tap(find.byKey(const Key('invitation-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coordinateur départemental').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-search')), findsNothing);

    await tester.tap(find.byKey(const Key('invitation-role')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Responsable de centre').last);
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

  testWidgets('provisioning confirms immediate activation email delivery', (
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

    await tester.tap(find.byKey(const Key('provision-invitation-pending')));
    await tester.pumpAndSettle();
    expect(find.text('Préparer ce compte ?'), findsOneWidget);
    expect(
      find.textContaining('envoie immédiatement l’e-mail d’activation'),
      findsOneWidget,
    );
    expect(find.textContaining('Aucun e-mail ne sera envoyé'), findsNothing);
    expect(find.textContaining('idempotente'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-provision-invitation')));
    await tester.pump();

    expect(repository.calls, 1);
    expect(find.text('Préparation…'), findsOneWidget);
    await tester.tap(find.byKey(const Key('provision-invitation-pending')));
    expect(repository.calls, 1);

    repository.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Compte préparé et e-mail d’activation envoyé.'),
      findsOneWidget,
    );
    expect(find.textContaining('compte activé'), findsNothing);
    expect(find.textContaining('Compte activé'), findsNothing);
  });

  testWidgets('provisioning error is explicit and keeps the pending action', (
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
    await tester.tap(find.byKey(const Key('provision-invitation-pending')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-provision-invitation')));
    await tester.pump();
    repository.fail();
    await tester.pumpAndSettle();

    expect(
      find.text('Le compte n’a pas pu être préparé. Réessayez.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('provision-invitation-pending')),
      findsOneWidget,
    );
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
    String invitationId,
  ) async => const AdminProvisioningResult(
    accountProvisioned: true,
    emailDelivery: 'pending',
    alreadyProvisioned: false,
  );
}

class _ProvisionInvitationRepository implements AdminInvitationRepository {
  _ProvisionInvitationRepository(this.invitation);

  final AdminInvitation invitation;
  final Completer<AdminProvisioningResult> _completer = Completer();
  int calls = 0;

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
  Future<AdminProvisioningResult> provisionInvitation(String invitationId) {
    calls++;
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
}
