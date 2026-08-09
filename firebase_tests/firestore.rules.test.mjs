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
  query,
  where,
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
const blankLocationIdVectors = [
  '\u0009', '\u000A', '\u000B', '\u000C', '\u000D', '\u0020', '\u0085',
  '\u00A0', '\u1680', '\u2000', '\u2001', '\u2002', '\u2003', '\u2004',
  '\u2005', '\u2006', '\u2007', '\u2008', '\u2009', '\u200A', '\u2028',
  '\u2029', '\u202F', '\u205F', '\u3000', '\uFEFF',
];
const hourInMilliseconds = 60 * 60 * 1000;
const missionStartDelayInHours = 24;
const missionDurationInHours = 4;
const activeMobilizationId = 'incendies-gironde-2026';

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
    await setDoc(doc(admin, 'platform/config'), {
      activeMobilizationId,
    });
    await setDoc(doc(admin, `mobilizations/${activeMobilizationId}`), {
      id: activeMobilizationId,
      territoryId: 'gironde',
      status: 'active',
    });
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

async function seedRole(uid, data) {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), `roles/${uid}`), data);
  });
}

function legacyRole(role, locationIds, active = true) {
  return {
    role,
    ...(locationIds === undefined ? {} : {locationIds}),
    active,
  };
}

function v2Role(roles, locationIds, overrides = {}) {
  return {
    role: roles.includes('coordinator') ? 'coordinator' : 'site_manager',
    roles,
    locationIds,
    active: true,
    schemaVersion: 2,
    ...overrides,
  };
}

async function createMissionFor(uid, id, locationId = 'site-a') {
  return setDoc(
    doc(db(uid), `missions/${id}`),
    mission({
      id,
      locationId,
      locationName: locationId === 'site-a' ? 'Site A' : 'Site B',
      createdBy: uid,
    }),
  );
}

