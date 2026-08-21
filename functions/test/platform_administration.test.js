import assert from 'node:assert/strict';
import test from 'node:test';

import {
  activateMobilization,
  archiveMobilization,
  assignMobilizationCoordinator,
  createOperation,
  createMobilization,
  deactivateMobilization,
  isPlatformAdministrator,
  PlatformAdministrationError,
  removeMobilizationCoordinator,
  setOperationCoordinator,
  transitionOperation,
  updateOperation,
  updateMobilization,
} from '../src/platform_administration.js';
import {
  platformAdministrationServices,
} from '../src/platform_administration_firestore.js';

const ADMIN_UID = 'platform-admin';
const COORDINATOR_UID = 'coordinator';
const NOW = new Date('2026-08-10T10:00:00.000Z');

function mobilizationPayload(overrides = {}) {
  return {
    mobilizationId: 'incendies-gironde-2026',
    territoryId: 'gironde',
    name: 'Mobilisation santé',
    subtitle: 'Incendies Gironde',
    contextType: 'fire',
    ...overrides,
  };
}

function mobilizationDocument(id, status = 'draft', overrides = {}) {
  return {
    id,
    territoryId: 'gironde',
    name: `Mobilisation ${id}`,
    subtitle: 'Contexte de test',
    contextType: 'fire',
    status,
    createdBy: ADMIN_UID,
    createdAt: new Date('2026-08-01T08:00:00.000Z'),
    updatedBy: ADMIN_UID,
    updatedAt: new Date('2026-08-01T08:00:00.000Z'),
    schemaVersion: 1,
    ...overrides,
  };
}

function operationPayload(overrides = {}) {
  return {
    operationId: 'operation-a',
    name: 'Opération A',
    type: 'natural_disaster',
    context: null,
    startAtMillis: Date.UTC(2026, 7, 20, 8),
    endAtMillis: null,
    scopeRefs: ['territories/gironde'],
    ...overrides,
  };
}

function operationDocument(id, status = 'draft', overrides = {}) {
  return {
    id,
    name: `Opération ${id}`,
    type: 'natural_disaster',
    status,
    context: null,
    startAt: new Date(Date.UTC(2026, 7, 20, 8)),
    endAt: null,
    scopeRefs: ['territories/gironde'],
    createdBy: ADMIN_UID,
    createdAt: new Date('2026-08-01T08:00:00.000Z'),
    updatedBy: ADMIN_UID,
    updatedAt: new Date('2026-08-01T08:00:00.000Z'),
    schemaVersion: 1,
    ...overrides,
  };
}

function harness({administrator = true} = {}) {
  const firestore = new MemoryFirestore();
  if (administrator !== null) {
    firestore.seed(`platformAdministrators/${ADMIN_UID}`, {
      active: administrator,
    });
  }
  firestore.seed('territories/gironde', {
    id: 'gironde',
    name: 'Gironde',
    code: '33',
    active: true,
  });
  firestore.seed(`roles/${COORDINATOR_UID}`, {
    role: 'coordinator',
    roles: ['coordinator'],
    locationIds: [],
    active: true,
    schemaVersion: 2,
  });
  return {
    firestore,
    services: platformAdministrationServices({
      firestore,
      serverTimestamp: () => new Date(NOW),
    }),
  };
}

function seedAssignment(firestore, mobilizationId, overrides = {}) {
  const uid = overrides.uid ?? COORDINATOR_UID;
  firestore.seed(
    `mobilizationAssignments/${mobilizationId}_${uid}`,
    {
      uid,
      mobilizationId,
      role: 'coordinator',
      active: true,
      assignedBy: ADMIN_UID,
      createdAt: new Date('2026-08-05T08:00:00.000Z'),
      updatedBy: ADMIN_UID,
      updatedAt: new Date('2026-08-05T08:00:00.000Z'),
      ...overrides,
    },
  );
}

async function assertCode(action, code) {
  await assert.rejects(
    action,
    (error) => error instanceof PlatformAdministrationError
      && error.code === code,
  );
}

