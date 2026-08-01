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

import {adminServices} from '../../src/index.js';
import {
  invitationNotificationIdempotencyKey,
  NOTIFICATION_LEASE_DURATION_MS,
} from '../../src/provision_admin_invitation.js';
import {
  NotificationService,
} from '../../src/notifications/notification_service.js';
import {
  FakeNotificationProvider,
} from '../../src/notifications/providers/fake_notification_provider.js';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'provisioning-emulator-tests');
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

function locations(start, count) {
  return Array.from(
    {length: count},
    (_, index) => `site-${String(start + index).padStart(3, '0')}`,
  );
}

async function client({
  uid,
  role,
  roleDocument,
  active = true,
  locationIds = [],
} = {}) {
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
    if (role || roleDocument) {
      await db.collection('roles').doc(user.uid).set(roleDocument ?? {
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

async function seedSiteManagerRole(uid) {
  await db.collection('roles').doc(uid).set({
    role: 'site_manager',
    roles: ['site_manager'],
    locationIds: ['merignac'],
    active: true,
    schemaVersion: 2,
  });
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
  assert.deepEqual(role.roles, ['site_manager']);
  assert.deepEqual(role.locationIds, ['merignac']);
  assert.equal(role.active, true);
  assert.equal(role.schemaVersion, 2);
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

test('active cumulative V2 coordinator can provision an invitation', async () => {
  const callable = await client({
    uid: unique('v2-coordinator'),
    roleDocument: {
      role: 'coordinator',
      roles: ['coordinator', 'site_manager'],
      locationIds: ['merignac'],
      active: true,
      schemaVersion: 2,
    },
  });
  const id = unique('v2-coordinator-invitation');
  await seedInvitation(id);
  const response = await callable({invitationId: id});
  assert.equal(response.data.invitationStatus, 'accepted');
});

test('provisioning transaction refuses a coordinator revoked after authorization', async () => {
  const callerUid = unique('revoked-coordinator');
  const targetUid = unique('revoked-target');
  const invitationId = unique('revoked-invitation');
  const invitation = await seedInvitation(invitationId, {
    createdBy: callerUid,
  });
  await db.collection('roles').doc(callerUid).set({
    role: 'coordinator',
    active: false,
    locationIds: [],
  });

  const services = adminServices({firestore: db, auth: adminAuth});
  await assert.rejects(
    services.commitProvisioning({
      invitationId,
      targetUid,
      expectedInvitation: invitation,
      createdBy: callerUid,
      timestamps: {
        acceptedAt: Timestamp.now(),
        provisionedAt: Timestamp.now(),
        activationLinkGeneratedAt: Timestamp.now(),
      },
    }),
    (error) => {
      assert.equal(error.code, 'permission-denied');
      return true;
    },
  );

  const unchangedInvitation = (
    await db.collection('adminInvitations').doc(invitationId).get()
  ).data();
  assert.equal(unchangedInvitation.status, 'pending');
  assert.equal('acceptedUid' in unchangedInvitation, false);
  assert.equal(
    (await db.collection('roles').doc(targetUid).get()).exists,
    false,
  );
  assert.equal('notificationStatus' in unchangedInvitation, false);
});

test('real transaction grants exactly one notification reservation owner', async () => {
  const invitationId = unique('notification-reservation-race');
  const targetUid = unique('notification-target');
  const reservedAt = new Date();
  await seedInvitation(invitationId, {
    status: 'accepted',
    acceptedUid: targetUid,
    notificationStatus: 'failed',
  });
  await seedSiteManagerRole(targetUid);
  const services = adminServices({firestore: db, auth: adminAuth});
  const reserve = (attemptId) => services.reserveNotificationDelivery({
    invitationId,
    targetUid,
    attemptId,
    reservedAt,
    leaseExpiresAt: new Date(
      reservedAt.getTime() + NOTIFICATION_LEASE_DURATION_MS,
    ),
  });
  const attempts = ['attempt-one', 'attempt-two'];
  const reservations = await Promise.all(attempts.map(reserve));
  assert.deepEqual(
    reservations.map((result) => result.state).sort(),
    ['in-progress', 'reserved'],
  );

  const provider = new FakeNotificationProvider({
    providerMessageId: 'reservation-message-id',
  });
  const service = new NotificationService({provider});
  const winner = attempts[reservations.findIndex(
    (result) => result.state === 'reserved',
  )];
  const notificationResult = await service.send({
    channel: 'email',
    recipient: 'responsable@example.test',
    subject: 'Activation MobSanté',
    text: 'Test Emulator sans réseau.',
    metadata: {kind: 'admin-invitation'},
  }, {
    idempotencyKey: invitationNotificationIdempotencyKey(invitationId),
  });
  assert.equal(provider.deliveries.length, 1);
  await services.markNotificationSent({
    invitationId,
    targetUid,
    attemptId: winner,
    provider: notificationResult.provider,
    providerMessageId: notificationResult.providerMessageId,
    sentAt: new Date(),
  });
  const sent = (
    await db.collection('adminInvitations').doc(invitationId).get()
  ).data();
  assert.equal(sent.notificationStatus, 'sent');
  assert.equal(sent.notificationProviderMessageId, 'reservation-message-id');
  assert.equal('notificationAttemptId' in sent, false);
  assert.equal('notificationLeaseExpiresAt' in sent, false);
});

test('notification reservation requires accepted invitation and assigned role', async () => {
  const services = adminServices({firestore: db, auth: adminAuth});
  const targetUid = unique('unassigned-notification-target');
  const pendingId = unique('pending-notification-reservation');
  await seedInvitation(pendingId);
  await assert.rejects(
    services.reserveNotificationDelivery({
      invitationId: pendingId,
      targetUid,
      attemptId: 'pending-attempt',
      reservedAt: new Date(),
      leaseExpiresAt: new Date(Date.now() + NOTIFICATION_LEASE_DURATION_MS),
    }),
    (error) => error.code === 'aborted',
  );
  const acceptedId = unique('unassigned-notification-reservation');
  await seedInvitation(acceptedId, {
    status: 'accepted',
    acceptedUid: targetUid,
    notificationStatus: 'pending',
  });
  await assert.rejects(
    services.reserveNotificationDelivery({
      invitationId: acceptedId,
      targetUid,
      attemptId: 'unassigned-attempt',
      reservedAt: new Date(),
      leaseExpiresAt: new Date(Date.now() + NOTIFICATION_LEASE_DURATION_MS),
    }),
    (error) => error.code === 'aborted',
  );
  const unchanged = (
    await db.collection('adminInvitations').doc(acceptedId).get()
  ).data();
  assert.equal(unchanged.notificationStatus, 'pending');
  assert.equal('notificationAttemptId' in unchanged, false);
});

test('expired reservation is reclaimable and stale failure cannot overwrite sent', async () => {
  const invitationId = unique('expired-notification-reservation');
  const targetUid = unique('expired-notification-target');
  const reservedAt = new Date(Date.now() - NOTIFICATION_LEASE_DURATION_MS - 1);
  await seedInvitation(invitationId, {
    status: 'accepted',
    acceptedUid: targetUid,
    notificationStatus: 'sending',
    notificationAttemptId: 'abandoned-attempt',
    notificationReservedAt: Timestamp.fromDate(reservedAt),
    notificationLeaseExpiresAt: Timestamp.fromDate(
      new Date(reservedAt.getTime() + NOTIFICATION_LEASE_DURATION_MS),
    ),
  });
  await seedSiteManagerRole(targetUid);
  const services = adminServices({firestore: db, auth: adminAuth});
  const replacement = await services.reserveNotificationDelivery({
    invitationId,
    targetUid,
    attemptId: 'replacement-attempt',
    reservedAt: new Date(),
    leaseExpiresAt: new Date(Date.now() + NOTIFICATION_LEASE_DURATION_MS),
  });
  assert.equal(replacement.state, 'reserved');
  await services.markNotificationSent({
    invitationId,
    targetUid,
    attemptId: 'replacement-attempt',
    provider: 'fake',
    providerMessageId: 'replacement-message-id',
    sentAt: new Date(),
  });
  const staleFinalization = await services.markNotificationFailed({
    invitationId,
    targetUid,
    attemptId: 'abandoned-attempt',
    errorCode: 'late-failure',
    failedAt: new Date(),
  });
  assert.equal(staleFinalization.state, 'sent');
  const finalInvitation = (
    await db.collection('adminInvitations').doc(invitationId).get()
  ).data();
  assert.equal(finalInvitation.notificationStatus, 'sent');
  assert.equal(
    finalInvitation.notificationProviderMessageId,
    'replacement-message-id',
  );
  assert.equal('notificationErrorCode' in finalInvitation, false);
});

test('historical sent notification remains terminal without reservation fields', async () => {
  const invitationId = unique('historical-sent-notification');
  const targetUid = unique('historical-sent-target');
  const sentAt = Timestamp.fromDate(new Date('2026-07-30T10:00:00Z'));
  await seedInvitation(invitationId, {
    status: 'accepted',
    acceptedUid: targetUid,
    notificationStatus: 'sent',
    notificationSentAt: sentAt,
    notificationProvider: 'fake',
    notificationProviderMessageId: 'historical-message-id',
  });
  await seedSiteManagerRole(targetUid);
  const services = adminServices({firestore: db, auth: adminAuth});
  const reservation = await services.reserveNotificationDelivery({
    invitationId,
    targetUid,
    attemptId: 'forbidden-attempt',
    reservedAt: new Date(),
    leaseExpiresAt: new Date(Date.now() + NOTIFICATION_LEASE_DURATION_MS),
  });
  assert.equal(reservation.state, 'sent');
  const unchanged = (
    await db.collection('adminInvitations').doc(invitationId).get()
  ).data();
  assert.equal(unchanged.notificationProviderMessageId, 'historical-message-id');
  assert.equal(unchanged.notificationSentAt.toMillis(), sentAt.toMillis());
  assert.equal('notificationAttemptId' in unchanged, false);
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
  assert.deepEqual(role.roles, ['site_manager']);
  assert.equal(role.schemaVersion, 2);
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
  assert.deepEqual(role.roles, ['site_manager']);
  assert.equal(role.schemaVersion, 2);
});

test('existing coordinator receives site manager additively', async () => {
  const callable = await coordinator();
  const targetEmail = email('existing-coordinator');
  const target = await adminAuth.createUser({email: targetEmail});
  await db.collection('roles').doc(target.uid).set({
    role: 'coordinator',
    locationIds: [],
    active: true,
  });
  const id = unique('existing-coordinator');
  await seedInvitation(id, {email: targetEmail});
  await callable({invitationId: id});
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  assert.equal(role.role, 'coordinator');
  assert.deepEqual(role.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(role.locationIds, ['merignac']);
  assert.equal(role.schemaVersion, 2);
});

test('existing site manager receives coordinator without losing metadata', async () => {
  const callable = await coordinator();
  const targetEmail = email('manager-to-coordinator');
  const target = await adminAuth.createUser({email: targetEmail});
  const createdAt = Timestamp.fromDate(new Date('2026-01-02T03:04:05Z'));
  await db.collection('roles').doc(target.uid).set({
    role: 'site_manager',
    locationIds: ['bazas'],
    active: true,
    createdAt,
    createdBy: 'bootstrap-coordinator',
    historicalNote: 'preserved',
  });
  const id = unique('manager-to-coordinator');
  await seedInvitation(id, {
    email: targetEmail,
    role: 'coordinator',
    locationIds: [],
  });
  await callable({invitationId: id});
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  assert.equal(role.role, 'coordinator');
  assert.deepEqual(role.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(role.locationIds, ['bazas']);
  assert.equal(role.createdAt.toMillis(), createdAt.toMillis());
  assert.equal(role.createdBy, 'bootstrap-coordinator');
  assert.equal(role.historicalNote, 'preserved');
  assert.ok(role.updatedAt);
});

test('legacy coordinator wildcard becomes cumulative without wildcard', async () => {
  const callable = await coordinator();
  const targetEmail = email('wildcard-coordinator');
  const target = await adminAuth.createUser({email: targetEmail});
  await db.collection('roles').doc(target.uid).set({
    role: 'coordinator',
    locationIds: ['*'],
    active: true,
  });
  const id = unique('wildcard-coordinator');
  await seedInvitation(id, {email: targetEmail, locationIds: ['bazas']});
  await callable({invitationId: id});
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  assert.deepEqual(role.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(role.locationIds, ['bazas']);
  assert.equal(role.locationIds.includes('*'), false);
});

test('existing cumulative V2 role merges a new center idempotently', async () => {
  const callable = await coordinator();
  const targetEmail = email('cumulative');
  const target = await adminAuth.createUser({email: targetEmail});
  await db.collection('roles').doc(target.uid).set({
    role: 'coordinator',
    roles: ['coordinator', 'site_manager'],
    locationIds: ['bazas'],
    active: true,
    schemaVersion: 2,
  });
  const id = unique('cumulative');
  await seedInvitation(id, {
    email: targetEmail,
    locationIds: ['bassens', 'bazas'],
  });
  await callable({invitationId: id});
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  assert.deepEqual(role.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(role.locationIds, ['bassens', 'bazas']);
});

test('location union writes exactly 65 centers', async () => {
  const callable = await coordinator();
  const targetEmail = email('limit-65');
  const target = await adminAuth.createUser({email: targetEmail});
  await db.collection('roles').doc(target.uid).set({
    role: 'site_manager',
    roles: ['site_manager'],
    locationIds: locations(0, 64),
    active: true,
    schemaVersion: 2,
  });
  const id = unique('limit-65');
  await seedInvitation(id, {
    email: targetEmail,
    locationIds: locations(64, 1),
  });

  await callable({invitationId: id});

  const role = (await db.collection('roles').doc(target.uid).get()).data();
  const accepted = (
    await db.collection('adminInvitations').doc(id).get()
  ).data();
  assert.deepEqual(role.locationIds, locations(0, 65));
  assert.equal(accepted.status, 'accepted');
  assert.equal(accepted.notificationStatus, 'sent');
});

test('location union refuses 66 centers without partial writes', async () => {
  const callable = await coordinator();
  const targetEmail = email('limit-66');
  const target = await adminAuth.createUser({email: targetEmail});
  const existingLocations = locations(0, 65);
  await db.collection('roles').doc(target.uid).set({
    role: 'site_manager',
    roles: ['site_manager'],
    locationIds: existingLocations,
    active: true,
    schemaVersion: 2,
  });
  const id = unique('limit-66');
  await seedInvitation(id, {
    email: targetEmail,
    locationIds: locations(65, 1),
  });

  await assertCallableCode(
    () => callable({invitationId: id}),
    'failed-precondition',
  );

  const role = (await db.collection('roles').doc(target.uid).get()).data();
  const pending = (
    await db.collection('adminInvitations').doc(id).get()
  ).data();
  assert.deepEqual(role.locationIds, existingLocations);
  assert.equal(pending.status, 'pending');
  assert.equal('acceptedUid' in pending, false);
  assert.equal('notificationStatus' in pending, false);
  assert.equal((await adminAuth.getUser(target.uid)).uid, target.uid);
});

test('different invitations for the same role and center keep one canonical state', async () => {
  const callable = await coordinator();
  const targetEmail = email('repeated-assignment');
  const firstId = unique('repeated-assignment-first');
  const secondId = unique('repeated-assignment-second');

  await seedInvitation(firstId, {
    email: targetEmail,
    locationIds: ['bazas'],
  });
  await callable({invitationId: firstId});

  const target = await adminAuth.getUserByEmail(targetEmail);
  const firstRole = (
    await db.collection('roles').doc(target.uid).get()
  ).data();

  await seedInvitation(secondId, {
    email: targetEmail,
    locationIds: ['bazas'],
  });
  await callable({invitationId: secondId});

  const secondRole = (
    await db.collection('roles').doc(target.uid).get()
  ).data();
  assert.equal(secondRole.role, firstRole.role);
  assert.deepEqual(secondRole.roles, firstRole.roles);
  assert.deepEqual(secondRole.locationIds, firstRole.locationIds);
  assert.equal(secondRole.active, firstRole.active);
  assert.equal(secondRole.schemaVersion, firstRole.schemaVersion);
  assert.equal(secondRole.createdAt.toMillis(), firstRole.createdAt.toMillis());
  assert.equal(secondRole.createdBy, firstRole.createdBy);
});

test('inactive existing role is refused without deleting Auth', async () => {
  const callable = await coordinator();
  const targetEmail = email('inactive-role');
  const target = await adminAuth.createUser({email: targetEmail});
  await db.collection('roles').doc(target.uid).set({
    role: 'coordinator', locationIds: [], active: false,
  });
  const id = unique('inactive-role');
  await seedInvitation(id, {email: targetEmail});
  await assertCallableCode(
    () => callable({invitationId: id}),
    'failed-precondition',
  );
  assert.equal((await adminAuth.getUser(target.uid)).uid, target.uid);
  assert.equal(
    (await db.collection('adminInvitations').doc(id).get()).data().status,
    'pending',
  );
});

test('malformed existing role is refused without mutation or Auth deletion', async () => {
  const callable = await coordinator();
  const targetEmail = email('malformed-role');
  const target = await adminAuth.createUser({email: targetEmail});
  const malformed = {
    role: 'coordinator',
    roles: ['site_manager', 'coordinator'],
    locationIds: ['bazas'],
    active: true,
    schemaVersion: 2,
  };
  await db.collection('roles').doc(target.uid).set(malformed);
  const id = unique('malformed-role');
  await seedInvitation(id, {email: targetEmail});
  await assertCallableCode(
    () => callable({invitationId: id}),
    'failed-precondition',
  );
  assert.deepEqual(
    (await db.collection('roles').doc(target.uid).get()).data(),
    malformed,
  );
  assert.equal((await adminAuth.getUser(target.uid)).uid, target.uid);
});

test('concurrent center invitations merge without lost update', async () => {
  const callable = await coordinator();
  const targetEmail = email('concurrent-centers');
  const target = await adminAuth.createUser({email: targetEmail});
  const firstId = unique('center-a');
  const secondId = unique('center-b');
  await Promise.all([
    seedInvitation(firstId, {email: targetEmail, locationIds: ['bazas']}),
    seedInvitation(secondId, {email: targetEmail, locationIds: ['bassens']}),
  ]);
  await Promise.all([
    callable({invitationId: firstId}),
    callable({invitationId: secondId}),
  ]);
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  assert.deepEqual(role.roles, ['site_manager']);
  assert.deepEqual(role.locationIds, ['bassens', 'bazas']);
});

test('concurrent role invitations merge into a cumulative account', async () => {
  const callable = await coordinator();
  const targetEmail = email('concurrent-roles');
  const target = await adminAuth.createUser({email: targetEmail});
  const coordinatorId = unique('role-coordinator');
  const managerId = unique('role-manager');
  await Promise.all([
    seedInvitation(coordinatorId, {
      email: targetEmail,
      role: 'coordinator',
      locationIds: [],
    }),
    seedInvitation(managerId, {
      email: targetEmail,
      role: 'site_manager',
      locationIds: ['bazas'],
    }),
  ]);
  await Promise.all([
    callable({invitationId: coordinatorId}),
    callable({invitationId: managerId}),
  ]);
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  assert.equal(role.role, 'coordinator');
  assert.deepEqual(role.roles, ['coordinator', 'site_manager']);
  assert.deepEqual(role.locationIds, ['bazas']);
});

test('concurrent provisioning keeps an initially absent Auth account', async () => {
  const callable = await coordinator();
  const targetEmail = email('concurrent-new-auth');
  const failedId = 'failure-concurrent';
  const successfulId = unique('success-concurrent');
  await Promise.all([
    seedInvitation(failedId, {
      email: targetEmail,
      locationIds: ['bazas'],
    }),
    seedInvitation(successfulId, {
      email: targetEmail,
      locationIds: ['bassens'],
    }),
  ]);

  const results = await Promise.allSettled([
    callable({invitationId: failedId}),
    callable({invitationId: successfulId}),
  ]);
  const fulfilled = results.filter((result) => result.status === 'fulfilled');
  const rejected = results.filter((result) => result.status === 'rejected');
  assert.equal(fulfilled.length, 1);
  assert.equal(rejected.length, 1);
  assert.equal(rejected[0].reason.code, 'functions/internal');

  const target = await adminAuth.getUserByEmail(targetEmail);
  const sameEmailAccounts = (await adminAuth.listUsers(1000)).users
    .filter((user) => user.email === targetEmail);
  assert.equal(sameEmailAccounts.length, 1);
  const role = (await db.collection('roles').doc(target.uid).get()).data();
  const failed = (
    await db.collection('adminInvitations').doc(failedId).get()
  ).data();
  const successful = (
    await db.collection('adminInvitations').doc(successfulId).get()
  ).data();
  assert.deepEqual(role.roles, ['site_manager']);
  assert.deepEqual(role.locationIds, ['bassens']);
  assert.equal(role.role, 'site_manager');
  assert.equal(role.active, true);
  assert.equal(role.schemaVersion, 2);
  assert.equal(failed.status, 'pending');
  assert.equal('acceptedUid' in failed, false);
  assert.equal(successful.status, 'accepted');
  assert.equal(successful.acceptedUid, target.uid);
  assert.equal(successful.notificationStatus, 'sent');

  const sentAt = successful.notificationSentAt.toMillis();
  const repeatedSuccess = await callable({invitationId: successfulId});
  const unchangedSuccess = (
    await db.collection('adminInvitations').doc(successfulId).get()
  ).data();
  assert.equal(repeatedSuccess.data.alreadyProvisioned, true);
  assert.equal(unchangedSuccess.notificationSentAt.toMillis(), sentAt);

  await callable({invitationId: failedId});
  const mergedRole = (
    await db.collection('roles').doc(target.uid).get()
  ).data();
  const retried = (
    await db.collection('adminInvitations').doc(failedId).get()
  ).data();
  assert.deepEqual(mergedRole.locationIds, ['bassens', 'bazas']);
  assert.equal(retried.status, 'accepted');
  assert.equal(retried.acceptedUid, target.uid);
  assert.equal(retried.notificationStatus, 'sent');
  const retriedSentAt = retried.notificationSentAt.toMillis();
  await callable({invitationId: failedId});
  const repeatedRetry = (
    await db.collection('adminInvitations').doc(failedId).get()
  ).data();
  assert.equal(repeatedRetry.notificationSentAt.toMillis(), retriedSentAt);
  assert.equal((await adminAuth.getUser(target.uid)).uid, target.uid);
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

test('concurrent callable calls on pending invitation keep one final delivery', async () => {
  const callable = await coordinator();
  const targetEmail = email('concurrent-pending-notification');
  const target = await adminAuth.createUser({email: targetEmail});
  const invitationId = unique('concurrent-pending-notification');
  await seedInvitation(invitationId, {email: targetEmail});

  const results = await Promise.allSettled([
    callable({invitationId}),
    callable({invitationId}),
  ]);
  assert.ok(results.some((result) => result.status === 'fulfilled'));
  const finalInvitation = (
    await db.collection('adminInvitations').doc(invitationId).get()
  ).data();
  assert.equal(finalInvitation.status, 'accepted');
  assert.equal(finalInvitation.acceptedUid, target.uid);
  assert.equal(finalInvitation.notificationStatus, 'sent');
  assert.equal(
    finalInvitation.notificationProviderMessageId,
    'emulator-message-id',
  );
  assert.equal('notificationAttemptId' in finalInvitation, false);
  assert.equal('notificationLeaseExpiresAt' in finalInvitation, false);
});

test('concurrent retries on failed invitation keep one final delivery', async () => {
  const callable = await coordinator();
  const targetEmail = email('concurrent-failed-notification');
  const target = await adminAuth.createUser({email: targetEmail});
  await db.collection('roles').doc(target.uid).set({
    role: 'site_manager',
    roles: ['site_manager'],
    locationIds: ['merignac'],
    active: true,
    schemaVersion: 2,
  });
  const invitationId = unique('concurrent-failed-notification');
  await seedInvitation(invitationId, {
    email: targetEmail,
    status: 'accepted',
    acceptedUid: target.uid,
    notificationStatus: 'failed',
    notificationErrorCode: 'provider-failure',
  });

  const results = await Promise.all([
    callable({invitationId}),
    callable({invitationId}),
  ]);
  assert.ok(results.every((result) =>
    new Set(['pending', 'sent']).has(result.data.emailDelivery)));
  const finalInvitation = (
    await db.collection('adminInvitations').doc(invitationId).get()
  ).data();
  assert.equal(finalInvitation.notificationStatus, 'sent');
  assert.equal(
    finalInvitation.notificationProviderMessageId,
    'emulator-message-id',
  );
  assert.equal('notificationErrorCode' in finalInvitation, false);
  assert.equal('notificationAttemptId' in finalInvitation, false);
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

test('new Auth account is preserved when Firestore commit fails', async () => {
  const callable = await coordinator();
  const invitation = await seedInvitation('failure-new');
  await assertCallableCode(
    () => callable({invitationId: 'failure-new'}),
    'internal',
  );
  const preservedTarget = await adminAuth.getUserByEmail(invitation.email);
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
  assert.equal(retriedTarget.uid, preservedTarget.uid);
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
  assert.equal(
    (await db.collection('roles').doc(target.uid).get()).exists,
    false,
  );
});
