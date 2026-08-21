import assert from 'node:assert/strict';
import test from 'node:test';

import {
  canReadOrganizationMissionTeam,
  ORGANIZATION_PERMISSIONS,
  readOrganizationAuthorization,
  resolveOrganizationAuthorization,
} from '../src/organization_authorization.js';

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