test('non-authenticated request is refused before any service call', async () => {
  let called = false;
  await assertCode(
    () => createMobilization({
      callerUid: null,
      data: mobilizationPayload(),
      services: {
        async createMobilization() {
          called = true;
        },
      },
    }),
    'unauthenticated',
  );
  assert.equal(called, false);
});

test('central administrator helper accepts only an active record', async () => {
  for (const [record, expected] of [
    [null, false],
    [{active: false}, false],
    [{active: 'true'}, false],
    [{active: true}, true],
  ]) {
    assert.equal(await isPlatformAdministrator(ADMIN_UID, {
      getAdministrator: async () => record,
    }), expected);
  }
});

test('authenticated non-administrator is refused without writes', async () => {
  const {firestore, services} = harness({administrator: null});
  await assertCode(
    () => createMobilization({
      callerUid: 'ordinary-user',
      data: mobilizationPayload(),
      services,
    }),
    'permission-denied',
  );
  assert.equal(firestore.has('mobilizations/incendies-gironde-2026'), false);
});

test('valid creation stores a strict draft with server audit fields', async () => {
  const {firestore, services} = harness();
  const result = await createMobilization({
    callerUid: ADMIN_UID,
    data: mobilizationPayload(),
    services,
  });

  assert.deepEqual(result, {
    mobilizationId: 'incendies-gironde-2026',
    status: 'draft',
  });
  assert.deepEqual(
    firestore.read('mobilizations/incendies-gironde-2026'),
    mobilizationDocument('incendies-gironde-2026', 'draft', {
      name: 'Mobilisation santé',
      subtitle: 'Incendies Gironde',
      createdAt: NOW,
      updatedAt: NOW,
      scopeRefs: ['territories/gironde'],
      schemaVersion: 2,
    }),
  );
});

test('unknown, missing and malformed payload fields are refused', async () => {
  const {services} = harness();
  for (const data of [
    {...mobilizationPayload(), unknown: true},
    {...mobilizationPayload(), contextType: 'wildfire'},
    {...mobilizationPayload(), mobilizationId: 'Invalid ID'},
    {...mobilizationPayload(), subtitle: '   '},
  ]) {
    await assertCode(
      () => createMobilization({callerUid: ADMIN_UID, data, services}),
      'invalid-argument',
    );
  }
});

test('update changes only editable data and preserves lifecycle state', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026', 'inactive'),
  );

  const result = await updateMobilization({
    callerUid: ADMIN_UID,
    data: mobilizationPayload({
      name: 'Nouveau nom',
      subtitle: 'Nouveau sous-titre',
      contextType: 'white_plan',
    }),
    services,
  });

  assert.equal(result.status, 'inactive');
  const stored = firestore.read('mobilizations/incendies-gironde-2026');
  assert.equal(stored.name, 'Nouveau nom');
  assert.equal(stored.subtitle, 'Nouveau sous-titre');
  assert.equal(stored.contextType, 'white_plan');
  assert.equal(stored.status, 'inactive');
  assert.equal(stored.createdAt.toISOString(), '2026-08-01T08:00:00.000Z');
  assert.equal(stored.updatedAt.toISOString(), NOW.toISOString());
});

test('activation without an eligible coordinator is refused atomically', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026'),
  );

  await assertCode(
    () => activateMobilization({
      callerUid: ADMIN_UID,
      data: {mobilizationId: 'incendies-gironde-2026'},
      services,
    }),
    'failed-precondition',
  );
  assert.equal(
    firestore.read('mobilizations/incendies-gironde-2026').status,
    'draft',
  );
  assert.equal(firestore.has('platform/config'), false);
});

test('valid activation writes mobilization and active pointer', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026'),
  );
  seedAssignment(firestore, 'incendies-gironde-2026');

  const result = await activateMobilization({
    callerUid: ADMIN_UID,
    data: {mobilizationId: 'incendies-gironde-2026'},
    services,
  });

  assert.equal(result.status, 'active');
  const stored = firestore.read('mobilizations/incendies-gironde-2026');
  assert.equal(stored.status, 'active');
  assert.equal(stored.activatedBy, ADMIN_UID);
  assert.equal(stored.activatedAt.toISOString(), NOW.toISOString());
  assert.deepEqual(firestore.read('platform/config'), {
    activeMobilizationId: 'incendies-gironde-2026',
    updatedBy: ADMIN_UID,
    updatedAt: NOW,
  });
});

