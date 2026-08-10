import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PlatformAdministratorConflictError,
  materializePlatformAdministratorDocument,
  platformAdministratorBootstrapActor,
  platformAdministratorBootstrapEmailEnvironmentKey,
  platformAdministratorBootstrapProjectId,
  platformAdministratorBootstrapUidEnvironmentKey,
  resolvePlatformAdministratorExecution,
  resolvePlatformAdministratorUid,
  runPlatformAdministratorBootstrap,
} from './platform_administrator_bootstrap.mjs';

const targetUid = 'firebase-user-123';
const targetPath = `platformAdministrators/${targetUid}`;
const targetEmail = 'owner@example.test';
const fakeTimestamp = Object.freeze({toDate: () => new Date(0)});

test('document absent plans the exact platform administrator creation', async () => {
  const store = memoryStore();

  const result = await execute(store, 'dry-run');
  const creation = materializePlatformAdministratorDocument({
    uid: targetUid,
    serverTimestamp: () => fakeTimestamp,
  });

  assert.equal(result.action, 'create');
  assert.equal(result.path, targetPath);
  assert.deepEqual(creation, {
    path: targetPath,
    data: {
      uid: targetUid,
      active: true,
      createdAt: fakeTimestamp,
      createdBy: platformAdministratorBootstrapActor,
      updatedAt: fakeTimestamp,
    },
  });
});

test('an identical document remains unchanged', async () => {
  const store = memoryStore(new Map([
    [targetPath, compatibleDocument()],
  ]));

  const result = await execute(store, 'dry-run');

  assert.equal(result.action, 'unchanged');
  assert.equal(result.writes, 0);
});

test('an incompatible document produces a NO-GO conflict', async () => {
  const store = memoryStore(new Map([
    [targetPath, {...compatibleDocument(), active: false}],
  ]));

  await assert.rejects(
    execute(store, 'dry-run'),
    (error) => {
      assert.equal(error instanceof PlatformAdministratorConflictError, true);
      assert.equal(error.path, targetPath);
      return true;
    },
  );
  assert.equal(store.createCalls.length, 0);
});

test('dry-run performs zero write and reads only the target document', async () => {
  const store = memoryStore();

  const result = await execute(store, 'dry-run');

  assert.equal(result.writes, 0);
  assert.deepEqual(store.readPaths, [targetPath]);
  assert.deepEqual(store.createCalls, []);
  assert.equal(store.documents.size, 0);
});

test('apply is idempotent', async () => {
  const store = memoryStore();

  const first = await execute(store, 'apply');
  const second = await execute(store, 'apply');

  assert.equal(first.writes, 1);
  assert.equal(second.writes, 0);
  assert.equal(second.action, 'unchanged');
  assert.deepEqual(store.createCalls, [targetPath]);
  assert.deepEqual([...store.documents.keys()], [targetPath]);
});

test('the target UID is resolved from the current Firebase account email', async () => {
  const calls = [];
  const uid = await resolvePlatformAdministratorUid({
    auth: {
      async getUserByEmail(email) {
        calls.push(email);
        return {uid: targetUid, email, disabled: false};
      },
      async getUser() {
        throw new Error('getUser ne doit pas être appelé');
      },
    },
    email: targetEmail,
    uid: null,
  });

  assert.equal(uid, targetUid);
  assert.deepEqual(calls, [targetEmail]);
});

test('the target UID can be validated without storing an email', async () => {
  const calls = [];
  const uid = await resolvePlatformAdministratorUid({
    auth: {
      async getUser() {
        calls.push(targetUid);
        return {uid: targetUid, disabled: false};
      },
      async getUserByEmail() {
        throw new Error('getUserByEmail ne doit pas être appelé');
      },
    },
    email: null,
    uid: targetUid,
  });

  assert.equal(uid, targetUid);
  assert.deepEqual(calls, [targetUid]);
});

test('execution requires explicit project, mode and one external identifier', () => {
  const environment = {
    [platformAdministratorBootstrapUidEnvironmentKey]: targetUid,
  };
  assert.deepEqual(
    resolvePlatformAdministratorExecution({
      environment,
      arguments: [
        '--project',
        platformAdministratorBootstrapProjectId,
        '--dry-run',
      ],
    }),
    {
      mode: 'dry-run',
      projectId: platformAdministratorBootstrapProjectId,
      targetEmail: null,
      targetUid,
    },
  );
  assert.throws(
    () => resolvePlatformAdministratorExecution({
      environment,
      arguments: ['--dry-run'],
    }),
    /exactement/,
  );
  assert.throws(
    () => resolvePlatformAdministratorExecution({
      environment,
      arguments: ['--project', 'other-project', '--apply'],
    }),
    /Projet Firebase refusé/,
  );
  assert.throws(
    () => resolvePlatformAdministratorExecution({
      environment: {},
      arguments: [
        '--project',
        platformAdministratorBootstrapProjectId,
        '--dry-run',
      ],
    }),
    /exactement une variable/,
  );
  assert.throws(
    () => resolvePlatformAdministratorExecution({
      environment: {
        [platformAdministratorBootstrapEmailEnvironmentKey]: targetEmail,
        [platformAdministratorBootstrapUidEnvironmentKey]: targetUid,
      },
      arguments: [
        '--project',
        platformAdministratorBootstrapProjectId,
        '--dry-run',
      ],
    }),
    /exactement une variable/,
  );
});

async function execute(store, mode) {
  return runPlatformAdministratorBootstrap({
    mode,
    uid: targetUid,
    readDocument: async (path) => {
      store.readPaths.push(path);
      return store.documents.get(path) ?? null;
    },
    createDocument: async ({path, data}) => {
      assert.equal(store.documents.has(path), false);
      store.documents.set(path, data);
      store.createCalls.push(path);
    },
    serverTimestamp: () => fakeTimestamp,
  });
}

function compatibleDocument() {
  return {
    uid: targetUid,
    active: true,
    createdAt: fakeTimestamp,
    createdBy: platformAdministratorBootstrapActor,
    updatedAt: fakeTimestamp,
  };
}

function memoryStore(documents = new Map()) {
  return {documents, createCalls: [], readPaths: []};
}
