import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';
import {deleteApp as deleteAdminApp, initializeApp as initializeAdminApp} from 'firebase-admin/app';
import {getAuth as getAdminAuth} from 'firebase-admin/auth';
import {getFirestore as getAdminFirestore} from 'firebase-admin/firestore';
import {deleteApp, initializeApp} from 'firebase/app';
import {connectAuthEmulator, getAuth, signInWithEmailAndPassword} from 'firebase/auth';
import {collection, connectFirestoreEmulator, doc, getDoc, getDocs,
  getFirestore, query, setDoc, where} from 'firebase/firestore';

const projectId = 'demo-mobsante';
const adminApp = initializeAdminApp({projectId}, 'demo-history-read-test');
const adminAuth = getAdminAuth(adminApp);
const adminDb = getAdminFirestore(adminApp);
const clients = [];
const suffix = `${process.pid}-${Date.now()}`;
const name = (prefix) => `${prefix}-${suffix}`;
const operationA = name('demo-a');
const operationB = name('demo-b');
const siteX = name('site-x');
const siteY = name('site-y');
const actorA = name('demo-actor-a');
const engagementA = name('demo-engagement-a');

before(() => assert.equal(process.env.GCLOUD_PROJECT, projectId));
after(async () => {
  await Promise.all(clients.map((app) => deleteApp(app)));
  await deleteAdminApp(adminApp);
});

async function client(kind) {
  const uid = name(kind);
  const email = `${uid}@example.test`;
  const password = 'Emulator-only-password-42!';
  await adminAuth.createUser({uid, email, password});
  const app = initializeApp({projectId, apiKey: 'fake-api-key'}, uid);
  clients.push(app);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', {disableWarnings: true});
  await signInWithEmailAndPassword(auth, email, password);
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1',
    Number(process.env.MOBSANTE_TEST_FIRESTORE_PORT ?? 8080));
  return {uid, db};
}

function anonymousClient() {
  const app = initializeApp({projectId, apiKey: 'fake-api-key'}, name('anonymous'));
  clients.push(app);
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1',
    Number(process.env.MOBSANTE_TEST_FIRESTORE_PORT ?? 8080));
  return db;
}

test('synthetic history is private, action-scoped, and never client-writable',
  async () => {
    const administrator = await client('admin');
    const authorized = await client('historical-coordinator');
    const manager = await client('historical-manager');
    const visitor = await client('visitor');
    const anonymous = anonymousClient();
    await adminDb.doc(`platformAdministrators/${administrator.uid}`)
      .set({active: true});
    for (const operationId of [operationA, operationB]) {
      await adminDb.doc(`operations/${operationId}`).set({
        id: operationId, purpose: 'demonstration', status: 'completed',
      });
    }
    await adminDb.doc(`historicalActionAccess/${operationA}_${authorized.uid}`)
      .set({uid: authorized.uid, operationId: operationA,
        active: true, schemaVersion: 1, roles: ['coordinator'],
        locationIds: []});
    await adminDb.doc(`historicalActionAccess/${operationA}_${manager.uid}`)
      .set({uid: manager.uid, operationId: operationA,
        active: true, schemaVersion: 1, roles: ['site_manager'],
        locationIds: [siteX]});
    await adminDb.doc(`demoActors/${actorA}`).set({
      id: actorA, operationId: operationA, label: 'Acteur fictif',
      historicalSiteIds: [siteX], roles: ['responsable'], professions: [],
    });
    await adminDb.doc(`demoEngagements/${engagementA}`).set({
      id: engagementA, operationId: operationA, actorId: actorA,
      missionId: name('mission'), locationId: siteX,
      profession: 'physiotherapist', status: 'unknown', statusKnown: false,
    });
    const actor = (db) => doc(db, 'demoActors', actorA);
    const engagement = (db) => doc(db, 'demoEngagements', engagementA);
    assert.equal((await getDoc(actor(administrator.db))).exists(), true);
    assert.equal((await getDoc(engagement(administrator.db))).exists(), true);
    assert.equal((await getDoc(actor(authorized.db))).exists(), true);
    assert.equal((await getDoc(engagement(authorized.db))).exists(), true);
    await assert.rejects(getDoc(actor(manager.db)));
    assert.equal((await getDoc(engagement(manager.db))).exists(), true);
    await assert.rejects(getDoc(actor(visitor.db)));
    await assert.rejects(getDoc(engagement(visitor.db)));
    await assert.rejects(getDoc(actor(anonymous)));
    await assert.rejects(getDoc(engagement(anonymous)));
    await assert.rejects(adminAuth.getUser(actorA),
      (error) => error.code === 'auth/user-not-found');
    assert.equal((await getDocs(query(collection(administrator.db, 'demoActors'),
      where('operationId', '==', operationA)))).size, 1);
    await assert.rejects(setDoc(actor(administrator.db), {label: 'changed'}));
    await assert.rejects(setDoc(engagement(authorized.db), {status: 'confirmed'}));
    await adminDb.doc(`historicalActionAccess/${operationA}_${manager.uid}`)
      .update({locationIds: [siteY]});
    await assert.rejects(getDoc(actor(manager.db)));
    await assert.rejects(getDoc(engagement(manager.db)));
    await assert.rejects(getDoc(doc(authorized.db, 'operations', operationB)));
    assert.equal((await getDoc(doc(administrator.db, 'operations', operationB)))
      .exists(), true);
    await adminDb.doc(`operations/${operationA}`).update({status: 'archived'});
    assert.equal((await getDoc(actor(authorized.db))).exists(), true);
    assert.equal((await adminDb.collection('notificationEvents').get()).size, 0);
  });