function mission(overrides = {}) {
  const startAt = Timestamp.fromMillis(
    Date.now() + missionStartDelayInHours * hourInMilliseconds,
  );
  return {
    id: 'mission-a',
    mobilizationId: activeMobilizationId,
    locationId: 'site-a',
    locationName: 'Site A',
    territorialGroup: 'medoc',
    startAt,
    endAt: Timestamp.fromMillis(
      startAt.toMillis() + missionDurationInHours * hourInMilliseconds,
    ),
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

const emptyQuotas = () => ({
  physiotherapist: 0,
  podiatrist: 0,
  physician: 0,
  nurse: 0,
  veterinarian: 0,
  other_health_professional: 0,
});

function genericMission(overrides = {}) {
  return mission({
    requiredMk: 0,
    requiredPp: 0,
    registeredMk: 0,
    registeredPp: 0,
    requiredByProfession: {
      ...emptyQuotas(),
      physician: 1,
    },
    registeredByProfession: emptyQuotas(),
    ...overrides,
  });
}

function canonicalProfession(value) {
  if (value === 'mk' || value === 'physiotherapist') return 'physiotherapist';
  if (value === 'pp' || value === 'podiatrist') return 'podiatrist';
  if (value === 'doctor' || value === 'physician') return 'physician';
  if (value === 'nurse') return 'nurse';
  if (value === 'veterinarian') return 'veterinarian';
  if (
    value === 'otherHealthProfessional'
    || value === 'other_health_professional'
  ) return 'other_health_professional';
  return value;
}

function volunteer(uid, overrides = {}) {
  return {
    uid, profession: 'mk', firstName: 'A', lastName: 'B', phone: '0600000000',
    email: 'a@example.fr', rpps: '10123456789',
    professionalIdType: 'rpps', professionalIdValue: '10123456789',
    cptsId: 'cpts-medoc', cptsLabel: 'CPTS Médoc',
    verificationStatus: 'unverified',
    equipment: [], createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function verifiedVolunteer(uid, overrides = {}) {
  return volunteer(uid, {
    verificationStatus: 'verified',
    verificationSource: 'ans_rpps',
    verifiedFirstName: 'Alice',
    verifiedLastName: 'EXEMPLE',
    verifiedProfessionCode: '70',
    verifiedProfessionLabel: 'Masseur-Kinésithérapeute',
    verifiedAt: Timestamp.now(),
    ...overrides,
  });
}

async function engage(
  uid,
  profession = 'mk',
  missionChanges = {},
  writeVolunteer = true,
) {
  const userDb = db(uid);
  const missionSnapshot = await getDoc(doc(userDb, 'missions/mission-a'));
  const missionData = missionSnapshot.data();
  const volunteerSnapshot = await getDoc(doc(userDb, `volunteers/${uid}`));
  const registeredMk = missionData.registeredMk + (profession === 'mk' ? 1 : 0);
  const registeredPp = missionData.registeredPp + (profession === 'pp' ? 1 : 0);
  const canonical = canonicalProfession(profession);
  const registeredByProfession = missionData.registeredByProfession
    ? {
        ...missionData.registeredByProfession,
        [canonical]: (missionData.registeredByProfession[canonical] ?? 0) + 1,
      }
    : undefined;
  const batch = writeBatch(userDb);
  if (writeVolunteer) {
    batch.set(doc(userDb, `volunteers/${uid}`), {
      ...volunteer(uid, {profession}),
      ...(volunteerSnapshot.exists()
        ? {createdAt: volunteerSnapshot.data().createdAt}
        : {}),
      updatedAt: serverTimestamp(),
    });
  }
  batch.set(doc(userDb, `engagements/mission-a_${uid}`), {
    missionId: 'mission-a', mobilizationId: activeMobilizationId,
    volunteerId: uid, profession,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    status: 'confirmed',
  });
  batch.update(doc(userDb, 'missions/mission-a'), {
    registeredMk,
    registeredPp,
    ...(registeredByProfession ? {registeredByProfession} : {}),
    status: expectedStatus({
      ...missionData,
      registeredMk,
      registeredPp,
      ...(registeredByProfession ? {registeredByProfession} : {}),
    }),
    ...missionChanges,
    updatedAt: serverTimestamp(),
  });
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
  const missionSnapshot = await getDoc(doc(userDb, 'missions/mission-a'));
  const missionData = missionSnapshot.data();
  const volunteerSnapshot = await getDoc(doc(userDb, `volunteers/${uid}`));
  const volunteerData = volunteerSnapshot.data();
  const registeredMk = missionData.registeredMk + (profession === 'mk' ? 1 : 0);
  const registeredPp = missionData.registeredPp + (profession === 'pp' ? 1 : 0);
  const batch = writeBatch(userDb);
  batch.set(doc(userDb, `volunteers/${uid}`), {
    ...volunteer(uid, {profession}),
    createdAt: volunteerData.createdAt,
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(userDb, `engagements/mission-a_${uid}`), {
    status: 'confirmed',
    profession,
    updatedAt: serverTimestamp(),
    ...engagementChanges,
  });
  batch.update(doc(userDb, 'missions/mission-a'), {
    registeredMk,
    registeredPp,
    status: expectedStatus({
      ...missionData,
      registeredMk,
      registeredPp,
    }),
    updatedAt: serverTimestamp(),
  });
  return batch.commit();
}

function expectedStatus(data) {
  const required = data.requiredByProfession
    ? Object.values(data.requiredByProfession).reduce((sum, value) => sum + value, 0)
    : data.requiredMk + data.requiredPp;
  const registered = data.registeredByProfession
    ? Object.values(data.registeredByProfession).reduce(
        (sum, value) => sum + value,
        0,
      )
    : data.registeredMk + data.registeredPp;
  const covered = data.requiredByProfession
    ? Object.keys(data.requiredByProfession).every(
        (profession) =>
          (data.registeredByProfession?.[profession] ?? 0)
            >= data.requiredByProfession[profession],
      )
    : data.registeredMk >= data.requiredMk
      && data.registeredPp >= data.requiredPp;
  if (covered) return 'complete';
  return registered * 2 < required
    ? 'critical'
    : 'toComplete';
}

async function seedEngagement(uid, status, profession = 'mk') {
  await env.withSecurityRulesDisabled(async (context) => {
    const data = {
      missionId: 'mission-a', mobilizationId: activeMobilizationId,
      volunteerId: uid, profession,
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

test('missions: active mobilization is mandatory for create and list', async () => {
  await seed();
  const missing = mission({id: 'missing-mobilization'});
  delete missing.mobilizationId;
  await assertFails(setDoc(
    doc(db('coord'), 'missions/missing-mobilization'),
    missing,
  ));
  await assertFails(setDoc(
    doc(db('coord'), 'missions/other-mobilization'),
    mission({
      id: 'other-mobilization',
      mobilizationId: 'another-mobilization',
    }),
  ));
  const snapshot = await assertSucceeds(getDocs(query(
    collection(db(), 'missions'),
    where('mobilizationId', '==', activeMobilizationId),
    where('isActive', '==', true),
  )));
  assert.equal(snapshot.size, 1);
  await assertFails(getDocs(collection(db(), 'missions')));
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
  const invalidDatesMission = mission({id: 'x4'});
  invalidDatesMission.endAt = Timestamp.fromMillis(
    invalidDatesMission.startAt.toMillis() - hourInMilliseconds,
  );
  await assertFails(setDoc(
    doc(db('coord'), 'missions/x4'),
    invalidDatesMission,
  ));
  await assertFails(setDoc(doc(db('coord'), 'missions/x5'), mission({
    id: 'x5', secret: true,
  })));
});

test('missions: legacy and valid generic quota documents are allowed', async () => {
  await seed({mission: false});
  await assertSucceeds(setDoc(
    doc(db('coord'), 'missions/legacy'),
    mission({id: 'legacy'}),
  ));
  await assertSucceeds(setDoc(
    doc(db('coord'), 'missions/generic'),
    genericMission({
      id: 'generic',
      requiredByProfession: {
        ...emptyQuotas(),
        veterinarian: 1,
      },
    }),
  ));
});

test('missions: generic maps reject unknown, negative and decimal values', async () => {
  await seed({mission: false});
  await assertFails(setDoc(
    doc(db('coord'), 'missions/unknown'),
    genericMission({
      id: 'unknown',
      requiredByProfession: {
        ...emptyQuotas(),
        unknown: 1,
      },
    }),
  ));
  await assertFails(setDoc(
    doc(db('coord'), 'missions/negative'),
    genericMission({
      id: 'negative',
      requiredByProfession: {
        ...emptyQuotas(),
        physician: -1,
      },
    }),
  ));
  await assertFails(setDoc(
    doc(db('coord'), 'missions/decimal'),
    genericMission({
      id: 'decimal',
      requiredByProfession: {
        ...emptyQuotas(),
        physician: 1.5,
      },
    }),
  ));
});

test('missions: generic registered quota cannot exceed required quota', async () => {
  await seed({mission: false});
  await assertFails(setDoc(
    doc(db('coord'), 'missions/over-quota'),
    genericMission({
      id: 'over-quota',
      registeredByProfession: {
        ...emptyQuotas(),
        physician: 2,
      },
    }),
  ));
});

test('missions: generic maps must remain synchronized with legacy MK PP', async () => {
  await seed({mission: false});
  for (const [id, changes] of [
    ['required-mk', {requiredMk: 1}],
    ['required-pp', {requiredPp: 1}],
    ['registered-mk', {
      requiredMk: 1,
      registeredMk: 1,
    }],
    ['registered-pp', {
      requiredPp: 1,
      registeredPp: 1,
    }],
  ]) {
    await assertFails(setDoc(
      doc(db('coord'), `missions/${id}`),
      genericMission({id, ...changes}),
    ));
  }
});

test('missions: volunteer cannot modify required or registered generic quotas', async () => {
  await seed();
  await assertFails(updateDoc(doc(db('alice'), 'missions/mission-a'), {
    requiredByProfession: {
      ...emptyQuotas(),
      physiotherapist: 2,
    },
    registeredByProfession: emptyQuotas(),
    updatedAt: serverTimestamp(),
  }));
});

test('volunteers: owner create/update/read; other access denied', async () => {
  await seed();
  await assertSucceeds(setDoc(doc(db('alice'), 'volunteers/alice'), volunteer('alice')));
  await assertSucceeds(updateDoc(doc(db('alice'), 'volunteers/alice'), {
    phone: '0611111111', updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(getDoc(doc(db('alice'), 'volunteers/alice')));
  await assertFails(getDoc(doc(db('bob'), 'volunteers/alice')));
  await assertFails(updateDoc(doc(db('bob'), 'volunteers/alice'), {phone: 'x'}));
});

test('volunteers: a client cannot forge a verified profile', async () => {
  await seed();
  await assertFails(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    verifiedVolunteer('alice'),
  ));
});

test('volunteers: an incomplete or incoherent verified block is denied', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'volunteers/alice'),
      verifiedVolunteer('alice'),
    );
  });
  await assertFails(updateDoc(doc(db('alice'), 'volunteers/alice'), {
    verifiedProfessionLabel: '',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db('alice'), 'volunteers/alice'), {
    verifiedProfessionCode: '10',
    updatedAt: serverTimestamp(),
  }));
});

test('volunteers: verification is preserved or invalidated with identity changes', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'volunteers/alice'),
      verifiedVolunteer('alice'),
    );
  });
  await assertSucceeds(updateDoc(doc(db('alice'), 'volunteers/alice'), {
    phone: '0611111111',
    updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db('alice'), 'volunteers/alice'), {
    verificationStatus: 'unverified',
    verificationSource: null,
    updatedAt: serverTimestamp(),
  }));
  const replacement = volunteer('alice', {
    professionalIdValue: '10987654321',
    rpps: '10987654321',
    createdAt: (await getDoc(doc(db('alice'), 'volunteers/alice'))).data().createdAt,
  });
  await assertSucceeds(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    replacement,
  ));
});