test('activation preserves other active mobilizations and the legacy pointer', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/previous',
    mobilizationDocument('previous', 'active'),
  );
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026', 'inactive'),
  );
  firestore.seed('platform/config', {activeMobilizationId: 'previous'});
  seedAssignment(firestore, 'incendies-gironde-2026');

  await activateMobilization({
    callerUid: ADMIN_UID,
    data: {mobilizationId: 'incendies-gironde-2026'},
    services,
  });

  const previous = firestore.read('mobilizations/previous');
  assert.equal(previous.status, 'active');
  assert.equal(
    firestore.read('mobilizations/incendies-gironde-2026').status,
    'active',
  );
  assert.equal(
    firestore.read('platform/config').activeMobilizationId,
    'previous',
  );
});

test('a stale legacy pointer never blocks target activation', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026', 'inactive'),
  );
  firestore.seed('platform/config', {
    activeMobilizationId: 'incendies-gironde-2026',
  });
  seedAssignment(firestore, 'incendies-gironde-2026');

  await activateMobilization({
    callerUid: ADMIN_UID,
    data: {mobilizationId: 'incendies-gironde-2026'},
    services,
  });

  assert.equal(
    firestore.read('mobilizations/incendies-gironde-2026').status,
    'active',
  );
  assert.equal(
    firestore.read('platform/config').activeMobilizationId,
    'incendies-gironde-2026',
  );
});

test('deactivating a non-legacy active mobilization keeps the fallback', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/previous',
    mobilizationDocument('previous', 'active'),
  );
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026', 'active'),
  );
  firestore.seed('platform/config', {activeMobilizationId: 'previous'});

  await deactivateMobilization({
    callerUid: ADMIN_UID,
    data: {mobilizationId: 'incendies-gironde-2026'},
    services,
  });

  assert.equal(
    firestore.read('platform/config').activeMobilizationId,
    'previous',
  );
});

test('operation lifecycle follows the strict transition graph', async () => {
  const {firestore, services} = harness();
  const created = await createOperation({
    callerUid: ADMIN_UID,
    data: operationPayload(),
    services,
  });
  assert.deepEqual(created, {operationId: 'operation-a', status: 'draft'});
  assert.deepEqual(
    firestore.read('operations/operation-a'),
    operationDocument('operation-a', 'draft', {
      name: 'Opération A',
      coordinatorUid: null,
      createdAt: NOW,
      updatedAt: NOW,
      schemaVersion: 2,
    }),
  );

  for (const targetStatus of ['planned', 'active', 'suspended', 'completed', 'archived']) {
    const result = await transitionOperation({
      callerUid: ADMIN_UID,
      data: {operationId: 'operation-a', targetStatus},
      services,
    });
    assert.equal(result.status, targetStatus);
  }
  await assertCode(
    () => transitionOperation({
      callerUid: ADMIN_UID,
      data: {operationId: 'operation-a', targetStatus: 'active'},
      services,
    }),
    'failed-precondition',
  );
});

test('operation update preserves status and accepts no end date', async () => {
  const {firestore, services} = harness();
  firestore.seed('operations/operation-a', operationDocument('operation-a', 'planned'));

  const result = await updateOperation({
    callerUid: ADMIN_UID,
    data: operationPayload({name: 'Opération A actualisée'}),
    services,
  });

  assert.equal(result.status, 'planned');
  assert.equal(firestore.read('operations/operation-a').endAt, null);
  assert.equal(
    firestore.read('operations/operation-a').name,
    'Opération A actualisée',
  );
});

test('operation coordinator can be named before any mobilization exists', async () => {
  const {firestore, services} = harness();
  firestore.seed('operations/operation-a', operationDocument('operation-a'));

  const result = await setOperationCoordinator({
    callerUid: ADMIN_UID,
    data: {operationId: 'operation-a', uid: COORDINATOR_UID},
    services,
  });

  assert.equal(result.mobilizationCount, 0);
  assert.equal(result.activeMobilizationCount, 0);
  assert.equal(
    firestore.read('operations/operation-a').coordinatorUid,
    COORDINATOR_UID,
  );
  assert.equal(
    firestore.read(`roles/${COORDINATOR_UID}`)
      .hasActiveMobilizationAssignments,
    false,
  );
});

