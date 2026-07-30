import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/admin_invitation.dart';
import 'package:interface_incendies_gironde/repositories/firestore_admin_invitation_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_admin_invitation_repository.dart';

void main() {
  final now = DateTime.utc(2026, 7, 30, 10);

  AdminInvitationDraft draft() => AdminInvitationDraft(
    email: ' RESPONSABLE@EXEMPLE.FR ',
    displayName: ' Camille Martin ',
    locationIds: {'site-b', 'site-a'},
    expiresAt: now.add(const Duration(days: 7)),
  );

  test('invitation model normalizes and validates its business fields', () {
    final value = draft();
    value.validate(now: now);

    expect(value.email, 'responsable@exemple.fr');
    expect(value.displayName, 'Camille Martin');
    expect(value.role, 'site_manager');
    expect(value.locationIds, {'site-a', 'site-b'});
    expect(
      adminInvitationStatusFromValue('cancelled'),
      AdminInvitationStatus.cancelled,
    );
    expect(
      () => AdminInvitationDraft(
        email: 'invalid',
        displayName: 'Responsable',
        locationIds: {'site-a'},
        expiresAt: now.add(const Duration(days: 1)),
      ).validate(now: now),
      throwsFormatException,
    );
  });

  test('coordinator invitation has no location restriction', () {
    final value = AdminInvitationDraft(
      email: 'coord@example.fr',
      displayName: 'Coordination Gironde',
      role: AdminInvitationDraft.coordinatorRole,
      locationIds: const {},
      expiresAt: now.add(const Duration(days: 7)),
    );
    value.validate(now: now);

    expect(value.role, 'coordinator');
    expect(value.locationIds, isEmpty);
    expect(
      () => AdminInvitationDraft(
        email: 'coord@example.fr',
        displayName: 'Coordination Gironde',
        role: AdminInvitationDraft.coordinatorRole,
        locationIds: const {'site-a'},
        expiresAt: now.add(const Duration(days: 7)),
      ).validate(now: now),
      throwsFormatException,
    );
  });

  test(
    'mock repository creates, reads, watches and cancels invitations',
    () async {
      final repository = MockAdminInvitationRepository(now: () => now);
      addTearDown(repository.dispose);
      final emissions = <List<AdminInvitation>>[];
      final subscription = repository.watchInvitations().listen(emissions.add);
      addTearDown(subscription.cancel);

      final created = await repository.createInvitation(draft());
      expect(created.status, AdminInvitationStatus.pending);
      expect(created.createdBy, 'mock-coordinator');
      expect(
        (await repository.getInvitation(created.id))?.email,
        created.email,
      );

      await repository.cancelInvitation(created.id);
      expect(
        (await repository.getInvitation(created.id))?.status,
        AdminInvitationStatus.cancelled,
      );
      expect(emissions.last.single.status, AdminInvitationStatus.cancelled);
      expect(() => repository.cancelInvitation(created.id), throwsStateError);
    },
  );

  test(
    'firestore repository writes only a pending coordinator invitation',
    () async {
      final source = _FakeInvitationDataSource(now: now);
      final repository = FirestoreAdminInvitationRepository(
        dataSource: source,
        now: () => now,
      );

      final created = await repository.createInvitation(draft());

      expect(created.id, 'invitation-1');
      expect(source.documents.single.data, containsPair('status', 'pending'));
      expect(source.documents.single.data, containsPair('createdBy', 'coord'));
      expect(source.documents.single.data['locationIds'], ['site-a', 'site-b']);
      expect(source.documents.single.data['acceptedAt'], isNull);
      expect(source.createdDocuments, 1);
    },
  );

  test(
    'firestore repository reads and cancels without touching identity',
    () async {
      final source = _FakeInvitationDataSource(now: now)
        ..documents.add(
          AdminInvitationDocument(
            id: 'existing',
            data: _invitationData(now: now),
          ),
        );
      final repository = FirestoreAdminInvitationRepository(
        dataSource: source,
        now: () => now,
      );

      final invitation = await repository.getInvitation('existing');
      expect(invitation?.email, 'responsable@example.fr');
      expect((await repository.watchInvitations().first).single.id, 'existing');

      await repository.cancelInvitation('existing');
      expect(source.lastUpdate, {'status': 'cancelled'});
      expect(source.documents.single.data['email'], 'responsable@example.fr');
    },
  );

  test('firestore repository refuses a non-coordinator session', () async {
    final source = _FakeInvitationDataSource(now: now, role: 'site_manager');
    final repository = FirestoreAdminInvitationRepository(
      dataSource: source,
      now: () => now,
    );

    await expectLater(repository.createInvitation(draft()), throwsStateError);
    expect(source.createdDocuments, 0);
  });
}

Map<String, Object?> _invitationData({required DateTime now}) => {
  'email': 'responsable@example.fr',
  'displayName': 'Responsable',
  'role': 'site_manager',
  'locationIds': ['site-a'],
  'createdBy': 'coord',
  'createdAt': now,
  'expiresAt': now.add(const Duration(days: 7)),
  'status': 'pending',
  'acceptedAt': null,
};

class _FakeInvitationDataSource implements AdminInvitationFirestoreDataSource {
  _FakeInvitationDataSource({required this.now, this.role = 'coordinator'});

  final DateTime now;
  final String role;
  final List<AdminInvitationDocument> documents = [];
  int createdDocuments = 0;
  Map<String, Object?>? lastUpdate;

  @override
  String? get currentUserId => 'coord';

  @override
  Object serverTimestamp() => now;

  @override
  Object timestampFromDate(DateTime value) => value;

  @override
  Future<String> addDocument(Map<String, Object?> data) async {
    createdDocuments++;
    const id = 'invitation-1';
    documents.add(AdminInvitationDocument(id: id, data: data));
    return id;
  }

  @override
  Future<AdminInvitationDocument?> getDocument(String id) async {
    return documents.where((document) => document.id == id).firstOrNull;
  }

  @override
  Future<Map<String, Object?>?> getCurrentRole() async => {
    'role': role,
    'active': true,
  };

  @override
  Future<void> updateDocument(String id, Map<String, Object?> data) async {
    lastUpdate = data;
    final index = documents.indexWhere((document) => document.id == id);
    final existing = documents[index];
    documents[index] = AdminInvitationDocument(
      id: id,
      data: {...existing.data, ...data},
    );
  }

  @override
  Stream<List<AdminInvitationDocument>> watchDocuments() {
    return Stream.value(List.unmodifiable(documents));
  }
}
