import assert from 'node:assert/strict';
import {after, test} from 'node:test';
import {deleteApp, initializeApp} from 'firebase-admin/app';
import {getFirestore, Timestamp} from 'firebase-admin/firestore';

import {
  reconcileAllPublicMissions,
  reconcilePublicMission,
} from '../../src/public_discovery/firestore_projector.js';
import {runRebuild} from '../../../scripts/rebuild_public_mission_discovery.mjs';
import {publicMissionId} from '../../src/public_discovery/projector.js';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  throw new Error('Firestore emulator required');
}
const app = initializeApp({projectId: 'demo-mobsante'}, 'public-discovery-test');
const firestore = getFirestore(app);
after(async () => deleteApp(app));

test('dry run, lifecycle repair and idempotence stay within public collection', async () => {
  const notificationEventsBefore =
    (await firestore.collection('notificationEvents').get()).size;
  const notificationDeliveriesBefore =
    (await firestore.collection('notificationDeliveries').get()).size;
  const missionRef = firestore.doc('missions/discovery-test-mission');
  const publicRef = firestore.doc(
    `publicMissionDiscovery/${publicMissionId('discovery-test-mission')}`,
  );
  const locationRef = firestore.doc('locations/discovery-sensitive-site');
  await firestore.doc('platform/config').set({
    activeMobilizationId: 'discovery-historical',
  });
  await firestore.doc('mobilizations/discovery-historical').set({
    id: 'discovery-historical', status: 'active',
  });
  await locationRef.set({
    name: 'Private place', address: 'Private street',
    latitude: 44.0, longitude: -0.5, contactPhone: 'private-phone',
    availableEquipment: ['sensitive'],
  });
  await missionRef.set({
    mobilizationId: 'discovery-historical',
    locationId: 'discovery-sensitive-site',
    locationName: 'Private place',
    territorialGroup: 'medoc',
    startAt: Timestamp.fromDate(new Date('2099-01-01T08:00:00Z')),
    endAt: Timestamp.fromDate(new Date('2099-01-01T12:00:00Z')),
    requiredByProfession: {nurse: 1},
    status: 'critical', isActive: true,
    details: 'Private operational note', createdBy: 'private-uid',
  });

  const logs = [];
  const dryRun = await runRebuild({
    firestore, log: (value) => logs.push(value),
  });
  assert.equal(dryRun.counts.CREATE, 1);
  assert.equal(dryRun.sourceCounts.locations, 1);
  assert.equal((await publicRef.get()).exists, false);
  assert.ok(logs.every((line) => !line.includes('Private')));

  assert.equal(await reconcilePublicMission(firestore, missionRef.id), 'CREATE');
  assert.deepEqual((await publicRef.get()).data(), {
    publicId: publicMissionId(missionRef.id),
    day: '2099-01-01', sectorLabel: 'Médoc',
    professions: ['nurse'], status: 'open',
  });
  assert.equal(await reconcilePublicMission(firestore, missionRef.id), 'UNCHANGED');
  await missionRef.update({territorialGroup: 'libournais'});
  assert.equal(await reconcilePublicMission(firestore, missionRef.id), 'UPDATE');
  assert.equal((await publicRef.get()).data().sectorLabel, 'Libournais');
  await missionRef.update({status: 'cancelled'});
  assert.equal(await reconcilePublicMission(firestore, missionRef.id), 'DELETE');
  assert.equal((await publicRef.get()).exists, false);

  await missionRef.update({status: 'critical'});
  await reconcileAllPublicMissions(firestore);
  assert.equal((await publicRef.get()).exists, true);
  await missionRef.update({
    startAt: Timestamp.fromDate(new Date('2020-01-01T08:00:00Z')),
    endAt: Timestamp.fromDate(new Date('2020-01-01T12:00:00Z')),
  });
  assert.equal(await reconcilePublicMission(firestore, missionRef.id), 'DELETE');
  assert.equal((await publicRef.get()).exists, false);
  await missionRef.update({
    startAt: Timestamp.fromDate(new Date('2099-01-01T08:00:00Z')),
    endAt: Timestamp.fromDate(new Date('2099-01-01T12:00:00Z')),
  });
  await reconcileAllPublicMissions(firestore);
  assert.equal((await publicRef.get()).exists, true);
  await missionRef.delete();
  await reconcileAllPublicMissions(firestore);
  assert.equal((await publicRef.get()).exists, false);
  assert.equal((await firestore.collection('notificationEvents').get()).size,
    notificationEventsBefore);
  assert.equal((await firestore.collection('notificationDeliveries').get()).size,
    notificationDeliveriesBefore);
});