test('volunteers: modular professional IDs and legacy RPPS are accepted', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'volunteers/legacy'), {
      uid: 'legacy',
      profession: 'mk',
      firstName: 'Legacy',
      lastName: 'Profile',
      phone: '0600000000',
      equipment: [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });
  await assertSucceeds(getDoc(doc(db('legacy'), 'volunteers/legacy')));

  await assertSucceeds(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    volunteer('alice'),
  ));
  const ordinal = volunteer('bob', {
    professionalIdType: 'ordinal',
    professionalIdValue: 'ORD-123',
  });
  delete ordinal.rpps;
  delete ordinal.cptsId;
  delete ordinal.cptsLabel;
  await assertSucceeds(setDoc(
    doc(db('bob'), 'volunteers/bob'),
    ordinal,
  ));
  const noId = volunteer('charlie', {
    professionalIdType: 'none',
    professionalIdValue: '',
    cptsId: '',
    cptsLabel: '',
    otherEquipmentDetails: 'Sac de soin',
  });
  delete noId.rpps;
  await assertSucceeds(setDoc(
    doc(db('charlie'), 'volunteers/charlie'),
    noId,
  ));
  const legacyWrite = volunteer('legacy-write');
  delete legacyWrite.professionalIdType;
  delete legacyWrite.professionalIdValue;
  delete legacyWrite.cptsId;
  delete legacyWrite.cptsLabel;
  await assertSucceeds(setDoc(
    doc(db('legacy-write'), 'volunteers/legacy-write'),
    legacyWrite,
  ));
});

test('volunteers: invalid professional identifiers are denied', async () => {
  await seed();
  await assertFails(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    volunteer('alice', {professionalIdType: 'unknown'}),
  ));
  await assertFails(setDoc(
    doc(db('bob'), 'volunteers/bob'),
    volunteer('bob', {
      rpps: '123',
      professionalIdValue: '123',
    }),
  ));
  const emptyOrdinal = volunteer('charlie', {
    professionalIdType: 'ordinal',
    professionalIdValue: '',
  });
  delete emptyOrdinal.rpps;
  await assertFails(setDoc(
    doc(db('charlie'), 'volunteers/charlie'),
    emptyOrdinal,
  ));
  const nonEmptyNone = volunteer('diane', {
    professionalIdType: 'none',
    professionalIdValue: 'unexpected',
  });
  delete nonEmptyNone.rpps;
  await assertFails(setDoc(
    doc(db('diane'), 'volunteers/diane'),
    nonEmptyNone,
  ));
  await assertFails(setDoc(
    doc(db('eve'), 'volunteers/eve'),
    volunteer('eve', {professionalIdValue: '10987654321'}),
  ));
  await assertFails(setDoc(
    doc(db('frank'), 'volunteers/frank'),
    volunteer('frank', {otherEquipmentDetails: 42}),
  ));
});

test('volunteers: other equipment requires non-empty details', async () => {
  await seed();
  await assertFails(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    volunteer('alice', {equipment: ['Autre matériel']}),
  ));
  await assertFails(setDoc(
    doc(db('bob'), 'volunteers/bob'),
    volunteer('bob', {
      equipment: ['Autre matériel'],
      otherEquipmentDetails: '',
    }),
  ));
  await assertSucceeds(setDoc(
    doc(db('charlie'), 'volunteers/charlie'),
    volunteer('charlie', {
      equipment: ['Autre matériel'],
      otherEquipmentDetails: 'Coussin ergonomique',
    }),
  ));
});

test('volunteers: CPTS identifiers and labels remain paired', async () => {
  await seed();
  const missingLabel = volunteer('alice', {cptsId: 'cpts-medoc'});
  delete missingLabel.cptsLabel;
  await assertFails(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    missingLabel,
  ));
  const missingId = volunteer('bob', {cptsLabel: 'CPTS Médoc'});
  delete missingId.cptsId;
  await assertFails(setDoc(
    doc(db('bob'), 'volunteers/bob'),
    missingId,
  ));
});

test('volunteers: createdAt is immutable and updatedAt must be server time', async () => {
  await seed();
  await assertSucceeds(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    volunteer('alice'),
  ));
  await assertFails(updateDoc(doc(db('alice'), 'volunteers/alice'), {
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
  await assertFails(updateDoc(doc(db('alice'), 'volunteers/alice'), {
    phone: '0611111111', updatedAt: Timestamp.now(),
  }));
});

test('volunteers: all profile professions allowed and unknown/extra denied', async () => {
  await seed();
  for (const profession of [
    'mk', 'pp', 'doctor', 'nurse', 'veterinarian',
    'otherHealthProfessional',
  ]) {
    const uid = `profile-${profession}`;
    await assertSucceeds(setDoc(
      doc(db(uid), `volunteers/${uid}`),
      volunteer(uid, {profession}),
    ));
  }
  await assertFails(setDoc(doc(db('alice'), 'volunteers/alice'), volunteer('alice', {profession: 'unknown'})));
  await assertFails(setDoc(doc(db('alice'), 'volunteers/alice'), volunteer('alice', {admin: true})));
});

test('engagements: owner creation confirms and increments MK and PP', async () => {
  await seed();
  await assertSucceeds(engage('alice'));
  await assertSucceeds(engage('bob', 'pp'));
  const adminDb = db('coord');
  assert.equal(
    (await getDoc(doc(adminDb, 'engagements/mission-a_alice'))).data().status,
    'confirmed',
  );
  assert.equal(
    (await getDoc(doc(adminDb, 'engagements/mission-a_bob'))).data().status,
    'confirmed',
  );
  const storedMission = (await getDoc(
    doc(adminDb, 'missions/mission-a'),
  )).data();
  assert.equal(storedMission.registeredMk, 1);
  assert.equal(storedMission.registeredPp, 1);
  assert.equal(storedMission.status, 'toComplete');
});

test('engagements: canonical non-legacy professions are allowed', async () => {
  for (const profession of [
    'physician',
    'nurse',
    'veterinarian',
    'other_health_professional',
  ]) {
    await seed({mission: false});
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'missions/mission-a'),
        genericMission({
          requiredByProfession: {
            ...emptyQuotas(),
            [profession]: 1,
          },
        }),
      );
    });
    await assertSucceeds(setDoc(
      doc(db(`user-${profession}`), `volunteers/user-${profession}`),
      volunteer(`user-${profession}`, {profession}),
    ));
    await assertSucceeds(engage(`user-${profession}`, profession, {}, false));
  }
});

