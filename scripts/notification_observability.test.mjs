import assert from 'node:assert/strict';
import test from 'node:test';
import {summarizeNotificationEvent} from './notification_observability.mjs';

test('trace reports event, recipients, attempts and failure categories without secrets', () => {
  const trace = summarizeNotificationEvent({
    exists: true,
    notifications: [{recipientUid: 'one', token: 'secret-token'}],
    deliveries: [
      {recipientUid: 'one', status: 'delivered', attempts: 1,
        providerMessageId: 'private-message'},
      {recipientUid: 'two', status: 'failed', attempts: 2,
        errorCode: 'messaging/registration-token-not-registered', token: 'private-token'},
    ],
  });
  assert.deepEqual(trace, {eventCreated: true, resolvedRecipients: 2,
    inAppNotifications: 1, pushDeliveries: 2, attempts: 3,
    statuses: {delivered: 1, failed: 1},
    failureCategories: {'messaging/registration-token-not-registered': 1}});
  assert.equal(JSON.stringify(trace).includes('private'), false);
  assert.equal(JSON.stringify(trace).includes('secret'), false);
});
