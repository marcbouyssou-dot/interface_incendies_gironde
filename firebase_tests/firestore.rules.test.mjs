import assert from 'node:assert/strict';
import {after, before, beforeEach, test} from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  doc,
  collection,
  getDoc,
  getDocs,
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
    await setDoc(doc(admin, 'locations/site-b'), {
      id: 'site-b', name: 'Site B', group: 'libournais', type: 'sdisStation',
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
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    status: 'pending',
  });
  if (Object.keys(missionChanges).length > 0) {
    batch.update(doc(userDb, 'missions/mission-a'), {
      ...missionChanges, updatedAt: serverTimestamp(),
    });
  }
  return batch.commit();
}

async function updateEngagement(uid, volunteerUid, status, missionChanges) {
  const userDb = db(uid);
  const batch = writeBatch(userDb);
  batch.update(doc(userDb, `engagements/mission-a_${volunteerUid}`), {
    status, updatedAt: serverTimestamp(),
  });
  if (missionChanges) {
    batch.update(doc(userDb, 'missions/mission-a'), {
      ...missionChanges, updatedAt: serverTimestamp(),
    });
  }
  return batch.commit();
}

async function reengage(uid, profession = 'mk', engagementChanges = {}) {
  const userDb = db(uid);
  const batch = writeBatch(userDb);
  batch.set(doc(userDb, `volunteers/${uid}`), volunteer(uid, {profession}));
  batch.update(doc(userDb, `engagements/mission-a_${uid}`), {
    status: 'pending',
    profession,
    updatedAt: serverTimestamp(),
    ...engagementChanges,
  });
  return batch.commit();
}

async function seedEngagement(uid, status, profession = 'mk') {
  await env.withSecurityRulesDisabled(async (context) => {
    const data = {
      missionId: 'mission-a', volunteerId: uid, profession,
      createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
    };
    if (status !== undefined) data.status = status;
    await setDoc(doc(context.firestore(), `engagements/mission-a_${uid}`), data);
  });
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
  await assertSucceeds(setDoc(doc(db('coord'), 'missions/c2'), mission({
    id: 'c2', locationId: 'site-b', locationName: 'Site B',
  })));
  await assertSucceeds(setDoc(doc(db('manager'), 'missions/m1'), mission({
    id: 'm1', createdBy: 'manager',
  })));
});

test('missions: invalid manager, quotas, counters, dates and extra fields denied', async () => {
  await seed({mission: false});
  await assertFails(setDoc(doc(db('manager'), 'missions/x1'), mission({
    id: 'x1', createdBy: 'manager', locationId: 'site-b',
    locationName: 'Site B',
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

test('engagements: owner creation in pending allowed for MK and PP', async () => {
  await seed();
  await assertSucceeds(engage('alice'));
  await assertSucceeds(engage('bob', 'pp'));
});

test('engagements: owner can get its missing deterministic document', async () => {
  await seed();
  const snapshot = await assertSucceeds(
    getDoc(doc(db('alice'), 'engagements/mission-a_alice')),
  );
  assert.equal(snapshot.exists(), false);
});

test('engagements: owner can get its existing deterministic document', async () => {
  await seed();
  await assertSucceeds(engage('alice'));
  const snapshot = await assertSucceeds(
    getDoc(doc(db('alice'), 'engagements/mission-a_alice')),
  );
  assert.equal(snapshot.exists(), true);
});

test('engagements: other users cannot get existing or missing documents', async () => {
  await seed();
  await assertSucceeds(engage('bob'));
  await assertFails(
    getDoc(doc(db('alice'), 'engagements/mission-a_bob')),
  );
  await assertFails(
    getDoc(doc(db('alice'), 'engagements/mission-b_bob')),
  );
});

test('engagements: owner cannot get a non-deterministic legacy document', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'engagements/legacy-document'), {
      missionId: 'mission-a',
      volunteerId: 'alice',
      profession: 'mk',
      createdAt: Timestamp.now(),
    });
  });
  await assertFails(
    getDoc(doc(db('alice'), 'engagements/legacy-document')),
  );
});

test('engagements: deterministic id cannot bypass an inconsistent owner field', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'engagements/mission-a_alice'),
      {
        missionId: 'mission-a',
        volunteerId: 'bob',
        profession: 'mk',
        status: 'pending',
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      },
    );
  });
  await assertFails(
    getDoc(doc(db('alice'), 'engagements/mission-a_alice')),
  );
});

