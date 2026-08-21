import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildLegacyOrganizationBackfillPlan,
  changesForLegacyOrganizationBackfill,
  legacyOrganizationBackfillProjectId,
  legacyOrganizationId,
  legacyOrganizationPath,
  legacyOrganizationValues,
  materializeLegacyOrganizationChange,
  resolveLegacyOrganizationBackfillExecution,
  runLegacyOrganizationBackfill,
} from './legacy_organization_backfill.mjs';

const fakeTimestamp = Object.freeze({toDate: () => new Date(0)});

test('legacy organization is prepared with an implicit document id', () => {
  const plan = buildPlan();
  const change = changesForLegacyOrganizationBackfill(plan)[0];
  const materialized = materializeLegacyOrganizationChange({
    change,
    serverTimestamp: () => fakeTimestamp,
  });

  assert.equal(plan.organization.action, 'create');
  assert.equal(change.path, legacyOrganizationPath);
  assert.deepEqual(materialized.values, {
    ...legacyOrganizationValues,
    createdAt: fakeTimestamp,
    updatedAt: fakeTimestamp,
  });
  assert.equal(Object.hasOwn(materialized.values, 'id'), false);
});

test('compatible additive organization is unchanged', () => {
  const plan = buildPlan({
    organizations: [{
      id: legacyOrganizationId,
      data: {
        ...legacyOrganizationValues,
        schemaVersion: 3,
        createdAt: fakeTimestamp,
        updatedAt: fakeTimestamp,
        futurePolicy: 'reserved',
      },
    }],
  });

  assert.equal(plan.organization.action, 'unchanged');
  assert.equal(plan.summary.global, 'GO');
});

