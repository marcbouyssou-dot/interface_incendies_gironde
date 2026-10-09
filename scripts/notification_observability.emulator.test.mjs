import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {test} from 'node:test';
import {resolve} from 'node:path';
import {deleteApp, initializeApp} from 'firebase-admin/app';
import {getFirestore} from 'firebase-admin/firestore';

test('read-only notification trace summarizes emulator event without private data', async () => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST);
  const projectId = 'demo-mobsante-notification-trace';
  const app = initializeApp({projectId}, `notification-trace-${process.pid}`);
  const db = getFirestore(app);
  const eventId = `event-${process.pid}`;
  await db.collection('notificationEvents').doc(eventId).set({
    eventId, eventType: 'mission.published', privateContent: 'private-body',
  });
  await db.collection('notifications').doc(`notice-${process.pid}`).set({
    eventId, recipientUid: 'private-uid', body: 'private-body',
  });
  await db.collection('notificationDeliveries').doc(`delivery-${process.pid}`).set({
    eventId, recipientUid: 'private-uid', attempts: 2, status: 'failed',
    errorCode: 'messaging/unavailable', token: 'private-token',
  });
  const run = spawnSync(process.execPath, [resolve('notification_observability.mjs'),
    '--project', projectId, '--event-id', eventId],
  {encoding: 'utf8', env: process.env});
  assert.equal(run.status, 0, run.stderr);
  const trace = JSON.parse(run.stdout);
  assert.equal(trace.eventCreated, true);
  assert.equal(trace.resolvedRecipients, 1);
  assert.equal(trace.attempts, 2);
  assert.equal(trace.failureCategories['messaging/unavailable'], 1);
  for (const value of ['private-uid', 'private-body', 'private-token']) {
    assert.equal(run.stdout.includes(value), false);
  }
  await deleteApp(app);
});