test('engagements: volunteers cannot list engagements', async () => {
  await seed();
  await assertSucceeds(engage('alice'));
  await assertFails(getDocs(collection(db('alice'), 'engagements')));
});

test('engagements: unauthenticated users cannot get missing documents', async () => {
  await seed();
  await assertFails(
    getDoc(doc(db(), 'engagements/mission-a_alice')),
  );
});

test('engagements: coordinator keeps get and list access', async () => {
  await seed();
  await assertSucceeds(engage('alice'));
  const snapshot = await assertSucceeds(
    getDoc(doc(db('coord'), 'engagements/mission-a_alice')),
  );
  assert.equal(snapshot.exists(), true);
  const querySnapshot = await assertSucceeds(
    getDocs(collection(db('coord'), 'engagements')),
  );
  assert.equal(querySnapshot.size, 1);
});

test('engagements: pending creation succeeds after an allowed missing get', async () => {
  await seed();
  const userDb = db('alice');
  const missionBefore = (await assertSucceeds(
    getDoc(doc(userDb, 'missions/mission-a')),
  )).data();
  const missing = await assertSucceeds(
    getDoc(doc(userDb, 'engagements/mission-a_alice')),
  );
  assert.equal(missing.exists(), false);

  await assertSucceeds(engage('alice'));

  const engagement = (await assertSucceeds(
    getDoc(doc(userDb, 'engagements/mission-a_alice')),
  )).data();
  const missionAfter = (await assertSucceeds(
    getDoc(doc(userDb, 'missions/mission-a')),
  )).data();
  assert.equal(engagement.status, 'pending');
  assert.equal(
    missionAfter.registeredMk,
    missionBefore.registeredMk,
  );
  assert.equal(
    missionAfter.registeredPp,
    missionBefore.registeredPp,
  );
});

test('engagements: pending creation remains allowed at reached quota', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
      registeredMk: 2,
      registeredPp: 1,
      status: 'complete',
    });
  });
  await assertSucceeds(engage('alice'));
  await assertSucceeds(engage('bob', 'pp'));
});

test('engagements: creation on an ended mission is denied', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
      endAt: Timestamp.fromMillis(Date.now() - 1000),
    });
  });
  await assertFails(engage('alice'));
});

test('engagements: direct confirmed creation denied', async () => {
  await seed();
  const userDb = db('alice');
  const batch = writeBatch(userDb);
  batch.set(doc(userDb, 'volunteers/alice'), volunteer('alice'));
  batch.set(doc(userDb, 'engagements/mission-a_alice'), {
    missionId: 'mission-a', volunteerId: 'alice', profession: 'mk',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    status: 'confirmed',
  });
  await assertFails(batch.commit());
});

test('engagements: old status-less document remains readable by owner', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'engagements/mission-a_alice'), {
      missionId: 'mission-a', volunteerId: 'alice', profession: 'mk',
      createdAt: Timestamp.now(),
    });
  });
  const snapshot = await assertSucceeds(
    getDoc(doc(db('alice'), 'engagements/mission-a_alice')),
  );
  assert.equal(snapshot.data().status, undefined);
});

test('engagements: owner cannot confirm or move itself to standby', async () => {
  await seed();
  await engage('alice');
  await assertFails(updateEngagement('alice', 'alice', 'confirmed', {
    registeredMk: 1, status: 'critical',
  }));
  await assertFails(updateEngagement('alice', 'alice', 'standby'));
});

test('engagements: owner cancellation is allowed and immutable fields stay protected', async () => {
  await seed();
  await engage('alice');
  await assertSucceeds(updateEngagement('alice', 'alice', 'cancelled'));
  await assertFails(updateDoc(doc(db('alice'), 'engagements/mission-a_alice'), {
    profession: 'pp', status: 'cancelled', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateEngagement('alice', 'alice', 'cancelled'));
});

test('engagements: cancelled owner can reengage pending without mission counters', async () => {
  await seed();
  await seedEngagement('alice', 'cancelled');
  let createdAt;
  let missionBefore;
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'volunteers/alice'), volunteer('alice'));
    createdAt = (await getDoc(
      doc(admin, 'engagements/mission-a_alice'),
    )).data().createdAt;
    missionBefore = (await getDoc(doc(admin, 'missions/mission-a'))).data();
  });

  await assertSucceeds(reengage('alice', 'pp'));

  const engagement = (await getDoc(
    doc(db('alice'), 'engagements/mission-a_alice'),
  )).data();
  const missionAfter = (await getDoc(
    doc(db('alice'), 'missions/mission-a'),
  )).data();
  assert.equal(engagement.status, 'pending');
  assert.equal(engagement.profession, 'pp');
  assert.equal(engagement.createdAt.toMillis(), createdAt.toMillis());
  assert.equal(missionAfter.registeredMk, missionBefore.registeredMk);
  assert.equal(missionAfter.registeredPp, missionBefore.registeredPp);
});