test('operation coordinator synchronizes active and inactive mobilizations', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'operations/operation-a',
    operationDocument('operation-a', 'active'),
  );
  firestore.seed(
    'mobilizations/mobilization-active',
    mobilizationDocument('mobilization-active', 'active', {
      operationId: 'operation-a',
    }),
  );
  firestore.seed(
    'mobilizations/mobilization-inactive',
    mobilizationDocument('mobilization-inactive', 'inactive', {
      operationId: 'operation-a',
    }),
  );

  const result = await setOperationCoordinator({
    callerUid: ADMIN_UID,
    data: {operationId: 'operation-a', uid: COORDINATOR_UID},
    services,
  });

  assert.equal(result.mobilizationCount, 2);
  assert.equal(result.activeMobilizationCount, 1);
  for (const id of ['mobilization-active', 'mobilization-inactive']) {
    assert.equal(
      firestore.read(
        `mobilizationAssignments/${id}_${COORDINATOR_UID}`,
      ).active,
      true,
    );
  }
});

test('replacement atomically harmonizes divergent assignments', async () => {
  const {firestore, services} = harness();
  const replacementUid = 'coordinator-2';
  firestore.seed(`roles/${replacementUid}`, {
    role: 'coordinator',
    roles: ['coordinator'],
    locationIds: [],
    active: true,
    schemaVersion: 2,
    hasActiveMobilizationAssignments: true,
  });
  firestore.seed(
    'operations/operation-a',
    operationDocument('operation-a', 'active', {
      coordinatorUid: COORDINATOR_UID,
    }),
  );
  for (const [id, status] of [
    ['mobilization-a', 'active'],
    ['mobilization-b', 'inactive'],
  ]) {
    firestore.seed(
      `mobilizations/${id}`,
      mobilizationDocument(id, status, {operationId: 'operation-a'}),
    );
  }
  seedAssignment(firestore, 'mobilization-a');
  seedAssignment(firestore, 'mobilization-b', {uid: replacementUid});

  const result = await setOperationCoordinator({
    callerUid: ADMIN_UID,
    data: {operationId: 'operation-a', uid: replacementUid},
    services,
  });

  assert.equal(result.previousCoordinatorUid, COORDINATOR_UID);
  assert.equal(
    firestore.read('operations/operation-a').coordinatorUid,
    replacementUid,
  );
  assert.equal(
    firestore.read(
      `mobilizationAssignments/mobilization-a_${COORDINATOR_UID}`,
    ).active,
    false,
  );
  for (const id of ['mobilization-a', 'mobilization-b']) {
    assert.equal(
      firestore.read(
        `mobilizationAssignments/${id}_${replacementUid}`,
      ).active,
      true,
    );
  }
  assert.equal(
    firestore.read(`roles/${COORDINATOR_UID}`)
      .hasActiveMobilizationAssignments,
    false,
  );
});

test('failed operation coordinator replacement leaves every record unchanged', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'operations/operation-a',
    operationDocument('operation-a', 'active', {
      coordinatorUid: COORDINATOR_UID,
    }),
  );
  firestore.seed(
    'mobilizations/mobilization-a',
    mobilizationDocument('mobilization-a', 'active', {
      operationId: 'operation-a',
    }),
  );
  seedAssignment(firestore, 'mobilization-a');
  const operationBefore = firestore.read('operations/operation-a');
  const assignmentBefore = firestore.read(
    `mobilizationAssignments/mobilization-a_${COORDINATOR_UID}`,
  );

  await assertCode(
    () => setOperationCoordinator({
      callerUid: ADMIN_UID,
      data: {operationId: 'operation-a', uid: 'inactive-coordinator'},
      services,
    }),
    'failed-precondition',
  );

  assert.deepEqual(firestore.read('operations/operation-a'), operationBefore);
  assert.deepEqual(
    firestore.read(
      `mobilizationAssignments/mobilization-a_${COORDINATOR_UID}`,
    ),
    assignmentBefore,
  );
  assert.equal(
    firestore.has(
      'mobilizationAssignments/mobilization-a_inactive-coordinator',
    ),
    false,
  );
});

