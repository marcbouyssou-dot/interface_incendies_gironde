import assert from 'node:assert/strict';
import test from 'node:test';

import {
  mergeResponsibleAccess,
  parseResponsibleAccess,
  ResponsibleAccessError,
} from '../src/responsible_access.js';

function legacy(role, locationIds, overrides = {}) {
  return {
    role,
    ...(locationIds === undefined ? {} : {locationIds}),
    active: true,
    ...overrides,
  };
}

function v2(roles, locationIds, overrides = {}) {
  return {
    role: roles.includes('coordinator') ? 'coordinator' : 'site_manager',
    roles,
    locationIds,
    active: true,
    schemaVersion: 2,
    ...overrides,
  };
}

function assignment(role, locationIds = []) {
  return {role, locationIds};
}

function assertAccessError(action, code = 'malformed-role') {
  assert.throws(action, (error) => {
    assert.ok(error instanceof ResponsibleAccessError);
    assert.equal(error.code, code);
    return true;
  });
}

test('parses a legacy coordinator wildcard without exposing it as a location', () => {
  const value = parseResponsibleAccess(legacy('coordinator', ['*']));
  assert.deepEqual(value.roles, ['coordinator']);
  assert.deepEqual(value.locationIds, []);
});

test('parses a legacy coordinator with an empty scope', () => {
  const value = parseResponsibleAccess(legacy('coordinator', []));
  assert.deepEqual(value.roles, ['coordinator']);
  assert.deepEqual(value.locationIds, []);
});

test('parses a legacy coordinator without locationIds', () => {
  const value = parseResponsibleAccess(legacy('coordinator', undefined));
  assert.deepEqual(value.locationIds, []);
});

test('parses a legacy single-location site manager', () => {
  const value = parseResponsibleAccess(legacy('site_manager', ['bazas']));
  assert.deepEqual(value.roles, ['site_manager']);
  assert.deepEqual(value.locationIds, ['bazas']);
});

test('parses and sorts a legacy multi-location site manager', () => {
  const value = parseResponsibleAccess(
    legacy('site_manager', ['bazas', 'bassens']),
  );
  assert.deepEqual(value.locationIds, ['bassens', 'bazas']);
});

test('refuses a legacy site manager without a location', () => {
  assertAccessError(() => parseResponsibleAccess(legacy('site_manager', [])));
});

test('refuses a legacy site manager wildcard', () => {
  assertAccessError(
    () => parseResponsibleAccess(legacy('site_manager', ['*'])),
  );
});

test('parses a V2 coordinator', () => {
  const value = parseResponsibleAccess(v2(['coordinator'], []));
  assert.equal(value.role, 'coordinator');
  assert.deepEqual(value.roles, ['coordinator']);
});

test('parses a V2 site manager', () => {
  const value = parseResponsibleAccess(v2(['site_manager'], ['bazas']));
  assert.equal(value.role, 'site_manager');
  assert.deepEqual(value.locationIds, ['bazas']);
});

test('parses a cumulative V2 role', () => {
  const value = parseResponsibleAccess(
    v2(['coordinator', 'site_manager'], ['bazas']),
  );
  assert.equal(value.role, 'coordinator');
  assert.deepEqual(value.roles, ['coordinator', 'site_manager']);
});

test('refuses an inconsistent V2 legacy projection', () => {
  assertAccessError(() => parseResponsibleAccess(v2(
    ['coordinator', 'site_manager'],
    ['bazas'],
    {role: 'site_manager'},
  )));
});

test('refuses non-canonical V2 role order', () => {
  assertAccessError(() => parseResponsibleAccess(
    v2(['site_manager', 'coordinator'], ['bazas']),
  ));
});

test('refuses duplicate V2 roles', () => {
  assertAccessError(() => parseResponsibleAccess(
    v2(['coordinator', 'coordinator'], []),
  ));
});

test('refuses an unknown V2 role', () => {
  assertAccessError(() => parseResponsibleAccess(v2(['administrator'], [])));
});

test('refuses an unsupported V2 schema version', () => {
  assertAccessError(() => parseResponsibleAccess(
    v2(['coordinator'], [], {schemaVersion: 3}),
  ));
});

