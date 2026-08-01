import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/admin_invitation.dart';
import 'package:interface_incendies_gironde/models/responsible_access.dart';
import 'package:interface_incendies_gironde/repositories/firestore_admin_invitation_repository.dart';
import 'package:interface_incendies_gironde/repositories/mock_admin_invitation_repository.dart';

const _blankLocationIdVectors = <String>[
  '\u0009',
  '\u000A',
  '\u000B',
  '\u000C',
  '\u000D',
  '\u0020',
  '\u0085',
  '\u00A0',
  '\u1680',
  '\u2000',
  '\u2001',
  '\u2002',
  '\u2003',
  '\u2004',
  '\u2005',
  '\u2006',
  '\u2007',
  '\u2008',
  '\u2009',
  '\u200A',
  '\u2028',
  '\u2029',
  '\u202F',
  '\u205F',
  '\u3000',
  '\uFEFF',
];

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
    expect(value.locationIds, unorderedEquals(['site-a', 'site-b']));
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

  test(
    'invitation draft refuses malformed emails and canonical blank names',
    () {
      for (final email in <String>[
        'invalid',
        'a@b',
        '@example.fr',
        'a@example',
        'a b@example.fr',
      ]) {
        expect(
          () => AdminInvitationDraft(
            email: email,
            displayName: 'Responsable',
            locationIds: const ['site-a'],
            expiresAt: now.add(const Duration(days: 1)),
          ).validate(now: now),
          throwsFormatException,
        );
      }
      for (final displayName in <String>['', ..._blankLocationIdVectors]) {
        expect(
          () => AdminInvitationDraft(
            email: 'responsable@example.fr',
            displayName: displayName,
            locationIds: const ['site-a'],
            expiresAt: now.add(const Duration(days: 1)),
          ).validate(now: now),
          throwsFormatException,
        );
      }
    },
  );

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

  group('strict invitation scope validation', () {
    AdminInvitationDraft scopedDraft({
      Object? role = AdminInvitationDraft.siteManagerRole,
      Iterable<Object?> locationIds = const ['site-a'],
    }) => AdminInvitationDraft(
      email: 'responsable@example.fr',
      displayName: 'Responsable',
      role: role,
      locationIds: locationIds,
      expiresAt: now.add(const Duration(days: 7)),
    );

    test('accepts coordinator and site manager scopes up to 65 locations', () {
      scopedDraft(
        role: AdminInvitationDraft.coordinatorRole,
        locationIds: const [],
      ).validate(now: now);
      scopedDraft(locationIds: const ['site-a']).validate(now: now);
      scopedDraft(locationIds: const ['site-a', 'site-b']).validate(now: now);
      scopedDraft(
        locationIds: List.generate(65, (index) => 'site-$index'),
      ).validate(now: now);
    });

    test('refuses incoherent role scopes and the 66th location', () {
      expect(
        () => scopedDraft(locationIds: const []).validate(now: now),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('au moins un centre'),
          ),
        ),
      );
      expect(
        () => scopedDraft(
          role: AdminInvitationDraft.coordinatorRole,
          locationIds: const ['site-a'],
        ).validate(now: now),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('ne doit pas être limité'),
          ),
        ),
      );
      expect(
        () => scopedDraft(
          locationIds: List.generate(66, (index) => 'site-$index'),
        ).validate(now: now),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('plus de 65 centres'),
          ),
        ),
      );
    });

    for (final invalidLocations in <List<Object?>>[
      [''],
      for (final value in _blankLocationIdVectors) [value],
      ['\t \n'],
      ['site-a', 'site-a'],
      ['*'],
      ['site-a\u001fsite-b'],
      ['site-a', 42],
    ]) {
      test('refuses malformed location selection $invalidLocations', () {
        expect(
          () => scopedDraft(locationIds: invalidLocations).validate(now: now),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              contains('sélection des centres est invalide'),
            ),
          ),
        );
      });
    }

    test(
      'preserves peripheral spaces, internal spaces and partial wildcard',
      () {
        final locations = <Object?>[
          ' bazas',
          'bazas ',
          ' bazas ',
          'ba zas',
          'bazas',
          'Bazas',
          'bazas*',
          '\u00a0bazas',
          'bazas\u0085',
          '\u0000',
          '\u001e',
          '\u007f',
          r'\u001F',
          '\u00e9',
          'e\u0301',
          '\u2217',
          ' * ',
        ];
        final draft = scopedDraft(locationIds: locations);

        draft.validate(now: now);

        expect(draft.locationIds, locations);
      },
    );

    for (final invalidRole in <Object?>[
      '',
      'unknown',
      'coordinator+site_manager',
      const ['coordinator', 'site_manager'],
    ]) {
      test('refuses unsupported singular role $invalidRole', () {
        expect(
          () => scopedDraft(role: invalidRole).validate(now: now),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'Rôle d’invitation invalide.',
            ),
          ),
        );
      });
    }

    test('validation is repeatable and never repairs an invalid payload', () {
      final duplicates = ['site-a', 'site-a'];
      final duplicateDraft = scopedDraft(locationIds: duplicates);
      duplicates.removeLast();

      expect(() => duplicateDraft.validate(now: now), throwsFormatException);
      expect(() => duplicateDraft.validate(now: now), throwsFormatException);
      expect(duplicateDraft.locationIds, ['site-a', 'site-a']);

      final oversizedDraft = scopedDraft(
        locationIds: List.generate(66, (index) => 'site-$index'),
      );
      expect(() => oversizedDraft.validate(now: now), throwsFormatException);
      expect(oversizedDraft.locationIds, hasLength(66));

      final wildcardDraft = scopedDraft(locationIds: const ['*']);
      expect(() => wildcardDraft.validate(now: now), throwsFormatException);
      expect(wildcardDraft.locationIds, ['*']);

      final separatorDraft = scopedDraft(
        locationIds: const ['site-a\u001fsite-b'],
      );
      expect(() => separatorDraft.validate(now: now), throwsFormatException);
      expect(separatorDraft.locationIds.single, contains('\u001f'));
    });
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

  test('firestore repository accepts a cumulative V2 coordinator', () async {
    final source = _FakeInvitationDataSource(
      now: now,
      roleDocument: {
        'role': 'coordinator',
        'roles': ['coordinator', 'site_manager'],
        'locationIds': ['bazas'],
        'active': true,
        'schemaVersion': 2,
      },
    );
    final repository = FirestoreAdminInvitationRepository(
      dataSource: source,
      now: () => now,
    );

    final created = await repository.createInvitation(draft());

    expect(created.status, AdminInvitationStatus.pending);
    expect(source.createdDocuments, 1);
  });

  test('repositories reject an invalid draft before any persistence', () async {
    final invalidDraft = AdminInvitationDraft(
      email: 'responsable@example.fr',
      displayName: 'Responsable',
      locationIds: const ['site-a', 'site-a'],
      expiresAt: now.add(const Duration(days: 7)),
    );
    final source = _FakeInvitationDataSource(now: now);
    final firestoreRepository = FirestoreAdminInvitationRepository(
      dataSource: source,
      now: () => now,
    );
    final mockRepository = MockAdminInvitationRepository(now: () => now);
    addTearDown(mockRepository.dispose);

    await expectLater(
      firestoreRepository.createInvitation(invalidDraft),
      throwsFormatException,
    );
    await expectLater(
      mockRepository.createInvitation(invalidDraft),
      throwsFormatException,
    );

    expect(source.roleReads, 0);
    expect(source.createdDocuments, 0);
    expect(await mockRepository.watchInvitations().first, isEmpty);
  });

  test('firestore repository persists exactly 65 valid locations', () async {
    final source = _FakeInvitationDataSource(now: now);
    final repository = FirestoreAdminInvitationRepository(
      dataSource: source,
      now: () => now,
    );
    final locations = List.generate(65, (index) => 'site-$index');

    await repository.createInvitation(
      AdminInvitationDraft(
        email: 'responsable@example.fr',
        displayName: 'Responsable',
        locationIds: locations,
        expiresAt: now.add(const Duration(days: 7)),
      ),
    );

    expect(source.createdDocuments, 1);
    expect(source.documents.single.data['locationIds'], hasLength(65));
  });

  test(
    'firestore repository rejects every malformed scope before reads',
    () async {
      final invalidDrafts = [
        AdminInvitationDraft(
          email: 'responsable@example.fr',
          displayName: 'Responsable',
          locationIds: List.generate(66, (index) => 'site-$index'),
          expiresAt: now.add(const Duration(days: 7)),
        ),
        AdminInvitationDraft(
          email: 'responsable@example.fr',
          displayName: 'Responsable',
          locationIds: const ['*'],
          expiresAt: now.add(const Duration(days: 7)),
        ),
        AdminInvitationDraft(
          email: 'responsable@example.fr',
          displayName: 'Responsable',
          locationIds: const ['site-a\u001fsite-b'],
          expiresAt: now.add(const Duration(days: 7)),
        ),
        AdminInvitationDraft(
          email: 'coord@example.fr',
          displayName: 'Coordination',
          role: AdminInvitationDraft.coordinatorRole,
          locationIds: const ['site-a'],
          expiresAt: now.add(const Duration(days: 7)),
        ),
      ];

      for (final invalidDraft in invalidDrafts) {
        final source = _FakeInvitationDataSource(now: now);
        final repository = FirestoreAdminInvitationRepository(
          dataSource: source,
          now: () => now,
        );
        await expectLater(
          repository.createInvitation(invalidDraft),
          throwsFormatException,
        );
        expect(source.roleReads, 0);
        expect(source.createdDocuments, 0);
        expect(source.provisionedInvitationId, isNull);
      }
    },
  );

  test('firestore repository exposes a malformed role document', () async {
    final source = _FakeInvitationDataSource(
      now: now,
      roleDocument: {
        'role': 'coordinator',
        'roles': ['coordinator', 'unknown'],
        'locationIds': const [],
        'active': true,
        'schemaVersion': 2,
      },
    );
    final repository = FirestoreAdminInvitationRepository(
      dataSource: source,
      now: () => now,
    );

    await expectLater(
      repository.createInvitation(draft()),
      throwsA(isA<ResponsibleAccessFormatException>()),
    );
    expect(source.createdDocuments, 0);
  });

  test(
    'mock repository provisions pending invitation without email delivery',
    () async {
      final repository = MockAdminInvitationRepository(now: () => now);
      addTearDown(repository.dispose);
      final created = await repository.createInvitation(draft());

      final result = await repository.provisionInvitation(created.id);
      final stored = await repository.getInvitation(created.id);

      expect(result.accountProvisioned, isTrue);
      expect(result.emailDelivery, 'pending');
      expect(stored?.status, AdminInvitationStatus.accepted);
      expect(stored?.acceptedUid, isNotEmpty);
      expect(stored?.provisionedAt, now);
    },
  );

  test('firestore repository delegates provisioning to the callable', () async {
    final source = _FakeInvitationDataSource(now: now);
    final repository = FirestoreAdminInvitationRepository(
      dataSource: source,
      now: () => now,
    );

    final result = await repository.provisionInvitation('invitation-a');

    expect(source.provisionedInvitationId, 'invitation-a');
    expect(result.accountProvisioned, isTrue);
    expect(result.emailDelivery, 'pending');
    expect(result.alreadyProvisioned, isFalse);
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
  _FakeInvitationDataSource({
    required this.now,
    this.role = 'coordinator',
    this.roleDocument,
  });

  final DateTime now;
  final String role;
  final Map<String, Object?>? roleDocument;
  final List<AdminInvitationDocument> documents = [];
  int createdDocuments = 0;
  int roleReads = 0;
  Map<String, Object?>? lastUpdate;
  String? provisionedInvitationId;

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
  Future<Map<String, Object?>?> getCurrentRole() async {
    roleReads++;
    return roleDocument ??
        {
          'role': role,
          'locationIds': role == 'site_manager' ? ['site-a'] : <String>[],
          'active': true,
        };
  }

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
  Future<Map<String, dynamic>> provisionInvitation(String id) async {
    provisionedInvitationId = id;
    return {
      'accountProvisioned': true,
      'emailDelivery': 'pending',
      'alreadyProvisioned': false,
    };
  }

  @override
  Stream<List<AdminInvitationDocument>> watchDocuments() {
    return Stream.value(List.unmodifiable(documents));
  }
}
