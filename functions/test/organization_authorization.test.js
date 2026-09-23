import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import test from 'node:test';

import {
  canReadOrganizationMissionTeam,
  LEGACY_ORGANIZATION_ID,
  ORGANIZATION_PERMISSIONS,
  ORGANIZATION_ROLES,
  readOrganizationAuthorization,
  resolveOrganizationAuthorization,
} from '../src/organization_authorization.js';

const authorizationContract = JSON.parse(readFileSync(
  new URL('../../contracts/organization_authorization_matrix.json', import.meta.url),
  'utf8',
));

test('canonical catalogues force the shared matrix to evolve with the engines', () => {
  assert.deepEqual(authorizationContract.roles, ORGANIZATION_ROLES);
  assert.deepEqual(authorizationContract.permissions, ORGANIZATION_PERMISSIONS);
  assert.equal(
    authorizationContract.legacyOrganizationId,
    LEGACY_ORGANIZATION_ID,
  );
});

for (const scenario of authorizationContract.scenarios) {
  test(`shared scenario: ${scenario.id}`, () => {
    if (scenario.expectedError === 'invalid_identity') {
      assert.throws(() => resolveContractScenario(scenario.input), TypeError);
      return;
    }

    const authorization = resolveContractScenario(scenario.input);
    const roleOrder = authorizationContract.roles;
    const roles = [...authorization.roles].sort(
      (left, right) => roleOrder.indexOf(left) - roleOrder.indexOf(right),
    );
    assert.deepEqual({
      hasActiveMembership: authorization.hasActiveMembership,
      usesLegacyFallback: authorization.usesLegacyFallback,
      isPlatformAdministrator: authorization.isPlatformAdministrator,
      isOrganizationAdmin: authorization.isOrganizationAdmin,
      isCoordinator: authorization.isCoordinator,
      isSiteManager: authorization.isSiteManager,
      isProfessional: authorization.isProfessional,
      hasOrganizationAccess: authorization.hasOrganizationAccess,
      roles,
      allowedPermissions: ORGANIZATION_PERMISSIONS.filter(
        authorization.allows,
      ),
    }, scenario.expected, scenario.description);
  });
}

test('organization admin is active only inside its membership organization', () => {
  const membership = membershipFor('organization-a', 'admin-a', [
    'organization_admin',
  ]);
  const inA = resolveOrganizationAuthorization({
    organizationId: 'organization-a',
    uid: 'admin-a',
    membership,
  });
  const inB = resolveOrganizationAuthorization({
    organizationId: 'organization-b',
    uid: 'admin-a',
  });

  assert.equal(inA.isOrganizationAdmin, true);
  assert.equal(inA.isPlatformAdministrator, false);
  assert.equal(ORGANIZATION_PERMISSIONS.every(inA.allows), true);
  assert.equal(inB.isOrganizationAdmin, false);
  assert.equal(inB.allows('read_operations'), false);
});

test('inactive or malformed membership fails closed without legacy fallback', () => {
  for (const membership of [
    membershipFor('legacy-gironde', 'user-a', ['coordinator'], {active: false}),
    membershipFor('legacy-gironde', 'user-a', ['unknown']),
    membershipFor('legacy-gironde', 'user-a', ['coordinator'], {
      schemaVersion: 0,
    }),
    membershipFor('legacy-gironde', 'user-a', ['coordinator'], {
      locationIds: ['*'],
    }),
    membershipFor('legacy-gironde', 'user-a', ['site_manager']),
  ]) {
    const authorization = resolveOrganizationAuthorization({
      organizationId: 'legacy-gironde',
      uid: 'user-a',
      membership,
      legacyRole: activeRole('coordinator'),
    });

    assert.equal(authorization.hasActiveMembership, false);
    assert.equal(authorization.usesLegacyFallback, false);
    assert.deepEqual(authorization.roles, []);
  }
});

test('platform admin stays global and distinct from organization admin', () => {
  for (const organizationId of ['organization-a', 'organization-b']) {
    const authorization = resolveOrganizationAuthorization({
      organizationId,
      uid: 'platform-admin',
      platformAdministrator: true,
    });

    assert.equal(authorization.isPlatformAdministrator, true);
    assert.equal(authorization.isOrganizationAdmin, false);
    assert.equal(ORGANIZATION_PERMISSIONS.every(authorization.allows), true);
  }
});

