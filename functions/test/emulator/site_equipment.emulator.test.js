import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';
import {deleteApp as deleteAdminApp, initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore} from 'firebase-admin/firestore';
import {deleteApp, initializeApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInWithEmailAndPassword} from 'firebase/auth';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'site-equipment-emulator-tests');
const auth = getAdminAuth(adminApp);
const db = getAdminFirestore(adminApp);
const clients = [];
let sequence = 0;
const unique = (prefix) => `${prefix}-${process.pid}-${++sequence}`;

async function user(role) {
  const uid = unique('site-equipment-user');
  const email = `${uid}@example.test`;
  const password = 'Test-only-password-42!';
  await auth.createUser({uid, email, password});
  if (role) await db.collection('roles').doc(uid).set(role);
  return {email, password};
}

async function callable(identity) {
  const app = initializeApp({projectId, apiKey: 'fake-api-key'}, unique('site-equipment-client'));
  clients.push(app);
  const clientAuth = getAuth(app);
  connectAuthEmulator(clientAuth, 'http://127.0.0.1:9099', {disableWarnings: true});
  if (identity) await signInWithEmailAndPassword(clientAuth, identity.email, identity.password);
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return httpsCallable(functions, 'updateSiteEquipment');
}

const manager = (id) => ({
  role: 'site_manager', roles: ['site_manager'], locationIds: [id],
  active: true, schemaVersion: 2,
});
const request = (id, availableEquipment = ['massage_table']) => ({locationId: id, availableEquipment});
async function denied(action, code) {
  await assert.rejects(action, (error) => error.code === `functions/${code}`);
}

before(() => assert.equal(process.env.GCLOUD_PROJECT, projectId));
after(async () => {
  await Promise.all(clients.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

test('assigned manager updates only Bassens equipment; other site and other fields stay intact', async () => {
  const bassens = unique('bassens');
  const other = unique('other');
  await db.collection('locations').doc(bassens).set({name: 'Bassens', active: true, isOperational: true});
  await db.collection('locations').doc(other).set({name: 'Autre', active: true, isOperational: true});
  const write = await callable(await user(manager(bassens)));
  await write(request(bassens, ['stethoscope', 'massage_table', 'massage_table']));
  assert.deepEqual((await db.collection('locations').doc(bassens).get()).data(), {
    name: 'Bassens', active: true, isOperational: true,
    availableEquipment: ['massage_table', 'stethoscope'],
  });
  await denied(() => write(request(other)), 'permission-denied');
  await denied(() => write({...request(bassens), role: 'coordinator'}), 'invalid-argument');
  await denied(() => write(request(bassens, ['unknown'])), 'invalid-argument');
  assert.equal((await db.collection('locations').doc(other).get()).data().availableEquipment, undefined);
});

test('professional and anonymous callers cannot update site inventory', async () => {
  const id = unique('restricted');
  await db.collection('locations').doc(id).set({name: 'Restricted', active: true, isOperational: true});
  const professional = await callable(await user({
    role: 'professional', roles: ['professional'], locationIds: [],
    active: true, schemaVersion: 2,
  }));
  const anonymous = await callable(null);
  await denied(() => professional(request(id)), 'permission-denied');
  await denied(() => anonymous(request(id)), 'unauthenticated');
  assert.equal((await db.collection('locations').doc(id).get()).data().availableEquipment, undefined);
});
