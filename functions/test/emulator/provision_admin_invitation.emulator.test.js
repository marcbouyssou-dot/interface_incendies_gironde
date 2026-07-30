import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';

import {deleteApp as deleteAdminApp, initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore, Timestamp} from 'firebase-admin/firestore';
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
const adminApp = initializeAdminApp({projectId});
const adminAuth = getAdminAuth(adminApp);
const db = getAdminFirestore(adminApp);
const clientApps = [];
let sequence = 0;

function unique(prefix) {
  sequence += 1;
  return `${prefix}-${process.pid}-${sequence}`;
}

function email(prefix) {
  return `${unique(prefix)}@example.test`;
}

async function client({uid, role, active = true, locationIds = []} = {}) {
  const name = unique('client');
  const app = initializeApp({projectId, apiKey: 'fake-api-key'}, name);
  clientApps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {
    disableWarnings: true,
  });
  if (uid) {
    const password = 'Test-only-password-42!';
    const userEmail = email(uid);
    const user = await adminAuth.createUser({
      uid,
      email: userEmail,
      password,
      disabled: false,
    });
    if (role) {
      await db.collection('roles').doc(user.uid).set({
        role,
        active,
        locationIds,
      });
    }
    await signInWithEmailAndPassword(auth, userEmail, password);
  }
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return httpsCallable(functions, 'provisionAdminInvitation');
}

function pendingInvitation(overrides = {}) {
  return {
    email: email('target'),
    displayName: 'Camille Martin',
    role: 'site_manager',
    locationIds: ['merignac'],
    createdBy: 'coordinator',
    createdAt: Timestamp.now(),
    expiresAt: Timestamp.fromDate(new Date(Date.now() + 3_600_000)),
    status: 'pending',
    ...overrides,
  };
}

async function seedInvitation(id, overrides = {}) {
  const value = pendingInvitation(overrides);
  await db.collection('adminInvitations').doc(id).set(value);
  return value;
}

async function coordinator(options = {}) {
  return client({
    uid: unique('coordinator'),
    role: 'coordinator',
    active: true,
    ...options,
  });
}

async function assertCallableCode(action, expected) {
  await assert.rejects(action, (error) => {
    assert.equal(error.code, `functions/${expected}`);
    return true;
  });
}

before(() => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  assert.equal(process.env.FIREBASE_AUTH_EMULATOR_HOST, '127.0.0.1:9099');
  assert.equal(process.env.FIRESTORE_EMULATOR_HOST, '127.0.0.1:8080');
});

