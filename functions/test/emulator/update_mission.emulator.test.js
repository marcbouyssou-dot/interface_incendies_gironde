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
const activeMobilizationId = 'incendies-gironde-2026';
const adminApp = initializeAdminApp({projectId}, 'mission-update-tests');
const adminAuth = getAdminAuth(adminApp);
const db = getAdminFirestore(adminApp);
const clientApps = [];
let sequence = 0;

function unique(prefix) {
  sequence += 1;
  return `${prefix}-${process.pid}-${sequence}`;
}

const quotas = (physiotherapist = 0, podiatrist = 0) => ({
  physiotherapist,
  podiatrist,
  physician: 0,
  nurse: 0,
  veterinarian: 0,
  other_health_professional: 0,
});

async function createUser(roleDocument) {
  const uid = unique('mission-user');
  const email = `${uid}@example.test`;
  const password = 'Test-only-password-42!';
  await adminAuth.createUser({uid, email, password});
  if (roleDocument) {
    await db.collection('roles').doc(uid).set(roleDocument);
    const roles = roleDocument.roles ?? [roleDocument.role];
    if (roleDocument.active === true && roles.includes('coordinator')) {
      await db.collection('mobilizationAssignments')
        .doc(`${activeMobilizationId}_${uid}`)
        .set({
          uid,
          mobilizationId: activeMobilizationId,
          role: 'coordinator',
          active: true,
        });
    }
  }
  return {uid, email, password};
}

async function callable(user) {
  const app = initializeApp(
    {projectId, apiKey: 'fake-api-key'},
    unique('mission-client'),
  );
  clientApps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  if (user) await signInWithEmailAndPassword(auth, user.email, user.password);
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return httpsCallable(functions, 'updateMission');
}

async function seedLocation(id, overrides = {}) {
  await db.collection('locations').doc(id).set({
    id,
    name: `Centre ${id}`,
    group: 'medoc',
    active: true,
    isOperational: true,
    ...overrides,
  });
}

async function seedMission(sourceId, overrides = {}) {
  const id = unique('mission');
  await db.collection('missions').doc(id).set({
    id,
    mobilizationId: activeMobilizationId,
    locationId: sourceId,
    locationName: `Centre ${sourceId}`,
    territorialGroup: 'medoc',
    startAt: new Date('2026-08-03T08:00:00Z'),
    endAt: new Date('2026-08-03T12:00:00Z'),
    requiredByProfession: quotas(2, 1),
    registeredByProfession: quotas(1, 0),
    requiredMk: 2,
    requiredPp: 1,
    registeredMk: 1,
    registeredPp: 0,
    requestedEquipment: ['Tables'],
    details: 'Avant',
    status: 'toComplete',
    isActive: true,
    createdBy: 'original-creator',
    createdAt: new Date('2026-08-01T10:00:00Z'),
    updatedAt: new Date('2026-08-01T10:00:00Z'),
    ...overrides,
  });
  return id;
}

function updateRequest(missionId, locationId, overrides = {}) {
  return {
    missionId,
    locationId,
    startAtMillis: Date.parse('2026-08-04T09:00:00Z'),
    endAtMillis: Date.parse('2026-08-04T13:00:00Z'),
    requiredByProfession: quotas(3, 1),
    equipment: ['Tables', 'Serviettes'],
    details: 'Après',
    ...overrides,
  };
}

const coordinatorRole = (active = true) => ({
  role: 'coordinator', locationIds: [], active,
});
const managerRole = (locationIds) => ({
  role: 'site_manager', locationIds, active: true,
});

async function assertCode(action, code) {
  await assert.rejects(action, (error) => {
    assert.equal(error.code, `functions/${code}`);
    return true;
  });
}

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  await db.collection('platform').doc('config').set({
    activeMobilizationId,
  });
  await db.collection('mobilizations').doc(activeMobilizationId).set({
    id: activeMobilizationId,
    territoryId: 'gironde',
    status: 'active',
  });
});

