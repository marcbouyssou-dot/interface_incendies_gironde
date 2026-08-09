import assert from 'node:assert/strict';
import test from 'node:test';

import {
  HistoricalMobilizationConflictError,
  historicalDocumentPaths,
  historicalMobilizationId,
  historicalTerritoryId,
  materializeHistoricalDocuments,
  platformBootstrapProjectEnvironmentKey,
  platformBootstrapProjectId,
  resolveHistoricalBootstrapExecution,
  runHistoricalMobilizationBootstrap,
} from './historical_mobilization_bootstrap.mjs';

const fakeTimestamp = Object.freeze({toDate: () => new Date(0)});

test('dry-run on an empty database plans no write execution', async () => {
  const store = memoryStore();

  const result = await execute(store, 'dry-run');

  assert.equal(result.writes, 0);
  assert.equal(store.createCalls.length, 0);
  assert.equal(store.documents.size, 0);
});

test('empty state plans the three exact platform documents', async () => {
  const result = await execute(memoryStore(), 'dry-run');

  assert.deepEqual(result.creates, [
    `territories/${historicalTerritoryId}`,
    `mobilizations/${historicalMobilizationId}`,
    'platform/config',
  ]);
  assert.deepEqual(result.summary, {create: 3, unchanged: 0});

  const creations = materializeHistoricalDocuments({
    paths: result.creates,
    serverTimestamp: () => fakeTimestamp,
  });
  assert.deepEqual(creations[0].data, {
    id: 'gironde',
    name: 'Gironde',
    code: '33',
    active: true,
    createdAt: fakeTimestamp,
    updatedAt: fakeTimestamp,
  });
  assert.equal(creations[1].data.status, 'active');
  assert.equal(creations[1].data.contextType, 'fire');
  assert.equal(creations[1].data.schemaVersion, 1);
  assert.equal(
    creations[2].data.activeMobilizationId,
    historicalMobilizationId,
  );
});

test('apply followed by a rerun is idempotent', async () => {
  const store = memoryStore();
  const first = await execute(store, 'apply');
  const writesAfterFirstRun = store.createCalls.length;
  const second = await execute(store, 'apply');

  assert.equal(first.writes, 3);
  assert.equal(writesAfterFirstRun, 3);
  assert.equal(second.writes, 0);
  assert.deepEqual(second.summary, {create: 0, unchanged: 3});
  assert.equal(store.createCalls.length, writesAfterFirstRun);
});

test('an incompatible territory is refused', async () => {
  const store = memoryStore(new Map([
    ['territories/gironde', {
      id: 'gironde',
      name: 'Autre territoire',
      code: '33',
      active: true,
      createdAt: fakeTimestamp,
      updatedAt: fakeTimestamp,
    }],
  ]));

  await assert.rejects(
    execute(store, 'dry-run'),
    conflictAt('territories/gironde'),
  );
  assert.equal(store.createCalls.length, 0);
});

test('an incompatible mobilization is refused', async () => {
  const store = memoryStore();
  await execute(store, 'apply');
  store.documents.get(
    `mobilizations/${historicalMobilizationId}`,
  ).subtitle = 'Sous-titre différent';

  await assert.rejects(
    execute(store, 'dry-run'),
    conflictAt(`mobilizations/${historicalMobilizationId}`),
  );
});

test('a conflicting activeMobilizationId is refused', async () => {
  const store = memoryStore();
  await execute(store, 'apply');
  store.documents.get('platform/config').activeMobilizationId = 'other';

  await assert.rejects(
    execute(store, 'dry-run'),
    conflictAt('platform/config'),
  );
});

test('missions and engagements are neither read nor modified', async () => {
  const mission = {name: 'Mission historique'};
  const engagement = {uid: 'volunteer'};
  const store = memoryStore(new Map([
    ['missions/existing', mission],
    ['engagements/existing', engagement],
  ]));

  await execute(store, 'apply');

  assert.deepEqual(store.readPaths, historicalDocumentPaths);
  assert.strictEqual(store.documents.get('missions/existing'), mission);
  assert.strictEqual(
    store.documents.get('engagements/existing'),
    engagement,
  );
  assert.equal(
    store.createCalls.some(
      (path) => path.startsWith('missions/')
        || path.startsWith('engagements/'),
    ),
    false,
  );
});

test('execution requires an explicit mode and the dedicated project', () => {
  const environment = {
    [platformBootstrapProjectEnvironmentKey]: platformBootstrapProjectId,
  };
  assert.deepEqual(
    resolveHistoricalBootstrapExecution({
      environment,
      arguments: ['--dry-run'],
    }),
    {mode: 'dry-run', projectId: platformBootstrapProjectId},
  );
  assert.deepEqual(
    resolveHistoricalBootstrapExecution({
      environment,
      arguments: ['--apply'],
    }),
    {mode: 'apply', projectId: platformBootstrapProjectId},
  );
  assert.throws(
    () => resolveHistoricalBootstrapExecution({environment, arguments: []}),
    /exactement un mode/,
  );
  assert.throws(
    () => resolveHistoricalBootstrapExecution({
      environment: {},
      arguments: ['--dry-run'],
    }),
    /Projet Firebase refusé/,
  );
});

async function execute(store, mode) {
  return runHistoricalMobilizationBootstrap({
    mode,
    readDocuments: async (paths) => {
      store.readPaths.push(...paths);
      return new Map(
        paths.map((path) => [path, store.documents.get(path) ?? null]),
      );
    },
    createDocuments: async (creations) => {
      for (const creation of creations) {
        assert.equal(store.documents.has(creation.path), false);
        store.documents.set(creation.path, creation.data);
        store.createCalls.push(creation.path);
      }
    },
    serverTimestamp: () => fakeTimestamp,
  });
}

function memoryStore(documents = new Map()) {
  return {documents, createCalls: [], readPaths: []};
}

function conflictAt(path) {
  return (error) => {
    assert.equal(error instanceof HistoricalMobilizationConflictError, true);
    assert.equal(error.path, path);
    return true;
  };
}
