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
  documentId,
  query,
  where,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
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
      port: Number(process.env.FIRESTORE_EMULATOR_PORT ?? 8080),
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
      hasActiveMobilizationAssignments: true,
    });
    await setDoc(
      doc(admin, `mobilizationAssignments/${activeMobilizationId}_coord`),
      {
        uid: 'coord',
        mobilizationId: activeMobilizationId,
        role: 'coordinator',
        active: true,
      },
    );
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
    const admin = context.firestore();
    const roles = Array.isArray(data.roles) ? data.roles : [data.role];
    await setDoc(doc(admin, `roles/${uid}`), {
      ...data,
      ...(roles.includes('coordinator')
        ? {hasActiveMobilizationAssignments: true}
        : {}),
    });
    if (roles.includes('coordinator')) {
      await setDoc(
        doc(admin, `mobilizationAssignments/${activeMobilizationId}_${uid}`),
        {
          uid,
          mobilizationId: activeMobilizationId,
          role: 'coordinator',
          active: true,
        },
      );
    }
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

function organization(id, overrides = {}) {
  return {
    id,
    name: `Organisation ${id}`,
    category: 'other',
    defaultVisibility: 'organization_private',
    active: true,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    schemaVersion: 1,
    ...overrides,
  };
}

function organizationMembership(organizationId, uid, overrides = {}) {
  return {
    organizationId,
    uid,
    roles: ['professional'],
    locationIds: [],
    active: true,
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    schemaVersion: 1,
    ...overrides,
  };
}

async function seedOrganizations() {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'platformAdministrators/platform-admin'), {
      active: true,
    });
    await setDoc(
      doc(admin, 'organizations/organization-a'),
      organization('organization-a'),
    );
    await setDoc(
      doc(admin, 'organizations/organization-b'),
      organization('organization-b'),
    );
    await setDoc(
      doc(admin, 'organizationMemberships/organization-a_member-a'),
      organizationMembership('organization-a', 'member-a', {
        roles: ['organization_admin', 'coordinator'],
      }),
    );
    await setDoc(
      doc(admin, 'organizationMemberships/organization-b_member-b'),
      organizationMembership('organization-b', 'member-b'),
    );
    await setDoc(
      doc(admin, 'organizationMemberships/organization-a_inactive-member'),
      organizationMembership('organization-a', 'inactive-member', {
        active: false,
      }),
    );
  });
}

async function seedOrganizationLocations() {
  await seedOrganizations();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'locations/legacy-implicit'), {
      id: 'legacy-implicit',
      name: 'Site legacy implicite',
      group: 'medoc',
      type: 'sdisStation',
      isActive: true,
      contactName: 'Contact legacy',
      contactPhone: '0600000000',
    });
    await setDoc(doc(admin, 'locations/legacy-explicit'), {
      id: 'legacy-explicit',
      name: 'Site legacy explicite',
      group: 'medoc',
      type: 'sdisStation',
      isActive: true,
      managingOrganizationId: 'legacy-gironde',
    });
    await setDoc(doc(admin, 'locations/site-organization-a'), {
      id: 'site-organization-a',
      name: 'Site organisation A',
      group: 'partnerSites',
      type: 'otherPartnerSite',
      isActive: true,
      managingOrganizationId: 'organization-a',
    });
    await setDoc(doc(admin, 'locations/site-organization-b'), {
      id: 'site-organization-b',
      name: 'Site organisation B',
      group: 'partnerSites',
      type: 'otherPartnerSite',
      isActive: true,
      managingOrganizationId: 'organization-b',
    });
    await setDoc(doc(admin, 'roles/legacy-coordinator'), {
      role: 'coordinator',
      locationIds: ['*'],
      active: true,
    });
    await setDoc(doc(admin, 'roles/legacy-manager'), {
      role: 'site_manager',
      locationIds: ['legacy-implicit'],
      active: true,
    });
  });
}

async function seedMultiOrganizationCore() {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'platform/config'), {activeMobilizationId});
    await setDoc(doc(admin, 'platformAdministrators/platform-admin'), {
      active: true,
    });
    for (const organizationId of [
      'legacy-gironde',
      'organization-a',
      'organization-b',
    ]) {
      await setDoc(
        doc(admin, `organizations/${organizationId}`),
        organization(organizationId),
      );
    }
    for (const [organizationId, uid, overrides] of [
      [
        'organization-a',
        'member-a',
        {roles: ['organization_admin', 'coordinator']},
      ],
      ['organization-b', 'member-b', {}],
      ['organization-a', 'inactive-member', {active: false}],
    ]) {
      await setDoc(
        doc(admin, `organizationMemberships/${organizationId}_${uid}`),
        organizationMembership(organizationId, uid, overrides),
      );
    }
    await setDoc(doc(admin, 'locations/site-a'), {
      id: 'site-a', name: 'Site A', group: 'medoc', type: 'sdisStation',
      isActive: true,
    });
    for (const [operationId, ownerOrganizationId] of [
      ['operation-a', 'organization-a'],
      ['operation-b', 'organization-b'],
      ['operation-legacy', null],
    ]) {
      await setDoc(doc(admin, `operations/${operationId}`), {
        id: operationId,
        name: `Opération ${operationId}`,
        type: 'emergency',
        status: 'active',
        ...(ownerOrganizationId === null ? {} : {ownerOrganizationId}),
      });
    }
    for (const [mobilizationId, operationId] of [
      ['mobilization-a', 'operation-a'],
      ['mobilization-b', 'operation-b'],
      [activeMobilizationId, null],
    ]) {
      await setDoc(doc(admin, `mobilizations/${mobilizationId}`), {
        id: mobilizationId,
        territoryId: 'gironde',
        status: 'active',
        ...(operationId === null ? {} : {operationId}),
      });
    }
    await setDoc(doc(admin, 'roles/member-a'), {
      role: 'coordinator',
      locationIds: ['*'],
      active: true,
      hasActiveMobilizationAssignments: true,
    });
    for (const mobilizationId of ['mobilization-a', 'mobilization-b']) {
      await setDoc(
        doc(admin, `mobilizationAssignments/${mobilizationId}_member-a`),
        {
          uid: 'member-a',
          mobilizationId,
          role: 'coordinator',
          active: true,
        },
      );
    }
    await setDoc(doc(admin, 'roles/legacy-coord'), {
      role: 'coordinator', locationIds: ['*'], active: true,
    });
    await setDoc(doc(admin, 'roles/legacy-manager'), {
      role: 'site_manager', locationIds: ['site-a'], active: true,
    });
    await setDoc(
      doc(admin, 'volunteers/professional'),
      volunteer('professional'),
    );
    for (const [missionId, mobilizationId] of [
      ['mission-org-a', 'mobilization-a'],
      ['mission-org-b', 'mobilization-b'],
      ['mission-legacy', activeMobilizationId],
    ]) {
      await setDoc(doc(admin, `missions/${missionId}`), mission({
        id: missionId,
        mobilizationId,
      }));
      await setDoc(
        doc(admin, `engagements/${missionId}_professional`),
        {
          missionId,
          mobilizationId,
          volunteerId: 'professional',
          profession: 'mk',
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          status: 'confirmed',
        },
      );
    }
  });
}

