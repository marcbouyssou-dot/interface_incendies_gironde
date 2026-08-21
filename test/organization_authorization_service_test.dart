import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';
import 'package:interface_incendies_gironde/services/organization_authorization_service.dart';

void main() {
  const service = OrganizationAuthorizationService();

  test(
    'active organization admin is scoped to its membership organization',
    () {
      final membership = _membership(
        organizationId: 'organization-a',
        uid: 'admin-a',
        roles: const {OrganizationRole.organizationAdmin},
      );

      final inA = service.resolve(
        organizationId: 'organization-a',
        uid: 'admin-a',
        membership: membership,
      );
      final inB = service.resolve(
        organizationId: 'organization-b',
        uid: 'admin-a',
      );

      expect(inA.hasActiveMembership, isTrue);
      expect(inA.isOrganizationAdmin, isTrue);
      expect(inA.isPlatformAdministrator, isFalse);
      expect(OrganizationPermission.values.every(inA.allows), isTrue);
      expect(inB.hasOrganizationAccess, isFalse);
      expect(inB.isOrganizationAdmin, isFalse);
      expect(
        () => service.resolve(
          organizationId: 'organization-b',
          uid: 'admin-a',
          membership: membership,
        ),
        throwsFormatException,
      );
    },
  );

  test('inactive membership exposes no role and disables legacy fallback', () {
    final authorization = service.resolve(
      organizationId: LegacyOrganizationResolver.legacyOrganizationId,
      uid: 'inactive',
      membership: _membership(
        organizationId: LegacyOrganizationResolver.legacyOrganizationId,
        uid: 'inactive',
        roles: const {
          OrganizationRole.organizationAdmin,
          OrganizationRole.coordinator,
        },
        active: false,
      ),
      legacyRoleValues: const ['coordinator'],
      isLegacyOrganization: true,
    );

    expect(authorization.hasActiveMembership, isFalse);
    expect(authorization.usesLegacyFallback, isFalse);
    expect(authorization.roles, isEmpty);
    expect(authorization.hasOrganizationAccess, isFalse);
  });

  test('platform admin remains global without becoming organization admin', () {
    for (final organizationId in ['organization-a', 'organization-b']) {
      final authorization = service.resolve(
        organizationId: organizationId,
        uid: 'platform-admin',
        isPlatformAdministrator: true,
      );

      expect(authorization.hasActiveMembership, isFalse);
      expect(authorization.isPlatformAdministrator, isTrue);
      expect(authorization.isOrganizationAdmin, isFalse);
      expect(OrganizationPermission.values.every(authorization.allows), isTrue);
    }
  });

  test('coordinator, site manager and professional stay distinct', () {
    final authorization = service.resolve(
      organizationId: 'organization-a',
      uid: 'multi-role',
      membership: _membership(
        organizationId: 'organization-a',
        uid: 'multi-role',
        roles: const {
          OrganizationRole.coordinator,
          OrganizationRole.siteManager,
          OrganizationRole.professional,
        },
        locationIds: const {'site-a'},
      ),
    );

    expect(authorization.isCoordinator, isTrue);
    expect(authorization.isSiteManager, isTrue);
    expect(authorization.isProfessional, isTrue);
    expect(authorization.isOrganizationAdmin, isFalse);
    expect(authorization.allows(OrganizationPermission.readOperations), isTrue);
    expect(
      authorization.allows(OrganizationPermission.manageOperations),
      isFalse,
    );
  });

  test('one UID can have different roles in organizations A and B', () {
    final inA = service.resolve(
      organizationId: 'organization-a',
      uid: 'shared-user',
      membership: _membership(
        organizationId: 'organization-a',
        uid: 'shared-user',
        roles: const {OrganizationRole.coordinator},
      ),
    );
    final inB = service.resolve(
      organizationId: 'organization-b',
      uid: 'shared-user',
      membership: _membership(
        organizationId: 'organization-b',
        uid: 'shared-user',
        roles: const {OrganizationRole.siteManager},
        locationIds: const {'site-b'},
      ),
    );

    expect(inA.roles, {OrganizationRole.coordinator});
    expect(inB.roles, {OrganizationRole.siteManager});
    expect(inA.isSiteManager, isFalse);
    expect(inB.isCoordinator, isFalse);
  });

  test('roles uid fallback is accepted only for legacy Gironde', () {
    final legacy = service.resolve(
      organizationId: LegacyOrganizationResolver.legacyOrganizationId,
      uid: 'legacy-user',
      legacyRoleValues: const ['coordinator', 'site_manager', 'unknown'],
      isLegacyOrganization: true,
    );
    final outside = service.resolve(
      organizationId: 'organization-a',
      uid: 'legacy-user',
      legacyRoleValues: const ['coordinator', 'site_manager'],
    );
    final unknownOnly = service.resolve(
      organizationId: LegacyOrganizationResolver.legacyOrganizationId,
      uid: 'unknown-legacy-user',
      legacyRoleValues: const ['unknown'],
      isLegacyOrganization: true,
    );

    expect(legacy.usesLegacyFallback, isTrue);
    expect(legacy.roles, {
      OrganizationRole.coordinator,
      OrganizationRole.siteManager,
    });
    expect(legacy.isOrganizationAdmin, isFalse);
    expect(outside.usesLegacyFallback, isFalse);
    expect(outside.roles, isEmpty);
    expect(unknownOnly.usesLegacyFallback, isFalse);
    expect(unknownOnly.hasOrganizationAccess, isFalse);
  });
}

OrganizationMembership _membership({
  required String organizationId,
  required String uid,
  required Set<OrganizationRole> roles,
  Set<String> locationIds = const {},
  bool active = true,
}) => OrganizationMembership(
  organizationId: organizationId,
  uid: uid,
  roles: roles,
  locationIds: locationIds,
  active: active,
  createdAt: DateTime.utc(2026, 8, 21),
  updatedAt: DateTime.utc(2026, 8, 21),
  schemaVersion: 1,
);
