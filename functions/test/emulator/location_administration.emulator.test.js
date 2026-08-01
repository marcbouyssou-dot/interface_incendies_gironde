import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';

import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore} from 'firebase-admin/firestore';
import {deleteApp, initializeApp} from 'firebase/app';
import {
  connectAuthEmulator,
  getAuth,
  signInWithEmailAndPassword,
} from 'firebase/auth';
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from 'firebase/functions';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp(
  {projectId},
  'location-administration-emulator-tests',
);
const adminAuth = getAdminAuth(adminApp);
const db = getAdminFirestore(adminApp);
const clientApps = [];
let sequence = 0;

function unique(prefix) {
  sequence += 1;
  return `${prefix}-${process.pid}-${sequence}`;
}

async function createUser(roleDocument) {
  const uid = unique('user');
  const email = `${uid}@example.test`;
  const password = 'Test-only-password-42!';
  await adminAuth.createUser({uid, email, password});
  if (roleDocument) await db.collection('roles').doc(uid).set(roleDocument);
  return {uid, email, password};
}

async function callables(user) {
  const app = initializeApp(
    {projectId, apiKey: 'fake-api-key'},
    unique('location-client'),
  );
  clientApps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  if (user) await signInWithEmailAndPassword(auth, user.email, user.password);
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return {
    list: httpsCallable(functions, 'listAdminLocations'),
    manage: httpsCallable(functions, 'manageLocation'),
  };
}

const coordinatorRole = (active = true) => ({
  role: 'coordinator', locationIds: [], active,
});
const managerRole = () => ({
  role: 'site_manager', locationIds: ['existing'], active: true,
});

function locationData(name = 'Centre Test') {
  return {
    name,
    group: 'bordeauxMetropole',
    type: 'sdisStation',
    addressLine1: '10 rue du Test',
    addressLine2: null,
    postalCode: '33000',
    city: 'Bordeaux',
    country: 'France',
    contactName: null,
    contactPhone: null,
    latitude: 44.84,
    longitude: -0.58,
  };
}

async function assertCode(action, code) {
  await assert.rejects(action, (error) => {
    assert.equal(error.code, `functions/${code}`);
    return true;
  });
}

before(() => assert.equal(process.env.GCLOUD_PROJECT, projectId));

after(async () => {
  await Promise.all(clientApps.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

test('only an active coordinator can list and manage locations', async () => {
  const id = unique('restricted');
  for (const [user, expected] of [
    [null, 'unauthenticated'],
    [await createUser(null), 'permission-denied'],
    [await createUser(managerRole()), 'permission-denied'],
    [await createUser(coordinatorRole(false)), 'permission-denied'],
  ]) {
    const callable = await callables(user);
    await assertCode(() => callable.list(), expected);
    await assertCode(() => callable.manage({
      action: 'create', locationId: id, data: locationData(),
    }), expected);
  }
  assert.equal((await db.collection('locations').doc(id).get()).exists, false);
});

test('coordinator creates, lists, updates, disables and reactivates a location', async () => {
  const user = await createUser(coordinatorRole());
  const callable = await callables(user);
  const id = unique('lifecycle');
  await callable.manage({
    action: 'create', locationId: id, data: locationData(),
  });
  await callable.manage({
    action: 'update',
    locationId: id,
    data: locationData('Centre Modifié'),
  });
  await callable.manage({
    action: 'setActive', locationId: id, data: {active: false},
  });
  let stored = (await db.collection('locations').doc(id).get()).data();
  assert.equal(stored.id, id);
  assert.equal(stored.name, 'Centre Modifié');
  assert.equal(stored.active, false);
  assert.equal(stored.activeNeeds, 0);
  assert.equal(stored.isOperational, true);
  const listed = (await callable.list()).data.locations;
  assert.equal(listed.find((value) => value.id === id).active, false);
  await callable.manage({
    action: 'setActive', locationId: id, data: {active: true},
  });
  stored = (await db.collection('locations').doc(id).get()).data();
  assert.equal(stored.active, true);
});

test('creation refuses duplicates, unknown fields and invalid types', async () => {
  const user = await createUser(coordinatorRole());
  const {manage} = await callables(user);
  const id = unique('strict');
  await manage({action: 'create', locationId: id, data: locationData()});
  await assertCode(
    () => manage({action: 'create', locationId: id, data: locationData()}),
    'already-exists',
  );
  await assertCode(() => manage({
    action: 'update',
    locationId: id,
    data: {...locationData(), unknown: true},
  }), 'invalid-argument');
  await assertCode(() => manage({
    action: 'setActive', locationId: id, data: {active: 'false'},
  }), 'invalid-argument');
});

test('update preserves historical and server-managed metadata', async () => {
  const user = await createUser(coordinatorRole());
  const {manage} = await callables(user);
  const id = unique('metadata');
  await db.collection('locations').doc(id).set({
    id,
    ...locationData(),
    active: true,
    activeNeeds: 4,
    isOperational: false,
    addressSourceUrl: 'https://example.test/source',
    customHistoricalField: 'preserved',
  });
  await manage({
    action: 'update', locationId: id, data: locationData('Nouveau nom'),
  });
  const stored = (await db.collection('locations').doc(id).get()).data();
  assert.equal(stored.activeNeeds, 4);
  assert.equal(stored.isOperational, false);
  assert.equal(stored.addressSourceUrl, 'https://example.test/source');
  assert.equal(stored.customHistoricalField, 'preserved');
});

for (const reference of ['mission', 'role', 'invitation']) {
  test(`deletion refuses a location referenced by a ${reference}`, async () => {
    const user = await createUser(coordinatorRole());
    const {manage} = await callables(user);
    const id = unique(`used-${reference}`);
    await db.collection('locations').doc(id).set({
      id, ...locationData(), active: false,
    });
    if (reference === 'mission') {
      await db.collection('missions').doc(unique('mission')).set({
        locationId: id,
      });
    } else if (reference === 'role') {
      await db.collection('roles').doc(unique('role')).set({
        role: 'site_manager', locationIds: [id], active: true,
      });
    } else {
      await db.collection('adminInvitations').doc(unique('invitation')).set({
        locationIds: [id],
      });
    }
    await assertCode(
      () => manage({action: 'delete', locationId: id}),
      'failed-precondition',
    );
    assert.equal((await db.collection('locations').doc(id).get()).exists, true);
  });
}

test('unused location deletion preserves Auth accounts and other data', async () => {
  const user = await createUser(coordinatorRole());
  const target = await createUser(null);
  const {manage} = await callables(user);
  const id = unique('unused');
  await db.collection('locations').doc(id).set({
    id, ...locationData(), active: false,
  });
  await manage({action: 'delete', locationId: id});
  assert.equal((await db.collection('locations').doc(id).get()).exists, false);
  assert.equal((await adminAuth.getUser(target.uid)).uid, target.uid);
});

test('concurrent creation commits exactly once', async () => {
  const user = await createUser(coordinatorRole());
  const {manage} = await callables(user);
  const request = {
    action: 'create', locationId: unique('concurrent'), data: locationData(),
  };
  const results = await Promise.allSettled([manage(request), manage(request)]);
  assert.equal(results.filter((value) => value.status === 'fulfilled').length, 1);
  assert.equal(results.filter((value) => value.status === 'rejected').length, 1);
});