test('engagements: unknown profession is denied', async () => {
  await seed({mission: false});
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'missions/mission-a'),
      genericMission({
        requiredByProfession: {
          ...emptyQuotas(),
          physician: 1,
        },
      }),
    );
  });
  await assertFails(engage('unknown-user', 'unknown'));
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
      mobilizationId: activeMobilizationId,
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
        mobilizationId: activeMobilizationId,
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
    getDocs(query(
      collection(db('coord'), 'engagements'),
      where('mobilizationId', '==', activeMobilizationId),
    )),
  );
  assert.equal(querySnapshot.size, 1);
});

test('engagements: confirmed creation succeeds after an allowed missing get', async () => {
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
  assert.equal(engagement.status, 'confirmed');
  assert.equal(
    missionAfter.registeredMk,
    missionBefore.registeredMk + 1,
  );
  assert.equal(
    missionAfter.registeredPp,
    missionBefore.registeredPp,
  );
});

test('engagements: creation is denied when the profession quota is reached', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
      registeredMk: 2,
      registeredPp: 1,
      status: 'complete',
    });
  });
  await assertFails(engage('alice'));
  await assertFails(engage('bob', 'pp'));
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

test('engagements: confirmed creation without mission increment is denied', async () => {
  await seed();
  const userDb = db('alice');
  const batch = writeBatch(userDb);
  batch.set(doc(userDb, 'volunteers/alice'), volunteer('alice'));
  batch.set(doc(userDb, 'engagements/mission-a_alice'), {
    missionId: 'mission-a', mobilizationId: activeMobilizationId,
    volunteerId: 'alice', profession: 'mk',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    status: 'confirmed',
  });
  await assertFails(batch.commit());
});

test('engagements: mobilization must match the mission and active context', async () => {
  await seed();
  const userDb = db('alice');
  const batch = writeBatch(userDb);
  batch.set(doc(userDb, 'volunteers/alice'), volunteer('alice'));
  batch.set(doc(userDb, 'engagements/mission-a_alice'), {
    missionId: 'mission-a',
    mobilizationId: 'another-mobilization',
    volunteerId: 'alice',
    profession: 'mk',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    status: 'confirmed',
  });
  batch.update(doc(userDb, 'missions/mission-a'), {
    registeredMk: 1,
    status: 'critical',
    updatedAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
});

test('engagements: new pending creation is denied', async () => {
  await seed();
  const userDb = db('alice');
  const batch = writeBatch(userDb);
  batch.set(doc(userDb, 'volunteers/alice'), volunteer('alice'));
  batch.set(doc(userDb, 'engagements/mission-a_alice'), {
    missionId: 'mission-a', mobilizationId: activeMobilizationId,
    volunteerId: 'alice', profession: 'mk',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    status: 'pending',
  });
  batch.update(doc(userDb, 'missions/mission-a'), {
    registeredMk: 1,
    status: 'critical',
    updatedAt: serverTimestamp(),
  });
  await assertFails(batch.commit());
});

test('engagements: old status-less document remains readable by owner', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'engagements/mission-a_alice'), {
      missionId: 'mission-a', mobilizationId: activeMobilizationId,
      volunteerId: 'alice', profession: 'mk',
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
  await assertSucceeds(updateEngagement('alice', 'alice', 'cancelled', {
    registeredMk: 0,
    status: 'critical',
  }));
  await assertFails(updateDoc(doc(db('alice'), 'engagements/mission-a_alice'), {
    profession: 'pp', status: 'cancelled', updatedAt: serverTimestamp(),
  }));
  await assertFails(updateEngagement('alice', 'alice', 'cancelled'));
});

test('engagements: cancelled owner reengages confirmed with exact counter', async () => {
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
  assert.equal(engagement.status, 'confirmed');
  assert.equal(engagement.profession, 'pp');
  assert.equal(engagement.createdAt.toMillis(), createdAt.toMillis());
  assert.equal(missionAfter.registeredMk, missionBefore.registeredMk);
  assert.equal(
    missionAfter.registeredPp,
    missionBefore.registeredPp + 1,
  );
});

test('engagements: historical pending can be confirmed by its owner', async () => {
  await seed();
  await seedEngagement('alice', 'pending');
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'volunteers/alice'), volunteer('alice'));
  });

  await assertSucceeds(reengage('alice'));

  const engagement = (await getDoc(
    doc(db('alice'), 'engagements/mission-a_alice'),
  )).data();
  const storedMission = (await getDoc(
    doc(db('alice'), 'missions/mission-a'),
  )).data();
  assert.equal(engagement.status, 'confirmed');
  assert.equal(storedMission.registeredMk, 1);
  assert.equal(storedMission.registeredPp, 0);
});

test('engagements: active or legacy confirmed cannot reactivate', async () => {
  for (const status of ['confirmed', 'standby', undefined]) {
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
    missionId: 'mission-a', mobilizationId: activeMobilizationId,
    volunteerId: 'bob', profession: 'doctor',
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

test('mission cancellation: only the mission creator is allowed', async () => {
  await seed();
  await assertSucceeds(cancelMission('coord'));
  await seed();
  await assertFails(cancelMission('manager'));
  await env.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), 'missions/mission-a'), {
      createdBy: 'manager',
    });
  });
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

