import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';
import {deleteApp, initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {
  claimVerifiedProfessionalIdentity,
  professionalIdentityClaimId,
  releaseRetiredProfessionalIdentityClaim,
} from '../../src/professional_identity_claims.js';

const projectId = 'demo-mobsante';
const secret = 'synthetic-emulator-only-claim-key-1234567890';
const app = initializeApp({projectId}, 'professional-identity-claims-tests');
const db = getFirestore(app);
let sequence = 0;
const uid = () => `claim-test-${process.pid}-${++sequence}`;
const rpps = () => String(80000000000 + sequence).padStart(11, '0');
const result = (value) => ({status: 'verified', rpps: value,
  firstName: 'Test', lastName: 'EXEMPLE', professionCode: '70',
  professionLabel: 'Kinésithérapeute'});
const claim = (id, value) => claimVerifiedProfessionalIdentity({
  firestore: db, uid: id, result: result(value),
  expectedProfession: 'physiotherapist', secret,
  serverTimestamp: FieldValue.serverTimestamp,
});
async function profile(id, value, verified = false) {
  await db.collection('volunteers').doc(id).set({uid: id,
    profession: 'physiotherapist', rpps: value,
    ...(verified ? {professionalIdType: 'rpps', professionalIdValue: value,
      verificationStatus: 'verified', verificationSource: 'ans_rpps'} : {})});
}

before(() => assert.equal(process.env.GCLOUD_PROJECT, projectId));
after(async () => deleteApp(app));

test('concurrent different UIDs cannot verify one RPPS', async () => {
  const first = uid(), second = uid(), value = rpps();
  await Promise.all([profile(first, value), profile(second, value)]);
  const attempts = await Promise.allSettled([claim(first, value), claim(second, value)]);
  assert.equal(attempts.filter((x) => x.status === 'fulfilled').length, 1);
  assert.equal(attempts.filter((x) => x.status === 'rejected').length, 1);
  const owner = (await db.collection('professionalIdentityClaims')
    .doc(professionalIdentityClaimId(value, secret)).get()).data().uid;
  assert.ok([first, second].includes(owner));
  const verified = await db.collection('volunteers').where('rpps','==',value).get();
  assert.equal(verified.docs.filter((doc) => doc.data().verificationStatus === 'verified').length, 1);
});

test('same UID recovery and Auth change preserve the claim', async () => {
  const id = uid(), value = rpps();
  await profile(id, value);
  assert.equal(await claim(id, value), true);
  assert.equal(await claim(id, value), true);
  assert.equal((await db.collection('professionalIdentityClaims')
    .where('uid','==',id).get()).size, 1);
});

test('legacy verified duplicate blocks claim before backfill', async () => {
  const legacy = uid(), newcomer = uid(), value = rpps();
  await Promise.all([profile(legacy, value, true), profile(newcomer, value)]);
  await assert.rejects(() => claim(newcomer, value),
    (error) => error.code === 'already-exists');
  assert.equal((await db.collection('professionalIdentityClaims')
    .doc(professionalIdentityClaimId(value, secret)).get()).exists, false);
});

test('archived/deleted profile can release claim, active verified cannot', async () => {
  const id = uid(), value = rpps();
  await profile(id, value);
  await claim(id, value);
  await assert.rejects(() => releaseRetiredProfessionalIdentityClaim({
    firestore: db, uid: id, rpps: value, secret,
  }), (error) => error.code === 'failed-precondition');
  await db.collection('volunteers').doc(id).delete();
  assert.equal(await releaseRetiredProfessionalIdentityClaim({
    firestore: db, uid: id, rpps: value, secret,
  }), true);
  assert.equal(await releaseRetiredProfessionalIdentityClaim({
    firestore: db, uid: id, rpps: value, secret,
  }), false);
  const replacement = uid();
  await profile(replacement, value);
  assert.equal(await claim(replacement, value), true);
});

test('a client cannot choose or transfer a claim ID', async () => {
  const id = uid(), value = rpps();
  await profile(id, value);
  await claim(id, value);
  const other = uid();
  await profile(other, value);
  await assert.rejects(() => claim(other, value),
    (error) => error.code === 'already-exists');
  assert.equal((await db.collection('professionalIdentityClaims')
    .doc(professionalIdentityClaimId(value, secret)).get()).data().uid, id);
});
