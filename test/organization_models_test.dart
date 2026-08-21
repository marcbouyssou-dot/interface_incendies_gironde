import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';

void main() {
  group('Organization enums', () {
    test('serialize and deserialize every supported value', () {
      for (final category in OrganizationCategory.values) {
        expect(
          organizationCategoryFromValue(category.serializedValue),
          category,
        );
      }
      for (final visibility in OrganizationVisibility.values) {
        expect(
          organizationVisibilityFromValue(visibility.serializedValue),
          visibility,
        );
      }
      for (final role in OrganizationRole.values) {
        expect(organizationRoleFromValue(role.serializedValue), role);
      }
    });

    test('preserve the RC3 role wire values', () {
      expect(OrganizationRole.coordinator.serializedValue, 'coordinator');
      expect(OrganizationRole.siteManager.serializedValue, 'site_manager');
    });

    test('reject unknown wire values', () {
      expect(
        () => organizationCategoryFromValue('unknown'),
        throwsFormatException,
      );
      expect(
        () => organizationVisibilityFromValue('worldwide'),
        throwsFormatException,
      );
      expect(() => organizationRoleFromValue('owner'), throwsFormatException);
    });
  });

  group('Organization', () {
    test('round-trips through its serialized representation', () {
      final organization = _organization();

      final restored = Organization.fromMap(organization.toMap());

      expect(restored, organization);
      expect(restored.hashCode, organization.hashCode);
      expect(restored.toMap(), {
        'id': 'sdis-33',
        'name': 'SDIS de la Gironde',
        'category': 'sdis',
        'defaultVisibility': 'organization_private',
        'active': true,
        'createdAt': DateTime.utc(2026, 8, 21),
        'updatedAt': DateTime.utc(2026, 8, 21),
        'schemaVersion': 1,
      });
    });

    test('uses value equality', () {
      expect(_organization(), _organization());
      expect(
        _organization(),
        isNot(equals(_organization(name: 'ARS Nouvelle-Aquitaine'))),
      );
    });

    test('accepts additive future fields and schema versions', () {
      final restored = Organization.fromMap({
        ..._organization().toMap(),
        'schemaVersion': 4,
        'futurePolicy': 'reserved',
      });

      expect(restored.schemaVersion, 4);
      expect(restored.toMap(), isNot(contains('futurePolicy')));
    });

    test('rejects malformed invariants', () {
      expect(
        () =>
            Organization.fromMap({..._organization().toMap(), 'id': 'bad/id'}),
        throwsFormatException,
      );
      expect(
        () => Organization.fromMap({
          ..._organization().toMap(),
          'updatedAt': DateTime.utc(2026, 8, 20),
        }),
        throwsFormatException,
      );
      expect(
        () => Organization.fromMap({
          ..._organization().toMap(),
          'schemaVersion': 0,
        }),
        throwsFormatException,
      );
    });
  });

  group('OrganizationMembership', () {
    test('round-trips with deterministic roles and locations', () {
      final membership = _membership();

      final restored = OrganizationMembership.fromMap(membership.toMap());

      expect(restored, membership);
      expect(restored.hashCode, membership.hashCode);
      expect(restored.toMap()['roles'], [
        'organization_admin',
        'coordinator',
        'site_manager',
      ]);
      expect(restored.toMap()['locationIds'], ['langon', 'merignac']);
    });

    test('defensively copies role and location collections', () {
      final roles = <OrganizationRole>{OrganizationRole.coordinator};
      final locations = <String>{'langon'};
      final membership = _membership(roles: roles, locationIds: locations);

      roles.add(OrganizationRole.organizationAdmin);
      locations.add('merignac');

      expect(membership.roles, {OrganizationRole.coordinator});
      expect(membership.locationIds, {'langon'});
      expect(
        () => membership.roles.add(OrganizationRole.professional),
        throwsUnsupportedError,
      );
      expect(() => membership.locationIds.add('bazas'), throwsUnsupportedError);
    });

    test('value equality is independent from input ordering', () {
      final first = _membership(
        roles: const {
          OrganizationRole.coordinator,
          OrganizationRole.siteManager,
        },
        locationIds: const {'langon', 'merignac'},
      );
      final second = _membership(
        roles: const {
          OrganizationRole.siteManager,
          OrganizationRole.coordinator,
        },
        locationIds: const {'merignac', 'langon'},
      );

      expect(first, second);
      expect(first.hashCode, second.hashCode);
    });

    test(
      'accepts additive future fields and an absent optional site scope',
      () {
        final data = Map<String, Object?>.of(_membership().toMap())
          ..remove('locationIds')
          ..addAll({'schemaVersion': 7, 'futureScope': 'reserved'});

        final restored = OrganizationMembership.fromMap(data);

        expect(restored.schemaVersion, 7);
        expect(restored.locationIds, isEmpty);
        expect(restored.toMap(), isNot(contains('futureScope')));
      },
    );

    test('rejects empty roles, duplicates and malformed site scopes', () {
      final data = _membership().toMap();
      expect(
        () => OrganizationMembership.fromMap({...data, 'roles': <Object?>[]}),
        throwsFormatException,
      );
      expect(
        () => OrganizationMembership.fromMap({
          ...data,
          'roles': <Object?>['coordinator', 'coordinator'],
        }),
        throwsFormatException,
      );
      expect(
        () => OrganizationMembership.fromMap({
          ...data,
          'locationIds': <Object?>['langon', 'langon'],
        }),
        throwsFormatException,
      );
      expect(
        () => OrganizationMembership.fromMap({
          ...data,
          'locationIds': <Object?>['*'],
        }),
        throwsFormatException,
      );
      expect(
        () => OrganizationMembership(
          organizationId: 'sdis-33',
          uid: 'user-a',
          roles: const [
            OrganizationRole.coordinator,
            OrganizationRole.coordinator,
          ],
          active: true,
          createdAt: DateTime.utc(2026, 8, 21),
          updatedAt: DateTime.utc(2026, 8, 21),
          schemaVersion: 1,
        ),
        throwsFormatException,
      );
    });
  });
}

Organization _organization({String name = 'SDIS de la Gironde'}) =>
    Organization(
      id: 'sdis-33',
      name: name,
      category: OrganizationCategory.sdis,
      defaultVisibility: OrganizationVisibility.organizationPrivate,
      active: true,
      createdAt: DateTime.utc(2026, 8, 21),
      updatedAt: DateTime.utc(2026, 8, 21),
      schemaVersion: 1,
    );

OrganizationMembership _membership({
  Set<OrganizationRole> roles = const {
    OrganizationRole.siteManager,
    OrganizationRole.coordinator,
    OrganizationRole.organizationAdmin,
  },
  Set<String> locationIds = const {'merignac', 'langon'},
}) => OrganizationMembership(
  organizationId: 'sdis-33',
  uid: 'user-a',
  roles: roles,
  locationIds: locationIds,
  active: true,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);