test('new mobilization refuses a missing operation reference', async () => {
  const {services} = harness();
  await assertCode(
    () => createMobilization({
      callerUid: ADMIN_UID,
      data: mobilizationPayload({
        operationId: 'missing-operation',
        scopeRefs: ['territories/gironde'],
      }),
      services,
    }),
    'not-found',
  );
});

test('multiple mobilizations can reference one operation and stay active', async () => {
  const {firestore, services} = harness();
  firestore.seed('operations/operation-a', operationDocument('operation-a', 'active'));
  for (const mobilizationId of ['mobilization-a1', 'mobilization-a2']) {
    await createMobilization({
      callerUid: ADMIN_UID,
      data: mobilizationPayload({
        mobilizationId,
        operationId: 'operation-a',
        scopeRefs: ['territories/gironde'],
      }),
      services,
    });
    seedAssignment(firestore, mobilizationId);
    await activateMobilization({
      callerUid: ADMIN_UID,
      data: {mobilizationId},
      services,
    });
  }
  assert.equal(firestore.read('mobilizations/mobilization-a1').status, 'active');
  assert.equal(firestore.read('mobilizations/mobilization-a2').status, 'active');
});

test('new mobilization inherits the authoritative operation coordinator', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'operations/operation-a',
    operationDocument('operation-a', 'active', {
      coordinatorUid: COORDINATOR_UID,
    }),
  );

  await createMobilization({
    callerUid: ADMIN_UID,
    data: mobilizationPayload({
      mobilizationId: 'mobilization-new',
      operationId: 'operation-a',
      scopeRefs: ['territories/gironde'],
    }),
    services,
  });

  assert.equal(
    firestore.read(
      `mobilizationAssignments/mobilization-new_${COORDINATOR_UID}`,
    ).active,
    true,
  );
  assert.equal(
    firestore.read(`roles/${COORDINATOR_UID}`)
      .hasActiveMobilizationAssignments,
    true,
  );
});

test('attaching a mobilization harmonizes it with the operation coordinator', async () => {
  const {firestore, services} = harness();
  const previousUid = 'coordinator-previous';
  firestore.seed(`roles/${previousUid}`, {
    role: 'coordinator',
    roles: ['coordinator'],
    locationIds: [],
    active: true,
    schemaVersion: 2,
    hasActiveMobilizationAssignments: true,
  });
  firestore.seed(
    'operations/operation-a',
    operationDocument('operation-a', 'active', {
      coordinatorUid: COORDINATOR_UID,
    }),
  );
  firestore.seed(
    'mobilizations/mobilization-attached',
    mobilizationDocument('mobilization-attached'),
  );
  seedAssignment(firestore, 'mobilization-attached', {uid: previousUid});

  await updateMobilization({
    callerUid: ADMIN_UID,
    data: mobilizationPayload({
      mobilizationId: 'mobilization-attached',
      operationId: 'operation-a',
      scopeRefs: ['territories/gironde'],
    }),
    services,
  });

  assert.equal(
    firestore.read(
      `mobilizationAssignments/mobilization-attached_${previousUid}`,
    ).active,
    false,
  );
  assert.equal(
    firestore.read(
      `mobilizationAssignments/mobilization-attached_${COORDINATOR_UID}`,
    ).active,
    true,
  );
});

test('deactivation updates status, audit and clears active pointer', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026', 'active'),
  );
  firestore.seed('platform/config', {
    activeMobilizationId: 'incendies-gironde-2026',
  });

  const result = await deactivateMobilization({
    callerUid: ADMIN_UID,
    data: {mobilizationId: 'incendies-gironde-2026'},
    services,
  });

  assert.equal(result.status, 'inactive');
  const stored = firestore.read('mobilizations/incendies-gironde-2026');
  assert.equal(stored.status, 'inactive');
  assert.equal(stored.deactivatedBy, ADMIN_UID);
  assert.equal(firestore.read('platform/config').activeMobilizationId, null);
});