async function seedOrganizationRoleScope({
  uid,
  organizationId,
  roles,
  locationIds = [],
  active = true,
  seedDocuments = true,
}) {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(
      doc(admin, `organizationMemberships/${organizationId}_${uid}`),
      organizationMembership(organizationId, uid, {
        roles,
        locationIds,
        active,
      }),
    );
    if (!seedDocuments) return;
    for (const [locationId, managingOrganizationId] of [
      ['site-rc43d-a', 'organization-a'],
      ['site-rc43d-a-other', 'organization-a'],
      ['site-rc43d-b', 'organization-b'],
      ['site-rc43d-b-outside', 'organization-b'],
    ]) {
      await setDoc(doc(admin, `locations/${locationId}`), {
        id: locationId,
        name: locationId,
        group: 'partnerSites',
        type: 'otherPartnerSite',
        isActive: true,
        managingOrganizationId,
      });
    }
    for (const [missionId, mobilizationId, locationId] of [
      ['mission-rc43d-a', 'mobilization-a', 'site-rc43d-a'],
      ['mission-rc43d-a-other', 'mobilization-a', 'site-rc43d-a-other'],
      ['mission-rc43d-b', 'mobilization-b', 'site-rc43d-b'],
      ['mission-rc43d-b-outside', 'mobilization-b', 'site-rc43d-b-outside'],
    ]) {
      await setDoc(doc(admin, `missions/${missionId}`), mission({
        id: missionId,
        mobilizationId,
        locationId,
        locationName: locationId,
      }));
      await setDoc(
        doc(admin, `engagements/${missionId}_professional`),
        {
          missionId,
          mobilizationId,
          volunteerId: 'professional',
          profession: 'mk',
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          status: 'confirmed',
        },
      );
    }
  });
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

async function engageMission(uid, missionId, mobilizationId) {
  const userDb = db(uid);
  const missionReference = doc(userDb, `missions/${missionId}`);
  const missionSnapshot = await getDoc(missionReference);
  const missionData = missionSnapshot.data();
  const volunteerReference = doc(userDb, `volunteers/${uid}`);
  const volunteerSnapshot = await getDoc(volunteerReference);
  const registeredMk = missionData.registeredMk + 1;
  const batch = writeBatch(userDb);
  batch.set(volunteerReference, {
    ...volunteer(uid),
    ...(volunteerSnapshot.exists()
      ? {createdAt: volunteerSnapshot.data().createdAt}
      : {}),
    updatedAt: serverTimestamp(),
  });
  batch.set(doc(userDb, `engagements/${missionId}_${uid}`), {
    missionId,
    mobilizationId,
    volunteerId: uid,
    profession: 'mk',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    status: 'confirmed',
  });
  batch.update(missionReference, {
    registeredMk,
    status: expectedStatus({...missionData, registeredMk}),
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
  assert.equal((await assertSucceeds(getDocs(collection(db(), 'locations')))).size, 2);
  await assertFails(setDoc(doc(db('u'), 'locations/new'), {name: 'x'}));
  await assertFails(updateDoc(doc(db('u'), 'locations/site-a'), {name: 'x'}));
  await assertFails(deleteDoc(doc(db('u'), 'locations/site-a')));
});

test('RC4.3B: legacy locations remain public for RC3 professionals', async () => {
  await seedOrganizationLocations();

  await assertSucceeds(getDoc(doc(db(), 'locations/legacy-implicit')));
  await assertSucceeds(getDoc(doc(db(), 'locations/legacy-explicit')));
  await assertSucceeds(getDoc(
    doc(db('legacy-coordinator'), 'locations/legacy-implicit'),
  ));
  await assertSucceeds(getDoc(
    doc(db('legacy-manager'), 'locations/legacy-implicit'),
  ));
  await assertFails(getDoc(doc(
    db(),
    'locations/site-organization-a',
  )));
});

test('RC4.3B: organization members only read their managed locations', async () => {
  await seedOrganizationLocations();
  const memberDb = db('member-a');

  await assertSucceeds(getDoc(doc(
    memberDb,
    'locations/site-organization-a',
  )));
  await assertFails(getDoc(doc(
    memberDb,
    'locations/site-organization-b',
  )));
  const ownLocations = await assertSucceeds(getDocs(query(
    collection(memberDb, 'locations'),
    where('managingOrganizationId', '==', 'organization-a'),
  )));
  assert.deepEqual(ownLocations.docs.map((item) => item.id), [
    'site-organization-a',
  ]);
  await assertFails(getDocs(query(
    collection(memberDb, 'locations'),
    where('managingOrganizationId', '==', 'organization-b'),
  )));
});

test('RC4.3B: platform admin is global and inactive membership is refused', async () => {
  await seedOrganizationLocations();

  const locations = await assertSucceeds(getDocs(
    collection(db('platform-admin'), 'locations'),
  ));
  assert.equal(locations.size, 4);
  await assertFails(getDoc(doc(
    db('inactive-member'),
    'locations/site-organization-a',
  )));
  // Le site legacy reste la projection publique RC3, indépendamment du rôle.
  await assertSucceeds(getDoc(doc(
    db('inactive-member'),
    'locations/legacy-implicit',
  )));
});

test('RC4.3B: no client identity gains a location write', async () => {
  await seedOrganizationLocations();

  for (const uid of [null, 'member-a', 'platform-admin']) {
    const userDb = db(uid);
    await assertFails(setDoc(doc(userDb, 'locations/forged'), {
      id: 'forged',
      name: 'Site forgé',
      managingOrganizationId: 'organization-a',
    }));
    await assertFails(updateDoc(
      doc(userDb, 'locations/site-organization-a'),
      {name: 'Site modifié'},
    ));
    await assertFails(deleteDoc(doc(
      userDb,
      'locations/site-organization-a',
    )));
  }
});

test('missions: public active read and anonymous create denied', async () => {
  await seed();
  await assertSucceeds(getDoc(doc(db(), 'missions/mission-a')));
  await assertFails(setDoc(doc(db(), 'missions/new'), mission({id: 'new'})));
});

test('notifications: owner can read and toggle readAt only', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), 'notifications/notif-a'), {
      notificationId: 'notif-a',
      recipientUid: 'professional-a',
      eventId: 'event-a',
      eventType: 'mission.updated',
      title: 'Mission modifiée',
      body: 'Langon',
      missionId: 'mission-a',
      occurredAt: Timestamp.now(),
      readAt: null,
    });
  });
  await assertSucceeds(getDoc(doc(db('professional-a'), 'notifications/notif-a')));
  await assertFails(getDoc(doc(db('professional-b'), 'notifications/notif-a')));
  await assertSucceeds(updateDoc(
    doc(db('professional-a'), 'notifications/notif-a'),
    {readAt: serverTimestamp()},
  ));
  await assertSucceeds(updateDoc(
    doc(db('professional-a'), 'notifications/notif-a'),
    {readAt: null},
  ));
  await assertFails(updateDoc(
    doc(db('professional-a'), 'notifications/notif-a'),
    {title: 'Contenu falsifié'},
  ));
  await assertFails(setDoc(
    doc(db('professional-a'), 'notifications/forged'),
    {recipientUid: 'professional-a'},
  ));
});

test('notification events and delivery journal remain server-only', async () => {
  await seed();
  for (const collectionName of ['notificationEvents', 'notificationDeliveries']) {
    await env.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), `${collectionName}/entry-a`), {uid: 'professional-a'});
    });
    await assertFails(getDoc(doc(db('professional-a'), `${collectionName}/entry-a`)));
    await assertFails(setDoc(doc(db('professional-a'), `${collectionName}/entry-b`), {uid: 'professional-a'}));
  }
});

test('notification preferences are owner-only and strictly validated', async () => {
  await seed();
  const preferences = {
    uid: 'professional-a',
    compatibleMissions: false,
    engagementUpdates: true,
    operationalAlerts: true,
    quietHoursStart: 22,
    quietHoursEnd: 7,
    updatedAt: serverTimestamp(),
  };
  await assertSucceeds(setDoc(
    doc(db('professional-a'), 'notificationPreferences/professional-a'),
    preferences,
  ));
  await assertSucceeds(getDoc(
    doc(db('professional-a'), 'notificationPreferences/professional-a'),
  ));
  await assertFails(getDoc(
    doc(db('professional-b'), 'notificationPreferences/professional-a'),
  ));
  await assertFails(setDoc(
    doc(db('professional-a'), 'notificationPreferences/professional-a'),
    {...preferences, quietHoursStart: 24},
  ));
  await assertFails(setDoc(
    doc(db('professional-a'), 'notificationPreferences/professional-a'),
    {...preferences, unexpected: true},
  ));
});