test('engagements: only cancelled may transition back to pending', async () => {
  for (const status of ['pending', 'confirmed', 'standby', undefined]) {
    await seed();
    await seedEngagement('alice', status);
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'volunteers/alice'), volunteer('alice'));
    });
    await assertFails(reengage('alice'));
  }
});

test('engagements: reengagement protects identity and creation fields', async () => {
  for (const changes of [
    {volunteerId: 'bob'},
    {missionId: 'mission-other'},
    {createdAt: serverTimestamp()},
  ]) {
    await seed();
    await seedEngagement('alice', 'cancelled');
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), 'volunteers/alice'), volunteer('alice'));
    });
    await assertFails(reengage('alice', 'mk', changes));
  }
});

test('engagements: authorized coordinator transitions are allowed', async () => {
  await seed();
  await seedEngagement('alice', 'pending');
  await assertSucceeds(updateEngagement('coord', 'alice', 'confirmed', {
    registeredMk: 1, status: 'critical',
  }));
  await assertSucceeds(updateEngagement('coord', 'alice', 'standby', {
    registeredMk: 0, status: 'critical',
  }));
  await assertSucceeds(updateEngagement('coord', 'alice', 'cancelled'));
});

test('engagements: manager outside mission perimeter is denied', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'roles/outside'), {
      role: 'site_manager', locationIds: ['site-b'], active: true,
    });
  });
  await seedEngagement('alice', 'pending');
  await assertFails(updateEngagement('outside', 'alice', 'standby'));
});

test('engagements: coordinator cannot change identity or profession', async () => {
  await seed();
  await seedEngagement('alice', 'pending');
  await assertFails(updateDoc(doc(db('coord'), 'engagements/mission-a_alice'), {
    status: 'standby', profession: 'pp', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db('coord'), 'engagements/mission-a_alice'), {
    status: 'standby', volunteerId: 'coord', updatedAt: serverTimestamp(),
  }));
});

test('engagements: legacy status-less document can move to standby and cancelled', async () => {
  for (const target of ['standby', 'cancelled']) {
    await seed();
    await seedEngagement('alice', undefined);
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
        registeredMk: 1, status: 'critical',
      });
    });
    await assertSucceeds(updateEngagement('coord', 'alice', target, {
      registeredMk: 0, status: 'critical',
    }));
  }
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

test('engagements: duplicate and delete denied', async () => {
  await seed();
  await assertSucceeds(engage('alice'));
  await assertFails(engage('alice'));
  await assertFails(deleteDoc(doc(db('alice'), 'engagements/mission-a_alice')));
});

test('disengagement: confirmed owner has exact MK decrement', async () => {
  await seed();
  await seedEngagement('alice', 'confirmed');
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
      registeredMk: 1, status: 'critical',
    });
  });
  await assertSucceeds(updateEngagement('alice', 'alice', 'cancelled', {
    registeredMk: 0, status: 'critical',
  }));
});

test('disengagement: other owner and wrong counter effects denied', async () => {
  await seed();
  await seedEngagement('alice', 'confirmed');
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
      registeredMk: 1, status: 'critical',
    });
  });
  await assertFails(updateEngagement('bob', 'alice', 'cancelled', {
    registeredMk: 0, status: 'critical',
  }));
  await assertFails(updateEngagement('alice', 'alice', 'cancelled'));
  await assertFails(updateEngagement('alice', 'alice', 'cancelled', {
    registeredMk: 1, status: 'critical',
  }));
});

test('disengagement: confirmed owner has exact PP decrement', async () => {
  await seed();
  await seedEngagement('alice', 'confirmed', 'pp');
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
      registeredPp: 1, status: 'critical',
    });
  });
  await assertSucceeds(updateEngagement('alice', 'alice', 'cancelled', {
    registeredPp: 0, status: 'critical',
  }));
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