after(async () => {
  await Promise.all(clientApps.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

test('main flow provisions Auth, role and accepted invitation safely', async () => {
  const callable = await coordinator();
  const invitationId = unique('main-flow');
  const invitation = await seedInvitation(invitationId);

  const response = await callable({invitationId});
  assert.deepEqual(response.data, {
    accountProvisioned: true,
    emailDelivery: 'sent',
    invitationStatus: 'accepted',
    alreadyProvisioned: false,
  });

  const target = await adminAuth.getUserByEmail(invitation.email);
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  const accepted = (
    await db.collection('adminInvitations').doc(invitationId).get()
  ).data();
  assert.equal(role.role, 'site_manager');
  assert.deepEqual(role.locationIds, ['merignac']);
  assert.equal(role.active, true);
  assert.match(role.createdBy, /^coordinator-/);
  assert.ok(role.createdAt);
  assert.ok(role.updatedAt);
  assert.equal(accepted.status, 'accepted');
  assert.equal(accepted.acceptedUid, target.uid);
  assert.ok(accepted.acceptedAt);
  assert.ok(accepted.provisionedAt);
  assert.ok(accepted.activationLinkGeneratedAt);
  assert.equal(accepted.notificationStatus, 'sent');
  assert.equal(accepted.notificationProvider, 'fake');
  assert.equal(
    accepted.notificationProviderMessageId,
    'emulator-message-id',
  );
  assert.ok(accepted.notificationSentAt);
  assert.equal('notificationErrorCode' in accepted, false);

  const persisted = JSON.stringify({role, accepted});
  assert.equal(persisted.includes('oobCode'), false);
  assert.equal('activationLink' in accepted, false);
  assert.equal(JSON.stringify(response.data).includes('oobCode'), false);
});

test('unauthenticated caller is refused', async () => {
  const callable = await client();
  const id = unique('unauthenticated');
  await seedInvitation(id);
  await assertCallableCode(() => callable({invitationId: id}), 'unauthenticated');
});

for (const [label, role, active] of [
  ['volunteer', null, true],
  ['site manager', 'site_manager', true],
  ['inactive coordinator', 'coordinator', false],
]) {
  test(`${label} caller is refused`, async () => {
    const callable = await client({
      uid: unique(label.replaceAll(' ', '-')),
      role,
      active,
      locationIds: role === 'site_manager' ? ['merignac'] : [],
    });
    const id = unique('forbidden');
    await seedInvitation(id);
    await assertCallableCode(() => callable({invitationId: id}), 'permission-denied');
  });
}

test('unknown invitation is refused', async () => {
  const callable = await coordinator();
  await assertCallableCode(
    () => callable({invitationId: unique('missing')}),
    'not-found',
  );
});

for (const [label, overrides, code] of [
  ['cancelled invitation', {status: 'cancelled'}, 'failed-precondition'],
  [
    'expired invitation',
    {expiresAt: Timestamp.fromMillis(Date.now() - 60_000)},
    'failed-precondition',
  ],
  ['invalid email', {email: 'invalid'}, 'invalid-argument'],
  ['invalid role', {role: 'administrator'}, 'invalid-argument'],
  ['site manager without location', {locationIds: []}, 'invalid-argument'],
  [
    'coordinator with locations',
    {role: 'coordinator', locationIds: ['merignac']},
    'invalid-argument',
  ],
]) {
  test(`${label} is refused`, async () => {
    const callable = await coordinator();
    const id = unique('invalid-invitation');
    await seedInvitation(id, overrides);
    await assertCallableCode(() => callable({invitationId: id}), code);
  });
}

test('already accepted invitation is an idempotent safe success', async () => {
  const callable = await coordinator();
  const id = unique('accepted');
  await seedInvitation(id, {
    status: 'accepted',
    acceptedUid: 'existing-target',
    notificationStatus: 'sent',
  });
  const response = await callable({invitationId: id});
  assert.equal(response.data.alreadyProvisioned, true);
  assert.equal(response.data.invitationStatus, 'accepted');
  assert.equal('uid' in response.data, false);
});

test('existing account without role receives the expected role', async () => {
  const callable = await coordinator();
  const targetEmail = email('existing-no-role');
  const target = await adminAuth.createUser({
    email: targetEmail,
    password: 'Test-only-password-42!',
  });
  const id = unique('existing-no-role');
  await seedInvitation(id, {email: targetEmail});
  await callable({invitationId: id});
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  assert.equal(role.role, 'site_manager');
});

test('existing account with compatible role is accepted', async () => {
  const callable = await coordinator();
  const targetEmail = email('existing-compatible');
  const target = await adminAuth.createUser({email: targetEmail});
  await db.collection('roles').doc(target.uid).set({
    role: 'site_manager',
    locationIds: ['merignac'],
    active: true,
    createdAt: Timestamp.now(),
    createdBy: 'previous-coordinator',
  });
  const id = unique('existing-compatible');
  await seedInvitation(id, {email: targetEmail});
  await callable({invitationId: id});
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  assert.equal(role.createdBy, 'previous-coordinator');
});

test('existing account with incompatible role is refused', async () => {
  const callable = await coordinator();
  const targetEmail = email('existing-incompatible');
  const target = await adminAuth.createUser({email: targetEmail});
  await db.collection('roles').doc(target.uid).set({
    role: 'coordinator',
    locationIds: [],
    active: true,
  });
  const id = unique('existing-incompatible');
  await seedInvitation(id, {email: targetEmail});
  await assertCallableCode(() => callable({invitationId: id}), 'already-exists');
  assert.equal((await db.collection('adminInvitations').doc(id).get()).data().status, 'pending');
});

test('disabled existing account is refused', async () => {
  const callable = await coordinator();
  const targetEmail = email('disabled');
  await adminAuth.createUser({email: targetEmail, disabled: true});
  const id = unique('disabled');
  await seedInvitation(id, {email: targetEmail});
  await assertCallableCode(
    () => callable({invitationId: id}),
    'failed-precondition',
  );
});

test('second call creates neither a second account, role nor activation timestamp', async () => {
  const callable = await coordinator();
  const id = unique('idempotent');
  const invitation = await seedInvitation(id);
  await callable({invitationId: id});
  const first = (await db.collection('adminInvitations').doc(id).get()).data();
  const target = await adminAuth.getUserByEmail(invitation.email);
  const secondResponse = await callable({invitationId: id});
  const second = (await db.collection('adminInvitations').doc(id).get()).data();
  const sameTarget = await adminAuth.getUserByEmail(invitation.email);
  assert.equal(secondResponse.data.alreadyProvisioned, true);
  assert.equal(sameTarget.uid, target.uid);
  assert.equal(second.acceptedUid, first.acceptedUid);
  assert.equal(
    second.activationLinkGeneratedAt.toMillis(),
    first.activationLinkGeneratedAt.toMillis(),
  );
  assert.equal(
    second.notificationSentAt.toMillis(),
    first.notificationSentAt.toMillis(),
  );
});

test('notification failure preserves provisioning and retry sends once', async () => {
  const callable = await coordinator();
  const invitation = await seedInvitation('notification-failure');

  await assertCallableCode(
    () => callable({invitationId: 'notification-failure'}),
    'unavailable',
  );
  const target = await adminAuth.getUserByEmail(invitation.email);
  const failed = (
    await db.collection('adminInvitations').doc('notification-failure').get()
  ).data();
  assert.equal(failed.status, 'accepted');
  assert.equal(failed.acceptedUid, target.uid);
  assert.equal(failed.notificationStatus, 'failed');
  assert.equal(failed.notificationErrorCode, 'provider-failure');
  assert.ok(
    (await db.collection('roles').doc(target.uid).get()).exists,
  );

  const retry = await callable({invitationId: 'notification-failure'});
  const sent = (
    await db.collection('adminInvitations').doc('notification-failure').get()
  ).data();
  assert.equal(retry.data.alreadyProvisioned, true);
  assert.equal(retry.data.emailDelivery, 'sent');
  assert.equal(sent.notificationStatus, 'sent');
  assert.equal(sent.notificationProviderMessageId, 'emulator-message-id');
  assert.equal('notificationErrorCode' in sent, false);
  assert.equal((await adminAuth.getUserByEmail(invitation.email)).uid, target.uid);
});

test('new Auth account is compensated when Firestore commit fails', async () => {
  const callable = await coordinator();
  const invitation = await seedInvitation('failure-new');
  await assertCallableCode(
    () => callable({invitationId: 'failure-new'}),
    'internal',
  );
  await assert.rejects(
    () => adminAuth.getUserByEmail(invitation.email),
    (error) => error.code === 'auth/user-not-found',
  );
  const stored = (
    await db.collection('adminInvitations').doc('failure-new').get()
  ).data();
  assert.equal(stored.status, 'pending');
  assert.equal(stored.acceptedUid, undefined);

  const retry = await callable({invitationId: 'failure-new'});
  assert.equal(retry.data.invitationStatus, 'accepted');
  const retriedTarget = await adminAuth.getUserByEmail(invitation.email);
  const retriedInvitation = (
    await db.collection('adminInvitations').doc('failure-new').get()
  ).data();
  assert.equal(retriedInvitation.acceptedUid, retriedTarget.uid);
});

test('pre-existing Auth account is never deleted on Firestore failure', async () => {
  const callable = await coordinator();
  const targetEmail = email('existing-failure');
  const target = await adminAuth.createUser({email: targetEmail});
  await seedInvitation('failure-existing', {email: targetEmail});
  await assertCallableCode(
    () => callable({invitationId: 'failure-existing'}),
    'internal',
  );
  const preserved = await adminAuth.getUser(target.uid);
  assert.equal(preserved.email, targetEmail);
  assert.equal(
    (await db.collection('adminInvitations').doc('failure-existing').get())
      .data().status,
    'pending',
  );
});
