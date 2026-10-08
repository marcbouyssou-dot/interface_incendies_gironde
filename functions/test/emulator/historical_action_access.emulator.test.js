import assert from 'node:assert/strict';
import {after, before, test} from 'node:test';
import {deleteApp, initializeApp} from 'firebase-admin/app';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';

import {
  revokeHistoricalActionAccess,
  transitionOperation,
} from '../../src/platform_administration.js';
import {platformAdministrationServices} from
  '../../src/platform_administration_firestore.js';
import {publicMissionId} from '../../src/public_discovery/projector.js';

const projectId = 'demo-mobsante';
const app = initializeApp({projectId}, 'historical-action-access-test');
const firestore = getFirestore(app);
const services = platformAdministrationServices({
  firestore,
  serverTimestamp: FieldValue.serverTimestamp,
});
const suffix = `${process.pid}-${Date.now()}`;
const id = (prefix) => `${prefix}-${suffix}`;
const operationA = id('fire-action');
const operationB = id('flood-action');
const mobilizationA = id('fire-mobilization');
const mobilizationB = id('flood-mobilization');
const siteA = id('fire-site');
const siteB = id('flood-site');
const unrelatedSite = id('unrelated-site');
const managerA = id('fire-manager');
const coordinatorA = id('fire-coordinator');
const managerB = id('flood-manager');
const coordinatorB = id('flood-coordinator');
const organizationId = id('urps-na');
const administrator = id('platform-admin');

before(() => assert.equal(process.env.GCLOUD_PROJECT, projectId));
after(async () => deleteApp(app));

function membership(uid, roles, locationIds) {
  return {uid, organizationId, roles, locationIds,
    active: true, schemaVersion: 1};
}