function adminInvitation(overrides = {}) {
  return {
    email: 'responsable@example.fr',
    displayName: 'Responsable Exemple',
    role: 'site_manager',
    locationIds: ['site-a'],
    createdBy: 'coord',
    createdAt: serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 7 * 24 * 60 * 60 * 1000),
    status: 'pending',
    acceptedAt: null,
    ...overrides,
  };
}

test('admin invitations: coordinator creates, reads and cancels', async () => {
  await seed();
  const reference = 'adminInvitations/invitation-a';
  await assertSucceeds(
    setDoc(doc(db('coord'), reference), adminInvitation()),
  );
  await assertSucceeds(getDoc(doc(db('coord'), reference)));
  await assertSucceeds(getDocs(collection(db('coord'), 'adminInvitations')));
  await assertSucceeds(
    updateDoc(doc(db('coord'), reference), {status: 'cancelled'}),
  );
  await assertSucceeds(
    setDoc(
      doc(db('coord'), 'adminInvitations/coordinator-invitation'),
      adminInvitation({role: 'coordinator', locationIds: []}),
    ),
  );
});

test('admin invitations: manager, volunteer and anonymous have no access', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'adminInvitations/invitation-a'),
      adminInvitation({createdAt: Timestamp.now()}),
    );
  });
  await assertFails(
    setDoc(
      doc(db('manager'), 'adminInvitations/manager-invitation'),
      adminInvitation({createdBy: 'manager'}),
    ),
  );
  await assertFails(getDoc(doc(db('manager'), 'adminInvitations/invitation-a')));
  await assertFails(getDoc(doc(db('alice'), 'adminInvitations/invitation-a')));
  await assertFails(getDoc(doc(db(), 'adminInvitations/invitation-a')));
});

test('admin invitations: protected creation fields are enforced', async () => {
  await seed();
  const collectionName = 'adminInvitations';
  await assertFails(
    setDoc(
      doc(db('coord'), `${collectionName}/accepted`),
      adminInvitation({status: 'accepted'}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('coord'), `${collectionName}/wrong-author`),
      adminInvitation({createdBy: 'other'}),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(db('coord'), `${collectionName}/coordinator-role`),
      adminInvitation({role: 'coordinator', locationIds: []}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('coord'), `${collectionName}/no-location`),
      adminInvitation({locationIds: []}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('coord'), `${collectionName}/coordinator-with-location`),
      adminInvitation({role: 'coordinator', locationIds: ['site-a']}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('coord'), `${collectionName}/unknown-role`),
      adminInvitation({role: 'administrator', locationIds: []}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('coord'), `${collectionName}/server-fields`),
      adminInvitation({
        acceptedUid: 'target',
        provisionedAt: serverTimestamp(),
        activationLinkGeneratedAt: serverTimestamp(),
      }),
    ),
  );
});

test('admin invitations: malformed emails are refused', async () => {
  await seed();
  for (const [index, email] of [
    'invalid',
    'a@b',
    '@example.fr',
    'a@example',
    'a b@example.fr',
    'user@example .com',
    'user@@example.com',
    'user@',
  ].entries()) {
    await assertFails(
      setDoc(
        doc(db('coord'), `adminInvitations/invalid-email-${index}`),
        adminInvitation({email}),
      ),
    );
  }
  const acceptedBoundaryEmail = `${'a'.repeat(243)}@example.com`;
  const refusedBoundaryEmail = `${'a'.repeat(244)}@example.com`;
  assert.equal(acceptedBoundaryEmail.length, 255);
  assert.equal(refusedBoundaryEmail.length, 256);
  await assertSucceeds(
    setDoc(
      doc(db('coord'), 'adminInvitations/email-255'),
      adminInvitation({email: ` ${acceptedBoundaryEmail} `}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('coord'), 'adminInvitations/email-256'),
      adminInvitation({email: refusedBoundaryEmail}),
    ),
  );
  for (const [index, email] of [
    'a@b.c',
    'user@example.com',
    ' user@example.com',
    'user@example.com ',
    ' user@example.com ',
    'user..name@example.com',
    'user+tag@example.com',
    'USER@example.com',
    'utilisateur@exemple.fr',
  ].entries()) {
    const idPrefix = 'valid-email-';
    const invitationId = `${idPrefix}${index}`;
    await assertSucceeds(
      setDoc(
        doc(db('coord'), `adminInvitations/${invitationId}`),
        adminInvitation({email}),
      ),
    );
    const snapshot = await assertSucceeds(
      getDoc(doc(db('coord'), `adminInvitations/${invitationId}`)),
    );
    assert.equal(snapshot.data().email, email);
  }
});

test('admin invitations: every canonical Unicode blank display name is refused', async () => {
  await seed();
  for (const [index, displayName] of blankLocationIdVectors.entries()) {
    await assertFails(
      setDoc(
        doc(db('coord'), `adminInvitations/blank-display-name-${index}`),
        adminInvitation({displayName}),
      ),
    );
  }
});

test('admin invitations: valid display names are preserved exactly', async () => {
  await seed();
  for (const [index, displayName] of [
    ' Marc ',
    'Marc',
    'Marc Bouyssou',
    '👨‍⚕️ Marc',
  ].entries()) {
    const invitationId = `valid-display-name-${index}`;
    await assertSucceeds(
      setDoc(
        doc(db('coord'), `adminInvitations/${invitationId}`),
        adminInvitation({displayName}),
      ),
    );
    const snapshot = await assertSucceeds(
      getDoc(doc(db('coord'), `adminInvitations/${invitationId}`)),
    );
    assert.equal(snapshot.data().displayName, displayName);
  }
});

test('admin invitations: multiple and exactly 65 locations are allowed', async () => {
  await seed();
  await assertSucceeds(
    setDoc(
      doc(db('coord'), 'adminInvitations/multiple-locations'),
      adminInvitation({locationIds: ['site-a', 'site-b']}),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(db('coord'), 'adminInvitations/sixty-five-locations'),
      adminInvitation({
        locationIds: Array.from({length: 65}, (_, index) => `site-${index}`),
      }),
    ),
  );
});

test('admin invitations: more than 65 locations are refused', async () => {
  await seed();
  await assertFails(
    setDoc(
      doc(db('coord'), 'adminInvitations/sixty-six-locations'),
      adminInvitation({
        locationIds: Array.from({length: 66}, (_, index) => `site-${index}`),
      }),
    ),
  );
});