const pushRegistration = (
  uid = 'professional-a',
  installationId = 'device-a',
  token = 'token-a',
) => ({
    uid, installationId, token, platform: 'web',
    active: true, lastUsedAt: serverTimestamp(),
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });

async function seedPushSubscription() {
  await assertSucceeds(setDoc(
    doc(db('professional-a'), 'pushSubscriptions/professional-a_device-a'),
    pushRegistration(),
  ));
}

test('push subscriptions: owner reads an existing subscription', async () => {
  await seedPushSubscription();
  await assertSucceeds(getDoc(
    doc(db('professional-a'), 'pushSubscriptions/professional-a_device-a'),
  ));
});

test('push subscriptions: another user cannot read an existing subscription', async () => {
  await seedPushSubscription();
  await assertFails(getDoc(
    doc(db('professional-b'), 'pushSubscriptions/professional-a_device-a'),
  ));
});

test('push subscriptions: owner transaction gets absent then creates', async () => {
  const ownerDb = db('professional-a');
  const reference = doc(
    ownerDb,
    'pushSubscriptions/professional-a_device-a',
  );
  await assertSucceeds(runTransaction(ownerDb, async (transaction) => {
    const existing = await transaction.get(reference);
    assert.equal(existing.exists(), false);
    transaction.set(reference, pushRegistration(), {merge: true});
  }));
});

test('push subscriptions: owner creates a subscription for own uid', async () => {
  await assertSucceeds(setDoc(
    doc(db('professional-a'), 'pushSubscriptions/professional-a_device-a'),
    pushRegistration(),
  ));
  await assertSucceeds(setDoc(
    doc(db('professional-a'), 'pushSubscriptions/professional-a_device-b'),
    pushRegistration('professional-a', 'device-b', 'token-b'),
  ));
});

test('push subscriptions: user cannot create for another uid', async () => {
  await assertFails(setDoc(
    doc(db('professional-a'), 'pushSubscriptions/professional-b_device-a'),
    pushRegistration('professional-b'),
  ));
});

test('push subscriptions: client list remains denied', async () => {
  await seedPushSubscription();
  await assertFails(getDocs(
    collection(db('professional-a'), 'pushSubscriptions'),
  ));
});

test('push subscriptions: owner updates an existing subscription', async () => {
  await seedPushSubscription();
  await assertSucceeds(updateDoc(
    doc(db('professional-a'), 'pushSubscriptions/professional-a_device-a'),
    {
      token: 'token-a-refreshed', active: true,
      lastUsedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    },
  ));
  await assertFails(deleteDoc(
    doc(db('professional-a'), 'pushSubscriptions/professional-a_device-a'),
  ));
});

test('push subscriptions: another user cannot update a subscription', async () => {
  await seedPushSubscription();
  await assertFails(updateDoc(
    doc(db('professional-b'), 'pushSubscriptions/professional-a_device-a'),
    {
      token: 'forged-token', active: true,
      lastUsedAt: serverTimestamp(), updatedAt: serverTimestamp(),
    },
  ));
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

test('RC3.8F.3: platform admin cannot use professional owner writes', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'platformAdministrators/platform-admin'), {
      active: true,
    });
    await setDoc(
      doc(admin, 'volunteers/platform-admin'),
      volunteer('platform-admin'),
    );
    await setDoc(doc(admin, 'engagements/mission-a_platform-admin'), {
      missionId: 'mission-a',
      mobilizationId: activeMobilizationId,
      volunteerId: 'platform-admin',
      profession: 'mk',
      status: 'confirmed',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    await updateDoc(doc(admin, 'missions/mission-a'), {
      registeredMk: 1,
      status: 'critical',
    });
  });

  const adminDb = db('platform-admin');

  // Existing owner reads remain unchanged; only professional writes are gated.
  await assertSucceeds(getDoc(
    doc(adminDb, 'volunteers/platform-admin'),
  ));
  await assertSucceeds(getDoc(
    doc(adminDb, 'engagements/mission-a_platform-admin'),
  ));

  await assertFails(updateDoc(
    doc(adminDb, 'volunteers/platform-admin'),
    {phone: '0611111111', updatedAt: serverTimestamp()},
  ));
  const cancellation = writeBatch(adminDb);
  cancellation.update(
    doc(adminDb, 'engagements/mission-a_platform-admin'),
    {status: 'cancelled', updatedAt: serverTimestamp()},
  );
  cancellation.update(doc(adminDb, 'missions/mission-a'), {
    registeredMk: 0,
    status: 'critical',
    updatedAt: serverTimestamp(),
  });
  await assertFails(cancellation.commit());

  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await deleteDoc(doc(admin, 'engagements/mission-a_platform-admin'));
    await deleteDoc(doc(admin, 'volunteers/platform-admin'));
    await updateDoc(doc(admin, 'missions/mission-a'), {
      registeredMk: 0,
      status: 'critical',
    });
  });

  await assertFails(setDoc(
    doc(adminDb, 'volunteers/platform-admin'),
    volunteer('platform-admin'),
  ));

  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), 'volunteers/platform-admin'),
      volunteer('platform-admin'),
    );
  });

  const creation = writeBatch(adminDb);
  creation.set(doc(adminDb, 'engagements/mission-a_platform-admin'), {
    missionId: 'mission-a',
    mobilizationId: activeMobilizationId,
    volunteerId: 'platform-admin',
    profession: 'mk',
    status: 'confirmed',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  creation.update(doc(adminDb, 'missions/mission-a'), {
    registeredMk: 1,
    status: 'critical',
    updatedAt: serverTimestamp(),
  });
  await assertFails(creation.commit());
});

test('RC3.8F.3: professional owner writes remain allowed', async () => {
  await seed();
  await assertSucceeds(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    volunteer('alice'),
  ));
  await assertSucceeds(updateDoc(doc(db('alice'), 'volunteers/alice'), {
    phone: '0611111111',
    updatedAt: serverTimestamp(),
  }));
  await assertSucceeds(engage('alice', 'mk', {}, false));
  await assertSucceeds(updateEngagement('alice', 'alice', 'cancelled', {
    registeredMk: 0,
    status: 'critical',
  }));
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

test('volunteers: CPTS label is primary and legacy identifiers stay valid', async () => {
  await seed();
  const missingLabel = volunteer('alice', {cptsId: 'cpts-medoc'});
  delete missingLabel.cptsLabel;
  await assertSucceeds(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    missingLabel,
  ));
  const missingId = volunteer('bob', {cptsLabel: 'CPTS Médoc'});
  delete missingId.cptsId;
  await assertSucceeds(setDoc(
    doc(db('bob'), 'volunteers/bob'),
    missingId,
  ));
  await assertFails(setDoc(
    doc(db('charlie'), 'volunteers/charlie'),
    volunteer('charlie', {cptsLabel: 42}),
  ));
});