for (const [label, document] of [
  ['missing active', {role: 'coordinator', locationIds: []}],
  ['invalid active type', legacy('coordinator', [], {active: 'true'})],
  [
    'non-string V2 location',
    v2(['site_manager'], ['bazas', 42]),
  ],
  [
    'duplicate V2 location',
    v2(['site_manager'], ['bazas', 'bazas']),
  ],
  ['V2 wildcard', v2(['site_manager'], ['*'])],
]) {
  test(`refuses malformed access: ${label}`, () => {
    assertAccessError(() => parseResponsibleAccess(document));
  });
}

test('creates a canonical coordinator role from no role', () => {
  assert.deepEqual(
    mergeResponsibleAccess(null, assignment('coordinator')),
    {
      role: 'coordinator',
      roles: ['coordinator'],
      locationIds: [],
      active: true,
      schemaVersion: 2,
    },
  );
});

test('creates a canonical site manager role from no role', () => {
  const value = mergeResponsibleAccess(
    null,
    assignment('site_manager', ['bazas']),
  );
  assert.deepEqual(value.roles, ['site_manager']);
  assert.deepEqual(value.locationIds, ['bazas']);
});

test('adds site manager to an existing coordinator', () => {
  const value = mergeResponsibleAccess(
    legacy('coordinator', []),
    assignment('site_manager', ['bazas']),
  );
  assert.deepEqual(value.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(value.locationIds, ['bazas']);
});

test('adds coordinator to an existing site manager', () => {
  const value = mergeResponsibleAccess(
    legacy('site_manager', ['bazas']),
    assignment('coordinator'),
  );
  assert.equal(value.role, 'coordinator');
  assert.deepEqual(value.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(value.locationIds, ['bazas']);
});

test('merges new locations into an existing site manager', () => {
  const value = mergeResponsibleAccess(
    legacy('site_manager', ['bazas']),
    assignment('site_manager', ['bassens']),
  );
  assert.deepEqual(value.locationIds, ['bassens', 'bazas']);
});

test('merges new locations into an existing cumulative role', () => {
  const value = mergeResponsibleAccess(
    v2(['coordinator', 'site_manager'], ['bazas']),
    assignment('site_manager', ['bassens']),
  );
  assert.deepEqual(value.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(value.locationIds, ['bassens', 'bazas']);
});

test('replaces a legacy coordinator wildcard with explicit manager locations', () => {
  const value = mergeResponsibleAccess(
    legacy('coordinator', ['*']),
    assignment('site_manager', ['bazas']),
  );
  assert.deepEqual(value.locationIds, ['bazas']);
  assert.equal(value.locationIds.includes('*'), false);
});

test('repeated assignment is idempotent', () => {
  const first = mergeResponsibleAccess(
    legacy('site_manager', ['bazas']),
    assignment('site_manager', ['bazas']),
  );
  const second = mergeResponsibleAccess(first, assignment(
    'site_manager',
    ['bazas'],
  ));
  assert.deepEqual(second, first);
});

test('canonical role order remains stable after every merge', () => {
  const value = mergeResponsibleAccess(
    legacy('site_manager', ['bazas']),
    assignment('coordinator'),
  );
  assert.deepEqual(value.roles, ['coordinator', 'site_manager']);
});

test('merged locations are sorted and deduplicated across assignments', () => {
  const value = mergeResponsibleAccess(
    legacy('site_manager', ['bazas', 'bassens']),
    assignment('site_manager', ['bazas', 'merignac']),
  );
  assert.deepEqual(value.locationIds, ['bassens', 'bazas', 'merignac']);
});

test('refuses additive attribution to an inactive account', () => {
  assertAccessError(
    () => mergeResponsibleAccess(
      legacy('coordinator', [], {active: false}),
      assignment('site_manager', ['bazas']),
    ),
    'inactive-role',
  );
});

for (const [label, requested] of [
  ['coordinator with locations', assignment('coordinator', ['bazas'])],
  ['site manager wildcard', assignment('site_manager', ['*'])],
  [
    'site manager duplicate locations',
    assignment('site_manager', ['bazas', 'bazas']),
  ],
]) {
  test(`refuses invalid requested assignment: ${label}`, () => {
    assertAccessError(
      () => mergeResponsibleAccess(null, requested),
      'invalid-assignment',
    );
  });
}