test('Gironde-like Action creates exact grants, archives and revokes without cross-Action access',
  async () => {
    const notificationsBefore =
      (await firestore.collection('notificationEvents').get()).size;
    await firestore.doc(`platformAdministrators/${administrator}`)
      .set({active: true});
    await firestore.doc(`organizations/${organizationId}`).set({
      id: organizationId, name: 'URPS MK Nouvelle-Aquitaine', active: true,
    });
    for (const [operationId, mobilizationId, siteId, managerUid,
      coordinatorUid, context] of [
      [operationA, mobilizationA, siteA, managerA, coordinatorA, 'fire'],
      [operationB, mobilizationB, siteB, managerB, coordinatorB, 'flood'],
    ]) {
      await firestore.doc(`operations/${operationId}`).set({
        id: operationId, name: context === 'fire'
          ? 'Incendies Gironde 2026' : 'Action inondation locale',
        status: 'active', ownerOrganizationId: organizationId,
        coordinatorUid, scopeRefs: [`locations/${siteId}`],
      });
      await firestore.doc(`mobilizations/${mobilizationId}`).set({
        id: mobilizationId, operationId, status: 'active',
        territoryId: 'gironde',
      });
      await firestore.doc(`locations/${siteId}`).set({
        id: siteId, name: siteId, isActive: true,
        managingOrganizationId: organizationId,
      });
      await firestore.doc(`missions/${id(`need-${context}`)}`).set({
        id: id(`need-${context}`), mobilizationId, locationId: siteId,
        isActive: true, status: 'critical',
      });
      await firestore.doc(
        `organizationMemberships/${organizationId}_${managerUid}`,
      ).set(membership(managerUid, ['site_manager'],
        context === 'fire' ? [siteId, unrelatedSite] : [siteId]));
      await firestore.doc(
        `organizationMemberships/${organizationId}_${coordinatorUid}`,
      ).set(membership(coordinatorUid, ['coordinator'], []));
      await firestore.doc(`operationAccess/${operationId}_${managerUid}`)
        .set({uid: managerUid, organizationId, operationId,
          roles: ['site_manager'], locationIds: [siteId],
          active: true, schemaVersion: 1});
      await firestore.doc(`operationAccess/${operationId}_${coordinatorUid}`)
        .set({uid: coordinatorUid, organizationId, operationId,
          roles: ['coordinator'], locationIds: [],
          active: true, schemaVersion: 1});
    }
    await firestore.doc(`engagements/${id('need-fire')}_${id('professional')}`)
      .set({missionId: id('need-fire'), mobilizationId: mobilizationA,
        volunteerId: id('professional'), status: 'confirmed'});

    const publicFire = firestore.doc(
      `publicMissionDiscovery/${publicMissionId(id('need-fire'))}`);
    const publicFlood = firestore.doc(
      `publicMissionDiscovery/${publicMissionId(id('need-flood'))}`);
    await publicFire.set({status: 'open'});
    await publicFlood.set({status: 'open'});
    await transitionOperation({callerUid: administrator, data: {
      operationId: operationA, targetStatus: 'suspended',
    }, services});
    assert.equal((await publicFire.get()).exists, false);
    assert.equal((await publicFlood.get()).exists, true);
    assert.equal((await firestore.doc(
      `historicalActionAccess/${operationA}_${managerA}`).get()).exists,
    false);
    await transitionOperation({callerUid: administrator, data: {
      operationId: operationA, targetStatus: 'active',
    }, services});
    await publicFire.set({status: 'open'});

    const completed = await transitionOperation({
      callerUid: administrator,
      data: {operationId: operationA, targetStatus: 'completed'},
      services,
    });
    assert.equal(completed.status, 'completed');
    assert.equal((await publicFire.get()).exists, false);
    assert.equal((await publicFlood.get()).exists, true);
    const managerGrantRef = firestore.doc(
      `historicalActionAccess/${operationA}_${managerA}`,
    );
    const coordinatorGrantRef = firestore.doc(
      `historicalActionAccess/${operationA}_${coordinatorA}`,
    );
    const managerGrant = (await managerGrantRef.get()).data();
    const coordinatorGrant = (await coordinatorGrantRef.get()).data();
    assert.deepEqual(managerGrant.locationIds, [siteA]);
    assert.deepEqual(managerGrant.roles, ['site_manager']);
    assert.deepEqual(coordinatorGrant.roles, ['coordinator']);
    assert.deepEqual(coordinatorGrant.locationIds, []);
    assert.equal(managerGrant.sourceTransition, 'active:completed');
    assert.equal(managerGrant.createdBy, administrator);
    assert.equal((await firestore.doc(
      `operationAccess/${operationA}_${managerA}`).get()).data().active,
    false);
    assert.equal((await firestore.doc(
      `operationAccess/${operationB}_${managerB}`).get()).data().active,
    true);
    assert.ok(managerGrant.createdAt.toDate() instanceof Date);
    assert.equal((await firestore.doc(
      `historicalActionAccess/${operationA}_${managerB}`,
    ).get()).exists, false);
    assert.equal((await firestore.doc(
      `historicalActionAccess/${operationB}_${managerA}`,
    ).get()).exists, false);
    await transitionOperation({callerUid: administrator, data: {
      operationId: operationA, targetStatus: 'completed',
    }, services});
    assert.deepEqual((await managerGrantRef.get()).data(), managerGrant);
    await transitionOperation({callerUid: administrator, data: {
      operationId: operationA, targetStatus: 'archived',
    }, services});
    assert.deepEqual((await managerGrantRef.get()).data(), managerGrant);

    await revokeHistoricalActionAccess({callerUid: administrator, data: {
      operationId: operationA, uid: managerA,
      reason: 'administrative_correction',
    }, services});
    assert.equal((await managerGrantRef.get()).data().active, false);
    assert.equal((await coordinatorGrantRef.get()).data().active, true);
    assert.equal((await firestore.doc(
      `historicalActionAccessAudit/${operationA}_${managerA}_revoked`,
    ).get()).data().event, 'revoked');
    assert.equal((await firestore.collection('notificationEvents').get()).size,
      notificationsBefore);
  });