test('volunteers: professional address is optional, structured and private', async () => {
  await seed();
  await assertSucceeds(setDoc(
    doc(db('alice'), 'volunteers/alice'),
    volunteer('alice', {
      professionalAddressLine1: '10 rue de la Santé',
      professionalAddressLine2: 'Cabinet 2',
      professionalPostalCode: '33000',
      professionalCity: 'Bordeaux',
      professionalCountryCode: 'FR',
    }),
  ));
  await assertFails(getDoc(doc(db('bob'), 'volunteers/alice')));

  await assertFails(setDoc(
    doc(db('bob'), 'volunteers/bob'),
    volunteer('bob', {
      professionalAddressLine1: '10 rue de la Santé',
      professionalPostalCode: '3300',
      professionalCity: 'Bordeaux',
      professionalCountryCode: 'FR',
    }),
  ));
  await assertFails(setDoc(
    doc(db('charlie'), 'volunteers/charlie'),
    volunteer('charlie', {
      professionalAddressLine1: '10 rue de la Santé',
      professionalPostalCode: '33000',
      professionalCountryCode: 'FR',
    }),
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

test('platform V6: platform administrator reads its dashboard without client writes', async () => {
  await seed();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'platformAdministrators/platform-admin'), {
      active: true,
    });
    await setDoc(doc(admin, 'volunteers/professional'), {
      uid: 'professional',
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
      doc(
        admin,
        `mobilizationAssignments/${activeMobilizationId}_coord`,
      ),
      {
        uid: 'coord',
        mobilizationId: activeMobilizationId,
        role: 'coordinator',
        active: true,
      },
    );
  });

  const administrationPaths = [
    'platformAdministrators/platform-admin',
    'territories/gironde',
    `mobilizationAssignments/${activeMobilizationId}_coord`,
  ];
  for (const uid of [null, 'alice']) {
    for (const path of administrationPaths) {
      await assertFails(getDoc(doc(db(uid), path)));
    }
  }
  await assertFails(getDoc(doc(db('coord'), 'territories/gironde')));
  await assertSucceeds(getDoc(doc(
    db('coord'),
    `mobilizationAssignments/${activeMobilizationId}_coord`,
  )));
  await assertSucceeds(getDoc(
    doc(db('platform-admin'), 'platformAdministrators/platform-admin'),
  ));
  await assertFails(getDoc(
    doc(db('platform-admin'), 'platformAdministrators/other-admin'),
  ));
  await assertSucceeds(getDoc(
    doc(db('platform-admin'), 'territories/gironde'),
  ));
  await assertSucceeds(getDocs(
    collection(db('platform-admin'), 'territories'),
  ));
  await assertSucceeds(getDoc(
    doc(db('platform-admin'), 'mobilizations/current'),
  ));
  await assertSucceeds(getDocs(
    collection(db('platform-admin'), 'mobilizations'),
  ));
  await assertSucceeds(getDocs(query(
    collection(db('platform-admin'), 'roles'),
    where('role', '==', 'coordinator'),
    where('active', '==', true),
  )));
  await assertSucceeds(getDoc(
    doc(
      db('platform-admin'),
      `mobilizationAssignments/${activeMobilizationId}_coord`,
    ),
  ));
  await assertSucceeds(getDocs(query(
    collection(db('platform-admin'), 'mobilizationAssignments'),
    where('mobilizationId', '==', activeMobilizationId),
    where('role', '==', 'coordinator'),
  )));
  await assertFails(getDocs(
    collection(db('platform-admin'), 'platformAdministrators'),
  ));
  await assertFails(getDocs(collection(db('alice'), 'territories')));
  await assertFails(getDocs(collection(db('alice'), 'mobilizations')));
  await assertFails(getDocs(collection(db('alice'), 'roles')));
  await assertFails(getDocs(
    collection(db('alice'), 'mobilizationAssignments'),
  ));

  for (const uid of [null, 'alice', 'coord', 'platform-admin']) {
    for (const path of [
      ...administrationPaths,
      'mobilizations/current',
    ]) {
      await assertFails(setDoc(doc(db(uid), path), {forged: true}));
      await assertFails(updateDoc(doc(db(uid), path), {forged: true}));
      await assertFails(deleteDoc(doc(db(uid), path)));
    }
  }
  for (const uid of ['professional', 'coord', 'platform-admin']) {
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

test('RC3.5A.1: production-like legacy coordinator keeps one mobilization', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'platform/config'), {activeMobilizationId});
    await setDoc(doc(admin, 'locations/site-a'), {
      id: 'site-a', name: 'Site A', group: 'medoc', type: 'sdisStation',
      isActive: true,
    });
    for (const [mobilizationId, status] of [
      [activeMobilizationId, 'active'],
      ['other-active', 'active'],
      ['other-inactive', 'inactive'],
    ]) {
      await setDoc(doc(admin, `mobilizations/${mobilizationId}`), {
        id: mobilizationId,
        territoryId: 'gironde',
        status,
      });
    }
    await setDoc(doc(admin, 'roles/legacy-coord'), {
      role: 'coordinator', locationIds: ['*'], active: true,
    });
    await setDoc(doc(admin, 'roles/inactive-coord'), {
      role: 'coordinator', locationIds: ['*'], active: false,
    });
    for (const [id, mobilizationId] of [
      ['legacy-existing', activeMobilizationId],
      ['other-existing', 'other-active'],
      ['inactive-existing', 'other-inactive'],
    ]) {
      await setDoc(doc(admin, `missions/${id}`), mission({
        id,
        mobilizationId,
        createdBy: 'legacy-coord',
      }));
    }
  });

  await assertSucceeds(getDoc(doc(
    db('legacy-coord'),
    `mobilizations/${activeMobilizationId}`,
  )));
  const legacyMissions = await assertSucceeds(getDocs(query(
    collection(db('legacy-coord'), 'missions'),
    where('mobilizationId', '==', activeMobilizationId),
    where('isActive', '==', true),
  )));
  assert.equal(legacyMissions.size, 1);
  await assertSucceeds(createMissionFor('legacy-coord', 'legacy-created'));

  for (const mobilizationId of ['other-active', 'other-inactive']) {
    await assertFails(getDocs(query(
      collection(db('legacy-coord'), 'missions'),
      where('mobilizationId', '==', mobilizationId),
      where('isActive', '==', true),
    )));
    await assertFails(setDoc(
      doc(db('legacy-coord'), `missions/create-${mobilizationId}`),
      mission({
        id: `create-${mobilizationId}`,
        mobilizationId,
        createdBy: 'legacy-coord',
      }),
    ));
  }
  await assertFails(createMissionFor('inactive-coord', 'inactive-denied'));
  await assertFails(createMissionFor('no-role', 'no-role-denied'));
});

test('RC3.5A.1: first explicit assignment disables the legacy fallback', async () => {
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'platform/config'), {activeMobilizationId});
    await setDoc(doc(admin, 'locations/site-a'), {
      id: 'site-a', name: 'Site A', group: 'medoc', type: 'sdisStation',
      isActive: true,
    });
    for (const mobilizationId of [activeMobilizationId, 'assigned-active']) {
      await setDoc(doc(admin, `mobilizations/${mobilizationId}`), {
        id: mobilizationId,
        territoryId: 'gironde',
        status: 'active',
      });
      await setDoc(doc(admin, `missions/${mobilizationId}-mission`), mission({
        id: `${mobilizationId}-mission`,
        mobilizationId,
        createdBy: 'legacy-coord',
      }));
    }
    await setDoc(doc(admin, 'roles/legacy-coord'), {
      role: 'coordinator', locationIds: ['*'], active: true,
    });
  });

  await assertSucceeds(getDocs(query(
    collection(db('legacy-coord'), 'missions'),
    where('mobilizationId', '==', activeMobilizationId),
    where('isActive', '==', true),
  )));

  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(
      doc(admin, 'mobilizationAssignments/assigned-active_legacy-coord'),
      {
        uid: 'legacy-coord',
        mobilizationId: 'assigned-active',
        role: 'coordinator',
        active: true,
      },
    );
    await updateDoc(doc(admin, 'roles/legacy-coord'), {
      hasActiveMobilizationAssignments: true,
    });
  });

  await assertFails(getDocs(query(
    collection(db('legacy-coord'), 'missions'),
    where('mobilizationId', '==', activeMobilizationId),
    where('isActive', '==', true),
  )));
  const assignedMissions = await assertSucceeds(getDocs(query(
    collection(db('legacy-coord'), 'missions'),
    where('mobilizationId', '==', 'assigned-active'),
    where('isActive', '==', true),
  )));
  assert.equal(assignedMissions.size, 1);
  await assertFails(createMissionFor('legacy-coord', 'legacy-now-denied'));
  await assertSucceeds(setDoc(
    doc(db('legacy-coord'), 'missions/assigned-created'),
    mission({
      id: 'assigned-created',
      mobilizationId: 'assigned-active',
      createdBy: 'legacy-coord',
    }),
  ));
});

