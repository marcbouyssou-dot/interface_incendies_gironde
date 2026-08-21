import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/repositories/in_memory_organization_read_repository.dart';
import 'package:interface_incendies_gironde/repositories/organization_read_repository.dart';

void main() {
  group('NoOrganizationReadRepository', () {
    const repository = NoOrganizationReadRepository();

    test('exposes an empty injectable source', () async {
      expect(
        await repository.watchAccessibleOrganizations(uid: 'user-a').first,
        isEmpty,
      );
      expect(
        await repository.watchOrganization('legacy-gironde').first,
        isNull,
      );
      expect(await repository.watchMembershipsForUser('user-a').first, isEmpty);
      expect(
        await repository
            .watchMembership(organizationId: 'legacy-gironde', uid: 'user-a')
            .first,
        isNull,
      );
    });
  });

  group('InMemoryOrganizationReadRepository', () {
    test('supports zero organization', () async {
      final repository = InMemoryOrganizationReadRepository();

      expect(
        await repository.watchAccessibleOrganizations(uid: 'user-a').first,
        isEmpty,
      );
    });

    test('reads one legacy organization without UI fallback', () async {
      final legacy = _organization(
        id: 'legacy-gironde',
        name: 'Organisation legacy Gironde',
      );
      final repository = InMemoryOrganizationReadRepository(
        organizations: [legacy],
        memberships: [
          _membership(
            organizationId: legacy.id,
            uid: 'legacy-admin',
            roles: const {OrganizationRole.organizationAdmin},
          ),
        ],
      );

      expect(await repository.watchOrganization(legacy.id).first, legacy);
      expect(
        await repository
            .watchAccessibleOrganizations(uid: 'legacy-admin')
            .first,
        [legacy],
      );
    });

    test(
      'lists several active accessible organizations deterministically',
      () async {
        final ars = _organization(id: 'ars-na', name: 'ARS Nouvelle-Aquitaine');
        final sdis = _organization(id: 'sdis-33', name: 'SDIS de la Gironde');
        final inactive = _organization(
          id: 'archive',
          name: 'Organisation archivée',
          active: false,
        );
        final repository = InMemoryOrganizationReadRepository(
          organizations: [sdis, inactive, ars],
          memberships: [
            _membership(organizationId: sdis.id, uid: 'user-a'),
            _membership(organizationId: ars.id, uid: 'user-a'),
            _membership(organizationId: inactive.id, uid: 'user-a'),
          ],
        );

        final result = await repository
            .watchAccessibleOrganizations(uid: 'user-a')
            .first;

        expect(result.map((organization) => organization.id), [
          'ars-na',
          'sdis-33',
        ]);
        expect(() => result.add(ars), throwsUnsupportedError);
      },
    );

    test('lists several memberships for the same uid', () async {
      final organizations = [
        _organization(id: 'ars-na', name: 'ARS Nouvelle-Aquitaine'),
        _organization(id: 'sdis-33', name: 'SDIS de la Gironde'),
      ];
      final repository = InMemoryOrganizationReadRepository(
        organizations: organizations,
        memberships: [
          _membership(organizationId: 'sdis-33', uid: 'user-a'),
          _membership(organizationId: 'ars-na', uid: 'user-a'),
          _membership(organizationId: 'sdis-33', uid: 'user-b'),
        ],
      );

      final memberships = await repository
          .watchMembershipsForUser('user-a')
          .first;

      expect(memberships.map((membership) => membership.organizationId), [
        'ars-na',
        'sdis-33',
      ]);
      expect(
        memberships.every((membership) => membership.uid == 'user-a'),
        isTrue,
      );
    });

    test('exposes different active roles for each organization', () async {
      final repository = InMemoryOrganizationReadRepository(
        organizations: [
          _organization(id: 'ars-na', name: 'ARS Nouvelle-Aquitaine'),
          _organization(id: 'sdis-33', name: 'SDIS de la Gironde'),
        ],
        memberships: [
          _membership(
            organizationId: 'ars-na',
            uid: 'user-a',
            roles: const {OrganizationRole.organizationAdmin},
          ),
          _membership(
            organizationId: 'sdis-33',
            uid: 'user-a',
            roles: const {
              OrganizationRole.coordinator,
              OrganizationRole.siteManager,
            },
          ),
        ],
      );

      expect(
        await repository
            .watchActiveOrganizationRoles(
              organizationId: 'ars-na',
              uid: 'user-a',
            )
            .first,
        {OrganizationRole.organizationAdmin},
      );
      expect(
        await repository
            .watchActiveOrganizationRoles(
              organizationId: 'sdis-33',
              uid: 'user-a',
            )
            .first,
        {OrganizationRole.coordinator, OrganizationRole.siteManager},
      );
    });

    test('keeps an inactive membership readable but not effective', () async {
      final organization = _organization(
        id: 'sdis-33',
        name: 'SDIS de la Gironde',
      );
      final membership = _membership(
        organizationId: organization.id,
        uid: 'user-a',
        roles: const {OrganizationRole.coordinator},
        active: false,
      );
      final repository = InMemoryOrganizationReadRepository(
        organizations: [organization],
        memberships: [membership],
      );

      expect(
        await repository
            .watchMembership(organizationId: organization.id, uid: 'user-a')
            .first,
        membership,
      );
      expect(
        await repository
            .watchMembershipIsActive(
              organizationId: organization.id,
              uid: 'user-a',
            )
            .first,
        isFalse,
      );
      expect(
        await repository
            .watchActiveOrganizationRoles(
              organizationId: organization.id,
              uid: 'user-a',
            )
            .first,
        isEmpty,
      );
      expect(
        await repository.watchAccessibleOrganizations(uid: 'user-a').first,
        isEmpty,
      );
    });

    test('accepts domain objects parsed from additive unknown data', () async {
      final organization = Organization.fromMap({
        ..._organization(id: 'cpts-a', name: 'CPTS A').toMap(),
        'schemaVersion': 3,
        'futureOrganizationField': true,
      });
      final membership = OrganizationMembership.fromMap({
        ..._membership(
          organizationId: organization.id,
          uid: 'user-a',
          roles: const {OrganizationRole.professional},
        ).toMap(),
        'schemaVersion': 5,
        'futureMembershipField': 'reserved',
      });
      final repository = InMemoryOrganizationReadRepository(
        organizations: [organization],
        memberships: [membership],
      );

      expect(
        await repository.watchAccessibleOrganizations(uid: 'user-a').first,
        [organization],
      );
      expect(
        (await repository.watchMembershipsForUser('user-a').first).single,
        membership,
      );
    });
  });
}

Organization _organization({
  required String id,
  required String name,
  bool active = true,
}) => Organization(
  id: id,
  name: name,
  category: OrganizationCategory.other,
  defaultVisibility: OrganizationVisibility.organizationPrivate,
  active: active,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);

OrganizationMembership _membership({
  required String organizationId,
  required String uid,
  Set<OrganizationRole> roles = const {OrganizationRole.professional},
  bool active = true,
}) => OrganizationMembership(
  organizationId: organizationId,
  uid: uid,
  roles: roles,
  active: active,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);