after(async () => {
  await Promise.all(clientApps.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

test('anonymous, professional and inactive coordinator are refused', async () => {
  const source = unique('source');
  const destination = unique('destination');
  await seedLocation(source);
  await seedLocation(destination);
  const missionId = await seedMission(source);
  for (const [user, code] of [
    [null, 'unauthenticated'],
    [await createUser(null), 'permission-denied'],
    [await createUser(coordinatorRole(false)), 'permission-denied'],
  ]) {
    const update = await callable(user);
    await assertCode(() => update(updateRequest(missionId, destination)), code);
  }
  assert.equal((await db.collection('missions').doc(missionId).get())
    .data().locationId, source);
});

test('coordinator updates editable data and preserves identity and counters', async () => {
  const source = unique('source');
  const destination = unique('destination');
  await seedLocation(source);
  await seedLocation(destination);
  const missionId = await seedMission(source, {
    requiredByProfession: {
      ...quotas(2, 1),
      veterinarian: 2,
    },
    registeredByProfession: {
      ...quotas(1, 0),
      veterinarian: 1,
    },
  });
  const user = await createUser(coordinatorRole());
  const update = await callable(user);
  await update(updateRequest(missionId, destination, {
    requiredByProfession: {
      ...quotas(3, 1),
      veterinarian: 2,
    },
  }));
  const stored = (await db.collection('missions').doc(missionId).get()).data();
  assert.equal(stored.id, missionId);
  assert.equal(stored.locationId, destination);
  assert.equal(stored.locationName, `Centre ${destination}`);
  assert.equal(stored.registeredMk, 1);
  assert.equal(stored.registeredByProfession.physiotherapist, 1);
  assert.equal(stored.requiredByProfession.veterinarian, 2);
  assert.equal(stored.registeredByProfession.veterinarian, 1);
  assert.equal(stored.createdBy, 'original-creator');
  assert.equal(stored.createdAt.toDate().toISOString(),
    '2026-08-01T10:00:00.000Z');
  assert.equal(stored.details, 'Après');
});

test('site manager must manage the source and destination', async () => {
  const source = unique('source');
  const destination = unique('destination');
  await seedLocation(source);
  await seedLocation(destination);
  for (const locationIds of [[source], [destination], [source, destination]]) {
    const missionId = await seedMission(source);
    const user = await createUser(managerRole(locationIds));
    const update = await callable(user);
    if (locationIds.length === 2) {
      await update(updateRequest(missionId, destination));
    } else {
      await assertCode(
        () => update(updateRequest(missionId, destination)),
        'permission-denied',
      );
    }
  }
});

test('cumulative coordinator is not restricted to its site-manager scope', async () => {
  const source = unique('source');
  const destination = unique('destination');
  await seedLocation(source);
  await seedLocation(destination);
  const missionId = await seedMission(source);
  const user = await createUser({
    role: 'coordinator',
    roles: ['coordinator', 'site_manager'],
    locationIds: [source],
    active: true,
    schemaVersion: 2,
  });
  await (await callable(user))(updateRequest(missionId, destination));
  assert.equal((await db.collection('missions').doc(missionId).get())
    .data().locationId, destination);
});

test('missing mission and inactive destination are refused', async () => {
  const source = unique('source');
  const destination = unique('destination');
  await seedLocation(source);
  await seedLocation(destination, {active: false});
  const user = await createUser(coordinatorRole());
  const update = await callable(user);
  await assertCode(
    () => update(updateRequest(unique('missing'), source)),
    'not-found',
  );
  const missionId = await seedMission(source);
  await assertCode(
    () => update(updateRequest(missionId, destination)),
    'failed-precondition',
  );
});

test('inactive historical location can remain but cannot become a destination', async () => {
  const historical = unique('historical');
  const destination = unique('destination');
  await seedLocation(historical, {active: false, isOperational: false});
  await seedLocation(destination, {active: false});
  const missionId = await seedMission(historical);
  const user = await createUser(coordinatorRole());
  const update = await callable(user);
  await update(updateRequest(missionId, historical));
  await assertCode(
    () => update(updateRequest(missionId, destination)),
    'failed-precondition',
  );
});

test('quota below a confirmed engagement count is refused atomically', async () => {
  const source = unique('source');
  await seedLocation(source);
  const missionId = await seedMission(source, {
    registeredByProfession: quotas(0, 0),
    registeredMk: 0,
  });
  await db.collection('engagements').doc(unique('engagement')).set({
    missionId,
    mobilizationId: activeMobilizationId,
    volunteerId: unique('volunteer'),
    profession: 'mk',
    status: 'confirmed',
  });
  const user = await createUser(coordinatorRole());
  const update = await callable(user);
  await assertCode(() => update(updateRequest(missionId, source, {
    requiredByProfession: quotas(0, 1),
  })), 'failed-precondition');
  assert.equal((await db.collection('missions').doc(missionId).get())
    .data().requiredMk, 2);
});

test('two concurrent valid updates both complete with last validated write wins', async () => {
  const source = unique('source');
  await seedLocation(source);
  const missionId = await seedMission(source);
  const user = await createUser(coordinatorRole());
  const update = await callable(user);
  const first = updateRequest(missionId, source, {details: 'Concurrent A'});
  const second = updateRequest(missionId, source, {details: 'Concurrent B'});
  const results = await Promise.allSettled([update(first), update(second)]);
  assert.equal(results.every((result) => result.status === 'fulfilled'), true);
  assert.ok(['Concurrent A', 'Concurrent B'].includes(
    (await db.collection('missions').doc(missionId).get()).data().details,
  ));
});