test('active mobilization cannot be archived', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026', 'active'),
  );

  await assertCode(
    () => archiveMobilization({
      callerUid: ADMIN_UID,
      data: {mobilizationId: 'incendies-gironde-2026'},
      services,
    }),
    'failed-precondition',
  );
  assert.equal(
    firestore.read('mobilizations/incendies-gironde-2026').status,
    'active',
  );
});

for (const status of ['draft', 'inactive']) {
  test(`${status} mobilization can be archived with audit`, async () => {
    const {firestore, services} = harness();
    firestore.seed(
      'mobilizations/incendies-gironde-2026',
      mobilizationDocument('incendies-gironde-2026', status),
    );

    const result = await archiveMobilization({
      callerUid: ADMIN_UID,
      data: {mobilizationId: 'incendies-gironde-2026'},
      services,
    });

    assert.equal(result.status, 'archived');
    const stored = firestore.read('mobilizations/incendies-gironde-2026');
    assert.equal(stored.status, 'archived');
    assert.equal(stored.archivedBy, ADMIN_UID);
    assert.equal(stored.archivedAt.toISOString(), NOW.toISOString());
  });
}

test('coordinator assignment is deterministic and preserves role scope', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026'),
  );
  const originalRole = firestore.read(`roles/${COORDINATOR_UID}`);

  const result = await assignMobilizationCoordinator({
    callerUid: ADMIN_UID,
    data: {
      mobilizationId: 'incendies-gironde-2026',
      uid: COORDINATOR_UID,
    },
    services,
  });

  assert.deepEqual(result, {
    assignmentId: `incendies-gironde-2026_${COORDINATOR_UID}`,
    active: true,
  });
  assert.deepEqual(
    firestore.read(
      `mobilizationAssignments/incendies-gironde-2026_${COORDINATOR_UID}`,
    ),
    {
      uid: COORDINATOR_UID,
      mobilizationId: 'incendies-gironde-2026',
      role: 'coordinator',
      active: true,
      assignedBy: ADMIN_UID,
      createdAt: NOW,
      updatedBy: ADMIN_UID,
      updatedAt: NOW,
    },
  );
  assert.deepEqual(firestore.read(`roles/${COORDINATOR_UID}`), {
    ...originalRole,
    hasActiveMobilizationAssignments: true,
  });
});

test('per-mobilization assignment cannot override an operation coordinator', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'operations/operation-a',
    operationDocument('operation-a', 'active', {
      coordinatorUid: COORDINATOR_UID,
    }),
  );
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026', 'draft', {
      operationId: 'operation-a',
    }),
  );

  await assertCode(
    () => assignMobilizationCoordinator({
      callerUid: ADMIN_UID,
      data: {
        mobilizationId: 'incendies-gironde-2026',
        uid: COORDINATOR_UID,
      },
      services,
    }),
    'failed-precondition',
  );
  assert.equal(
    firestore.has(
      `mobilizationAssignments/incendies-gironde-2026_${COORDINATOR_UID}`,
    ),
    false,
  );
});

test('removing a coordinator soft-disables the assignment', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/incendies-gironde-2026',
    mobilizationDocument('incendies-gironde-2026', 'inactive'),
  );
  seedAssignment(firestore, 'incendies-gironde-2026');

  const result = await removeMobilizationCoordinator({
    callerUid: ADMIN_UID,
    data: {
      mobilizationId: 'incendies-gironde-2026',
      uid: COORDINATOR_UID,
    },
    services,
  });

  assert.equal(result.active, false);
  const stored = firestore.read(
    `mobilizationAssignments/incendies-gironde-2026_${COORDINATOR_UID}`,
  );
  assert.equal(stored.active, false);
  assert.equal(stored.createdAt.toISOString(), '2026-08-05T08:00:00.000Z');
  assert.equal(stored.updatedAt.toISOString(), NOW.toISOString());
  assert.equal(
    firestore.read(`roles/${COORDINATOR_UID}`)
      .hasActiveMobilizationAssignments,
    false,
  );
});