test('RC3.5A.2: direct mobilization get respects every supported identity', async () => {
  const assignedMobilizationId = 'assigned-active';
  const otherMobilizationId = 'other-active';
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'platform/config'), {activeMobilizationId});
    for (const mobilizationId of [
      activeMobilizationId,
      assignedMobilizationId,
      otherMobilizationId,
    ]) {
      await setDoc(doc(admin, `mobilizations/${mobilizationId}`), {
        id: mobilizationId,
        territoryId: 'gironde',
        status: 'active',
      });
    }
    await setDoc(doc(admin, 'roles/legacy-coord'), {
      role: 'coordinator', locationIds: ['*'], active: true,
    });
    await setDoc(doc(admin, 'roles/assigned-coord'), {
      role: 'coordinator', locationIds: ['*'], active: true,
      hasActiveMobilizationAssignments: true,
    });
    await setDoc(doc(admin, 'roles/inactive-coord'), {
      role: 'coordinator', locationIds: ['*'], active: false,
    });
    await setDoc(doc(admin, 'roles/manager'), {
      role: 'site_manager', locationIds: ['site-a'], active: true,
    });
    await setDoc(
      doc(
        admin,
        `mobilizationAssignments/${assignedMobilizationId}_assigned-coord`,
      ),
      {
        uid: 'assigned-coord',
        mobilizationId: assignedMobilizationId,
        role: 'coordinator',
        active: true,
      },
    );
    await setDoc(doc(admin, 'platformAdministrators/platform-admin'), {
      active: true,
    });
    await setDoc(doc(admin, 'volunteers/professional'), {
      uid: 'professional',
    });
  });

  await assertSucceeds(getDoc(doc(
    db('legacy-coord'),
    `mobilizations/${activeMobilizationId}`,
  )));
  await assertSucceeds(getDoc(doc(
    db('assigned-coord'),
    `mobilizations/${assignedMobilizationId}`,
  )));
  await assertSucceeds(getDoc(doc(
    db('platform-admin'),
    `mobilizations/${otherMobilizationId}`,
  )));
  await assertSucceeds(getDoc(doc(
    db('manager'),
    `mobilizations/${otherMobilizationId}`,
  )));
  await assertFails(getDoc(doc(
    db('professional'),
    `mobilizations/${otherMobilizationId}`,
  )));

  await assertFails(getDoc(doc(
    db('legacy-coord'),
    `mobilizations/${otherMobilizationId}`,
  )));
  await assertFails(getDoc(doc(
    db('assigned-coord'),
    `mobilizations/${otherMobilizationId}`,
  )));
  await assertSucceeds(getDoc(doc(
    db('inactive-coord'),
    `mobilizations/${activeMobilizationId}`,
  )));
  await assertSucceeds(getDoc(doc(
    db('no-role'),
    `mobilizations/${activeMobilizationId}`,
  )));
});

test('RC3.5: role scopes remain isolated across three active mobilizations', async () => {
  await seed({mission: false});
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    for (const [operationId, name] of [
      ['operation-a', 'Opération A'],
      ['operation-b', 'Opération B'],
    ]) {
      await setDoc(doc(admin, `operations/${operationId}`), {
        id: operationId,
        name,
        type: 'emergency',
        status: 'active',
        visibility: 'platform',
      });
    }
    for (const [mobilizationId, operationId] of [
      [activeMobilizationId, 'operation-a'],
      ['mobilization-a2', 'operation-a'],
      ['mobilization-b1', 'operation-b'],
    ]) {
      await setDoc(doc(admin, `mobilizations/${mobilizationId}`), {
        id: mobilizationId,
        territoryId: 'gironde',
        operationId,
        status: 'active',
      });
    }
    await setDoc(doc(admin, 'roles/coord-b'), {
      role: 'coordinator', locationIds: ['*'], active: true,
      hasActiveMobilizationAssignments: true,
    });
    for (const [mobilizationId, uid] of [
      [activeMobilizationId, 'coord'],
      ['mobilization-a2', 'coord'],
      ['mobilization-b1', 'coord-b'],
    ]) {
      await setDoc(
        doc(admin, `mobilizationAssignments/${mobilizationId}_${uid}`),
        {uid, mobilizationId, role: 'coordinator', active: true},
      );
    }
    await setDoc(doc(admin, 'missions/mission-a1'), mission({
      id: 'mission-a1',
      mobilizationId: activeMobilizationId,
      locationId: 'site-a',
    }));
    await setDoc(doc(admin, 'missions/mission-a2'), mission({
      id: 'mission-a2',
      mobilizationId: 'mobilization-a2',
      locationId: 'site-b',
    }));
    await setDoc(doc(admin, 'missions/mission-b1'), mission({
      id: 'mission-b1',
      mobilizationId: 'mobilization-b1',
      locationId: 'site-a',
    }));
    await setDoc(doc(admin, 'platformAdministrators/platform-admin'), {
      active: true,
    });
    await setDoc(doc(admin, 'volunteers/professional'), {
      uid: 'professional',
    });
  });

  const coordA1 = await assertSucceeds(getDocs(query(
    collection(db('coord'), 'missions'),
    where('mobilizationId', '==', activeMobilizationId),
    where('isActive', '==', true),
  )));
  const coordA2 = await assertSucceeds(getDocs(query(
    collection(db('coord'), 'missions'),
    where('mobilizationId', '==', 'mobilization-a2'),
    where('isActive', '==', true),
  )));
  assert.equal(coordA1.size, 1);
  assert.equal(coordA2.size, 1);
  await assertFails(getDocs(query(
    collection(db('coord'), 'missions'),
    where('mobilizationId', '==', 'mobilization-b1'),
    where('isActive', '==', true),
  )));

  let managerMissionCount = 0;
  for (const mobilizationId of [activeMobilizationId, 'mobilization-b1']) {
    const managerMissions = await assertSucceeds(getDocs(query(
      collection(db('manager'), 'missions'),
      where('mobilizationId', '==', mobilizationId),
      where('locationId', '==', 'site-a'),
      where('isActive', '==', true),
    )));
    managerMissionCount += managerMissions.size;
  }
  assert.equal(managerMissionCount, 2);
  await assertFails(getDocs(query(
    collection(db('manager'), 'missions'),
    where('mobilizationId', '==', 'mobilization-a2'),
    where('locationId', '==', 'site-b'),
    where('isActive', '==', true),
  )));

  const activeMobilizations = await assertSucceeds(getDocs(query(
    collection(db('professional'), 'mobilizations'),
    where('operationId', 'in', ['operation-a', 'operation-b']),
    where('status', '==', 'active'),
  )));
  assert.equal(activeMobilizations.size, 3);
  await assertFails(getDocs(query(
    collection(db('coord'), 'mobilizations'),
    where('status', '==', 'active'),
  )));
  let professionalMissionCount = 0;
  for (const mobilizationId of [
    activeMobilizationId,
    'mobilization-a2',
    'mobilization-b1',
  ]) {
    const professionalMissions = await assertSucceeds(getDocs(query(
      collection(db('professional'), 'missions'),
      where('mobilizationId', '==', mobilizationId),
      where('isActive', '==', true),
    )));
    professionalMissionCount += professionalMissions.size;
  }
  assert.equal(professionalMissionCount, 3);
  await assertFails(getDocs(query(
    collection(db('platform-admin'), 'missions'),
    where('mobilizationId', '==', activeMobilizationId),
    where('isActive', '==', true),
  )));

  await assertSucceeds(getDocs(query(
    collection(db('coord'), 'mobilizationAssignments'),
    where('uid', '==', 'coord'),
    where('role', '==', 'coordinator'),
    where('active', '==', true),
  )));
  await assertFails(getDoc(doc(
    db('coord'),
    'mobilizationAssignments/mobilization-b1_coord-b',
  )));
  await assertSucceeds(getDocs(collection(db('platform-admin'), 'operations')));
  await assertSucceeds(getDoc(doc(db('professional'), 'operations/operation-a')));
  await assertFails(setDoc(doc(db('platform-admin'), 'operations/forged'), {
    id: 'forged', status: 'active',
  }));
});

