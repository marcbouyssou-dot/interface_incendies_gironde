import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  writeBatch,
  Timestamp,
  serverTimestamp,
} from 'firebase/firestore';
import {readFileSync} from 'node:fs';

let env;
const projectId = 'demo-interface-recup';

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: readFileSync('../firestore.rules', 'utf8'),
    },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

const db = (uid) => uid
  ? env.authenticatedContext(uid).firestore()
  : env.unauthenticatedContext().firestore();

async function seed(extra = {}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'locations/site-a'), {
      id: 'site-a', name: 'Site A', group: 'medoc', type: 'sdisStation',
      isActive: true,
    });
    await setDoc(doc(admin, 'roles/coord'), {
      role: 'coordinator', locationIds: ['*'], active: true,
    });
    await setDoc(doc(admin, 'roles/manager'), {
      role: 'site_manager', locationIds: ['site-a'], active: true,
    });
    if (extra.mission !== false) {
      await setDoc(doc(admin, 'missions/mission-a'), mission());
    }
  });
}

function mission(overrides = {}) {
  return {
    id: 'mission-a',
    locationId: 'site-a',
    locationName: 'Site A',
    territorialGroup: 'medoc',
    startAt: Timestamp.fromDate(new Date('2026-08-01T08:00:00Z')),
    endAt: Timestamp.fromDate(new Date('2026-08-01T12:00:00Z')),
    requiredMk: 2,
    requiredPp: 1,
    registeredMk: 0,
    registeredPp: 0,
    requestedEquipment: ['Tables'],
    details: '',
    status: 'critical',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    isActive: true,
    createdBy: 'coord',
    ...overrides,
  };
}

function volunteer(uid, overrides = {}) {
  return {
    uid, profession: 'mk', firstName: 'A', lastName: 'B', phone: '0600000000',
    equipment: [], createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    ...overrides,
  };
}

async function engage(uid, profession = 'mk', missionChanges = {}) {
  const userDb = db(uid);
  const batch = writeBatch(userDb);
  batch.set(doc(userDb, `volunteers/${uid}`), volunteer(uid, {profession}));
  batch.set(doc(userDb, `engagements/mission-a_${uid}`), {
    missionId: 'mission-a', volunteerId: uid, profession,
    createdAt: Timestamp.now(), status: 'confirmed',
  });
  const counters = profession === 'mk'
    ? {registeredMk: 1, registeredPp: 0, status: 'critical'}
    : {registeredMk: 0, registeredPp: 1, status: 'critical'};
  batch.update(doc(userDb, 'missions/mission-a'), {
    ...counters, updatedAt: Timestamp.now(), ...missionChanges,
  });
  return batch.commit();
}

async function disengage(uid, profession = 'mk', missionChanges = {}) {
  const userDb = db(uid);
  const batch = writeBatch(userDb);
  batch.delete(doc(userDb, `engagements/mission-a_${uid}`));
  const counters = profession === 'mk'
    ? {registeredMk: 0, registeredPp: 0, status: 'critical'}
    : {registeredMk: 0, registeredPp: 0, status: 'critical'};
  batch.update(doc(userDb, 'missions/mission-a'), {
    ...counters, updatedAt: Timestamp.now(), ...missionChanges,
  });
  return batch.commit();
}

async function cancelMission(uid, changes = {}) {
  return updateDoc(doc(db(uid), 'missions/mission-a'), {
    status: 'cancelled',
    isActive: false,
    cancelledAt: serverTimestamp(),
    cancelledBy: uid,
    cancellationReason: 'Vent violent',
    updatedAt: serverTimestamp(),
    ...changes,
  });
}

test('locations: public read allowed, all writes denied', async () => {
  await seed();
  assert.equal((await assertSucceeds(getDoc(doc(db(), 'locations/site-a')))).exists(), true);
  await assertFails(setDoc(doc(db('u'), 'locations/new'), {name: 'x'}));
  await assertFails(updateDoc(doc(db('u'), 'locations/site-a'), {name: 'x'}));
  await assertFails(deleteDoc(doc(db('u'), 'locations/site-a')));
});

test('missions: public active read and anonymous create denied', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(db(), 'missions/mission-a')));
  await assertFails(setDoc(doc(db(), 'missions/new'), mission({id: 'new'})));
});

test('missions: coordinator and authorized manager create', async () => {
  await seed({mission: false});
  await assertSucceeds(setDoc(doc(db('coord'), 'missions/c1'), mission({id: 'c1'})));
  await assertSucceeds(setDoc(doc(db('manager'), 'missions/m1'), mission({
    id: 'm1', createdBy: 'manager',
  })));
});

test('missions: invalid manager, quotas, counters, dates and extra fields denied', async () => {
  await seed({mission: false});
  await assertFails(setDoc(doc(db('manager'), 'missions/x1'), mission({
    id: 'x1', createdBy: 'manager', locationId: 'other',
  })));
  await assertFails(setDoc(doc(db('coord'), 'missions/x2'), mission({
    id: 'x2', requiredMk: 0, requiredPp: 0,
  })));
  await assertFails(setDoc(doc(db('coord'), 'missions/x3'), mission({
    id: 'x3', registeredMk: 1,
  })));
  await assertFails(setDoc(doc(db('coord'), 'missions/x4'), mission({
    id: 'x4', endAt: Timestamp.fromDate(new Date('2026-08-01T07:00:00Z')),
  })));
  await assertFails(setDoc(doc(db('coord'), 'missions/x5'), mission({
    id: 'x5', secret: true,
  })));
});

