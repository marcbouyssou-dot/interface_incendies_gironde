import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';

import {
  deleteApp as deleteAdminApp,
  initializeApp as initializeAdminApp,
} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore} from 'firebase-admin/firestore';
import {userDisplayIdentityServices} from '../../src/index.js';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'identity-emulator-tests');
const adminAuth = getAdminAuth(adminApp);
const db = getAdminFirestore(adminApp);
let sequence = 0;
const services = userDisplayIdentityServices({firestore: db, auth: adminAuth});

function unique(prefix) {
  sequence += 1;
  return `${prefix}-${process.pid}-${sequence}`;
}

async function createUser({role, platformAdministrator = false} = {}) {
  const uid = unique('user');
  const email = `${uid}@example.test`;
  const password = 'Test-only-password-42!';
  await adminAuth.createUser({
    uid,
    email,
    password,
    displayName: `Nom ${uid}`,
  });
  if (role) await db.collection('roles').doc(uid).set(role);
  if (platformAdministrator) {
    await db.collection('platformAdministrators').doc(uid).set({active: true});
  }
  return {uid, email, password};
}

async function assertCode(action, code) {
  await assert.rejects(action, (error) => {
    assert.equal(error.code, code);
    return true;
  });
}

const coordinatorRole = {
  role: 'coordinator',
  roles: ['coordinator'],
  locationIds: [],
  active: true,
  schemaVersion: 2,
};

const managerRole = (locationId) => ({
  role: 'site_manager',
  roles: ['site_manager'],
  locationIds: [locationId],
  active: true,
  schemaVersion: 2,
});

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  await db.collection('platform').doc('config').set({
    activeMobilizationId: 'mobilization-identity-test',
  });
  await db.collection('mobilizations').doc('mobilization-identity-test').set({
    id: 'mobilization-identity-test',
    territoryId: 'gironde',
    status: 'active',
  });
  await db.collection('missions').doc('mission-identity-test').set({
    id: 'mission-identity-test',
    mobilizationId: 'mobilization-identity-test',
    locationId: 'merignac',
    isActive: true,
  });
  await db.collection('volunteers').doc('volunteer-identity-test').set({
    uid: 'volunteer-identity-test',
    firstName: 'Marc',
    lastName: 'BOUYSSOU',
    profession: 'physiotherapist',
    phone: '0600000000',
    email: 'secret@example.test',
    rpps: '12345678901',
  });
  await db.collection('engagements').doc(
    'mission-identity-test_volunteer-identity-test',
  ).set({
    missionId: 'mission-identity-test',
    mobilizationId: 'mobilization-identity-test',
    volunteerId: 'volunteer-identity-test',
    profession: 'physiotherapist',
    status: 'confirmed',
  });
});

after(async () => {
  await deleteAdminApp(adminApp);
});

test('only the responsible perimeter receives the minimal team identity', async () => {
  const authorized = await createUser({role: managerRole('merignac')});
  const outside = await createUser({role: managerRole('langon')});
  const response = await services.listMissionTeam({
    callerUid: authorized.uid,
    missionId: 'mission-identity-test',
  });
  const member = response[0];

  assert.equal(member.displayName, 'Marc BOUYSSOU');
  assert.equal(member.professionLabel, 'Masseur-Kinésithérapeute');
  assert.equal(Object.hasOwn(member, 'phone'), false);
  assert.equal(Object.hasOwn(member, 'email'), false);
  assert.equal(Object.hasOwn(member, 'rpps'), false);

  await assertCode(
    () => services.listMissionTeam({
      callerUid: outside.uid,
      missionId: 'mission-identity-test',
    }),
    'permission-denied',
  );
});

test('legacy coordinator team access stops after an explicit assignment', async () => {
  const coordinator = await createUser({role: coordinatorRole});

  const legacyTeam = await services.listMissionTeam({
    callerUid: coordinator.uid,
    missionId: 'mission-identity-test',
  });
  assert.equal(legacyTeam.length, 1);

  const assignedMobilizationId = unique('assigned-mobilization');
  const assignedMissionId = unique('assigned-mission');
  await Promise.all([
    db.collection('mobilizations').doc(assignedMobilizationId).set({
      id: assignedMobilizationId,
      territoryId: 'gironde',
      status: 'active',
    }),
    db.collection('missions').doc(assignedMissionId).set({
      id: assignedMissionId,
      mobilizationId: assignedMobilizationId,
      locationId: 'langon',
      isActive: true,
    }),
    db.collection('mobilizationAssignments')
      .doc(`${assignedMobilizationId}_${coordinator.uid}`)
      .set({
        uid: coordinator.uid,
        mobilizationId: assignedMobilizationId,
        role: 'coordinator',
        active: true,
      }),
    db.collection('roles').doc(coordinator.uid).update({
      hasActiveMobilizationAssignments: true,
    }),
  ]);

  await assertCode(
    () => services.listMissionTeam({
      callerUid: coordinator.uid,
      missionId: 'mission-identity-test',
    }),
    'permission-denied',
  );
  const assignedTeam = await services.listMissionTeam({
    callerUid: coordinator.uid,
    missionId: assignedMissionId,
  });
  assert.deepEqual(assignedTeam, []);
});

test('only a platform administrator resolves coordinator names', async () => {
  const coordinator = await createUser({role: coordinatorRole});
  const administrator = await createUser({platformAdministrator: true});
  const manager = await createUser({role: managerRole('merignac')});
  const response = await services.listPlatformCoordinators({
    callerUid: administrator.uid,
  });
  const identity = response.find(
    (candidate) => candidate.uid === coordinator.uid,
  );

  assert.equal(identity.displayName, `Nom ${coordinator.uid}`);
  assert.equal(identity.professionLabel, 'Coordinateur');
  assert.equal(identity.organizationLabel, 'Périmètre départemental');
  await assertCode(
    () => services.listPlatformCoordinators({callerUid: manager.uid}),
    'permission-denied',
  );
});