test('RC3.5: one professional engages in two mobilizations without mixing quotas', async () => {
  await seed({mission: false});
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'operations/operation-b1'), {
      id: 'operation-b1',
      name: 'Opération plateforme B1',
      type: 'emergency',
      status: 'active',
      visibility: 'platform',
    });
    await setDoc(doc(admin, 'mobilizations/mobilization-b1'), {
      id: 'mobilization-b1',
      territoryId: 'gironde',
      status: 'active',
      operationId: 'operation-b1',
    });
    await setDoc(doc(admin, 'missions/mission-a1'), mission({
      id: 'mission-a1',
      mobilizationId: activeMobilizationId,
    }));
    await setDoc(doc(admin, 'missions/mission-b1'), mission({
      id: 'mission-b1',
      mobilizationId: 'mobilization-b1',
    }));
  });

  await assertSucceeds(engageMission(
    'professional',
    'mission-a1',
    activeMobilizationId,
  ));
  await assertSucceeds(engageMission(
    'professional',
    'mission-b1',
    'mobilization-b1',
  ));

  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    assert.equal(
      (await getDoc(doc(admin, 'missions/mission-a1'))).data().registeredMk,
      1,
    );
    assert.equal(
      (await getDoc(doc(admin, 'missions/mission-b1'))).data().registeredMk,
      1,
    );
    assert.equal(
      (await getDoc(doc(
        admin,
        'engagements/mission-a1_professional',
      ))).data().mobilizationId,
      activeMobilizationId,
    );
    assert.equal(
      (await getDoc(doc(
        admin,
        'engagements/mission-b1_professional',
      ))).data().mobilizationId,
      'mobilization-b1',
    );
  });
});

test('RC4.1F: platform administrator reads every organization and membership', async () => {
  await seedOrganizations();
  const platformAdminDb = db('platform-admin');

  await assertSucceeds(getDoc(doc(
    platformAdminDb,
    'organizations/organization-a',
  )));
  const organizations = await assertSucceeds(getDocs(
    collection(platformAdminDb, 'organizations'),
  ));
  const memberships = await assertSucceeds(getDocs(
    collection(platformAdminDb, 'organizationMemberships'),
  ));

  assert.equal(organizations.size, 2);
  assert.equal(memberships.size, 3);
});

test('RC4.1F: active member reads its organization and own memberships', async () => {
  await seedOrganizations();
  const memberDb = db('member-a');

  await assertSucceeds(getDoc(doc(
    memberDb,
    'organizations/organization-a',
  )));
  const organizations = await assertSucceeds(getDocs(query(
    collection(memberDb, 'organizations'),
    where(documentId(), 'in', ['organization-a']),
  )));
  const memberships = await assertSucceeds(getDocs(query(
    collection(memberDb, 'organizationMemberships'),
    where('uid', '==', 'member-a'),
  )));
  await assertSucceeds(getDoc(doc(
    memberDb,
    'organizationMemberships/organization-a_member-a',
  )));

  assert.equal(organizations.size, 1);
  assert.equal(memberships.size, 1);
});

test('RC4.1F: inactive member reads its status but not the organization', async () => {
  await seedOrganizations();
  const inactiveDb = db('inactive-member');

  await assertFails(getDoc(doc(
    inactiveDb,
    'organizations/organization-a',
  )));
  const memberships = await assertSucceeds(getDocs(query(
    collection(inactiveDb, 'organizationMemberships'),
    where('uid', '==', 'inactive-member'),
  )));
  await assertSucceeds(getDoc(doc(
    inactiveDb,
    'organizationMemberships/organization-a_inactive-member',
  )));

  assert.equal(memberships.size, 1);
  assert.equal(memberships.docs[0].data().active, false);
});

test('RC4.1F: organization and membership reads remain isolated', async () => {
  await seedOrganizations();
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        'organizationMemberships/organization-b_member-a',
      ),
      organizationMembership('organization-a', 'member-a'),
    );
  });
  const memberDb = db('member-a');

  await assertFails(getDoc(doc(
    memberDb,
    'organizations/organization-b',
  )));
  await assertFails(getDocs(query(
    collection(memberDb, 'organizations'),
    where(documentId(), 'in', ['organization-a', 'organization-b']),
  )));
  await assertFails(getDoc(doc(
    memberDb,
    'organizationMemberships/organization-b_member-b',
  )));
  await assertFails(getDoc(doc(
    memberDb,
    'organizationMemberships/organization-b_member-a',
  )));
  await assertFails(getDocs(query(
    collection(memberDb, 'organizationMemberships'),
    where('uid', '==', 'member-b'),
  )));
  await assertFails(getDocs(
    collection(memberDb, 'organizationMemberships'),
  ));
  await assertFails(getDoc(doc(
    db('non-member'),
    'organizations/organization-a',
  )));
  await assertFails(getDoc(doc(
    db('non-member'),
    'organizationMemberships/organization-a_member-a',
  )));
  await assertFails(getDoc(doc(
    db(),
    'organizations/organization-a',
  )));
});

test('RC4.1F: every client organization write is denied', async () => {
  await seedOrganizations();

  for (const uid of [null, 'member-a', 'platform-admin']) {
    const userDb = db(uid);
    await assertFails(setDoc(
      doc(userDb, 'organizations/forged'),
      organization('forged'),
    ));
    await assertFails(updateDoc(
      doc(userDb, 'organizations/organization-a'),
      {name: 'Nom modifié'},
    ));
    await assertFails(deleteDoc(doc(
      userDb,
      'organizations/organization-a',
    )));
    await assertFails(setDoc(
      doc(
        userDb,
        `organizationMemberships/organization-a_${uid ?? 'anonymous'}-forged`,
      ),
      organizationMembership(
        'organization-a',
        `${uid ?? 'anonymous'}-forged`,
      ),
    ));
    await assertFails(updateDoc(
      doc(userDb, 'organizationMemberships/organization-a_member-a'),
      {active: false},
    ));
    await assertFails(deleteDoc(doc(
      userDb,
      'organizationMemberships/organization-a_member-a',
    )));
  }
});

test('RC4.3C: organization admin reads memberships only inside its organization', async () => {
  await seedOrganizations();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(
      doc(admin, 'organizationMemberships/organization-a_coordinator-a'),
      organizationMembership('organization-a', 'coordinator-a', {
        roles: ['coordinator'],
      }),
    );
    await setDoc(
      doc(admin, 'organizationMemberships/organization-b_coordinator-a'),
      organizationMembership('organization-b', 'coordinator-a', {
        roles: ['site_manager'],
        locationIds: ['site-b'],
      }),
    );
  });
  const organizationAdminDb = db('member-a');

  await assertSucceeds(getDoc(doc(
    organizationAdminDb,
    'organizationMemberships/organization-a_coordinator-a',
  )));
  await assertFails(getDoc(doc(
    organizationAdminDb,
    'organizationMemberships/organization-b_coordinator-a',
  )));
  const memberships = await assertSucceeds(getDocs(query(
    collection(organizationAdminDb, 'organizationMemberships'),
    where('organizationId', '==', 'organization-a'),
  )));
  assert.equal(memberships.size, 3);
  await assertFails(getDocs(query(
    collection(organizationAdminDb, 'organizationMemberships'),
    where('organizationId', '==', 'organization-b'),
  )));
});

test('RC4.3C: coordinator and site manager do not inherit organization admin', async () => {
  await seedOrganizations();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    for (const [uid, role] of [
      ['coordinator-a', 'coordinator'],
      ['manager-a', 'site_manager'],
    ]) {
      await setDoc(
        doc(admin, `organizationMemberships/organization-a_${uid}`),
        organizationMembership('organization-a', uid, {
          roles: [role],
          locationIds: role === 'site_manager' ? ['site-a'] : [],
        }),
      );
    }
  });

  for (const uid of ['coordinator-a', 'manager-a']) {
    const userDb = db(uid);
    await assertSucceeds(getDoc(doc(
      userDb,
      `organizationMemberships/organization-a_${uid}`,
    )));
    await assertFails(getDoc(doc(
      userDb,
      'organizationMemberships/organization-a_member-a',
    )));
    await assertSucceeds(getDoc(doc(
      userDb,
      'organizations/organization-a',
    )));
  }
});

