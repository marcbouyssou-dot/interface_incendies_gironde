import assert from 'node:assert/strict';
import test from 'node:test';

import {
  listResponsibleAccess,
  ResponsibleAccessAdministrationError,
  safeResponsibleAccount,
  updateResponsibleAccess,
  validateUpdateRequest,
} from '../src/update_responsible_access.js';

const siteIds = (count) => Array.from(
  {length: count},
  (_, index) => `site-${String(index + 1).padStart(2, '0')}`,
);

function request(overrides = {}) {
  return {
    targetUid: 'target',
    roles: ['site_manager'],
    locationIds: ['merignac'],
    active: true,
    ...overrides,
  };
}

function services() {
  const calls = [];
  return {
    calls,
    async commitResponsibleAccessUpdate(value) {
      calls.push(value);
      return {account: value};
    },
    async listResponsibleAccounts({callerUid}) {
      calls.push({callerUid});
      return [{uid: 'target'}];
    },
  };
}

test('normalizes all three supported assignments', () => {
  assert.deepEqual(validateUpdateRequest(request({
    roles: ['coordinator'], locationIds: [],
  })).roles, ['coordinator']);
  assert.deepEqual(validateUpdateRequest(request()).roles, ['site_manager']);
  assert.deepEqual(validateUpdateRequest(request({
    roles: ['coordinator', 'site_manager'],
  })).roles, ['coordinator', 'site_manager']);
});

test('accepts deactivation and exactly 65 locations', () => {
  const value = validateUpdateRequest(request({
    locationIds: siteIds(65), active: false,
  }));
  assert.equal(value.locationIds.length, 65);
  assert.equal(value.active, false);
});

for (const [label, overrides] of [
  ['unknown field', {unexpected: true}],
  ['missing field', {active: undefined}],
  ['unknown role', {roles: ['administrator']}],
  ['wrong role order', {roles: ['site_manager', 'coordinator']}],
  ['duplicate role', {roles: ['site_manager', 'site_manager']}],
  ['coordinator scope', {roles: ['coordinator'], locationIds: ['merignac']}],
  ['site manager without scope', {locationIds: []}],
  ['duplicate location', {locationIds: ['merignac', 'merignac']}],
  ['wildcard', {locationIds: ['*']}],
  ['blank location', {locationIds: ['\u00a0']}],
  ['rules separator', {locationIds: ['merignac\u001f']}],
  ['66 locations', {locationIds: siteIds(66)}],
]) {
  test(`refuses invalid update: ${label}`, () => {
    const value = request(overrides);
    if (label === 'missing field') delete value.active;
    assert.throws(() => validateUpdateRequest(value), (error) => {
      assert.ok(error instanceof ResponsibleAccessAdministrationError);
      assert.equal(error.code, 'invalid-argument');
      return true;
    });
  });
}

test('refuses an unauthenticated caller before the service', async () => {
  const fake = services();
  await assert.rejects(
    () => updateResponsibleAccess({callerUid: null, data: request(), services: fake}),
    (error) => error.code === 'unauthenticated',
  );
  assert.equal(fake.calls.length, 0);
});

test('always refuses self-modification before the service', async () => {
  const fake = services();
  await assert.rejects(
    () => updateResponsibleAccess({
      callerUid: 'target', data: request(), services: fake,
    }),
    (error) => error.code === 'failed-precondition',
  );
  assert.equal(fake.calls.length, 0);
});

test('passes only a canonical update to the injected service', async () => {
  const fake = services();
  await updateResponsibleAccess({
    callerUid: 'coordinator',
    data: request({roles: ['coordinator'], locationIds: [], active: false}),
    services: fake,
  });
  assert.deepEqual(fake.calls.single ?? fake.calls[0], {
    callerUid: 'coordinator',
    targetUid: 'target',
    role: 'coordinator',
    roles: ['coordinator'],
    locationIds: [],
    active: false,
    schemaVersion: 2,
  });
});

test('lists accounts only through the injected service', async () => {
  const fake = services();
  assert.deepEqual(
    await listResponsibleAccess({callerUid: 'coordinator', services: fake}),
    {accounts: [{uid: 'target'}]},
  );
});

test('safe account projection omits unsupported identity values', () => {
  assert.deepEqual(safeResponsibleAccount('target', {
    role: 'site_manager',
    locationIds: ['merignac'],
    active: false,
  }, {email: 'target@example.test', displayName: 42}), {
    uid: 'target',
    email: 'target@example.test',
    displayName: null,
    role: 'site_manager',
    roles: ['site_manager'],
    locationIds: ['merignac'],
    active: false,
    schemaVersion: 2,
  });
});

test('legacy account projection uses the strict V2 callable contract', () => {
  const account = safeResponsibleAccount('legacy-manager', {
    role: 'site_manager',
    locationIds: ['merignac'],
    active: true,
  });

  assert.deepEqual(account.roles, ['site_manager']);
  assert.equal(account.role, 'site_manager');
  assert.deepEqual(account.locationIds, ['merignac']);
  assert.equal(account.active, true);
  assert.equal(account.schemaVersion, 2);
});
