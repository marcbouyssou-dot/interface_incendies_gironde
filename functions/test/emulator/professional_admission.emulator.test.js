import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';
import {deleteApp as deleteAdminApp, initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore, Timestamp} from 'firebase-admin/firestore';
import {deleteApp, initializeApp} from 'firebase/app';
import {EmailAuthProvider, connectAuthEmulator, getAuth, linkWithCredential, signInAnonymously, signInWithEmailAndPassword} from 'firebase/auth';
import {collection, connectFirestoreEmulator, deleteField, doc, getDoc, getDocs, getFirestore, query, serverTimestamp, setDoc, updateDoc, where, writeBatch} from 'firebase/firestore';
import {connectFunctionsEmulator, getFunctions, httpsCallable} from 'firebase/functions';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'professional-admission-tests');
const adminAuth = getAdminAuth(adminApp);
const adminDb = getAdminFirestore(adminApp);
const apps = [];
let sequence = 0;
const unique = (label) => `${label}-${process.pid}-${++sequence}`;

before(async () => {
  assert.equal(process.env.GCLOUD_PROJECT, projectId);
  await adminDb.doc('platform/config').set({admissionMode: 'invitation_only'}, {merge: true});
});
after(async () => {
  await adminDb.doc('platform/config').set({admissionMode: 'open'}, {merge: true});
  await Promise.all(apps.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

async function actor({administrator = false, verified = false, emailVerified = true,
  withProfile = true, termsAccepted = true,
  profession = 'physiotherapist'} = {}) {
  const uid = unique('actor');
  const email = `${uid}@example.test`;
  const password = 'Test-only-password-42!';
  await adminAuth.createUser({uid, email, password, emailVerified});
  if (emailVerified && termsAccepted) {
    await adminDb.collection('termsAcceptances').doc(uid).set({
      uid, acceptedVersion: 'beta-v1', acceptedAt: Timestamp.now(),
    });
    await adminAuth.setCustomUserClaims(uid, {cguVersion: 'beta-v1'});
  }
  if (administrator) {
    await adminDb.collection('platformAdministrators').doc(uid).set({active: true});
  } else if (withProfile) {
    await adminDb.collection('volunteers').doc(uid).set({
      uid, profession, firstName: 'Alice', lastName: 'EXEMPLE', phone: '', email,
      equipment: [], professionalIdType: 'rpps', professionalIdValue: '10123456789',
      rpps: '10123456789', verificationStatus: verified ? 'verified' : 'unverified',
      ...(verified ? {
        verificationSource: 'ans_rpps', verifiedFirstName: 'Alice',
        verifiedLastName: 'EXEMPLE', verifiedProfessionCode: '70',
        verifiedProfessionLabel: 'Kinésithérapeute', verifiedAt: new Date(),
      } : {}),
      createdAt: new Date(), updatedAt: new Date(),
    });
  }
  const app = initializeApp({projectId, apiKey: 'fake-api-key'}, unique('client'));
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  await signInWithEmailAndPassword(auth, email, password);
  const firestore = getFirestore(app);
  connectFirestoreEmulator(firestore, '127.0.0.1',
    Number(process.env.MOBSANTE_TEST_FIRESTORE_PORT ?? 8080));
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  return {
    uid, email, auth, firestore,
    create: httpsCallable(functions, 'createProfessionalInvitation'),
    send: httpsCallable(functions, 'sendProfessionalInvitationEmail'),
    status: httpsCallable(functions, 'getProfessionalInvitationStatus'),
    list: httpsCallable(functions, 'listProfessionalInvitations'),
    redeem: httpsCallable(functions, 'redeemProfessionalInvitation'),
    acceptTerms: httpsCallable(functions, 'acceptBetaTerms'),
    prepare: httpsCallable(functions, 'prepareProfessionalRegistration'),
    revoke: httpsCallable(functions, 'revokeProfessionalInvitation'),
    missionLocations: httpsCallable(functions, 'listProfessionalMissionLocations'),
  };
}

async function action() {
  const operationId = unique('operation');
  const organizationId = unique('organization');
  const mobilizationId = unique('mobilization');
  const missionId = unique('mission');
  await adminDb.collection('operations').doc(operationId).set({
    id: operationId, ownerOrganizationId: organizationId,
    status: 'active', purpose: 'operational', visibility: 'platform',
  });
  await adminDb.collection('mobilizations').doc(mobilizationId).set({
    id: mobilizationId, operationId, status: 'active',
  });
  await adminDb.collection('missions').doc(missionId).set({
    id: missionId, mobilizationId, locationId: unique('location'),
    isActive: true, status: 'critical',
    startAt: new Date(Date.now() + 3_600_000),
    endAt: new Date(Date.now() + 7_200_000),
    requiredMk: 1, registeredMk: 0, requiredPp: 0, registeredPp: 0,
    requiredByProfession: {physiotherapist: 1, nurse: 0},
    registeredByProfession: {physiotherapist: 0, nurse: 0},
    updatedAt: new Date(),
  });
  return {operationId, organizationId, mobilizationId, missionId};
}

async function invitation(admin, target, recipient, profession = 'physiotherapist') {
  const response = await admin.create({
    organizationId: target.organizationId, operationId: target.operationId,
    expectedProfession: profession, targetEmail: ` ${recipient.email.toUpperCase()} `,
    expiresAt: new Date(Date.now() + 86_400_000).toISOString(),
  });
  return response.data;
}

async function denied(operation) {
  await assert.rejects(operation, (error) =>
    error.code === 'permission-denied'
      || error.code === 'functions/unauthenticated'
      || error.code === 'functions/failed-precondition'
      || error.code === 'functions/permission-denied'
      || error.code === 'functions/already-exists');
}

test('closed registration requires a live invitation bound to verified email and profession', async () => {
  const admin = await actor({administrator: true});
  const newcomer = await actor({withProfile: false});
  const other = await actor({withProfile: false});
  const target = await action();
  const issued = await invitation(admin, target, newcomer);
  const profile = (uid, email, profession = 'physiotherapist') => ({
    uid, email, profession, firstName: 'Alice', lastName: 'EXEMPLE',
    phone: '', equipment: [], verificationStatus: 'unverified',
    rpps: '10123456789', professionalIdType: 'rpps',
    professionalIdValue: '10123456789',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  const profileRef = doc(newcomer.firestore, 'volunteers', newcomer.uid);
  await denied(() => setDoc(profileRef, profile(newcomer.uid, newcomer.email)));
  await denied(() => other.prepare({code: issued.code}));
  await newcomer.prepare({code: issued.code});
  await denied(() => getDoc(doc(newcomer.firestore,
    'professionalRegistrationPermits', newcomer.uid)));
  await denied(() => setDoc(profileRef,
    profile(newcomer.uid, newcomer.email, 'nurse')));
  await assert.rejects(() => newcomer.redeem({code: issued.code}),
    (error) => error.code === 'functions/permission-denied');
  await setDoc(profileRef, profile(newcomer.uid, newcomer.email));
  assert.equal((await getDoc(profileRef)).exists(), true);
  await denied(() => newcomer.redeem({code: issued.code}));
});

test('Admin can send one individual invitation email without exposing its code in status', async () => {
  const admin = await actor({administrator: true});
  const recipient = await actor({verified: true});
  const target = await action();
  const issued = await invitation(admin, target, recipient);
  await denied(() => recipient.send({code: issued.code}));
  assert.equal((await admin.send({code: issued.code})).data.alreadySent, false);
  assert.equal((await admin.send({code: issued.code})).data.alreadySent, true);
  const status = (await admin.status({invitationId: issued.invitationId})).data;
  assert.equal(status.deliveryStatus, 'sent');
  assert.equal(JSON.stringify(status).includes(issued.code), false);
  await denied(() => recipient.list({}));
  const listed = (await admin.list({})).data.invitations;
  assert.equal(listed.some((item) => item.invitationId === issued.invitationId
    && item.deliveryStatus === 'sent'), true);
  assert.equal(JSON.stringify(listed).includes(issued.code), false);
});

test('revocation and expiration close prepared registration before profile creation', async () => {
  const admin = await actor({administrator: true});
  const newcomer = await actor({withProfile: false});
  const target = await action();
  const issued = await invitation(admin, target, newcomer);
  await newcomer.prepare({code: issued.code});
  await admin.revoke({invitationId: issued.invitationId});
  await denied(() => setDoc(doc(newcomer.firestore, 'volunteers', newcomer.uid), {
    uid: newcomer.uid, email: newcomer.email, profession: 'physiotherapist',
    firstName: 'Alice', lastName: 'EXEMPLE', phone: '', equipment: [],
    rpps: '10123456789', professionalIdType: 'rpps',
    professionalIdValue: '10123456789',
    verificationStatus: 'unverified', createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await denied(() => newcomer.prepare({code: issued.code}));
  const expiring = await actor({withProfile: false});
  const shortLived = await invitation(admin, target, expiring);
  await expiring.prepare({code: shortLived.code});
  await adminDb.collection('professionalRegistrationPermits').doc(expiring.uid)
    .update({expiresAt: Timestamp.fromMillis(Date.now() - 1000)});
  await denied(() => setDoc(doc(expiring.firestore, 'volunteers', expiring.uid), {
    uid: expiring.uid, email: expiring.email, profession: 'physiotherapist',
    firstName: 'Alice', lastName: 'EXEMPLE', phone: '', equipment: [],
    rpps: '10123456789', professionalIdType: 'rpps',
    professionalIdValue: '10123456789', verificationStatus: 'unverified',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  }));
});

test('transferred link cannot be consumed and target can use it for one Action', async () => {
  const admin = await actor({administrator: true});
  const targetUser = await actor({verified: true});
  const otherUser = await actor({verified: true});
  const targetA = await action();
  const targetB = await action();
  const issued = await invitation(admin, targetA, targetUser);
  assert.equal((await admin.status({invitationId: issued.invitationId})).data
    .targetEmailNormalized, targetUser.email);
  let transferredError;
  await assert.rejects(() => otherUser.redeem({code: issued.code}), (error) => {
    transferredError = error;
    return error.code === 'functions/permission-denied';
  });
  await assert.rejects(() => otherUser.redeem({code: 'x'.repeat(43)}), (error) =>
    error.code === transferredError.code && error.message === transferredError.message);
  assert.equal((await admin.status({invitationId: issued.invitationId})).data.status, 'valid');
  assert.equal((await adminDb.collection('professionalAdmissions')
    .doc(`${targetA.operationId}_${otherUser.uid}`).get()).exists, false);
  await denied(() => otherUser.status({invitationId: issued.invitationId}));
  await denied(() => getDoc(doc(otherUser.firestore, 'professionalInvitations', issued.invitationId)));
  await denied(() => getDoc(doc(targetUser.firestore, 'professionalInvitations', issued.invitationId)));
  await denied(() => getDoc(doc(admin.firestore, 'professionalInvitations', issued.invitationId)));
  await targetUser.redeem({code: issued.code});
  assert.equal((await targetUser.redeem({code: issued.code})).data.alreadyRedeemed, true);
  await denied(() => getDoc(doc(targetUser.firestore, 'missions', targetB.missionId)));
  const second = await invitation(admin, targetB, targetUser);
  await targetUser.redeem({code: second.code});
  assert.equal((await getDoc(doc(targetUser.firestore, 'missions', targetB.missionId))).exists(), true);
});

test('unverified email and anonymous identity cannot redeem', async () => {
  const admin = await actor({administrator: true});
  const targetUser = await actor({verified: true, emailVerified: false});
  const target = await action();
  const issued = await invitation(admin, target, targetUser);
  await denied(() => targetUser.redeem({code: issued.code}));
  assert.equal((await admin.status({invitationId: issued.invitationId})).data.status, 'valid');
  await adminAuth.updateUser(targetUser.uid, {emailVerified: true});
  await adminDb.collection('termsAcceptances').doc(targetUser.uid).set({
    uid: targetUser.uid, acceptedVersion: 'beta-v1', acceptedAt: Timestamp.now(),
  });
  await adminAuth.setCustomUserClaims(targetUser.uid, {cguVersion: 'beta-v1'});
  await targetUser.auth.currentUser.getIdToken(true);
  const anonymousApp = initializeApp({projectId, apiKey: 'fake-api-key'}, unique('anonymous'));
  apps.push(anonymousApp);
  const anonymousAuth = getAuth(anonymousApp);
  connectAuthEmulator(anonymousAuth, 'http://127.0.0.1:9099', {disableWarnings: true});
  const anonymousFunctions = getFunctions(anonymousApp, 'europe-west1');
  connectFunctionsEmulator(anonymousFunctions, '127.0.0.1', 5001);
  const anonymousRedeem = httpsCallable(anonymousFunctions, 'redeemProfessionalInvitation');
  await denied(() => anonymousRedeem({code: issued.code}));
  await signInAnonymously(anonymousAuth);
  await denied(() => anonymousRedeem({code: issued.code}));
  await targetUser.redeem({code: issued.code});
});

test('verified Professional may redeem alongside management capabilities', async () => {
  const admin = await actor({administrator: true});
  for (const capability of ['site_manager', 'coordinator', 'platform_admin']) {
    const professional = await actor({verified: true});
    if (capability === 'platform_admin') {
      await adminDb.collection('platformAdministrators').doc(professional.uid)
        .set({active: true});
    } else {
      await adminDb.collection('roles').doc(professional.uid)
        .set({role: capability, active: true,
          locationIds: capability === 'site_manager' ? ['site-x'] : []});
    }
    const target = await action();
    const issued = await invitation(admin, target, professional);
    await professional.redeem({code: issued.code});
    const admission = (await adminDb.collection('professionalAdmissions')
      .doc(`${target.operationId}_${professional.uid}`).get()).data();
    assert.equal(admission.uid, professional.uid);
    assert.equal(admission.operationId, target.operationId);
  }
});

test('management capabilities neither admit nor bypass Professional engagement', async () => {
  const admin = await actor({administrator: true});
  for (const capability of ['site_manager', 'coordinator', 'platform_admin', 'all']) {
    const professional = await actor({verified: true});
    const allowed = await action();
    const other = await action();
    if (capability === 'site_manager' || capability === 'all') {
      await adminDb.collection('roles').doc(professional.uid).set({
        role: capability === 'all' ? 'coordinator' : 'site_manager',
        roles: capability === 'all'
          ? ['coordinator', 'site_manager'] : ['site_manager'],
        schemaVersion: 2, active: true,
        locationIds: [(await adminDb.collection('missions')
          .doc(allowed.missionId).get()).data().locationId],
      });
    } else if (capability === 'coordinator') {
      await adminDb.collection('roles').doc(professional.uid).set({
        role: 'coordinator', active: true, locationIds: [],
      });
    }
    if (capability === 'platform_admin' || capability === 'all') {
      await adminDb.collection('platformAdministrators')
        .doc(professional.uid).set({active: true});
    }
    if (capability === 'site_manager' || capability === 'all') {
      // Creating a mission as a manager does not grant Professional admission.
      await adminDb.collection('missions').doc(allowed.missionId)
        .update({createdBy: professional.uid});
    }
    await denied(() => engage(professional, allowed));
    const issued = await invitation(admin, allowed, professional);
    await professional.redeem({code: issued.code});
    await denied(() => engage(professional, other));
    await engage(professional, allowed);
    assert.equal((await getDoc(doc(professional.firestore, 'engagements',
      `${allowed.missionId}_${professional.uid}`))).exists(), true);
    const batch = writeBatch(professional.firestore);
    batch.update(doc(professional.firestore, 'engagements',
      `${allowed.missionId}_${professional.uid}`), {
      status: 'cancelled', updatedAt: serverTimestamp(),
    });
    batch.update(doc(professional.firestore, 'missions', allowed.missionId), {
      registeredMk: 0,
      registeredByProfession: {physiotherapist: 0, nurse: 0},
      status: 'critical', updatedAt: serverTimestamp(),
    });
    await batch.commit();
    assert.equal((await adminDb.collection('engagements')
      .doc(`${allowed.missionId}_${professional.uid}`).get()).data().status,
    'cancelled');
  }
});

test('Admin capability cannot replace Professional verification, profession or active Action', async () => {
  const admin = await actor({administrator: true});
  const professional = await actor({verified: true});
  await adminDb.collection('platformAdministrators')
    .doc(professional.uid).set({active: true});
  const target = await action();
  const issued = await invitation(admin, target, professional);
  await professional.redeem({code: issued.code});
  const profile = adminDb.collection('volunteers').doc(professional.uid);
  await profile.update({verificationStatus: 'unverified'});
  await denied(() => engage(professional, target));
  await profile.update({verificationStatus: 'verified', profession: 'nurse'});
  await denied(() => engage(professional, target));
  await profile.update({profession: 'physiotherapist'});
  await adminDb.collection('operations').doc(target.operationId).update({
    status: 'completed', purpose: 'demonstration',
  });
  await denied(() => engage(professional, target));
});

test('linking an anonymous professional keeps the UID and needs email verification', async () => {
  const admin = await actor({administrator: true});
  const target = await action();
  const app = initializeApp({projectId, apiKey: 'fake-api-key'}, unique('linked-client'));
  apps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  const anonymous = await signInAnonymously(auth);
  const uid = anonymous.user.uid;
  const email = `${unique('linked')}@example.test`;
  await adminDb.collection('volunteers').doc(uid).set({
    uid, profession: 'physiotherapist',
    professionalIdType: 'rpps', professionalIdValue: '10123456789',
    rpps: '10123456789', verificationStatus: 'verified',
    verificationSource: 'ans_rpps', verifiedFirstName: 'Alice',
    verifiedLastName: 'EXEMPLE', verifiedProfessionCode: '70',
    verifiedProfessionLabel: 'Kinésithérapeute', verifiedAt: Timestamp.now(),
  });
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  const redeem = httpsCallable(functions, 'redeemProfessionalInvitation');
  const issued = await invitation(admin, target, {email});
  await denied(() => redeem({code: issued.code}));
  await linkWithCredential(anonymous.user, EmailAuthProvider.credential(
    email, 'Test-only-password-42!'));
  assert.equal(auth.currentUser.uid, uid);
  await denied(() => redeem({code: issued.code}));
  await adminAuth.updateUser(uid, {emailVerified: true});
  await adminDb.collection('termsAcceptances').doc(uid).set({
    uid, acceptedVersion: 'beta-v1', acceptedAt: Timestamp.now(),
  });
  await adminAuth.setCustomUserClaims(uid, {cguVersion: 'beta-v1'});
  await auth.currentUser.getIdToken(true);
  assert.equal((await redeem({code: issued.code})).data.operationId, target.operationId);
  assert.equal((await adminDb.collection('professionalAdmissions')
    .doc(`${target.operationId}_${uid}`).get()).data().uid, uid);
});

test('current CGU acceptance gates admission and a later mandatory version', async () => {
  const admin = await actor({administrator: true});
  const professional = await actor({verified: true, termsAccepted: false});
  const target = await action();
  const issued = await invitation(admin, target, professional);
  await denied(() => professional.redeem({code: issued.code}));
  await denied(() => setDoc(doc(professional.firestore,
    'termsAcceptances', professional.uid), {
    uid: professional.uid, acceptedVersion: 'beta-v1',
    acceptedAt: serverTimestamp(),
  }));
  await professional.acceptTerms({version: 'beta-v1'});
  await professional.auth.currentUser.getIdToken(true);
  const receipt = (await adminDb.collection('termsAcceptances')
    .doc(professional.uid).get()).data();
  assert.equal(receipt.uid, professional.uid);
  assert.equal(receipt.acceptedVersion, 'beta-v1');
  assert.ok(receipt.acceptedAt instanceof Timestamp);
  const other = await actor({verified: true, termsAccepted: false});
  await denied(() => getDoc(doc(other.firestore,
    'termsAcceptances', professional.uid)));
  await denied(() => setDoc(doc(other.firestore,
    'termsAcceptances', professional.uid), {
    uid: professional.uid, acceptedVersion: 'beta-v1',
    acceptedAt: serverTimestamp(),
  }));
  assert.equal((await adminDb.collection('termsAcceptances')
    .doc(other.uid).get()).exists, false);
  await professional.redeem({code: issued.code});
  assert.equal((await getDoc(doc(professional.firestore, 'missions',
    target.missionId))).exists(), true);
  await adminDb.doc('platform/config').set({mandatoryCguVersion: 'beta-v2'}, {merge: true});
  try {
    await denied(() => getDoc(doc(professional.firestore, 'missions', target.missionId)));
    await denied(() => professional.acceptTerms({version: 'beta-v1'}));
    await professional.acceptTerms({version: 'beta-v2'});
    await professional.auth.currentUser.getIdToken(true);
    assert.equal((await getDoc(doc(professional.firestore, 'missions',
      target.missionId))).exists(), true);
  } finally {
    await adminDb.doc('platform/config').set({mandatoryCguVersion: 'beta-v1'}, {merge: true});
  }
});

function engage(actor, target) {
  const batch = writeBatch(actor.firestore);
  batch.set(doc(actor.firestore, 'engagements', `${target.missionId}_${actor.uid}`), {
    missionId: target.missionId, mobilizationId: target.mobilizationId,
    volunteerId: actor.uid, profession: 'physiotherapist', status: 'confirmed',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  batch.update(doc(actor.firestore, 'missions', target.missionId), {
    registeredMk: 1, registeredByProfession: {physiotherapist: 1, nurse: 0},
    status: 'complete', updatedAt: serverTimestamp(),
  });
  return batch.commit();
}

test('invitation-only requires a scoped grant and verified matching identity', async (t) => {
  const admin = await actor({administrator: true});
  const verified = await actor({verified: true});
  const unverified = await actor();
  const targetA = await action();
  const targetB = await action();
  t.diagnostic('seeded');
  await denied(() => getDoc(doc(verified.firestore, 'missions', targetA.missionId)));
  await denied(() => engage(verified, targetA));
  t.diagnostic('uninvited denied');
  const first = await invitation(admin, targetA, unverified);
  await denied(() => unverified.redeem({code: first.code}));
  t.diagnostic('unverified denied');
  await denied(() => getDoc(doc(unverified.firestore, 'missions', targetA.missionId)));
  await denied(() => engage(unverified, targetA));
  t.diagnostic('unverified denied');
  const second = await invitation(admin, targetA, verified);
  await verified.redeem({code: second.code});
  t.diagnostic('verified redeemed');
  const storedAdmission = (await adminDb.collection('professionalAdmissions')
    .doc(`${targetA.operationId}_${verified.uid}`).get()).data();
  t.diagnostic(`grant: ${JSON.stringify({
    exists: !!storedAdmission,
    status: storedAdmission?.status,
    operationMatches: storedAdmission?.operationId === targetA.operationId,
    organizationMatches: storedAdmission?.organizationId === targetA.organizationId,
    profession: storedAdmission?.profession,
    expiresAt: storedAdmission?.expiresAt?.toMillis(),
  })}`);
  assert.equal((await getDoc(doc(verified.firestore, 'professionalAdmissions',
    `${targetA.operationId}_${verified.uid}`))).exists(), true);
  t.diagnostic('self grant read');
  await updateDoc(doc(verified.firestore, 'volunteers', verified.uid), {
    phone: '', updatedAt: serverTimestamp(),
  });
  assert.equal((await adminDb.collection('volunteers').doc(verified.uid).get())
    .data().admissionScopes[targetA.operationId].status, 'active');
  assert.equal((await getDoc(doc(verified.firestore, 'missions', targetA.missionId))).exists(), true);
  await denied(() => getDoc(doc(verified.firestore, 'missions', targetB.missionId)));
  await denied(() => engage(verified, targetB));
  await denied(() => updateDoc(doc(verified.firestore, 'volunteers', verified.uid), {
    admissionScopes: {
      [targetB.operationId]: {
        status: 'active', profession: 'physiotherapist',
        organizationId: targetB.organizationId,
        expiresAt: new Date(Date.now() + 86_400_000),
      },
    },
  }));
  await denied(() => setDoc(doc(verified.firestore, 'professionalAdmissions',
    `${targetB.operationId}_${verified.uid}`), {
    uid: verified.uid, operationId: targetB.operationId, status: 'active',
  }));
  await engage(verified, targetA);
  assert.equal((await adminDb.collection('engagements')
    .doc(`${targetA.missionId}_${verified.uid}`).get()).exists, true);
  assert.equal((await verified.redeem({code: second.code})).data.alreadyRedeemed, true);
  await admin.revoke({invitationId: second.invitationId});
  // Revocation ends discovery, while the existing participant retains the
  // current mission context needed to review their own engagement.
  assert.equal((await getDoc(doc(verified.firestore, 'missions',
    targetA.missionId))).exists(), true);
});

test('expired, revoked and wrong-profession invitations cannot admit', async () => {
  const admin = await actor({administrator: true});
  const professional = await actor({verified: true});
  const target = await action();
  const expired = await invitation(admin, target, professional);
  await adminDb.collection('professionalInvitations').doc(expired.invitationId)
    .update({expiresAt: Timestamp.fromMillis(Date.now() - 1000)});
  await denied(() => professional.redeem({code: expired.code}));
  const revoked = await invitation(admin, target, professional);
  await admin.revoke({invitationId: revoked.invitationId});
  await denied(() => professional.redeem({code: revoked.code}));
  const wrong = await invitation(admin, target, professional, 'nurse');
  await denied(() => professional.redeem({code: wrong.code}));
});

test('an invited professional resolves only the private Action and own admission', async () => {
  const admin = await actor({administrator: true});
  const professional = await actor({verified: true});
  const target = await action();
  const other = await action();
  await adminDb.collection('operations').doc(target.operationId)
    .update({visibility: 'organization_private'});
  await adminDb.collection('operations').doc(other.operationId)
    .update({visibility: 'organization_private'});
  await denied(() => getDoc(doc(professional.firestore, 'missions', target.missionId)));
  const issued = await invitation(admin, target, professional);
  await professional.redeem({code: issued.code});
  assert.equal((await getDocs(query(
    collection(professional.firestore, 'professionalAdmissions'),
    where('uid', '==', professional.uid),
  ))).size, 1);
  assert.equal((await getDocs(query(
    collection(professional.firestore, 'mobilizations'),
    where('operationId', 'in', [target.operationId]),
    where('status', '==', 'active'),
  ))).size, 1);
  assert.equal((await getDoc(doc(professional.firestore, 'operations', target.operationId))).exists(), true);
  await denied(() => getDoc(doc(professional.firestore, 'operations', other.operationId)));
  assert.equal((await getDoc(doc(professional.firestore, 'missions', target.missionId))).exists(), true);
  await denied(() => getDoc(doc(professional.firestore, 'missions', other.missionId)));
});

test('open mode still requires RPPS verification', async () => {
  const verified = await actor({verified: true});
  const unverified = await actor();
  const target = await action();
  await adminDb.doc('platform/config').set({admissionMode: 'open'}, {merge: true});
  assert.equal((await getDoc(doc(verified.firestore, 'missions', target.missionId))).exists(), true);
  await denied(() => engage(unverified, target));
  await adminDb.doc('platform/config').set({admissionMode: 'invitation_only'}, {merge: true});
});

test('Admin can stage an invitation before switching to invitation-only', async () => {
  const admin = await actor({administrator: true});
  const professional = await actor({verified: true});
  const target = await action();
  const originalProfile = (await adminDb.collection('volunteers')
    .doc(professional.uid).get()).data();
  await adminDb.doc('platform/config').set({admissionMode: 'open'}, {merge: true});
  const issued = await invitation(admin, target, professional);
  assert.equal((await adminDb.collection('professionalAdmissions')
    .doc(`${target.operationId}_${professional.uid}`).get()).exists, false);
  await denied(() => professional.redeem({code: issued.code}));
  await adminDb.doc('platform/config').set({admissionMode: 'invitation_only'}, {merge: true});
  await denied(() => getDoc(doc(professional.firestore, 'missions', target.missionId)));
  await professional.redeem({code: issued.code});
  const transitionedProfile = (await adminDb.collection('volunteers')
    .doc(professional.uid).get()).data();
  assert.equal(transitionedProfile.uid, professional.uid);
  assert.equal(transitionedProfile.rpps, originalProfile.rpps);
  assert.equal(transitionedProfile.verificationStatus, 'verified');
  assert.equal((await getDoc(doc(professional.firestore, 'missions', target.missionId))).exists(), true);
});

test('mission site details are projected only for the invited Action', async () => {
  const admin = await actor({administrator: true});
  const professional = await actor({verified: true});
  const unverified = await actor();
  const target = await action();
  const other = await action();
  const locationId = (await adminDb.collection('missions').doc(target.missionId)
    .get()).data().locationId;
  await adminDb.collection('locations').doc(locationId).set({
    name: 'Site de test', address: '1 rue de test', contactPhone: '0102030405',
    privateNote: 'Must never leave the server',
  });
  await denied(() => professional.missionLocations({missionIds: [target.missionId]}));
  await denied(() => unverified.missionLocations({missionIds: [target.missionId]}));
  const issued = await invitation(admin, target, professional);
  await professional.redeem({code: issued.code});
  const result = (await professional.missionLocations({missionIds: [target.missionId]})).data;
  assert.deepEqual(result.locations, [{
    id: locationId, name: 'Site de test', address: '1 rue de test',
    contactPhone: '0102030405',
  }]);
  await denied(() => professional.missionLocations({missionIds: [other.missionId]}));
  await denied(() => professional.missionLocations({missionIds: [target.missionId, other.missionId]}));
  await denied(() => getDoc(doc(professional.firestore, 'locations', locationId)));
  await admin.revoke({invitationId: issued.invitationId});
  await denied(() => professional.missionLocations({missionIds: [target.missionId]}));
});

test('targeting point and radius belong only to the professional', async () => {
  const owner = await actor();
  const other = await actor();
  const responsible = await actor();
  const coordinator = await actor();
  const admin = await actor({administrator: true});
  await adminDb.collection('roles').doc(responsible.uid)
    .set({role: 'site_manager', active: true, locationIds: ['site-a']});
  await adminDb.collection('roles').doc(coordinator.uid)
    .set({role: 'coordinator', active: true, locationIds: ['*']});
  const reference = doc(owner.firestore, 'professionalTargeting', owner.uid);
  await setDoc(reference, {
    uid: owner.uid, enabled: false, radiusKm: 20,
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
  });
  assert.equal((await getDoc(reference)).data().enabled, false);
  await denied(() => updateDoc(reference, {
    enabled: true, updatedAt: serverTimestamp(),
  }));
  await denied(() => updateDoc(reference, {
    radiusKm: 5, updatedAt: serverTimestamp(),
  }));
  await updateDoc(reference, {
    enabled: true, latitude: 44.84, longitude: -0.58,
    source: 'selected_point', geocodingProvider: 'ign_geoplateforme',
    geocodingPrecision: 'housenumber', confirmedAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  assert.equal((await getDoc(reference)).data().radiusKm, 20);
  await denied(() => updateDoc(reference, {
    latitude: 45.1, updatedAt: serverTimestamp(),
  }));
  await updateDoc(reference, {
    enabled: false, latitude: deleteField(), longitude: deleteField(),
    source: deleteField(), geocodingProvider: deleteField(),
    geocodingPrecision: deleteField(), confirmedAt: deleteField(),
    updatedAt: serverTimestamp(),
  });
  assert.equal((await getDoc(reference)).data().enabled, false);
  assert.equal((await getDoc(reference)).data().latitude, undefined);
  await denied(() => getDoc(doc(other.firestore, 'professionalTargeting', owner.uid)));
  await denied(() => getDoc(doc(responsible.firestore, 'professionalTargeting', owner.uid)));
  await denied(() => getDoc(doc(coordinator.firestore, 'professionalTargeting', owner.uid)));
  await denied(() => getDoc(doc(admin.firestore, 'professionalTargeting', owner.uid)));
  await denied(() => getDocs(collection(other.firestore, 'professionalTargeting')));
  const publicApp = initializeApp({projectId, apiKey: 'fake-api-key'}, unique('public'));
  apps.push(publicApp);
  const publicFirestore = getFirestore(publicApp);
  connectFirestoreEmulator(publicFirestore, '127.0.0.1',
    Number(process.env.MOBSANTE_TEST_FIRESTORE_PORT ?? 8080));
  await denied(() => getDoc(doc(publicFirestore, 'professionalTargeting', owner.uid)));
  await denied(() => setDoc(doc(other.firestore, 'professionalTargeting', owner.uid), {
    uid: owner.uid, enabled: false, createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  }));
  await denied(() => updateDoc(reference, {
    radiusKm: 1000, updatedAt: serverTimestamp(),
  }));
});