test('admin invitations: missing locationIds is refused', async () => {
  await seed();
  const invitation = adminInvitation();
  delete invitation.locationIds;
  await assertFails(
    setDoc(
      doc(db('coord'), 'adminInvitations/missing-locations'),
      invitation,
    ),
  );
});

test('admin invitations: non-list locationIds is refused', async () => {
  await seed();
  await assertFails(
    setDoc(
      doc(db('coord'), 'adminInvitations/non-list-locations'),
      adminInvitation({locationIds: 'site-a'}),
    ),
  );
});

for (const [label, locationIds] of [
  ['empty-location', ['']],
  ['single-space-location', [' ']],
  ['blank-location', ['   ']],
  ['tab-location', ['\t']],
  ['newline-location', ['\n']],
  ['carriage-return-location', ['\r']],
  ['mixed-whitespace-location', ['\t \n']],
  ['non-string-location', ['site-a', 42]],
  ['duplicate-location', ['site-a', 'site-a']],
  ['wildcard-location', ['*']],
  ['separator-location', ['site-a\u001fsite-b']],
]) {
  test(`admin invitations: ${label} is refused`, async () => {
    await seed();
    await assertFails(
      setDoc(
        doc(db('coord'), `adminInvitations/${label}`),
        adminInvitation({locationIds}),
      ),
    );
  });
}

test('admin invitations: every canonical Unicode blank is refused', async () => {
  await seed();
  for (const [index, locationId] of blankLocationIdVectors.entries()) {
    await assertFails(
      setDoc(
        doc(db('coord'), `adminInvitations/unicode-blank-${index}`),
        adminInvitation({locationIds: [locationId]}),
      ),
    );
  }
});

test('admin invitations: peripheral spaces and partial wildcard are preserved', async () => {
  await seed();
  await assertSucceeds(
    setDoc(
      doc(db('coord'), 'adminInvitations/peripheral-spaces'),
      adminInvitation({
        locationIds: [
          ' site-a', 'site-a ', ' site-a ', 'site a', 'site-a', 'Site-a',
          'site-a*',
          '\u00A0site-a', 'site-a\u0085',
          '\u0000', '\u001E', '\u007F', String.raw`\u001F`,
          '\u00E9', 'e\u0301', '\u2217', ' * ',
        ],
      }),
    ),
  );
});

test('admin invitations: role and location scope remain coherent', async () => {
  await seed();
  await assertFails(
    setDoc(
      doc(db('coord'), 'adminInvitations/coordinator-scoped'),
      adminInvitation({role: 'coordinator', locationIds: ['site-a']}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('coord'), 'adminInvitations/manager-empty'),
      adminInvitation({locationIds: []}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('coord'), 'adminInvitations/unknown-role'),
      adminInvitation({role: 'administrator', locationIds: []}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('coord'), 'adminInvitations/unsupported-cumulative-role'),
      adminInvitation({
        roles: ['coordinator', 'site_manager'],
        locationIds: ['site-a'],
      }),
    ),
  );
});

test('admin invitations: role and locations cannot be mutated later', async () => {
  await seed();
  const reference = 'adminInvitations/immutable-scope';
  await assertSucceeds(
    setDoc(doc(db('coord'), reference), adminInvitation()),
  );
  await assertFails(
    updateDoc(doc(db('coord'), reference), {
      status: 'cancelled',
      locationIds: ['site-b'],
    }),
  );
  await assertFails(
    updateDoc(doc(db('coord'), reference), {
      status: 'cancelled',
      role: 'coordinator',
    }),
  );
  await assertFails(
    updateDoc(doc(db('coord'), reference), {
      status: 'cancelled',
      unexpected: true,
    }),
  );
});

test('admin invitations: client cannot accept, mutate identity or delete', async () => {
  await seed();
  const reference = 'adminInvitations/invitation-a';
  await assertSucceeds(
    setDoc(doc(db('coord'), reference), adminInvitation()),
  );
  await assertFails(
    updateDoc(doc(db('coord'), reference), {
      status: 'accepted',
      acceptedAt: serverTimestamp(),
      acceptedUid: 'target',
      provisionedAt: serverTimestamp(),
      activationLinkGeneratedAt: serverTimestamp(),
    }),
  );
  await assertFails(
    updateDoc(doc(db('coord'), reference), {
      status: 'cancelled',
      email: 'other@example.fr',
    }),
  );
  await assertFails(deleteDoc(doc(db('coord'), reference)));
});

test('roles dual-read: valid legacy scopes keep their exact permissions', async () => {
  await seed({mission: false});
  await seedRole('coord-no-scope', legacyRole('coordinator', undefined));
  await seedRole('coord-empty', legacyRole('coordinator', []));
  await seedRole(
    'manager-multi',
    legacyRole('site_manager', ['site-a', 'site-b']),
  );

  await assertSucceeds(createMissionFor('coord', 'legacy-wildcard', 'site-b'));
  await assertSucceeds(
    createMissionFor('coord-no-scope', 'legacy-no-scope', 'site-b'),
  );
  await assertSucceeds(createMissionFor('coord-empty', 'legacy-empty', 'site-b'));
  await assertSucceeds(createMissionFor('manager', 'legacy-single', 'site-a'));
  await assertSucceeds(
    createMissionFor('manager-multi', 'legacy-multi', 'site-b'),
  );
  await assertFails(createMissionFor('manager', 'legacy-outside', 'site-b'));
});

test('roles dual-read: invalid and inactive legacy documents deny access', async () => {
  await seed({mission: false});
  const cases = [
    ['legacy-empty-manager', legacyRole('site_manager', [])],
    ...blankLocationIdVectors.map((locationId, index) => [
      `legacy-unicode-blank-${index}`,
      legacyRole('site_manager', [locationId]),
    ]),
    ['legacy-space-manager', legacyRole('site_manager', [' '])],
    ['legacy-blank-manager', legacyRole('site_manager', ['   '])],
    ['legacy-tab-manager', legacyRole('site_manager', ['\t'])],
    ['legacy-newline-manager', legacyRole('site_manager', ['\n'])],
    ['legacy-carriage-return-manager', legacyRole('site_manager', ['\r'])],
    ['legacy-mixed-whitespace-manager', legacyRole('site_manager', ['\t \n'])],
    ['legacy-wildcard-manager', legacyRole('site_manager', ['*'])],
    ['legacy-unknown', legacyRole('administrator', [])],
    ['legacy-inactive', legacyRole('coordinator', ['*'], false)],
  ];

  for (const [uid, roleData] of cases) {
    await seedRole(uid, roleData);
    await assertFails(createMissionFor(uid, `mission-${uid}`));
  }
});