test('current Action scope is explicit even when organization and site are shared',
  async () => {
    const org = name('shared-organization');
    const actionA = name('current-a');
    const actionB = name('current-b');
    const mobilizationA = name('current-mob-a');
    const mobilizationB = name('current-mob-b');
    const missionAX = name('mission-a-x');
    const missionAY = name('mission-a-y');
    const missionBX = name('mission-b-x');
    const coordinator = await client('coordinator-a');
    const coordinatorBoth = await client('coordinator-both');
    const manager = await client('manager-a-x');
    const admin = await client('admin-current');
    await adminDb.doc(`platformAdministrators/${admin.uid}`)
      .set({active: true});
    for (const [operationId, mobilizationId] of [
      [actionA, mobilizationA], [actionB, mobilizationB],
    ]) {
      await adminDb.doc(`operations/${operationId}`).set({
        id: operationId, ownerOrganizationId: org, status: 'active',
        visibility: 'organization_private',
      });
      await adminDb.doc(`mobilizations/${mobilizationId}`).set({
        id: mobilizationId, operationId, status: 'active',
      });
    }
    for (const [missionId, mobilizationId, locationId] of [
      [missionAX, mobilizationA, siteX],
      [missionAY, mobilizationA, siteY],
      [missionBX, mobilizationB, siteX],
    ]) {
      await adminDb.doc(`missions/${missionId}`).set({
        id: missionId, mobilizationId, locationId,
        isActive: true, status: 'critical',
      });
    }
    for (const person of [coordinator, coordinatorBoth, manager]) {
      const responsible = person === manager;
      await adminDb.doc(`organizationMemberships/${org}_${person.uid}`)
        .set({uid: person.uid, organizationId: org, active: true,
          roles: [responsible ? 'site_manager' : 'coordinator'],
          locationIds: responsible ? [siteX, siteY] : [], schemaVersion: 1});
      for (const operationId of person === coordinatorBoth
        ? [actionA, actionB] : [actionA]) {
        await adminDb.doc(`operationAccess/${operationId}_${person.uid}`)
          .set({uid: person.uid, operationId, organizationId: org,
            active: true, schemaVersion: 1,
            roles: [responsible ? 'site_manager' : 'coordinator'],
            locationIds: responsible ? [siteX] : []});
      }
    }
    const action = (person, operationId) => getDoc(doc(person.db,
      'operations', operationId));
    const need = (person, missionId) => getDoc(doc(person.db,
      'missions', missionId));
    assert.equal((await action(coordinator, actionA)).exists(), true);
    assert.equal((await getDocs(query(
      collection(coordinator.db, 'operationAccess'),
      where('uid', '==', coordinator.uid),
      where('active', '==', true),
    ))).size, 1);
    await assert.rejects(action(coordinator, actionB));
    assert.equal((await need(coordinator, missionAX)).exists(), true);
    await assert.rejects(need(coordinator, missionBX));
    const activeNeeds = (person, mobilizationId, locationId) => {
      const clauses = [where('mobilizationId', '==', mobilizationId),
        where('isActive', '==', true)];
      if (locationId !== undefined) {
        clauses.push(where('locationId', '==', locationId));
      }
      return getDocs(query(collection(person.db, 'missions'), ...clauses));
    };
    assert.equal((await activeNeeds(coordinator, mobilizationA)).size, 2);
    await assert.rejects(activeNeeds(coordinator, mobilizationB));
    assert.equal((await action(manager, actionA)).exists(), true);
    await assert.rejects(action(manager, actionB));
    assert.equal((await need(manager, missionAX)).exists(), true);
    await assert.rejects(need(manager, missionAY));
    await assert.rejects(need(manager, missionBX));
    assert.equal((await activeNeeds(manager, mobilizationA, siteX)).size, 1);
    await assert.rejects(activeNeeds(manager, mobilizationA, siteY));
    await assert.rejects(activeNeeds(manager, mobilizationB, siteX));
    assert.equal((await action(coordinatorBoth, actionA)).exists(), true);
    assert.equal((await action(coordinatorBoth, actionB)).exists(), true);
    assert.equal((await need(coordinatorBoth, missionBX)).exists(), true);
    assert.equal((await action(admin, actionA)).exists(), true);
    assert.equal((await action(admin, actionB)).exists(), true);
  });