test('volunteers: owner create/update/read; other access denied', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db('alice'), 'volunteers/alice'), volunteer('alice')));
  await assertSucceeds(updateDoc(doc(db('alice'), 'volunteers/alice'), {phone: '0611111111'}));
  await assertSucceeds(getDoc(doc(db('alice'), 'volunteers/alice')));
  await assertFails(getDoc(doc(db('bob'), 'volunteers/alice')));
  await assertFails(updateDoc(doc(db('bob'), 'volunteers/alice'), {phone: 'x'}));
});

test('volunteers: invalid profession and extra field denied', async () => {
  await seed();
  await assertFails(setDoc(doc(db('alice'), 'volunteers/alice'), volunteer('alice', {profession: 'doctor'})));
  await assertFails(setDoc(doc(db('alice'), 'volunteers/alice'), volunteer('alice', {admin: true})));
});

test('engagements: atomic MK and PP increments allowed', async () => {
  await seed();
  await assertSucceeds(engage('alice'));
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
      registeredMk: 0, registeredPp: 0, status: 'critical',
    });
  });
  await assertSucceeds(engage('bob', 'pp'));
});

test('engagements: wrong owner/profession/id denied', async () => {
  await seed();
  const userDb = db('alice');
  const batch = writeBatch(userDb);
  batch.set(doc(userDb, 'engagements/mission-a_bob'), {
    missionId: 'mission-a', volunteerId: 'bob', profession: 'doctor',
    createdAt: Timestamp.now(), status: 'confirmed',
  });
  batch.update(doc(userDb, 'missions/mission-a'), {
    registeredMk: 1, status: 'toComplete', updatedAt: Timestamp.now(),
  });
  await assertFails(batch.commit());
});

test('engagements: duplicate, update and delete denied', async () => {
  await seed();
  await assertSucceeds(engage('alice'));
  await assertFails(engage('alice'));
  await assertFails(updateDoc(doc(db('alice'), 'engagements/mission-a_alice'), {status: 'cancelled'}));
  await assertFails(deleteDoc(doc(db('alice'), 'engagements/mission-a_alice')));
});

test('disengagement: owner with exact MK decrement allowed', async () => {
  await seed();
  await engage('alice');
  await assertSucceeds(disengage('alice'));
  await env.withSecurityRulesDisabled(async (context) => {
    assert.equal(
      (await getDoc(doc(context.firestore(), 'engagements/mission-a_alice'))).exists(),
      false,
    );
  });
});

test('disengagement: other owner, missing/wrong/excess decrement denied', async () => {
  await seed();
  await engage('alice');
  await assertFails(deleteDoc(doc(db('bob'), 'engagements/mission-a_alice')));
  await assertFails(deleteDoc(doc(db('alice'), 'engagements/mission-a_alice')));
  await assertFails(disengage('alice', 'mk', {registeredMk: 1}));
  await assertFails(disengage('alice', 'mk', {registeredPp: -1}));
  await assertFails(disengage('alice', 'mk', {registeredMk: -1}));
});

test('disengagement: exact PP decrement allowed', async () => {
  await seed();
  await engage('alice', 'pp');
  await assertSucceeds(disengage('alice', 'pp'));
});

test('mission cancellation: coordinator and authorized manager allowed', async () => {
  await seed();
  await assertSucceeds(cancelMission('coord'));
  await seed();
  await assertSucceeds(cancelMission('manager'));
});

test('mission cancellation: unauthorized, quota mutation and reactivation denied', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'roles/other'), {
      role: 'site_manager', locationIds: ['other-site'], active: true,
    });
  });
  await assertFails(cancelMission('other'));
  await assertFails(cancelMission('coord', {requiredMk: 9}));
  await assertSucceeds(cancelMission('coord'));
  await assertFails(updateDoc(doc(db('coord'), 'missions/mission-a'), {
    status: 'critical', isActive: true, updatedAt: serverTimestamp(),
  }));
});

test('engagement on a cancelled mission is denied and existing engagement stays', async () => {
  await seed();
  await engage('alice');
  await cancelMission('coord');
  await assertFails(engage('bob'));
  await env.withSecurityRulesDisabled(async (context) => {
    assert.equal(
      (await getDoc(doc(context.firestore(), 'engagements/mission-a_alice'))).exists(),
      true,
    );
  });
});

test('counters: mismatched, +2, both, over quota, other field, and direct update denied', async () => {
  await seed();
  await assertFails(engage('alice', 'mk', {registeredPp: 1}));
  await assertFails(engage('alice', 'mk', {registeredMk: 2}));
  await assertFails(engage('alice', 'mk', {registeredMk: 1, registeredPp: 1}));
  await assertFails(engage('alice', 'mk', {details: 'changed'}));
  await assertFails(updateDoc(doc(db('alice'), 'missions/mission-a'), {
    registeredMk: 1, status: 'critical', updatedAt: Timestamp.now(),
  }));
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
      registeredMk: 2, status: 'toComplete',
    });
  });
  await assertFails(engage('alice', 'mk', {registeredMk: 3}));
});

test('roles: own get allowed; other get and all writes denied', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(db('coord'), 'roles/coord')));
  await assertFails(getDoc(doc(db('coord'), 'roles/manager')));
  await assertFails(setDoc(doc(db('coord'), 'roles/new'), {role: 'coordinator'}));
  await assertFails(updateDoc(doc(db('coord'), 'roles/coord'), {active: false}));
  await assertFails(deleteDoc(doc(db('coord'), 'roles/coord')));
});