test('RC4.3C: inactive and malformed memberships never grant a role', async () => {
  await seedOrganizations();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(
      doc(admin, 'organizationMemberships/organization-a_inactive-admin'),
      organizationMembership('organization-a', 'inactive-admin', {
        roles: ['organization_admin'],
        active: false,
      }),
    );
    await setDoc(
      doc(admin, 'organizationMemberships/organization-a_malformed-admin'),
      organizationMembership('organization-a', 'malformed-admin', {
        roles: ['organization_admin', 'unknown'],
      }),
    );
  });

  for (const uid of ['inactive-admin', 'malformed-admin']) {
    const userDb = db(uid);
    await assertFails(getDoc(doc(
      userDb,
      'organizations/organization-a',
    )));
    await assertFails(getDoc(doc(
      userDb,
      'organizationMemberships/organization-a_member-a',
    )));
  }
});

test('RC4.3C: roles uid fallback is restricted to legacy Gironde', async () => {
  await seedOrganizations();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(admin, 'roles/legacy-only'), {
      role: 'coordinator',
      locationIds: [],
      active: true,
    });
    await setDoc(doc(admin, 'roles/legacy-inactive-membership'), {
      role: 'coordinator',
      locationIds: [],
      active: true,
    });
    await setDoc(
      doc(
        admin,
        'organizationMemberships/legacy-gironde_legacy-inactive-membership',
      ),
      organizationMembership('legacy-gironde', 'legacy-inactive-membership', {
        roles: ['coordinator'],
        active: false,
      }),
    );
    await setDoc(doc(admin, 'operations/legacy-fallback-operation'), {
      id: 'legacy-fallback-operation',
      name: 'Opération legacy',
      type: 'emergency',
      status: 'draft',
    });
    await setDoc(doc(admin, 'operations/organization-a-operation'), {
      id: 'organization-a-operation',
      name: 'Opération A',
      type: 'emergency',
      status: 'draft',
      ownerOrganizationId: 'organization-a',
    });
  });

  await assertSucceeds(getDoc(doc(
    db('legacy-only'),
    'operations/legacy-fallback-operation',
  )));
  await assertFails(getDoc(doc(
    db('legacy-only'),
    'operations/organization-a-operation',
  )));
  await assertFails(getDoc(doc(
    db('legacy-inactive-membership'),
    'operations/legacy-fallback-operation',
  )));
});

test('RC4.3D: coordinator membership is isolated to its organization', async () => {
  await seedMultiOrganizationCore();
  await seedOrganizationRoleScope({
    uid: 'organization-coordinator-a',
    organizationId: 'organization-a',
    roles: ['coordinator', 'professional'],
  });

  const coordinatorDb = db('organization-coordinator-a');
  await assertSucceeds(getDoc(doc(
    coordinatorDb,
    'engagements/mission-rc43d-a_professional',
  )));
  await assertFails(getDoc(doc(
    coordinatorDb,
    'engagements/mission-rc43d-b_professional',
  )));
  await assertSucceeds(getDoc(doc(
    coordinatorDb,
    'locations/site-rc43d-a',
  )));
  await assertFails(getDoc(doc(
    coordinatorDb,
    'locations/site-rc43d-b',
  )));
  await assertFails(getDocs(collection(
    coordinatorDb,
    'platformAdministrators',
  )));
});

test('RC4.3D: site manager membership is limited to declared organization sites', async () => {
  await seedMultiOrganizationCore();
  await seedOrganizationRoleScope({
    uid: 'organization-manager-a',
    organizationId: 'organization-a',
    roles: ['site_manager'],
    locationIds: ['site-rc43d-a'],
  });

  const managerDb = db('organization-manager-a');
  await assertSucceeds(getDoc(doc(managerDb, 'locations/site-rc43d-a')));
  await assertFails(getDoc(doc(managerDb, 'locations/site-rc43d-a-other')));
  await assertFails(getDoc(doc(managerDb, 'locations/site-rc43d-b')));
  await assertSucceeds(getDoc(doc(
    managerDb,
    'engagements/mission-rc43d-a_professional',
  )));
  await assertFails(getDoc(doc(
    managerDb,
    'engagements/mission-rc43d-a-other_professional',
  )));
  await assertFails(getDoc(doc(
    managerDb,
    'engagements/mission-rc43d-b_professional',
  )));
});

test('RC4.3D: one UID keeps distinct coordinator and manager roles in A and B', async () => {
  await seedMultiOrganizationCore();
  await seedOrganizationRoleScope({
    uid: 'organization-multi-role',
    organizationId: 'organization-a',
    roles: ['organization_admin', 'coordinator'],
  });
  await seedOrganizationRoleScope({
    uid: 'organization-multi-role',
    organizationId: 'organization-b',
    roles: ['site_manager'],
    locationIds: ['site-rc43d-b'],
    seedDocuments: false,
  });

  const userDb = db('organization-multi-role');
  await assertSucceeds(getDoc(doc(
    userDb,
    'engagements/mission-rc43d-a_professional',
  )));
  await assertSucceeds(getDoc(doc(
    userDb,
    'engagements/mission-rc43d-b_professional',
  )));
  await assertFails(getDoc(doc(
    userDb,
    'engagements/mission-rc43d-b-outside_professional',
  )));
});

test('RC4.3D: inactive membership blocks organization roles and legacy fallback', async () => {
  await seedMultiOrganizationCore();
  await seedOrganizationRoleScope({
    uid: 'organization-inactive-coordinator',
    organizationId: 'organization-a',
    roles: ['coordinator'],
    active: false,
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await setDoc(doc(
      admin,
      'roles/organization-inactive-coordinator',
    ), {
      role: 'coordinator',
      locationIds: [],
      active: true,
    });
    await setDoc(
      doc(
        admin,
        'organizationMemberships/legacy-gironde_organization-inactive-coordinator',
      ),
      organizationMembership(
        'legacy-gironde',
        'organization-inactive-coordinator',
        {roles: ['coordinator'], active: false},
      ),
    );
  });

  await assertFails(getDoc(doc(
    db('organization-inactive-coordinator'),
    'engagements/mission-rc43d-a_professional',
  )));
  await assertFails(getDoc(doc(
    db('organization-inactive-coordinator'),
    'engagements/mission-legacy_professional',
  )));
});

test('RC4.2G: organization member is isolated across the complete parent chain', async () => {
  await seedMultiOrganizationCore();
  const memberDb = db('member-a');

  await assertSucceeds(getDoc(doc(memberDb, 'operations/operation-a')));
  await assertFails(getDoc(doc(memberDb, 'operations/operation-b')));
  await assertSucceeds(getDocs(query(
    collection(memberDb, 'operations'),
    where('ownerOrganizationId', '==', 'organization-a'),
  )));
  await assertFails(getDocs(query(
    collection(memberDb, 'operations'),
    where('ownerOrganizationId', '==', 'organization-b'),
  )));

  await assertSucceeds(getDoc(doc(memberDb, 'mobilizations/mobilization-a')));
  await assertFails(getDoc(doc(memberDb, 'mobilizations/mobilization-b')));
  await assertSucceeds(getDocs(query(
    collection(memberDb, 'mobilizations'),
    where('operationId', '==', 'operation-a'),
    where('status', '==', 'active'),
  )));
  await assertFails(getDocs(query(
    collection(memberDb, 'mobilizations'),
    where('operationId', '==', 'operation-b'),
    where('status', '==', 'active'),
  )));

  await assertSucceeds(getDoc(doc(memberDb, 'missions/mission-org-a')));
  await assertFails(getDoc(doc(memberDb, 'missions/mission-org-b')));
  await assertSucceeds(getDocs(query(
    collection(memberDb, 'missions'),
    where('mobilizationId', '==', 'mobilization-a'),
    where('isActive', '==', true),
  )));
  await assertFails(getDocs(query(
    collection(memberDb, 'missions'),
    where('mobilizationId', '==', 'mobilization-b'),
    where('isActive', '==', true),
  )));

  await assertSucceeds(getDoc(doc(
    memberDb,
    'engagements/mission-org-a_professional',
  )));
  await assertFails(getDoc(doc(
    memberDb,
    'engagements/mission-org-b_professional',
  )));
  await assertSucceeds(getDocs(query(
    collection(memberDb, 'engagements'),
    where('mobilizationId', '==', 'mobilization-a'),
  )));
  await assertFails(getDocs(query(
    collection(memberDb, 'engagements'),
    where('mobilizationId', '==', 'mobilization-b'),
  )));

  await assertSucceeds(setDoc(
    doc(memberDb, 'missions/member-a-create'),
    mission({
      id: 'member-a-create',
      mobilizationId: 'mobilization-a',
      createdBy: 'member-a',
    }),
  ));
  await assertFails(setDoc(
    doc(memberDb, 'missions/member-b-forged-create'),
    mission({
      id: 'member-b-forged-create',
      mobilizationId: 'mobilization-b',
      createdBy: 'member-a',
    }),
  ));
});

