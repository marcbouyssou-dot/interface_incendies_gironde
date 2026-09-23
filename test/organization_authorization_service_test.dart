import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_incendies_gironde/models/organization_membership.dart';
import 'package:interface_incendies_gironde/models/organization_role.dart';
import 'package:interface_incendies_gironde/services/legacy_organization_resolver.dart';
import 'package:interface_incendies_gironde/services/organization_authorization_service.dart';

void main() {
  const service = OrganizationAuthorizationService();

  group('canonical Dart ↔ Functions authorization contract', () {
    final contract = _loadAuthorizationContract();
    final roleOrder = (contract['roles'] as List).cast<String>();
    final permissionOrder = (contract['permissions'] as List).cast<String>();

    test('catalogues force the shared matrix to evolve with the engines', () {
      expect(
        OrganizationRole.values.map((role) => role.serializedValue),
        roleOrder,
      );
      expect(
        OrganizationPermission.values.map(_permissionValue),
        permissionOrder,
      );
      expect(
        contract['legacyOrganizationId'],
        LegacyOrganizationResolver.legacyOrganizationId,
      );
    });

    for (final scenario
        in (contract['scenarios'] as List).cast<Map<String, Object?>>()) {
      test('shared scenario: ${scenario['id']}', () {
        final input = (scenario['input'] as Map).cast<String, Object?>();
        if (scenario['expectedError'] == 'invalid_identity') {
          expect(
            () => _resolveContractScenario(service, input),
            throwsFormatException,
          );
          return;
        }

        final authorization = _resolveContractScenario(service, input);
        final actualRoles =
            authorization.roles
                .map((role) => role.serializedValue)
                .toList(growable: false)
              ..sort(
                (left, right) =>
                    roleOrder.indexOf(left).compareTo(roleOrder.indexOf(right)),
              );
        final allowedPermissions = OrganizationPermission.values
            .where(authorization.allows)
            .map(_permissionValue)
            .toList(growable: false);

        expect(
          <String, Object?>{
            'hasActiveMembership': authorization.hasActiveMembership,
            'usesLegacyFallback': authorization.usesLegacyFallback,
            'isPlatformAdministrator': authorization.isPlatformAdministrator,
            'isOrganizationAdmin': authorization.isOrganizationAdmin,
            'isCoordinator': authorization.isCoordinator,
            'isSiteManager': authorization.isSiteManager,
            'isProfessional': authorization.isProfessional,
            'hasOrganizationAccess': authorization.hasOrganizationAccess,
            'roles': actualRoles,
            'allowedPermissions': allowedPermissions,
          },
          (scenario['expected'] as Map).cast<String, Object?>(),
          reason: scenario['description'] as String,
        );
      });
    }
  });

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

Map<String, Object?> _loadAuthorizationContract() =>
    (jsonDecode(
              File(
                'contracts/organization_authorization_matrix.json',
              ).readAsStringSync(),
            )
            as Map)
        .cast<String, Object?>();

OrganizationAuthorization _resolveContractScenario(
  OrganizationAuthorizationService service,
  Map<String, Object?> input,
) {
  final rawMembership = input['membership'];
  final membership = rawMembership == null
      ? null
      : _contractMembership((rawMembership as Map).cast<String, Object?>());
  final rawLegacyAccess = input['legacyAccess'];
  final legacyAccess = rawLegacyAccess == null
      ? null
      : (rawLegacyAccess as Map).cast<String, Object?>();
  return service.resolve(
    organizationId: input['organizationId']! as String,
    uid: input['uid']! as String,
    membership: membership,
    legacyRoleValues: legacyAccess?['active'] == true
        ? (legacyAccess!['roles'] as List).cast<String>()
        : const [],
    isLegacyOrganization:
        input['organizationId'] ==
        LegacyOrganizationResolver.legacyOrganizationId,
    isPlatformAdministrator: input['platformAdministrator']! as bool,
  );
}

OrganizationMembership _contractMembership(Map<String, Object?> data) =>
    OrganizationMembership(
      organizationId: data['organizationId']! as String,
      uid: data['uid']! as String,
      roles: (data['roles'] as List).map(organizationRoleFromValue),
      locationIds: (data['locationIds'] as List).cast<String>(),
      active: data['active']! as bool,
      createdAt: DateTime.utc(2026, 8, 21),
      updatedAt: DateTime.utc(2026, 8, 21),
      schemaVersion: data['schemaVersion']! as int,
    );

String _permissionValue(OrganizationPermission permission) =>
    switch (permission) {
      OrganizationPermission.readOrganization => 'read_organization',
      OrganizationPermission.readOperations => 'read_operations',
      OrganizationPermission.manageOperations => 'manage_operations',
      OrganizationPermission.manageCoordinators => 'manage_coordinators',
      OrganizationPermission.manageSiteManagers => 'manage_site_managers',
      OrganizationPermission.manageSites => 'manage_sites',
      OrganizationPermission.viewActors => 'view_actors',
      OrganizationPermission.viewStatistics => 'view_statistics',
      OrganizationPermission.viewHistory => 'view_history',
      OrganizationPermission.exportData => 'export_data',
      OrganizationPermission.manageInvitations => 'manage_invitations',
    };
