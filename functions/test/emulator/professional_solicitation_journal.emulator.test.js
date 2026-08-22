import assert from 'node:assert/strict';
import {after, test} from 'node:test';

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
  collection,
  connectFirestoreEmulator,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  getFirestore,
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';
import {
  connectFunctionsEmulator,
  getFunctions,
  httpsCallable,
} from 'firebase/functions';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'solicitation-journal-tests');
const adminAuth = getAdminAuth(adminApp);
const adminDb = getAdminFirestore(adminApp);
const clientApps = [];
let sequence = 0;

function unique(prefix) {
  sequence += 1;
  return `${prefix}-${process.pid}-${sequence}`;
}

async function createUser() {
  const uid = unique('solicitation-professional');
  const email = `${uid}@example.test`;
  const password = 'Test-only-password-42!';
  await adminAuth.createUser({uid, email, password});
  return {uid, email, password};
}

async function client(user) {
  const app = initializeApp(
    {projectId, apiKey: 'fake-api-key'},
    unique('solicitation-client'),
  );
  clientApps.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  if (user !== null) {
    await signInWithEmailAndPassword(auth, user.email, user.password);
    await auth.currentUser.getIdToken(true);
  }
  const functions = getFunctions(app, 'europe-west1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  const firestore = getFirestore(app);
  connectFirestoreEmulator(firestore, '127.0.0.1', 8080);
  return {
    firestore,
    recordConsulted: httpsCallable(
      functions,
      'recordProfessionalSolicitationConsulted',
    ),
    listJournal: httpsCallable(
      functions,
      'listProfessionalSolicitationJournal',
    ),
  };
}

async function assertCode(action, code) {
  await assert.rejects(action, (error) => {
    assert.equal(error.code, `functions/${code}`);
    return true;
  });
}

async function seedContext({recipientUid, organizationId, suffix}) {
  const operationId = `operation-${suffix}`;
  const mobilizationId = `mobilization-${suffix}`;
  const missionId = `mission-${suffix}`;
  const notificationId = `notification-${suffix}`;
  await Promise.all([
    adminDb.collection('operations').doc(operationId).set({
      id: operationId,
      ownerOrganizationId: organizationId,
    }),
    adminDb.collection('mobilizations').doc(mobilizationId).set({
      id: mobilizationId,
      operationId,
    }),
    adminDb.collection('missions').doc(missionId).set({
      id: missionId,
      mobilizationId,
    }),
    adminDb.collection('notifications').doc(notificationId).set({
      notificationId,
      recipientUid,
      eventId: `event-${suffix}`,
      eventType: 'mission.published',
      category: 'compatible',
      missionId,
      mobilizationId,
      occurredAt: new Date('2026-08-20T10:00:00.000Z'),
      readAt: null,
    }),
  ]);
  return {operationId, mobilizationId, missionId, notificationId};
}

function journalEntry({entryId, recipientUid, organizationId, occurredAt}) {
  return {
    entryId,
    solicitationId: `solicitation-${entryId}`,
    recipientUid,
    factType: 'created',
    missionId: `mission-${entryId}`,
    organizationId,
    channel: 'in_app',
    occurredAt,
    source: 'notification_dispatch',
    sources: ['canonical_journal'],
    sourceRecordIds: [`source-${entryId}`],
    quality: 'complete',
    schemaVersion: 1,
    recordedAt: occurredAt,
  };
}

after(async () => {
  await Promise.all(clientApps.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

test('consulted and paginated journal are owner-only and organization-derived', async () => {
  const [professionalA, professionalB] = await Promise.all([
    createUser(),
    createUser(),
  ]);
  const contextA = await seedContext({
    recipientUid: professionalA.uid,
    organizationId: 'organization-a',
    suffix: unique('a'),
  });
  await seedContext({
    recipientUid: professionalB.uid,
    organizationId: 'organization-b',
    suffix: unique('b'),
  });
  const clientA = await client(professionalA);
  const clientB = await client(professionalB);
  const anonymous = await client(null);

  await assertCode(
    () => anonymous.recordConsulted({
      recipientUid: professionalA.uid,
      solicitationId: contextA.notificationId,
    }),
    'unauthenticated',
  );
  await assertCode(
    () => clientB.recordConsulted({
      recipientUid: professionalA.uid,
      solicitationId: contextA.notificationId,
    }),
    'permission-denied',
  );
  await assertCode(
    () => clientA.recordConsulted({
      recipientUid: professionalA.uid,
      solicitationId: contextA.notificationId,
      organizationId: 'organization-forged',
    }),
    'invalid-argument',
  );

  const first = await clientA.recordConsulted({
    recipientUid: professionalA.uid,
    solicitationId: contextA.notificationId,
  });
  const retry = await clientA.recordConsulted({
    recipientUid: professionalA.uid,
    solicitationId: contextA.notificationId,
  });
  assert.equal(first.data.created, true);
  assert.equal(retry.data.created, false);

  const consultedSnapshot = await adminDb
    .collection('professionalSolicitationJournal')
    .where('recipientUid', '==', professionalA.uid)
    .where('factType', '==', 'consulted')
    .get();
  assert.equal(consultedSnapshot.size, 1);
  const consulted = consultedSnapshot.docs[0].data();
  assert.equal(consulted.organizationId, 'organization-a');
  assert.equal(consulted.operationId, contextA.operationId);
  assert.equal(consulted.mobilizationId, contextA.mobilizationId);
  assert.equal(consulted.source, 'consultation_callable');

  const fixedEntries = [
    ['page-entry-3', new Date('2030-01-03T00:00:00.000Z')],
    ['page-entry-2', new Date('2030-01-03T00:00:00.000Z')],
    ['page-entry-1', new Date('2030-01-01T00:00:00.000Z')],
  ];
  await Promise.all(fixedEntries.map(([entryId, occurredAt]) =>
    adminDb.collection('professionalSolicitationJournal').doc(entryId).set(
      journalEntry({
        entryId,
        recipientUid: professionalA.uid,
        organizationId: 'organization-a',
        occurredAt,
      }),
    )));
  await adminDb.collection('professionalSolicitationJournal')
    .doc('organization-b-entry')
    .set(journalEntry({
      entryId: 'organization-b-entry',
      recipientUid: professionalB.uid,
      organizationId: 'organization-b',
      occurredAt: new Date('2031-01-01T00:00:00.000Z'),
    }));

  const firstPage = await clientA.listJournal({
    recipientUid: professionalA.uid,
    limit: 2,
  });
  assert.deepEqual(
    firstPage.data.entries.map((entry) => entry.entryId),
    ['page-entry-3', 'page-entry-2'],
  );
  assert.equal(firstPage.data.nextCursor.entryId, 'page-entry-2');
  const secondPage = await clientA.listJournal({
    recipientUid: professionalA.uid,
    limit: 2,
    cursor: firstPage.data.nextCursor,
  });
  assert.equal(secondPage.data.entries[0].entryId, 'page-entry-1');
  assert.equal(
    secondPage.data.entries.some(
      (entry) => entry.organizationId === 'organization-b',
    ),
    false,
  );
  await assertCode(
    () => clientB.listJournal({recipientUid: professionalA.uid}),
    'permission-denied',
  );

  const consultedRef = doc(
    clientA.firestore,
    `professionalSolicitationJournal/${consultedSnapshot.docs[0].id}`,
  );
  await assert.rejects(() => getDoc(consultedRef));
  await assert.rejects(() => setDoc(
    doc(clientA.firestore, 'professionalSolicitationJournal/forged'),
    {recipientUid: professionalA.uid},
  ));
  await assert.rejects(() => updateDoc(consultedRef, {factType: 'created'}));
  await assert.rejects(() => deleteDoc(consultedRef));
  await assert.rejects(() => getDocs(query(
    collection(clientA.firestore, 'professionalSolicitationJournal'),
    where('recipientUid', '==', professionalA.uid),
  )));
});
