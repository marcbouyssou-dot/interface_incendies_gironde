import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';

import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from 'firebase-admin/app';
import {
  FieldValue,
  getFirestore as getAdminFirestore,
} from 'firebase-admin/firestore';

import {setOperationCoordinator} from '../../src/platform_administration.js';
import {
  platformAdministrationServices,
} from '../../src/platform_administration_firestore.js';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp(
  {projectId},
  'set-operation-coordinator-emulator-tests',
);
const db = getAdminFirestore(adminApp);
let sequence = 0;

function unique(prefix) {
  sequence += 1;
  return `${prefix}-${process.pid}-${sequence}`;
}

async function createUser({platformAdministrator = false} = {}) {
  const uid = unique('user');
  if (platformAdministrator) {
    await db.collection('platformAdministrators').doc(uid).set({active: true});
  }
  return {uid};
}

const services = platformAdministrationServices({
  firestore: db,
  serverTimestamp: FieldValue.serverTimestamp,
});

function coordinatorRole(active = true) {
  return {
    role: 'coordinator',
    roles: ['coordinator'],
    locationIds: [],
    active,
    schemaVersion: 2,
  };
}

before(() => assert.equal(process.env.GCLOUD_PROJECT, projectId));

after(async () => {
  await deleteAdminApp(adminApp);
});

test('replacement is atomic and harmonizes every operation mobilization', async () => {
  const administrator = await createUser({platformAdministrator: true});
  const previous = await createUser();
  const replacement = await createUser();
  await Promise.all([
    db.collection('roles').doc(previous.uid).set(coordinatorRole()),
    db.collection('roles').doc(replacement.uid).set(coordinatorRole()),
  ]);
  const operationId = unique('operation');
  const mobilizationIds = [unique('mobilization'), unique('mobilization')];
  await db.collection('operations').doc(operationId).set({
    id: operationId,
    status: 'active',
    coordinatorUid: previous.uid,
  });
  for (const [index, mobilizationId] of mobilizationIds.entries()) {
    await db.collection('mobilizations').doc(mobilizationId).set({
      id: mobilizationId,
      operationId,
      territoryId: 'gironde',
      status: index === 0 ? 'active' : 'inactive',
    });
    await db
      .collection('mobilizationAssignments')
      .doc(`${mobilizationId}_${previous.uid}`)
      .set({
        uid: previous.uid,
        mobilizationId,
        role: 'coordinator',
        active: true,
      });
  }

  const response = await setOperationCoordinator({
    callerUid: administrator.uid,
    data: {operationId, uid: replacement.uid},
    services,
  });

  assert.equal(response.coordinatorUid, replacement.uid);
  assert.equal(response.mobilizationCount, 2);
  assert.equal(response.activeMobilizationCount, 1);
  assert.equal(
    (await db.collection('operations').doc(operationId).get()).data()
      .coordinatorUid,
    replacement.uid,
  );
  for (const mobilizationId of mobilizationIds) {
    assert.equal(
      (await db
        .collection('mobilizationAssignments')
        .doc(`${mobilizationId}_${previous.uid}`)
        .get()).data().active,
      false,
    );
    assert.equal(
      (await db
        .collection('mobilizationAssignments')
        .doc(`${mobilizationId}_${replacement.uid}`)
        .get()).data().active,
      true,
    );
  }
});

test('an invalid replacement rolls back the complete transaction', async () => {
  const administrator = await createUser({platformAdministrator: true});
  const previous = await createUser();
  const inactive = await createUser();
  await Promise.all([
    db.collection('roles').doc(previous.uid).set(coordinatorRole()),
    db.collection('roles').doc(inactive.uid).set(coordinatorRole(false)),
  ]);
  const operationId = unique('rollback-operation');
  const mobilizationId = unique('rollback-mobilization');
  await db.collection('operations').doc(operationId).set({
    id: operationId,
    status: 'active',
    coordinatorUid: previous.uid,
  });
  await db.collection('mobilizations').doc(mobilizationId).set({
    id: mobilizationId,
    operationId,
    territoryId: 'gironde',
    status: 'active',
  });
  await db
    .collection('mobilizationAssignments')
    .doc(`${mobilizationId}_${previous.uid}`)
    .set({
      uid: previous.uid,
      mobilizationId,
      role: 'coordinator',
      active: true,
    });

  await assert.rejects(
    () => setOperationCoordinator({
      callerUid: administrator.uid,
      data: {operationId, uid: inactive.uid},
      services,
    }),
    (error) => error.code === 'failed-precondition',
  );

  assert.equal(
    (await db.collection('operations').doc(operationId).get()).data()
      .coordinatorUid,
    previous.uid,
  );
  assert.equal(
    (await db
      .collection('mobilizationAssignments')
      .doc(`${mobilizationId}_${previous.uid}`)
      .get()).data().active,
    true,
  );
  assert.equal(
    (await db
      .collection('mobilizationAssignments')
      .doc(`${mobilizationId}_${inactive.uid}`)
      .get()).exists,
    false,
  );
});