test('roles dual-read: valid V2 roles enforce coordinator priority', async () => {
  await seed({mission: false});
  await seedRole('v2-coord', v2Role(['coordinator'], []));
  await seedRole('v2-manager', v2Role(['site_manager'], ['site-a']));
  await seedRole(
    'v2-manager-multi',
    v2Role(['site_manager'], ['site-a', 'site-b']),
  );
  await seedRole(
    'v2-cumulative',
    v2Role(['coordinator', 'site_manager'], ['site-a']),
  );

  await assertSucceeds(createMissionFor('v2-coord', 'v2-global', 'site-b'));
  await assertSucceeds(createMissionFor('v2-manager', 'v2-local', 'site-a'));
  await assertFails(createMissionFor('v2-manager', 'v2-outside', 'site-b'));
  await assertSucceeds(
    createMissionFor('v2-manager-multi', 'v2-multi-local', 'site-b'),
  );
  await assertSucceeds(
    createMissionFor('v2-cumulative', 'v2-cumulative-global', 'site-b'),
  );
  const roleSnapshot = await assertSucceeds(
    getDoc(doc(db('v2-cumulative'), 'roles/v2-cumulative')),
  );
  assert.deepEqual(roleSnapshot.data().roles, ['coordinator', 'site_manager']);
});

test('roles dual-read: invalid V2 role lists never fall back to role', async () => {
  await seed({mission: false});
  const missingSchema = v2Role(['coordinator'], []);
  delete missingSchema.schemaVersion;
  const cases = [
    ['v2-roles-type', v2Role('coordinator', [])],
    ['v2-empty-roles', v2Role([], [])],
    ['v2-duplicate', v2Role(['coordinator', 'coordinator'], [])],
    [
      'v2-order',
      v2Role(['site_manager', 'coordinator'], ['site-a']),
    ],
    ['v2-unknown', v2Role(['unknown'], ['site-a'])],
    [
      'v2-non-string-role',
      v2Role(['coordinator', 42], []),
    ],
    ['v2-missing-schema', missingSchema],
    ['v2-wrong-schema', v2Role(['coordinator'], [], {schemaVersion: 3})],
    [
      'v2-wrong-projection',
      v2Role(['coordinator', 'site_manager'], ['site-a'], {
        role: 'site_manager',
      }),
    ],
  ];

  for (const [uid, roleData] of cases) {
    await seedRole(uid, roleData);
    await assertFails(createMissionFor(uid, `mission-${uid}`));
  }
});

test('roles dual-read: invalid V2 fields and scopes deny all privilege', async () => {
  await seed({mission: false});
  const missingActive = v2Role(['coordinator'], []);
  delete missingActive.active;
  const missingLocationIds = v2Role(['site_manager'], ['site-a']);
  delete missingLocationIds.locationIds;
  const cases = [
    ['v2-active-missing', missingActive],
    [
      'v2-active-type',
      v2Role(['coordinator'], [], {active: 'true'}),
    ],
    ['v2-location-missing', missingLocationIds],
    [
      'v2-location-type',
      v2Role(['site_manager'], 'site-a'),
    ],
    [
      'v2-location-item-type',
      v2Role(['site_manager'], ['site-a', 42]),
    ],
    [
      'v2-location-duplicate',
      v2Role(['site_manager'], ['site-a', 'site-a']),
    ],
    ...blankLocationIdVectors.map((locationId, index) => [
      `v2-location-unicode-blank-${index}`,
      v2Role(['site_manager'], [locationId]),
    ]),
    ['v2-location-space', v2Role(['site_manager'], [' '])],
    ['v2-location-blank', v2Role(['site_manager'], ['   '])],
    ['v2-location-tab', v2Role(['site_manager'], ['\t'])],
    ['v2-location-newline', v2Role(['site_manager'], ['\n'])],
    ['v2-location-carriage-return', v2Role(['site_manager'], ['\r'])],
    ['v2-location-mixed-whitespace', v2Role(['site_manager'], ['\t \n'])],
    ['v2-wildcard', v2Role(['site_manager'], ['*'])],
    ['v2-coordinator-scoped', v2Role(['coordinator'], ['site-a'])],
    ['v2-manager-empty', v2Role(['site_manager'], [])],
    [
      'v2-cumulative-empty',
      v2Role(['coordinator', 'site_manager'], []),
    ],
  ];

  for (const [uid, roleData] of cases) {
    await seedRole(uid, roleData);
    await assertFails(createMissionFor(uid, `mission-${uid}`));
  }
});

test('roles dual-read: peripheral spaces and partial wildcard stay exact', async () => {
  await seed({mission: false});
  const locationIds = [
    ' site-a', 'site-a ', ' site-a ', 'site a', 'site-a', 'Site-a', 'site-a*',
    '\u00A0site-a', 'site-a\u0085',
    '\u0000', '\u001E', '\u007F', String.raw`\u001F`,
    '\u00E9', 'e\u0301', '\u2217', ' * ',
  ];

  for (const [index, locationId] of locationIds.entries()) {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `locations/${locationId}`), {
        id: locationId,
        name: locationId,
        group: 'medoc',
        type: 'sdisStation',
        isActive: true,
      });
    });
    const v2Uid = `v2-exact-location-${index}`;
    const legacyUid = `legacy-exact-location-${index}`;
    await seedRole(v2Uid, v2Role(['site_manager'], [locationId]));
    await seedRole(legacyUid, legacyRole('site_manager', [locationId]));
    await assertSucceeds(
      createMissionFor(v2Uid, `mission-v2-exact-location-${index}`, locationId),
    );
    await assertSucceeds(
      createMissionFor(
        legacyUid,
        `mission-legacy-exact-location-${index}`,
        locationId,
      ),
    );
  }
});

