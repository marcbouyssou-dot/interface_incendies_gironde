import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/repositories/firestore_organization_mapper.dart';
import 'package:interface_incendies_gironde/repositories/firestore_organization_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_read_repository.dart';

void main() {
  group('FirestoreOrganizationMapper', () {
    test('parses an organization with timestamps and additive fields', () {
      final data = _organizationDocumentData(
        id: 'sdis-33',
        name: 'SDIS de la Gironde',
        schemaVersion: 8,
      )..['futurePolicy'] = {'reserved': true};

      final organization =
          FirestoreOrganizationMapper.organizationFromFirestore(
            documentId: 'sdis-33',
            data: data,
          );

      expect(organization.id, 'sdis-33');
      expect(organization.createdAt.toUtc(), DateTime.utc(2026, 8, 21));
      expect(organization.schemaVersion, 8);
      expect(organization.toMap(), isNot(contains('futurePolicy')));
      expect(data['createdAt'], isA<Timestamp>());
    });

    test('uses the document id and rejects an incoherent embedded id', () {
      final withoutId = _organizationDocumentData(
        id: 'ars-na',
        name: 'ARS Nouvelle-Aquitaine',
      )..remove('id');

      expect(
        FirestoreOrganizationMapper.organizationFromFirestore(
          documentId: 'ars-na',
          data: withoutId,
        ).id,
        'ars-na',
      );
      expect(
        () => FirestoreOrganizationMapper.organizationFromFirestore(
          documentId: 'ars-na',
          data: {
            ..._organizationDocumentData(
              id: 'another-id',
              name: 'ARS Nouvelle-Aquitaine',
            ),
          },
        ),
        throwsFormatException,
      );
    });

    test('parses inactive membership, multiple roles and future schema', () {
      final membership = FirestoreOrganizationMapper.membershipFromFirestore(
        data: _membershipDocumentData(
          organizationId: 'sdis-33',
          uid: 'user-a',
          roles: const [
            OrganizationRole.organizationAdmin,
            OrganizationRole.coordinator,
          ],
          active: false,
          schemaVersion: 12,
        )..['futureScope'] = 'reserved',
      );

      expect(membership.active, isFalse);
      expect(membership.roles, {
        OrganizationRole.organizationAdmin,
        OrganizationRole.coordinator,
      });
      expect(membership.schemaVersion, 12);
      expect(membership.toMap(), isNot(contains('futureScope')));
    });
  });

  group('FirestoreOrganizationReadRepository', () {
    test('returns null when organization and membership are absent', () async {
      final repository = FirestoreOrganizationReadRepository(
        _FakeOrganizationFirestoreDataSource(),
      );

      expect(await repository.watchOrganization('missing').first, isNull);
      expect(
        await repository
            .watchMembership(organizationId: 'missing', uid: 'user-a')
            .first,
        isNull,
      );
      expect(
        await repository
            .watchMembershipIsActive(organizationId: 'missing', uid: 'user-a')
            .first,
        isFalse,
      );
      expect(
        await repository
            .watchActiveOrganizationRoles(
              organizationId: 'missing',
              uid: 'user-a',
            )
            .first,
        isEmpty,
      );
    });

    test(
      'lists several memberships and exposes roles by organization',
      () async {
        final source = _FakeOrganizationFirestoreDataSource(
          membershipDocuments: [
            _membershipDocument(
              id: 'membership-sdis',
              organizationId: 'sdis-33',
              uid: 'user-a',
              roles: const [
                OrganizationRole.coordinator,
                OrganizationRole.siteManager,
              ],
            ),
            _membershipDocument(
              id: 'membership-ars',
              organizationId: 'ars-na',
              uid: 'user-a',
              roles: const [OrganizationRole.organizationAdmin],
            ),
            _membershipDocument(
              id: 'membership-other-user',
              organizationId: 'sdis-33',
              uid: 'user-b',
            ),
          ],
        );
        final repository = FirestoreOrganizationReadRepository(source);

        final memberships = await repository
            .watchMembershipsForUser('user-a')
            .first;

        expect(memberships.map((item) => item.organizationId), [
          'ars-na',
          'sdis-33',
        ]);
        expect(
          await repository
              .watchActiveOrganizationRoles(
                organizationId: 'sdis-33',
                uid: 'user-a',
              )
              .first,
          {OrganizationRole.coordinator, OrganizationRole.siteManager},
        );
        expect(source.lastMembershipUid, 'user-a');
        expect(source.lastExactMembershipLookup, (
          organizationId: 'sdis-33',
          uid: 'user-a',
        ));
      },
    );

    test(
      'inactive membership remains readable but has no effective role',
      () async {
        final repository = FirestoreOrganizationReadRepository(
          _FakeOrganizationFirestoreDataSource(
            membershipDocuments: [
              _membershipDocument(
                id: 'inactive',
                organizationId: 'sdis-33',
                uid: 'user-a',
                roles: const [OrganizationRole.coordinator],
                active: false,
              ),
            ],
          ),
        );

        final membership = await repository
            .watchMembership(organizationId: 'sdis-33', uid: 'user-a')
            .first;

        expect(membership?.active, isFalse);
        expect(
          await repository
              .watchActiveOrganizationRoles(
                organizationId: 'sdis-33',
                uid: 'user-a',
              )
              .first,
          isEmpty,
        );
      },
    );

    test('returns only active organizations with active memberships', () async {
      final source = _FakeOrganizationFirestoreDataSource(
        organizationDocuments: [
          _organizationDocument(id: 'sdis-33', name: 'SDIS de la Gironde'),
          _organizationDocument(id: 'ars-na', name: 'ARS Nouvelle-Aquitaine'),
          _organizationDocument(
            id: 'archived',
            name: 'Organisation archivée',
            active: false,
          ),
          _organizationDocument(
            id: 'cpts-inactive-membership',
            name: 'CPTS sans appartenance active',
          ),
        ],
        membershipDocuments: [
          _membershipDocument(
            id: 'membership-sdis',
            organizationId: 'sdis-33',
            uid: 'user-a',
          ),
          _membershipDocument(
            id: 'membership-ars',
            organizationId: 'ars-na',
            uid: 'user-a',
          ),
          _membershipDocument(
            id: 'membership-archived',
            organizationId: 'archived',
            uid: 'user-a',
          ),
          _membershipDocument(
            id: 'membership-inactive',
            organizationId: 'cpts-inactive-membership',
            uid: 'user-a',
            active: false,
          ),
        ],
      );
      final repository = FirestoreOrganizationReadRepository(source);

      final organizations = await repository
          .watchAccessibleOrganizations(uid: 'user-a')
          .first;

      expect(organizations.map((organization) => organization.id), [
        'ars-na',
        'sdis-33',
      ]);
      expect(source.lastOrganizationIds, {'ars-na', 'archived', 'sdis-33'});
      expect(
        () => organizations.add(organizations.first),
        throwsUnsupportedError,
      );
    });

    test('bounds organization document lookups to Firestore whereIn limit', () {
      final batches = boundedOrganizationDocumentIdBatches([
        for (var index = 0; index < 65; index++) 'organization-$index',
        'organization-0',
      ]);

      expect(batches, hasLength(3));
      expect(batches[0], hasLength(30));
      expect(batches[1], hasLength(30));
      expect(batches[2], hasLength(5));
      expect(batches.expand((batch) => batch).toSet(), hasLength(65));
    });
  });
}

