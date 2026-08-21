import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/operation.dart';
import 'package:interface_incendies_gironde/models/organization.dart';
import 'package:interface_incendies_gironde/models/organization_category.dart';
import 'package:interface_incendies_gironde/models/organization_context.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/models/organization_visibility.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';

void main() {
  const resolver = LegacyOrganizationResolver();

  test(
    'operation without owner belongs to the canonical legacy organization',
    () {
      final operation = Operation.fromMap(_operationData());

      expect(
        resolver.resolveOperationOrganizationId(operation),
        LegacyOrganizationResolver.legacyOrganizationId,
      );
      expect(
        LegacyOrganizationResolver.legacyOrganization.id,
        'legacy-gironde',
      );
    },
  );

  test('explicit RC4 operation owner takes priority over legacy fallback', () {
    final operation = Operation.fromMap({
      ..._operationData(),
      'ownerOrganizationId': 'ars-nouvelle-aquitaine',
      'schemaVersion': 3,
    });

    expect(operation.ownerOrganizationId, 'ars-nouvelle-aquitaine');
    expect(
      resolver.resolveOperationOrganizationId(operation),
      'ars-nouvelle-aquitaine',
    );
    expect(operation.toMap()['ownerOrganizationId'], 'ars-nouvelle-aquitaine');
  });

  test('site manager resolution uses the same centralized priority rule', () {
    expect(
      resolver.resolveSiteOrganizationId(),
      LegacyOrganizationResolver.legacyOrganizationId,
    );
    expect(
      resolver.resolveSiteOrganizationId(managingOrganizationId: 'hopital-a'),
      'hopital-a',
    );
  });

  test('active membership exposes roles for a normal RC4 organization', () {
    final organization = _organization('cpts-a');
    final membership = _membership(
      organizationId: organization.id,
      active: true,
      roles: const {
        OrganizationRole.organizationAdmin,
        OrganizationRole.coordinator,
      },
    );

    final context = resolver.resolveContext(
      uid: 'user-a',
      selectedOrganization: organization,
      membership: membership,
      legacyRoleValues: const ['site_manager'],
    );

    expect(context.organization, organization);
    expect(context.membership, membership);
    expect(context.hasActiveMembership, isTrue);
    expect(context.isLegacy, isFalse);
    expect(context.effectiveRoles, {
      OrganizationRole.organizationAdmin,
      OrganizationRole.coordinator,
    });
  });

  test('inactive membership wins over legacy role fallback', () {
    final membership = _membership(
      organizationId: LegacyOrganizationResolver.legacyOrganizationId,
      active: false,
      roles: const {OrganizationRole.coordinator},
    );

    final context = resolver.resolveContext(
      uid: 'user-a',
      selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
      membership: membership,
      legacyRoleValues: const ['coordinator', 'site_manager'],
    );

    expect(context.isLegacy, isTrue);
    expect(context.hasInactiveMembership, isTrue);
    expect(context.effectiveRoles, isEmpty);
  });

  test('legacy global roles apply only to the legacy organization', () {
    final legacyContext = resolver.resolveContext(
      uid: 'user-a',
      selectedOrganization: LegacyOrganizationResolver.legacyOrganization,
      legacyRoleValues: const ['coordinator', 'site_manager', 'unknown'],
    );
    final normalContext = resolver.resolveContext(
      uid: 'user-a',
      selectedOrganization: _organization('cpts-a'),
      legacyRoleValues: const ['coordinator', 'site_manager'],
    );

    expect(legacyContext.effectiveRoles, {
      OrganizationRole.coordinator,
      OrganizationRole.siteManager,
    });
    expect(normalContext.effectiveRoles, isEmpty);
  });

  test('platform administrator remains global without organization roles', () {
    final context = resolver.resolveContext(
      uid: 'platform-admin',
      isPlatformAdministrator: true,
      legacyRoleValues: const ['coordinator'],
    );

    expect(context.hasSelectedOrganization, isFalse);
    expect(context.organization, isNull);
    expect(context.isPlatformAdministrator, isTrue);
    expect(context.effectiveRoles, isEmpty);
  });

  test('absence of organization produces an unselected regular context', () {
    final context = resolver.resolveContext(uid: 'user-a');

    expect(context.hasSelectedOrganization, isFalse);
    expect(context.isLegacy, isFalse);
    expect(context.isPlatformAdministrator, isFalse);
    expect(context.membership, isNull);
    expect(context.effectiveRoles, isEmpty);
  });

  test('context rejects roles absent from the active membership', () {
    final organization = _organization('cpts-a');
    final membership = _membership(
      organizationId: organization.id,
      active: true,
      roles: const {OrganizationRole.professional},
    );

    expect(
      () => OrganizationContext.selected(
        uid: 'user-a',
        organization: organization,
        membership: membership,
        effectiveRoles: const {OrganizationRole.organizationAdmin},
      ),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _operationData() => {
  'id': 'operation-a',
  'name': 'Opération A',
  'type': 'emergency',
  'status': 'active',
  'context': null,
  'startAt': DateTime.utc(2026, 8, 21),
  'endAt': null,
  'scopeRefs': <Object?>['territories/gironde'],
  'createdBy': 'admin',
  'createdAt': DateTime.utc(2026, 8, 21),
  'updatedBy': 'admin',
  'updatedAt': DateTime.utc(2026, 8, 21),
  'schemaVersion': 1,
};

Organization _organization(String id) => Organization(
  id: id,
  name: 'Organisation $id',
  category: OrganizationCategory.cpts,
  defaultVisibility: OrganizationVisibility.organizationPrivate,
  active: true,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);

OrganizationMembership _membership({
  required String organizationId,
  required bool active,
  required Set<OrganizationRole> roles,
}) => OrganizationMembership(
  organizationId: organizationId,
  uid: 'user-a',
  roles: roles,
  active: active,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);