test('legacy and V2 RC3 roles produce canonical memberships', () => {
  const plan = buildPlan({
    roles: [
      roleDocument('coordinator', {
        role: 'coordinator',
        locationIds: ['*'],
        active: true,
      }),
      roleDocument('manager', {
        role: 'site_manager',
        locationIds: ['site-a'],
        active: false,
      }),
      roleDocument('cumulative', {
        role: 'coordinator',
        roles: ['coordinator', 'site_manager'],
        locationIds: ['site-b'],
        active: true,
        schemaVersion: 2,
      }),
    ],
    platformAdministrators: [document('platform-admin', {active: true})],
    volunteers: [document('anonymous-professional', {uid: 'anonymous-professional'})],
  });

  assert.equal(plan.summary.memberships.usersConcerned, 3);
  assert.equal(plan.summary.memberships.create, 3);
  assert.equal(plan.summary.memberships.inactive, 1);
  assert.equal(
    plan.summary.memberships.platformAdministratorMembershipsProposed,
    0,
  );
  assert.equal(plan.summary.memberships.professionalMembershipsProposed, 0);
  assert.deepEqual(
    plan.memberships.entries.map((entry) => entry.path).sort(),
    [
      `organizationMemberships/${legacyOrganizationId}_coordinator`,
      `organizationMemberships/${legacyOrganizationId}_cumulative`,
      `organizationMemberships/${legacyOrganizationId}_manager`,
    ],
  );
  const cumulative = plan.memberships.entries.find(
    (entry) => entry.uid === 'cumulative',
  );
  assert.deepEqual(cumulative.values.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(cumulative.values.locationIds, ['site-b']);
});

test('canonical existing membership prevents duplicates', () => {
  const plan = buildPlan({
    roles: [roleDocument('coordinator', {
      role: 'coordinator',
      locationIds: ['*'],
      active: true,
    })],
    organizationMemberships: [membershipDocument('coordinator')],
  });

  assert.equal(plan.summary.memberships.create, 0);
  assert.equal(plan.summary.memberships.unchanged, 1);
  assert.equal(plan.summary.memberships.conflicts, 0);
});

test('malformed roles and non-canonical memberships are blockers', () => {
  const plan = buildPlan({
    roles: [roleDocument('malformed-role', {
      role: 'coordinator',
      locationIds: ['site-a'],
      active: true,
    })],
    organizationMemberships: [{
      id: 'non-canonical',
      data: membershipData('another-user'),
    }],
  });

  assert.equal(plan.summary.memberships.malformedRoles, 1);
  assert.equal(plan.summary.memberships.conflicts, 1);
  assert.equal(plan.summary.global, 'NO-GO');
  assert.throws(
    () => changesForLegacyOrganizationBackfill(plan),
    /diagnostic contient des conflits/,
  );
});

test('operations without owner are additive and explicit owners are preserved', () => {
  const plan = buildPlan({
    operations: [
      document('missing-owner', {}),
      document('null-owner', {ownerOrganizationId: null}),
      document('legacy-owner', {ownerOrganizationId: legacyOrganizationId}),
      document('explicit-owner', {ownerOrganizationId: 'ars-na'}),
    ],
  });

  assert.deepEqual(plan.summary.operations, {
    total: 4,
    toBackfill: 2,
    alreadyLegacy: 1,
    explicitRc4: 1,
    conflicts: 0,
    malformed: 0,
  });
  const operationChanges = changesForLegacyOrganizationBackfill(plan)
    .filter((change) => change.kind === 'operation');
  assert.deepEqual(
    operationChanges.map((change) => change.path).sort(),
    ['operations/missing-owner', 'operations/null-owner'],
  );
});

test('children are audited for derivation without planned writes', () => {
  const plan = buildPlan({
    operations: [document('operation-a', {})],
    mobilizations: [
      document('mobilization-a', {operationId: 'operation-a'}),
      document('mobilization-legacy', {}),
    ],
    missions: [
      document('mission-a', {mobilizationId: 'mobilization-a'}),
      document('mission-legacy', {mobilizationId: 'mobilization-legacy'}),
      document('mission-orphan', {mobilizationId: 'missing'}),
    ],
    engagements: [document('engagement-a', {missionId: 'mission-a'})],
    mobilizationAssignments: [
      document('assignment-a', {mobilizationId: 'mobilization-a'}),
    ],
    locations: [
      document('site-deferred', {}),
      document('site-explicit', {managingOrganizationId: 'hospital-a'}),
    ],
  });

  assert.deepEqual(plan.summary.children.mobilizations, {
    total: 2,
    derive: 1,
    legacyFallback: 1,
    explicit: 0,
    defer: 0,
    unresolved: 0,
    backfillNow: 0,
  });
  assert.equal(plan.summary.children.missions.derive, 1);
  assert.equal(plan.summary.children.missions.legacyFallback, 1);
  assert.equal(plan.summary.children.missions.unresolved, 1);
  assert.equal(plan.summary.children.locations.defer, 1);
  assert.equal(plan.summary.children.locations.explicit, 1);
});

test('dry-run performs no write', async () => {
  const store = memoryStore({operations: [document('operation-a', {})]});

  const result = await execute(store, 'dry-run');

  assert.equal(result.writes, 0);
  assert.equal(store.writeCalls, 0);
  assert.equal(store.changes.length, 0);
});

test('apply logic is idempotent in memory', async () => {
  const store = memoryStore({
    roles: [roleDocument('coordinator', {
      role: 'coordinator',
      locationIds: ['*'],
      active: true,
    })],
    operations: [document('operation-a', {})],
  });

  const first = await execute(store, 'apply');
  const second = await execute(store, 'apply');

  assert.equal(first.writes, 3);
  assert.equal(second.writes, 0);
  assert.equal(first.after.summary.operations.toBackfill, 0);
  assert.equal(first.after.summary.memberships.create, 0);
  assert.equal(store.changes.length, 3);
});

test('project and write mode must be explicit', () => {
  assert.deepEqual(
    resolveLegacyOrganizationBackfillExecution([
      '--project',
      legacyOrganizationBackfillProjectId,
      '--dry-run',
    ]),
    {mode: 'dry-run', projectId: legacyOrganizationBackfillProjectId},
  );
  assert.deepEqual(
    resolveLegacyOrganizationBackfillExecution([
      `--project=${legacyOrganizationBackfillProjectId}`,
      '--apply-confirmed',
    ]),
    {mode: 'apply', projectId: legacyOrganizationBackfillProjectId},
  );
  assert.throws(
    () => resolveLegacyOrganizationBackfillExecution([
      '--project',
      legacyOrganizationBackfillProjectId,
    ]),
    /mode explicite/i,
  );
  assert.throws(
    () => resolveLegacyOrganizationBackfillExecution([
      '--project',
      'another-project',
      '--dry-run',
    ]),
    /Projet Firebase refusé/,
  );
});

function buildPlan(overrides = {}) {
  return buildLegacyOrganizationBackfillPlan({
    organizations: [],
    organizationMemberships: [],
    roles: [],
    platformAdministrators: [],
    volunteers: [],
    operations: [],
    mobilizations: [],
    missions: [],
    engagements: [],
    mobilizationAssignments: [],
    locations: [],
    ...overrides,
    isTimestamp: (value) => value === fakeTimestamp,
  });
}

function roleDocument(id, data) {
  return document(id, data);
}

function membershipDocument(uid) {
  return document(`${legacyOrganizationId}_${uid}`, membershipData(uid));
}

function membershipData(uid) {
  return {
    organizationId: legacyOrganizationId,
    uid,
    roles: ['coordinator'],
    locationIds: [],
    active: true,
    schemaVersion: 1,
    createdAt: fakeTimestamp,
    updatedAt: fakeTimestamp,
  };
}

function document(id, data) {
  return {id, data};
}

function emptyCollections() {
  return {
    organizations: [],
    organizationMemberships: [],
    roles: [],
    platformAdministrators: [],
    volunteers: [],
    operations: [],
    mobilizations: [],
    missions: [],
    engagements: [],
    mobilizationAssignments: [],
    locations: [],
  };
}

function memoryStore(initial = {}) {
  return {
    documents: {...emptyCollections(), ...initial},
    changes: [],
    writeCalls: 0,
  };
}

async function execute(store, mode) {
  return runLegacyOrganizationBackfill({
    mode,
    readCollections: async () => cloneCollections(store.documents),
    writeChanges: async (changes) => {
      store.writeCalls++;
      for (const change of changes) {
        const [collection, id] = change.path.split('/');
        if (change.kind === 'operation') {
          const target = store.documents[collection].find(
            (candidate) => candidate.id === id,
          );
          Object.assign(target.data, change.values);
        } else {
          const materialized = materializeLegacyOrganizationChange({
            change,
            serverTimestamp: () => fakeTimestamp,
          });
          store.documents[collection].push({
            id,
            data: materialized.values,
          });
        }
        store.changes.push(change);
      }
      return changes.length;
    },
    batchSize: 2,
  });
}

function cloneCollections(collections) {
  return Object.fromEntries(
    Object.entries(collections).map(([name, documents]) => [
      name,
      documents.map((item) => ({
        id: item.id,
        data: {
          ...item.data,
          ...(Array.isArray(item.data.roles)
            ? {roles: [...item.data.roles]}
            : {}),
          ...(Array.isArray(item.data.locationIds)
            ? {locationIds: [...item.data.locationIds]}
            : {}),
        },
      })),
    ]),
  );
}