class _FakeOrganizationFirestoreDataSource
    implements OrganizationFirestoreDataSource {
  _FakeOrganizationFirestoreDataSource({
    List<OrganizationFirestoreDocument> organizationDocuments = const [],
    List<OrganizationFirestoreDocument> membershipDocuments = const [],
  }) : _organizationDocuments = {
         for (final document in organizationDocuments) document.id: document,
       },
       _membershipDocuments = List.unmodifiable(membershipDocuments);

  final Map<String, OrganizationFirestoreDocument> _organizationDocuments;
  final List<OrganizationFirestoreDocument> _membershipDocuments;

  Set<String>? lastOrganizationIds;
  String? lastMembershipUid;
  ({String organizationId, String uid})? lastExactMembershipLookup;

  @override
  Stream<OrganizationFirestoreDocument?> watchOrganizationDocument(
    String organizationId,
  ) => Stream.value(_organizationDocuments[organizationId]);

  @override
  Stream<List<OrganizationFirestoreDocument>> watchOrganizationDocumentsByIds(
    Set<String> organizationIds,
  ) {
    lastOrganizationIds = Set.unmodifiable(organizationIds);
    return Stream.value([
      for (final id in organizationIds) ?_organizationDocuments[id],
    ]);
  }

  @override
  Stream<List<OrganizationFirestoreDocument>> watchMembershipDocumentsForUser(
    String uid,
  ) {
    lastMembershipUid = uid;
    return Stream.value([
      for (final document in _membershipDocuments)
        if (document.data['uid'] == uid) document,
    ]);
  }

  @override
  Stream<List<OrganizationFirestoreDocument>> watchMembershipDocuments({
    required String organizationId,
    required String uid,
  }) {
    lastExactMembershipLookup = (organizationId: organizationId, uid: uid);
    return Stream.value([
      for (final document in _membershipDocuments)
        if (document.data['organizationId'] == organizationId &&
            document.data['uid'] == uid)
          document,
    ]);
  }
}

OrganizationFirestoreDocument _organizationDocument({
  required String id,
  required String name,
  bool active = true,
}) => OrganizationFirestoreDocument(
  id: id,
  data: _organizationDocumentData(id: id, name: name, active: active),
);

Map<String, Object?> _organizationDocumentData({
  required String id,
  required String name,
  bool active = true,
  int schemaVersion = 1,
}) => {
  'id': id,
  'name': name,
  'category': OrganizationCategory.other.serializedValue,
  'defaultVisibility':
      OrganizationVisibility.organizationPrivate.serializedValue,
  'active': active,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 21)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 21)),
  'schemaVersion': schemaVersion,
};

OrganizationFirestoreDocument _membershipDocument({
  required String id,
  required String organizationId,
  required String uid,
  List<OrganizationRole> roles = const [OrganizationRole.professional],
  bool active = true,
}) => OrganizationFirestoreDocument(
  id: id,
  data: _membershipDocumentData(
    organizationId: organizationId,
    uid: uid,
    roles: roles,
    active: active,
  ),
);

Map<String, Object?> _membershipDocumentData({
  required String organizationId,
  required String uid,
  List<OrganizationRole> roles = const [OrganizationRole.professional],
  bool active = true,
  int schemaVersion = 1,
}) => {
  'organizationId': organizationId,
  'uid': uid,
  'roles': roles.map((role) => role.serializedValue).toList(),
  'locationIds': <String>[],
  'active': active,
  'createdAt': Timestamp.fromDate(DateTime.utc(2026, 8, 21)),
  'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 8, 21)),
  'schemaVersion': schemaVersion,
};
