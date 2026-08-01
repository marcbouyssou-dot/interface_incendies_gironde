import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';

import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {
  getFirestore as getAdminFirestore,
  Timestamp,
} from 'firebase-admin/firestore';
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
  'invitation-management-emulator-tests',
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

async function callable(user) {
  const app = initializeApp(
    {projectId, apiKey: 'fake-api-key'},
    unique('management-client'),
  );
  clientApps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  if (user) await signInWithEmailAndPassword(auth, user.email, user.password);
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return httpsCallable(functions, 'manageAdminInvitation');
}

function coordinatorRole(active = true) {
  return {role: 'coordinator', locationIds: [], active};
}

function managerRole() {
  return {role: 'site_manager', locationIds: ['merignac'], active: true};
}

function invitation(overrides = {}) {
  const current = Date.now();
  return {
    email: 'manager@example.test',
    displayName: 'Responsable Test',
    role: 'site_manager',
    locationIds: ['merignac'],
    createdBy: 'bootstrap',
    createdAt: Timestamp.fromMillis(current - 86_400_000),
    expiresAt: Timestamp.fromMillis(current + 7 * 86_400_000),
    status: 'pending',
    acceptedAt: null,
    ...overrides,
  };
}

async function seedInvitation(id, value = invitation()) {
  await db.collection('adminInvitations').doc(id).set(value);
}

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

test('only an active coordinator can manage invitations', async () => {
  const id = unique('restricted');
  await seedInvitation(id);
  await assertCode(
    () => callable(null).then((manage) => manage({
      invitationId: id, action: 'cancel',
    })),
    'unauthenticated',
  );
  for (const role of [managerRole(), coordinatorRole(false)]) {
    const user = await createUser(role);
    const manage = await callable(user);
    await assertCode(
      () => manage({invitationId: id, action: 'cancel'}),
      'permission-denied',
    );
  }
  assert.equal(
    (await db.collection('adminInvitations').doc(id).get()).data().status,
    'pending',
  );
});

test('update, cancel and reactivate preserve identity and the document', async () => {
  const caller = await createUser(coordinatorRole());
  const manage = await callable(caller);
  const id = unique('lifecycle');
  await seedInvitation(id);
  const before = (await db.collection('adminInvitations').doc(id).get()).data();

  await manage({
    invitationId: id,
    action: 'update',
    displayName: 'Nouveau responsable',
    role: 'coordinator',
    locationIds: [],
  });
  await manage({invitationId: id, action: 'cancel'});
  const expiresAtMillis = Date.now() + 14 * 86_400_000;
  await manage({invitationId: id, action: 'reactivate', expiresAtMillis});

  const after = (await db.collection('adminInvitations').doc(id).get()).data();
  assert.equal(after.email, before.email);
  assert.equal(after.createdBy, before.createdBy);
  assert.equal(after.createdAt.toMillis(), before.createdAt.toMillis());
  assert.equal(after.displayName, 'Nouveau responsable');
  assert.equal(after.role, 'coordinator');
  assert.deepEqual(after.locationIds, []);
  assert.equal(after.status, 'pending');
  assert.equal(after.acceptedAt, null);
  assert.equal(after.expiresAt.toMillis(), expiresAtMillis);
});

test('deletion removes only an unused invitation and never its Auth account', async () => {
  const caller = await createUser(coordinatorRole());
  const target = await createUser(null);
  const manage = await callable(caller);
  const id = unique('delete');
  await seedInvitation(id, invitation({email: target.email}));

  await manage({invitationId: id, action: 'delete'});

  assert.equal(
    (await db.collection('adminInvitations').doc(id).get()).exists,
    false,
  );
  assert.equal((await adminAuth.getUser(target.uid)).uid, target.uid);
});

test('accepted invitations refuse update, cancellation, reactivation and delete', async () => {
  const caller = await createUser(coordinatorRole());
  const manage = await callable(caller);
  const id = unique('accepted');
  const acceptedAt = Timestamp.fromMillis(Date.now() - 1_000);
  await seedInvitation(id, invitation({
    status: 'accepted',
    acceptedAt,
    acceptedUid: unique('accepted-user'),
    provisionedAt: acceptedAt,
    activationLinkGeneratedAt: acceptedAt,
    notificationStatus: 'pending',
  }));
  const requests = [
    {invitationId: id, action: 'cancel'},
    {
      invitationId: id,
      action: 'reactivate',
      expiresAtMillis: Date.now() + 86_400_000,
    },
    {
      invitationId: id,
      action: 'update',
      displayName: 'Autre nom',
      role: 'coordinator',
      locationIds: [],
    },
    {invitationId: id, action: 'delete'},
  ];
  for (const request of requests) {
    await assertCode(() => manage(request), 'failed-precondition');
  }
  assert.equal(
    (await db.collection('adminInvitations').doc(id).get()).data().status,
    'accepted',
  );
});

test('concurrent reactivation commits exactly once', async () => {
  const caller = await createUser(coordinatorRole());
  const manage = await callable(caller);
  const id = unique('concurrent');
  await seedInvitation(id, invitation({status: 'cancelled'}));
  const request = {
    invitationId: id,
    action: 'reactivate',
    expiresAtMillis: Date.now() + 7 * 86_400_000,
  };
  const results = await Promise.allSettled([manage(request), manage(request)]);
  assert.equal(results.filter((value) => value.status === 'fulfilled').length, 1);
  assert.equal(results.filter((value) => value.status === 'rejected').length, 1);
  assert.equal(
    (await db.collection('adminInvitations').doc(id).get()).data().status,
    'pending',
  );
});