test('roles dual-read: V2 invitation access remains coordinator-only', async () => {
  await seed();
  await seedRole('v2-coord', v2Role(['coordinator'], []));
  await seedRole('v2-manager', v2Role(['site_manager'], ['site-a']));
  await seedRole(
    'v2-cumulative',
    v2Role(['coordinator', 'site_manager'], ['site-a']),
  );

  await assertSucceeds(
    setDoc(
      doc(db('v2-coord'), 'adminInvitations/v2-coord'),
      adminInvitation({createdBy: 'v2-coord'}),
    ),
  );
  await assertFails(
    setDoc(
      doc(db('v2-manager'), 'adminInvitations/v2-manager'),
      adminInvitation({createdBy: 'v2-manager'}),
    ),
  );
  await assertSucceeds(
    setDoc(
      doc(db('v2-cumulative'), 'adminInvitations/v2-cumulative'),
      adminInvitation({createdBy: 'v2-cumulative'}),
    ),
  );
});

test('roles dual-read: V2 coordinators retain engagement administration', async () => {
  await seed();
  await seedRole('v2-coord', v2Role(['coordinator'], []));
  await seedRole('v2-manager', v2Role(['site_manager'], ['site-a']));
  await seedRole(
    'v2-cumulative',
    v2Role(['coordinator', 'site_manager'], ['site-a']),
  );
  await seedEngagement('alice', 'pending');
  await seedEngagement('bob', 'pending');

  await assertSucceeds(
    getDoc(doc(db('v2-coord'), 'engagements/mission-a_alice')),
  );
  await assertSucceeds(getDocs(query(
    collection(db('v2-coord'), 'engagements'),
    where('mobilizationId', '==', activeMobilizationId),
  )));
  await assertFails(
    getDoc(doc(db('v2-manager'), 'engagements/mission-a_alice')),
  );
  await assertSucceeds(
    updateEngagement('v2-coord', 'alice', 'standby'),
  );
  await assertSucceeds(
    updateEngagement('v2-cumulative', 'bob', 'standby'),
  );
  await assertFails(updateEngagement('v2-manager', 'bob', 'cancelled'));
});

test('roles dual-read: own role remains readable but never client-writable', async () => {
  await seed();
  await seedRole('v2-manager', v2Role(['site_manager'], ['site-a']));

  await assertSucceeds(getDoc(doc(db('v2-manager'), 'roles/v2-manager')));
  await assertFails(getDoc(doc(db('v2-manager'), 'roles/coord')));
  await assertFails(
    updateDoc(doc(db('v2-manager'), 'roles/v2-manager'), {
      role: 'coordinator',
      roles: ['coordinator', 'site_manager'],
      schemaVersion: 2,
    }),
  );
  await assertFails(
    setDoc(
      doc(db('alice'), 'roles/alice'),
      v2Role(['coordinator'], []),
    ),
  );
});

test('roles dual-read: inactive cumulative role is denied everywhere', async () => {
  await seed({mission: false});
  await seedRole(
    'v2-inactive',
    v2Role(['coordinator', 'site_manager'], ['site-a'], {active: false}),
  );
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'adminInvitations/inactive'),
      adminInvitation({createdAt: Timestamp.now()}),
    );
    await setDoc(doc(context.firestore(), 'engagements/mission-x_alice'), {
      missionId: 'mission-x',
      mobilizationId: activeMobilizationId,
      volunteerId: 'alice',
      profession: 'mk',
      status: 'pending',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });

  await assertFails(createMissionFor('v2-inactive', 'inactive-mission'));
  await assertFails(
    getDoc(doc(db('v2-inactive'), 'adminInvitations/inactive')),
  );
  await assertFails(
    getDoc(doc(db('v2-inactive'), 'engagements/mission-x_alice')),
  );
  await assertSucceeds(getDoc(doc(db('v2-inactive'), 'roles/v2-inactive')));
});

test('roles dual-read: anonymous professional rights do not open admin data', async () => {
  await seed();
  await assertSucceeds(engage('anonymous-professional'));
  await assertFails(
    getDocs(collection(db('anonymous-professional'), 'adminInvitations')),
  );
  await assertFails(getDocs(collection(db(), 'adminInvitations')));
  await assertFails(getDocs(collection(db(), 'roles')));
});

test('platform V6: only active context metadata is readable when signed in', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'platformAdministrators/platform-admin'), {
      active: true,
    });
    await setDoc(doc(admin, 'territories/gironde'), {
      id: 'gironde',
      name: 'Gironde',
      code: '33',
      active: true,
    });
    await setDoc(doc(admin, 'mobilizations/current'), {
      id: 'current',
      territoryId: 'gironde',
      status: 'draft',
    });
    await setDoc(
      doc(admin, 'mobilizationAssignments/current_coord'),
      {
        uid: 'coord',
        mobilizationId: 'current',
        role: 'coordinator',
        active: true,
      },
    );
  });

  const deniedPaths = [
    'platformAdministrators/platform-admin',
    'territories/gironde',
    'mobilizations/current',
    'mobilizationAssignments/current_coord',
  ];
  for (const uid of [null, 'alice', 'coord', 'platform-admin']) {
    for (const path of deniedPaths) {
      await assertFails(getDoc(doc(db(uid), path)));
      await assertFails(setDoc(doc(db(uid), path), {forged: true}));
      await assertFails(updateDoc(doc(db(uid), path), {forged: true}));
      await assertFails(deleteDoc(doc(db(uid), path)));
    }
  }
  for (const uid of ['alice', 'coord', 'platform-admin']) {
    await assertSucceeds(getDoc(doc(db(uid), 'platform/config')));
    await assertSucceeds(getDoc(
      doc(db(uid), `mobilizations/${activeMobilizationId}`),
    ));
  }
  await assertFails(getDoc(doc(db(), 'platform/config')));
  await assertFails(getDoc(
    doc(db(), `mobilizations/${activeMobilizationId}`),
  ));
  for (const path of [
    'platform/config',
    `mobilizations/${activeMobilizationId}`,
  ]) {
    await assertFails(setDoc(doc(db('coord'), path), {forged: true}));
    await assertFails(updateDoc(doc(db('coord'), path), {forged: true}));
    await assertFails(deleteDoc(doc(db('coord'), path)));
  }
});

test('platform V6: existing V5 permissions remain unchanged', async () => {
  await seed();

  await assertSucceeds(getDoc(doc(db(), 'locations/site-a')));
  await assertSucceeds(getDoc(doc(db(), 'missions/mission-a')));
  await assertSucceeds(createMissionFor('coord', 'v5-compatible'));
  await assertFails(createMissionFor('manager', 'v5-outside', 'site-b'));
  await assertSucceeds(getDoc(doc(db('manager'), 'roles/manager')));
});
