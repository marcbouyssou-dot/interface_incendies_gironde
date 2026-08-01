import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';

import {deleteApp as deleteAdminApp, initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore, Timestamp} from 'firebase-admin/firestore';
import {deleteApp, initializeApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInWithEmailAndPassword} from 'firebase/auth';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'access-admin-emulator-tests');
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
  await adminAuth.createUser({uid, email, password, displayName: `Nom ${uid}`});
  if (roleDocument) await db.collection('roles').doc(uid).set(roleDocument);
  return {uid, email, password};
}

async function client(user) {
  const app = initializeApp(
    {projectId, apiKey: 'fake-api-key'},
    unique('access-client'),
  );
  clientApps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  if (user) await signInWithEmailAndPassword(auth, user.email, user.password);
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return {
    update: httpsCallable(functions, 'updateResponsibleAccess'),
    list: httpsCallable(functions, 'listResponsibleAccess'),
  };
}

const coordinatorRole = (active = true) => ({
  role: 'coordinator', locationIds: [], active,
});
const managerRole = (active = true) => ({
  role: 'site_manager', locationIds: ['merignac'], active,
});
const payload = (targetUid, overrides = {}) => ({
  targetUid,
  roles: ['site_manager'],
  locationIds: ['merignac'],
  active: true,
  ...overrides,
});

async function assertCode(action, code) {
  await assert.rejects(action, (error) => {
    assert.equal(error.code, `functions/${code}`);
    return true;
  });
}

before(() => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
});

after(async () => {
  await Promise.all(clientApps.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

test('anonymous, site manager and inactive coordinator are refused', async () => {
  const target = await createUser(managerRole());
  const anonymous = await client(null);
  await assertCode(() => anonymous.update(payload(target.uid)), 'unauthenticated');
  for (const role of [managerRole(), coordinatorRole(false)]) {
    const caller = await createUser(role);
    const callable = await client(caller);
    await assertCode(() => callable.update(payload(target.uid)), 'permission-denied');
    await assertCode(() => callable.list(), 'permission-denied');
  }
});

test('active coordinator lists existing legacy accounts with safe identity', async () => {
  const caller = await createUser(coordinatorRole());
  const target = await createUser(managerRole());
  const callable = await client(caller);
  const response = await callable.list();
  const account = response.data.accounts.find((value) => value.uid === target.uid);
  assert.equal(account.email, target.email);
  assert.equal(account.role, 'site_manager');
  assert.deepEqual(account.roles, ['site_manager']);
});

test('legacy target is converted to strict V2 and metadata is preserved', async () => {
  const caller = await createUser(coordinatorRole());
  const target = await createUser(managerRole());
  const createdAt = Timestamp.now();
  await db.collection('roles').doc(target.uid).set({
    ...managerRole(), createdAt, createdBy: 'bootstrap', note: 'conserver',
  });
  const beforeAuth = await adminAuth.getUser(target.uid);
  const callable = await client(caller);
  await callable.update(payload(target.uid, {
    roles: ['coordinator', 'site_manager'],
    locationIds: ['langon', 'merignac'],
    active: false,
  }));
  const value = (await db.collection('roles').doc(target.uid).get()).data();
  assert.equal(value.role, 'coordinator');
  assert.deepEqual(value.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(value.locationIds, ['langon', 'merignac']);
  assert.equal(value.active, false);
  assert.equal(value.schemaVersion, 2);
  assert.equal(value.createdBy, 'bootstrap');
  assert.equal(value.note, 'conserver');
  assert.equal(value.createdAt.toMillis(), createdAt.toMillis());
  assert.ok(value.updatedAt);
  const afterAuth = await adminAuth.getUser(target.uid);
  assert.equal(afterAuth.disabled, beforeAuth.disabled);
  assert.equal(afterAuth.email, beforeAuth.email);
});

test('deactivation then reactivation preserves the same Auth account', async () => {
  const caller = await createUser(coordinatorRole());
  const target = await createUser(managerRole());
  const callable = await client(caller);
  await callable.update(payload(target.uid, {active: false}));
  await callable.update(payload(target.uid, {active: true}));
  const value = (await db.collection('roles').doc(target.uid).get()).data();
  assert.equal(value.active, true);
  assert.equal((await adminAuth.getUser(target.uid)).uid, target.uid);
});

test('self-update and unknown target are refused without writes', async () => {
  const caller = await createUser(coordinatorRole());
  const callable = await client(caller);
  await assertCode(() => callable.update(payload(caller.uid)), 'failed-precondition');
  await assertCode(() => callable.update(payload(unique('missing'))), 'not-found');
  assert.deepEqual(
    (await db.collection('roles').doc(caller.uid).get()).data(),
    coordinatorRole(),
  );
});

test('invalid payloads and malformed targets fail closed', async () => {
  const caller = await createUser(coordinatorRole());
  const malformed = await createUser({
    role: 'site_manager', roles: ['unknown'], locationIds: [], active: true,
    schemaVersion: 2,
  });
  const callable = await client(caller);
  await assertCode(
    () => callable.update({...payload(malformed.uid), extra: true}),
    'invalid-argument',
  );
  await assertCode(
    () => callable.update(payload(malformed.uid)),
    'failed-precondition',
  );
});

test('concurrent valid updates are atomic and last committed state is complete', async () => {
  const caller = await createUser(coordinatorRole());
  const target = await createUser(managerRole());
  const callable = await client(caller);
  const first = payload(target.uid, {
    roles: ['coordinator'], locationIds: [], active: true,
  });
  const second = payload(target.uid, {
    roles: ['site_manager'], locationIds: ['langon'], active: false,
  });
  await Promise.all([callable.update(first), callable.update(second)]);
  const value = (await db.collection('roles').doc(target.uid).get()).data();
  const states = [
    ['coordinator', 'coordinator', true, ''],
    ['site_manager', 'site_manager', false, 'langon'],
  ];
  assert.ok(states.some(([role, onlyRole, active, location]) =>
    value.role === role
    && value.roles.length === 1
    && value.roles[0] === onlyRole
    && value.active === active
    && value.locationIds.join(',') === location));
  assert.equal(value.schemaVersion, 2);
});
