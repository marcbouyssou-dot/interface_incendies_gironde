import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';
import {deleteApp as deleteAdminApp, initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore} from 'firebase-admin/firestore';
import {deleteApp, initializeApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInWithEmailAndPassword} from 'firebase/auth';
import {
  connectFirestoreEmulator,
  doc,
  getFirestore,
  serverTimestamp,
  writeBatch,
} from 'firebase/firestore';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'verified-professional-gate-tests');
const adminAuth = getAdminAuth(adminApp);
const adminDb = getAdminFirestore(adminApp);
const clients = [];
let sequence = 0;
const unique = (prefix) => `${prefix}-${process.pid}-${++sequence}`;

before(() => assert.equal(process.env.GCLOUD_PROJECT, projectId));
after(async () => {
  await Promise.all(clients.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

async function professional(verified) {
  const uid = unique('professional');
  const email = `${uid}@example.test`;
  const password = 'Test-only-password-42!';
  await adminAuth.createUser({uid, email, password});
  await adminDb.collection('volunteers').doc(uid).set({
    uid,
    profession: 'physiotherapist',
    firstName: 'Alice',
    lastName: 'MARTIN',
    phone: '0600000000',
    email,
    equipment: [],
    professionalIdType: 'rpps',
    professionalIdValue: '10123456789',
    rpps: '10123456789',
    verificationStatus: verified ? 'verified' : 'unverified',
    ...(verified ? {
      verificationSource: 'ans_rpps',
      verifiedFirstName: 'Alice',
      verifiedLastName: 'MARTIN',
      verifiedProfessionCode: '70',
      verifiedProfessionLabel: 'Masseur-Kinésithérapeute',
      verifiedAt: new Date(),
    } : {}),
    createdAt: new Date(),
    updatedAt: new Date(),
  });
  const app = initializeApp({projectId, apiKey: 'fake-api-key'}, unique('client'));
  clients.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  await signInWithEmailAndPassword(auth, email, password);
  const firestore = getFirestore(app);
  connectFirestoreEmulator(
    firestore, '127.0.0.1',
    Number(process.env.MOBSANTE_TEST_FIRESTORE_PORT ?? 8080));
  return {uid, firestore};
}

async function mission() {
  const mobilizationId = unique('mobilization');
  const missionId = unique('mission');
  await adminDb.collection('mobilizations').doc(mobilizationId).set({
    id: mobilizationId,
    status: 'active',
  });
  await adminDb.collection('missions').doc(missionId).set({
    id: missionId,
    mobilizationId,
    locationId: unique('location'),
    isActive: true,
    status: 'critical',
    startAt: new Date(Date.now() + 3600000),
    endAt: new Date(Date.now() + 7200000),
    requiredMk: 1,
    registeredMk: 0,
    requiredPp: 0,
    registeredPp: 0,
    requiredByProfession: {physiotherapist: 1, nurse: 1},
    registeredByProfession: {physiotherapist: 0, nurse: 0},
    updatedAt: new Date(),
  });
  return {mobilizationId, missionId};
}

function engage({firestore, uid}, {mobilizationId, missionId}, profession) {
  const batch = writeBatch(firestore);
  batch.set(doc(firestore, 'engagements', `${missionId}_${uid}`), {
    missionId,
    mobilizationId,
    volunteerId: uid,
    profession,
    status: 'confirmed',
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(firestore, 'missions', missionId), {
    registeredMk: profession === 'physiotherapist' ? 1 : 0,
    registeredByProfession: {
      physiotherapist: profession === 'physiotherapist' ? 1 : 0,
      nurse: profession === 'nurse' ? 1 : 0,
    },
    status: 'toComplete',
    updatedAt: serverTimestamp(),
  });
  return batch.commit();
}

async function cancelledEngagement({uid}, {mobilizationId, missionId}) {
  await adminDb.collection('engagements').doc(`${missionId}_${uid}`).set({
    missionId,
    mobilizationId,
    volunteerId: uid,
    profession: 'physiotherapist',
    status: 'cancelled',
    createdAt: new Date(),
    updatedAt: new Date(),
  });
}

function reengage({firestore, uid}, {missionId}) {
  const batch = writeBatch(firestore);
  batch.update(doc(firestore, 'engagements', `${missionId}_${uid}`), {
    profession: 'physiotherapist',
    status: 'confirmed',
    updatedAt: serverTimestamp(),
  });
  batch.update(doc(firestore, 'missions', missionId), {
    registeredMk: 1,
    registeredByProfession: {physiotherapist: 1, nurse: 0},
    status: 'toComplete',
    updatedAt: serverTimestamp(),
  });
  return batch.commit();
}

test('unverified identifier alone cannot create an engagement', async () => {
  const identity = await professional(false);
  const target = await mission();
  await assert.rejects(engage(identity, target, 'physiotherapist'),
    (error) => error.code === 'permission-denied');
});

test('verified MK can engage as MK but not as another open profession', async () => {
  const identity = await professional(true);
  const ownTarget = await mission();
  await engage(identity, ownTarget, 'physiotherapist');
  const stored = (await adminDb.collection('engagements')
    .doc(`${ownTarget.missionId}_${identity.uid}`).get()).data();
  assert.equal(stored.profession, 'physiotherapist');
  const otherTarget = await mission();
  await assert.rejects(engage(identity, otherTarget, 'nurse'),
    (error) => error.code === 'permission-denied');
});

test('reengagement also requires the verified profile', async () => {
  const identity = await professional(true);
  const allowedTarget = await mission();
  await cancelledEngagement(identity, allowedTarget);
  await reengage(identity, allowedTarget);
  const deniedTarget = await mission();
  await cancelledEngagement(identity, deniedTarget);
  await adminDb.collection('volunteers').doc(identity.uid).update({
    verificationStatus: 'unverified',
  });
  await assert.rejects(reengage(identity, deniedTarget),
    (error) => error.code === 'permission-denied');
});