test('removing one assignment preserves explicit authority for another', async () => {
  const {firestore, services} = harness();
  firestore.seed(
    'mobilizations/mobilization-a',
    mobilizationDocument('mobilization-a', 'inactive'),
  );
  firestore.seed(
    'mobilizations/mobilization-b',
    mobilizationDocument('mobilization-b', 'active'),
  );
  seedAssignment(firestore, 'mobilization-a');
  seedAssignment(firestore, 'mobilization-b');

  await removeMobilizationCoordinator({
    callerUid: ADMIN_UID,
    data: {mobilizationId: 'mobilization-a', uid: COORDINATOR_UID},
    services,
  });

  assert.equal(
    firestore.read(`roles/${COORDINATOR_UID}`)
      .hasActiveMobilizationAssignments,
    true,
  );
});

class MemoryFirestore {
  #documents = new Map();

  seed(path, data) {
    this.#documents.set(path, structuredClone(data));
  }

  has(path) {
    return this.#documents.has(path);
  }

  read(path) {
    const data = this.#documents.get(path);
    return data === undefined ? null : structuredClone(data);
  }

  collection(path) {
    return new MemoryCollectionReference(this, path);
  }

  async runTransaction(action) {
    const transaction = new MemoryTransaction(this);
    const result = await action(transaction);
    transaction.commit();
    return result;
  }

  snapshot(reference) {
    const data = this.#documents.get(reference.path);
    return new MemoryDocumentSnapshot(
      reference.id,
      data === undefined ? null : structuredClone(data),
    );
  }

  querySnapshot(query) {
    const prefix = `${query.collectionPath}/`;
    const documents = [...this.#documents.entries()]
      .filter(([path]) => path.startsWith(prefix))
      .filter(([path]) => !path.slice(prefix.length).includes('/'))
      .filter(([, data]) => query.filters.every(({field, value}) =>
        data[field] === value))
      .map(([path, data]) => new MemoryDocumentSnapshot(
        path.slice(prefix.length),
        structuredClone(data),
      ));
    return {docs: documents, empty: documents.length === 0};
  }

  create(path, data) {
    if (this.#documents.has(path)) throw new Error('already exists');
    this.#documents.set(path, structuredClone(data));
  }

  update(path, fields) {
    const current = this.#documents.get(path);
    if (current === undefined) throw new Error('missing document');
    this.#documents.set(path, structuredClone({...current, ...fields}));
  }

  set(path, data, merge) {
    const current = this.#documents.get(path);
    this.#documents.set(
      path,
      structuredClone(merge && current ? {...current, ...data} : data),
    );
  }
}

class MemoryCollectionReference {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
  }

  doc(id) {
    return new MemoryDocumentReference(this.firestore, `${this.path}/${id}`);
  }

  where(field, operator, value) {
    assert.equal(operator, '==');
    return new MemoryQuery(this.firestore, this.path, [{field, value}]);
  }
}

class MemoryDocumentReference {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
  }

  get id() {
    return this.path.split('/').at(-1);
  }
}

class MemoryQuery {
  constructor(firestore, collectionPath, filters) {
    this.firestore = firestore;
    this.collectionPath = collectionPath;
    this.filters = filters;
  }

  where(field, operator, value) {
    assert.equal(operator, '==');
    return new MemoryQuery(this.firestore, this.collectionPath, [
      ...this.filters,
      {field, value},
    ]);
  }
}

class MemoryDocumentSnapshot {
  constructor(id, data) {
    this.id = id;
    this.value = data;
  }

  get exists() {
    return this.value !== null;
  }

  data() {
    return this.value === null ? undefined : structuredClone(this.value);
  }
}

class MemoryTransaction {
  constructor(firestore) {
    this.firestore = firestore;
    this.writes = [];
  }

  async get(reference) {
    return reference instanceof MemoryQuery
      ? this.firestore.querySnapshot(reference)
      : this.firestore.snapshot(reference);
  }

  create(reference, data) {
    this.writes.push(() => this.firestore.create(reference.path, data));
  }

  update(reference, fields) {
    this.writes.push(() => this.firestore.update(reference.path, fields));
  }

  set(reference, data, options = {}) {
    this.writes.push(() =>
      this.firestore.set(reference.path, data, options.merge === true));
  }

  commit() {
    for (const write of this.writes) write();
  }
}