test('RC4.2G: inactive membership is denied and platform admin stays global', async () => {
  await seedMultiOrganizationCore();
  const inactiveDb = db('inactive-member');
  const platformAdminDb = db('platform-admin');

  await assertFails(getDoc(doc(inactiveDb, 'operations/operation-a')));
  await assertFails(getDoc(doc(inactiveDb, 'mobilizations/mobilization-a')));
  for (const path of [
    'operations/operation-a',
    'operations/operation-b',
    'mobilizations/mobilization-a',
    'mobilizations/mobilization-b',
  ]) {
    await assertSucceeds(getDoc(doc(platformAdminDb, path)));
  }
  await assertSucceeds(getDocs(collection(platformAdminDb, 'operations')));
  await assertSucceeds(getDocs(collection(platformAdminDb, 'mobilizations')));

  // RC3.8F.3 remains stricter than the organization boundary for previews.
  await assertFails(getDoc(doc(platformAdminDb, 'missions/mission-org-a')));
  await assertFails(getDoc(doc(
    platformAdminDb,
    'engagements/mission-org-a_professional',
  )));
});

test('RC4.2G: legacy coordinator and responsible retain their RC3 scope', async () => {
  await seedMultiOrganizationCore();

  for (const uid of ['legacy-coord', 'legacy-manager']) {
    await assertSucceeds(getDoc(doc(
      db(uid),
      `mobilizations/${activeMobilizationId}`,
    )));
    await assertSucceeds(getDoc(doc(db(uid), 'missions/mission-legacy')));
  }
  await assertSucceeds(getDoc(doc(
    db('legacy-coord'),
    'operations/operation-legacy',
  )));
  await assertSucceeds(getDoc(doc(
    db('legacy-coord'),
    'engagements/mission-legacy_professional',
  )));
  await assertFails(getDoc(doc(
    db('legacy-coord'),
    'mobilizations/mobilization-a',
  )));
});

test('RC4.2G: public professional reads and owner engagement rights stay unchanged', async () => {
  await seedMultiOrganizationCore();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    for (const operationId of ['operation-a', 'operation-b']) {
      await updateDoc(doc(admin, `operations/${operationId}`), {
        visibility: 'platform',
      });
    }
  });
  const professionalDb = db('professional');

  for (const mobilizationId of ['mobilization-a', 'mobilization-b']) {
    await assertSucceeds(getDoc(doc(
      professionalDb,
      `mobilizations/${mobilizationId}`,
    )));
  }
  for (const missionId of ['mission-org-a', 'mission-org-b']) {
    await assertSucceeds(getDoc(doc(db(), `missions/${missionId}`)));
    await assertSucceeds(getDoc(doc(
      professionalDb,
      `engagements/${missionId}_professional`,
    )));
  }
});

test('HOTFIX RC4.3: public flow is bounded by explicit platform operations', async () => {
  await seedMultiOrganizationCore();
  await env.withSecurityRulesDisabled(async (context) => {
    const admin = context.firestore();
    await updateDoc(doc(admin, 'operations/operation-a'), {
      visibility: 'platform',
    });
    await updateDoc(doc(admin, 'operations/operation-b'), {
      visibility: 'shared',
    });
    await setDoc(doc(admin, 'operations/operation-platform-2'), {
      id: 'operation-platform-2',
      name: 'Opération plateforme 2',
      type: 'emergency',
      status: 'planned',
      ownerOrganizationId: 'organization-b',
      visibility: 'platform',
    });
    await setDoc(doc(admin, 'operations/operation-private'), {
      id: 'operation-private',
      name: 'Opération privée',
      type: 'emergency',
      status: 'active',
      ownerOrganizationId: 'organization-b',
      visibility: 'organization_private',
    });
    await setDoc(doc(admin, 'operations/operation-public'), {
      id: 'operation-public',
      name: 'Opération public réservée',
      type: 'emergency',
      status: 'active',
      ownerOrganizationId: 'organization-b',
      visibility: 'public',
    });
    for (const [mobilizationId, operationId] of [
      ['mobilization-platform-2', 'operation-platform-2'],
      ['mobilization-private', 'operation-private'],
      ['mobilization-public', 'operation-public'],
    ]) {
      await setDoc(doc(admin, `mobilizations/${mobilizationId}`), {
        id: mobilizationId,
        territoryId: 'gironde',
        status: 'active',
        operationId,
      });
    }
    await setDoc(doc(admin, 'mobilizations/mobilization-inactive'), {
      id: 'mobilization-inactive',
      territoryId: 'gironde',
      status: 'inactive',
      operationId: 'operation-a',
    });
    await setDoc(doc(admin, 'locations/site-platform-private'), {
      id: 'site-platform-private',
      name: 'Site administratif privé',
      group: 'partnerSites',
      type: 'otherPartnerSite',
      isActive: true,
      managingOrganizationId: 'organization-a',
    });
  });

  const publicDb = db('public-session');
  const operationSnapshot = await assertSucceeds(getDocs(query(
    collection(publicDb, 'operations'),
    where('visibility', '==', 'platform'),
    where('status', 'in', ['planned', 'active', 'suspended', 'completed']),
  )));
  assert.deepEqual(
    operationSnapshot.docs.map((snapshot) => snapshot.id).sort(),
    ['operation-a', 'operation-platform-2'],
  );

  const mobilizationSnapshot = await assertSucceeds(getDocs(query(
    collection(publicDb, 'mobilizations'),
    where('operationId', 'in', ['operation-a', 'operation-platform-2']),
    where('status', '==', 'active'),
  )));
  assert.deepEqual(
    mobilizationSnapshot.docs.map((snapshot) => snapshot.id).sort(),
    ['mobilization-a', 'mobilization-platform-2'],
  );

  for (const operationId of [
    'operation-b',
    'operation-private',
    'operation-public',
  ]) {
    await assertFails(getDocs(query(
      collection(publicDb, 'mobilizations'),
      where('operationId', '==', operationId),
      where('status', '==', 'active'),
    )));
  }
  await assertFails(getDocs(query(
    collection(publicDb, 'mobilizations'),
    where('status', '==', 'active'),
  )));
  await assertFails(getDoc(doc(
    publicDb,
    'mobilizations/mobilization-inactive',
  )));

  await assertSucceeds(getDoc(doc(publicDb, 'platform/config')));
  await assertSucceeds(getDoc(doc(
    publicDb,
    `mobilizations/${activeMobilizationId}`,
  )));
  await assertSucceeds(getDocs(query(
    collection(publicDb, 'missions'),
    where('mobilizationId', 'in', [
      'mobilization-a',
      'mobilization-platform-2',
      activeMobilizationId,
    ]),
    where('isActive', '==', true),
  )));

  await assertFails(getDocs(collection(publicDb, 'engagements')));
  await assertSucceeds(getDoc(doc(publicDb, 'locations/site-a')));
  await assertFails(getDoc(doc(
    publicDb,
    'locations/site-platform-private',
  )));
});