test('one uid can hold different roles in organizations A and B', () => {
  const coordinator = resolveOrganizationAuthorization({
    organizationId: 'organization-a',
    uid: 'same-user',
    membership: membershipFor('organization-a', 'same-user', ['coordinator']),
  });
  const manager = resolveOrganizationAuthorization({
    organizationId: 'organization-b',
    uid: 'same-user',
    membership: membershipFor('organization-b', 'same-user', ['site_manager'], {
      locationIds: ['site-b'],
    }),
  });

  assert.equal(coordinator.isCoordinator, true);
  assert.equal(coordinator.isSiteManager, false);
  assert.equal(manager.isCoordinator, false);
  assert.equal(manager.isSiteManager, true);
  assert.equal(manager.allows('manage_sites'), false);
});

test('coordinator is organization-wide and site manager is location-scoped', () => {
  const coordinator = resolveOrganizationAuthorization({
    organizationId: 'organization-a',
    uid: 'coordinator-a',
    membership: membershipFor('organization-a', 'coordinator-a', [
      'coordinator',
      'professional',
    ]),
  });
  const manager = resolveOrganizationAuthorization({
    organizationId: 'organization-b',
    uid: 'manager-b',
    membership: membershipFor('organization-b', 'manager-b', [
      'site_manager',
    ], {locationIds: ['site-b']}),
  });

  assert.equal(canReadOrganizationMissionTeam({
    authorization: coordinator,
    locationId: 'any-site-a',
  }), true);
  assert.equal(canReadOrganizationMissionTeam({
    authorization: manager,
    locationId: 'site-b',
  }), true);
  assert.equal(canReadOrganizationMissionTeam({
    authorization: manager,
    locationId: 'site-a',
  }), false);
});

test('legacy roles are accepted only in legacy Gironde and without membership', () => {
  const legacy = resolveOrganizationAuthorization({
    organizationId: 'legacy-gironde',
    uid: 'legacy-user',
    legacyRole: activeRole('site_manager'),
  });
  const outside = resolveOrganizationAuthorization({
    organizationId: 'organization-a',
    uid: 'legacy-user',
    legacyRole: activeRole('site_manager'),
  });

  assert.equal(legacy.usesLegacyFallback, true);
  assert.equal(legacy.isSiteManager, true);
  assert.equal(outside.usesLegacyFallback, false);
  assert.deepEqual(outside.roles, []);
});

test('shared reader loads roles only for the legacy organization', async () => {
  const documents = new Map([
    ['organizationMemberships/organization-a_user-a', membershipFor(
      'organization-a',
      'user-a',
      ['professional'],
    )],
    ['platformAdministrators/user-a', {active: false}],
    ['roles/user-a', activeRole('coordinator')],
  ]);
  const reads = [];
  const firestore = fakeFirestore(documents, reads);

  const explicit = await readOrganizationAuthorization({
    firestore,
    organizationId: 'organization-a',
    uid: 'user-a',
  });
  assert.equal(explicit.isProfessional, true);
  assert.equal(reads.includes('roles/user-a'), false);

  reads.length = 0;
  const legacy = await readOrganizationAuthorization({
    firestore,
    organizationId: 'legacy-gironde',
    uid: 'user-a',
  });
  assert.equal(legacy.isCoordinator, true);
  assert.equal(reads.includes('roles/user-a'), true);
});

function membershipFor(organizationId, uid, roles, overrides = {}) {
  return {
    organizationId,
    uid,
    roles,
    locationIds: [],
    active: true,
    schemaVersion: 1,
    ...overrides,
  };
}

function activeRole(role) {
  return {
    role,
    locationIds: role === 'coordinator' ? [] : ['site-a'],
    active: true,
  };
}

function resolveContractScenario(input) {
  return resolveOrganizationAuthorization({
    organizationId: input.organizationId,
    uid: input.uid,
    membership: input.membership,
    legacyRole: legacyRoleDocument(input.legacyAccess),
    platformAdministrator: input.platformAdministrator,
  });
}

function legacyRoleDocument(access) {
  if (access === null) return null;
  return {
    role: access.roles.includes('coordinator')
      ? 'coordinator'
      : 'site_manager',
    roles: access.roles,
    locationIds: access.locationIds,
    active: access.active,
    schemaVersion: 2,
  };
}

function fakeFirestore(documents, reads) {
  return {
    collection(collectionName) {
      return {
        doc(id) {
          const path = `${collectionName}/${id}`;
          return {
            async get() {
              reads.push(path);
              const data = documents.get(path);
              return {
                exists: data !== undefined,
                data: () => data,
              };
            },
          };
        },
      };
    },
  };
}
