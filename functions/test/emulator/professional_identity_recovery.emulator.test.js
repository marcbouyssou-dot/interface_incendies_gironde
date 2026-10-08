import assert from 'node:assert/strict';
import {after, test} from 'node:test';
import {deleteApp as deleteAdminApp, initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore, Timestamp} from 'firebase-admin/firestore';
import {deleteApp, initializeApp} from 'firebase/app';
import {
  applyActionCode, connectAuthEmulator, getAuth, sendEmailVerification,
  signInAnonymously, signInWithEmailAndPassword,
} from 'firebase/auth';

const projectId = 'demo-mobsante';
const authHost = process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
const adminApp = initializeAdminApp({projectId}, 'professional-identity-recovery');
const adminAuth = getAdminAuth(adminApp);
const db = getAdminFirestore(adminApp);
const clients = [];
let sequence = 0;

function client() {
  const app = initializeApp({projectId, apiKey: 'fake-api-key'},
    `recovery-client-${process.pid}-${++sequence}`);
  clients.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, `http://${authHost}`, {disableWarnings: true});
  return auth;
}

after(async () => {
  await Promise.all(clients.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

test('Admin recovery preserves anonymous UID and verified profile; owner verifies email', async (t) => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  assert.ok(process.env.FIREBASE_AUTH_EMULATOR_HOST);
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);

  const oldAuth = client();
  const anonymous = await signInAnonymously(oldAuth);
  const uid = anonymous.user.uid;
  const email = `recovery-${process.pid}-${sequence}@example.test`;
  const password = 'Emulator-only-password-42!';
  const profileRef = db.collection('volunteers').doc(uid);
  await profileRef.set({
    uid, profession: 'physiotherapist',
    professionalIdType: 'rpps', professionalIdValue: '70123456789',
    rpps: '70123456789', verificationStatus: 'verified',
    verificationSource: 'ans_rpps', verifiedFirstName: 'Test',
    verifiedLastName: 'EXEMPLE', verifiedProfessionCode: '70',
    verifiedProfessionLabel: 'Kinésithérapeute', verifiedAt: Timestamp.now(),
  });
  const before = await profileRef.get();
  assert.equal((await adminAuth.getUser(uid)).email, undefined);

  // Admin changes the existing Auth record without using the old session;
  // neither a custom token nor a second Professional is created.
  const updated = await adminAuth.updateUser(uid, {email, password});
  assert.equal(updated.uid, uid);
  assert.equal(updated.emailVerified, false);
  let oldSessionCanRefresh;
  try {
    await anonymous.user.getIdToken(true);
    oldSessionCanRefresh = true;
  } catch {
    oldSessionCanRefresh = false;
  }
  t.diagnostic(`old anonymous session refresh after Auth update: ${oldSessionCanRefresh}`);
  await oldAuth.signOut();

  const recoveredAuth = client();
  const signedIn = await signInWithEmailAndPassword(recoveredAuth, email, password);
  assert.equal(signedIn.user.uid, uid);
  assert.equal(signedIn.user.emailVerified, false);
  assert.deepEqual((await profileRef.get()).data(), before.data());
  assert.equal((await db.collection('volunteers').where('rpps', '==',
    '70123456789').get()).size, 1);

  await sendEmailVerification(signedIn.user);
  const response = await fetch(`http://${authHost}/emulator/v1/projects/${projectId}/oobCodes`);
  assert.equal(response.status, 200);
  const codes = (await response.json()).oobCodes;
  const code = codes.find((item) => item.email === email && item.requestType === 'VERIFY_EMAIL');
  assert.ok(code?.oobCode);
  await applyActionCode(recoveredAuth, code.oobCode);
  await signedIn.user.reload();
  assert.equal(signedIn.user.emailVerified, true);
  assert.equal((await adminAuth.getUser(uid)).emailVerified, true);

  await recoveredAuth.signOut();
  const reconnect = await signInWithEmailAndPassword(recoveredAuth, email, password);
  assert.equal(reconnect.user.uid, uid);
  assert.equal(reconnect.user.emailVerified, true);
  assert.deepEqual((await profileRef.get()).data(), before.data());

  const secondAnonymous = await signInAnonymously(client());
  await assert.rejects(() => adminAuth.updateUser(secondAnonymous.user.uid,
    {email, password}), (error) => error.code === 'auth/email-already-exists');
  assert.equal((await adminAuth.getUser(secondAnonymous.user.uid)).email, undefined);
  assert.equal((await db.collection('volunteers').where('rpps', '==',
    '70123456789').get()).size, 1);

  await adminAuth.revokeRefreshTokens(uid);
  let recoveredSessionCanRefreshAfterRevocation;
  try {
    await reconnect.user.getIdToken(true);
    recoveredSessionCanRefreshAfterRevocation = true;
  } catch {
    recoveredSessionCanRefreshAfterRevocation = false;
  }
  t.diagnostic(`recovered session refresh after explicit revocation: ${recoveredSessionCanRefreshAfterRevocation}`);
  await recoveredAuth.signOut();
  assert.equal((await signInWithEmailAndPassword(recoveredAuth, email, password))
    .user.uid, uid);
});
