import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';

import {deleteApp as deleteAdminApp, initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore} from 'firebase-admin/firestore';
import {deleteApp, initializeApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInWithEmailAndPassword} from 'firebase/auth';
import {connectFirestoreEmulator, doc, getFirestore, serverTimestamp, setDoc, Timestamp, updateDoc} from 'firebase/firestore';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'r09-governance-tests');
const adminAuth = getAdminAuth(adminApp);
const adminDb = getAdminFirestore(adminApp);
const apps = [];
let sequence = 0;
const unique = (prefix) => `${prefix}-${process.pid}-${++sequence}`;
const day = 86_400_000;

before(() => assert.equal(process.env.GCLOUD_PROJECT, projectId));
after(async () => {
  await Promise.all(apps.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

async function actor(role, administrator = false) {
  const uid = unique('actor');
  const email = `${uid}@example.test`;
  const password = 'Test-only-password-42!';
  await adminAuth.createUser({uid, email, password});
  if (role) await adminDb.collection('roles').doc(uid).set({
    role, active: true, locationIds: role === 'coordinator' ? [] : ['merignac'],
  });
  if (administrator) {
    await adminDb.collection('platformAdministrators').doc(uid).set({active: true});
  }
  const app = initializeApp({projectId, apiKey: 'fake-api-key'}, unique('client'));
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  await signInWithEmailAndPassword(auth, email, password);
  const firestore = getFirestore(app);
  connectFirestoreEmulator(firestore, '127.0.0.1',
    Number(process.env.MOBSANTE_TEST_FIRESTORE_PORT ?? 8080));
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return {
    uid, firestore,
    update: httpsCallable(functions, 'updateResponsibleAccess'),
    manage: httpsCallable(functions, 'manageAdminInvitation'),
    provision: httpsCallable(functions, 'provisionAdminInvitation'),
  };
}

function invitation(actorUid, days, role = 'site_manager') {
  return {
    email: `${unique('invitee')}@example.test`,
    displayName: 'Camille Martin', role,
    locationIds: role === 'coordinator' ? [] : ['merignac'],
    createdBy: actorUid, createdAt: serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + days * day),
    status: 'pending', acceptedAt: null,
  };
}

async function assertDenied(action) {
  await assert.rejects(action);
}

test('direct invitation creation enforces 90 days and coordinator governance', async () => {
  const coordinator = await actor('coordinator');
  for (const days of [14, 30, 60, 90]) {
    const id = unique('valid');
    await setDoc(doc(coordinator.firestore, 'adminInvitations', id),
      invitation(coordinator.uid, days));
    assert.equal((await adminDb.collection('adminInvitations').doc(id).get()).exists, true);
  }
  for (const days of [-1, 0, 91]) {
    await assertDenied(() => setDoc(
      doc(coordinator.firestore, 'adminInvitations', unique('invalid')),
      invitation(coordinator.uid, days)));
  }
  await assertDenied(() => setDoc(
    doc(coordinator.firestore, 'adminInvitations', unique('malformed')),
    {...invitation(coordinator.uid, 14), expiresAt: 'tomorrow'}));
  await assertDenied(() => setDoc(
    doc(coordinator.firestore, 'adminInvitations', unique('coordinator')),
    invitation(coordinator.uid, 14, 'coordinator')));

  const administrator = await actor(null, true);
  const id = unique('admin-coordinator');
  await setDoc(doc(administrator.firestore, 'adminInvitations', id),
    invitation(administrator.uid, 90, 'coordinator'));
  assert.equal((await adminDb.collection('adminInvitations').doc(id).get()).data().createdBy,
    administrator.uid);
  await assertDenied(() => updateDoc(
    doc(coordinator.firestore, 'adminInvitations', id), {status: 'cancelled'}));
  await updateDoc(doc(administrator.firestore, 'adminInvitations', id),
    {status: 'cancelled'});
  for (const role of ['site_manager', null]) {
    const user = await actor(role);
    await assertDenied(() => setDoc(
      doc(user.firestore, 'adminInvitations', unique('forbidden')),
      invitation(user.uid, 14, 'coordinator')));
  }
  await assertDenied(() => setDoc(doc(coordinator.firestore, 'roles', unique('role')),
    {role: 'coordinator', active: true, locationIds: []}));
});

test('callables reject Coordinator promotion and retain Responsable management', async () => {
  const coordinator = await actor('coordinator');
  const administrator = await actor(null, true);
  const target = await actor('site_manager');
  const request = (roles, locationIds) => ({
    targetUid: target.uid, roles, locationIds, active: true,
  });
  await assert.rejects(() => coordinator.update(request(['coordinator'], [])),
    (error) => error.code === 'functions/permission-denied');
  await coordinator.update(request(['site_manager'], ['merignac']));
  await administrator.update(request(['coordinator'], []));
  const promoted = (await adminDb.collection('roles').doc(target.uid).get()).data();
  assert.equal(promoted.role, 'coordinator');
  assert.equal(promoted.updatedBy, administrator.uid);
  assert.ok(promoted.updatedAt);
  await assert.rejects(() => coordinator.update(request(['site_manager'], ['merignac'])),
    (error) => error.code === 'functions/permission-denied');
});

test('historical invitations stay readable; only Admin can turn them into Coordinator', async () => {
  const coordinator = await actor('coordinator');
  const administrator = await actor(null, true);
  const id = unique('historical');
  const createdAt = new Date(Date.now() - 10 * day);
  await adminDb.collection('adminInvitations').doc(id).set({
    email: `${unique('historical-target')}@example.test`,
    displayName: 'Ancienne invitation', role: 'coordinator', locationIds: [],
    createdBy: coordinator.uid, createdAt,
    expiresAt: new Date(Date.now() + 100 * day),
    status: 'pending', acceptedAt: null,
  });
  await assert.rejects(() => coordinator.provision({invitationId: id}),
    (error) => error.code === 'functions/permission-denied');
  await assert.rejects(() => coordinator.manage({
    invitationId: id, action: 'reactivate',
    expiresAtMillis: Date.now() + 30 * day,
  }), (error) => error.code === 'functions/permission-denied');
  const result = await administrator.provision({invitationId: id});
  assert.equal(result.data.invitationStatus, 'accepted');
  const accepted = (await adminDb.collection('adminInvitations').doc(id).get()).data();
  assert.equal(accepted.createdBy, coordinator.uid);
  assert.ok(accepted.acceptedAt);
  const user = await adminAuth.getUserByEmail(accepted.email);
  const assigned = (await adminDb.collection('roles').doc(user.uid).get()).data();
  assert.equal(assigned.createdBy, administrator.uid);
});

test('management rejects Coordinator role updates and overlong reactivation', async () => {
  const coordinator = await actor('coordinator');
  const administrator = await actor(null, true);
  const id = unique('managed');
  await adminDb.collection('adminInvitations').doc(id).set({
    email: `${unique('managed-target')}@example.test`, displayName: 'Responsable',
    role: 'site_manager', locationIds: ['merignac'], createdBy: coordinator.uid,
    createdAt: new Date(Date.now() - day),
    expiresAt: new Date(Date.now() + day), status: 'cancelled', acceptedAt: null,
  });
  await assert.rejects(() => coordinator.manage({
    invitationId: id, action: 'update', displayName: 'Coordination',
    role: 'coordinator', locationIds: [],
  }), (error) => error.code === 'functions/permission-denied');
  await assert.rejects(() => coordinator.manage({
    invitationId: id, action: 'reactivate',
    expiresAtMillis: Date.now() + 91 * day,
  }), (error) => error.code === 'functions/invalid-argument');
  await coordinator.manage({
    invitationId: id, action: 'reactivate',
    expiresAtMillis: Date.now() + 90 * day - 60_000,
  });
  await administrator.manage({
    invitationId: id, action: 'update', displayName: 'Coordination',
    role: 'coordinator', locationIds: [],
  });
  assert.equal((await adminDb.collection('adminInvitations').doc(id).get()).data().role,
    'coordinator');
});
