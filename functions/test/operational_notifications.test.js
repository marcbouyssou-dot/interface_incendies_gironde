import assert from 'node:assert/strict';
import test from 'node:test';

import {
  engagementCreatedEvents,
  engagementUpdatedEvents,
  missionCreatedEvents,
  missionUpdatedEvents,
} from '../src/operational_notifications/event_factory.js';
import {
  isCriticalEvent,
  isQuietHour,
  recipientsForEvent,
} from '../src/operational_notifications/targeting.js';
import {
  deliveryClaimDecision,
  isInvalidToken,
} from '../src/operational_notifications/firestore_service.js';

const timestamp = (milliseconds) => ({toMillis: () => milliseconds});
const now = Date.UTC(2026, 7, 15, 12);
const baseMission = Object.freeze({
  id: 'mission-a',
  mobilizationId: 'mob-a',
  locationId: 'site-a',
  locationName: 'Langon',
  createdBy: 'manager',
  isActive: true,
  status: 'toComplete',
  startAt: timestamp(now + 4 * 3600000),
  endAt: timestamp(now + 8 * 3600000),
  requiredByProfession: {nurse: 2},
  registeredByProfession: {nurse: 1},
});

test('canonical factories emit only the seven immutable event contracts', () => {
  const occurredAt = timestamp(now);
  const published = missionCreatedEvents({
    mission: baseMission,
    sourceEventId: 'create-a',
    occurredAt,
  });
  const missionEvents = missionUpdatedEvents({
    before: baseMission,
    after: {...baseMission, status: 'critical', details: 'nouveau'},
    sourceEventId: 'update-a',
    occurredAt,
  });
  const covered = missionUpdatedEvents({
    before: {...baseMission, status: 'toComplete'},
    after: {...baseMission, status: 'complete'},
    sourceEventId: 'cover-a',
    occurredAt,
  });
  const cancelled = missionUpdatedEvents({
    before: baseMission,
    after: {...baseMission, status: 'cancelled', cancelledBy: 'manager'},
    sourceEventId: 'cancel-a',
    occurredAt,
  });
  const engagement = {id: 'e-a', missionId: 'mission-a', mobilizationId: 'mob-a', volunteerId: 'pro-a', profession: 'nurse', status: 'confirmed'};
  const engagementCreated = engagementCreatedEvents({engagement, mission: baseMission, sourceEventId: 'eng-create', occurredAt});
  const engagementCancelled = engagementUpdatedEvents({before: engagement, after: {...engagement, status: 'cancelled'}, mission: baseMission, sourceEventId: 'eng-cancel', occurredAt});
  const engagementRestored = engagementUpdatedEvents({before: {...engagement, status: 'cancelled'}, after: engagement, mission: baseMission, sourceEventId: 'eng-restore', occurredAt});

  const events = [...published, ...missionEvents, ...covered, ...cancelled, ...engagementCreated, ...engagementCancelled, ...engagementRestored];
  assert.deepEqual(new Set(events.map((event) => event.eventType)), new Set([
    'mission.published', 'mission.updated', 'mission.cancelled',
    'engagement.created', 'engagement.cancelled',
    'mission.became_critical', 'mission.fully_covered',
  ]));
  for (const event of events) {
    assert.equal(event.eventId.length, 64);
    assert.equal(event.idempotencyKey, event.eventId);
    assert.equal(event.version, 1);
    assert.equal(Object.isFrozen(event), true);
    assert.equal(Object.isFrozen(event.payload), true);
    assert.equal('phone' in event.payload, false);
    assert.equal('email' in event.payload, false);
    assert.equal('firstName' in event.payload, false);
    assert.equal('lastName' in event.payload, false);
  }
});

test('a counter-only mission write does not fabricate a mission.updated event', () => {
  const events = missionUpdatedEvents({
    before: baseMission,
    after: {...baseMission, registeredByProfession: {nurse: 1}, updatedAt: timestamp(now)},
    sourceEventId: 'counter',
    occurredAt: timestamp(now),
  });
  assert.deepEqual(events, []);
});

test('inactive or already cancelled documents do not emit publication events', () => {
  assert.deepEqual(missionCreatedEvents({
    mission: {...baseMission, isActive: false},
    sourceEventId: 'draft',
    occurredAt: timestamp(now),
  }), []);
  assert.deepEqual(engagementCreatedEvents({
    engagement: {
      id: 'e', missionId: 'mission-a', mobilizationId: 'mob-a',
      status: 'cancelled',
    },
    mission: baseMission,
    sourceEventId: 'cancelled-engagement',
    occurredAt: timestamp(now),
  }), []);
});

test('compatible targeting is opt-in, profession matched, capped and excludes engaged/self', () => {
  const event = missionCreatedEvents({mission: baseMission, sourceEventId: 'create', occurredAt: timestamp(now)})[0];
  const volunteers = [
    {uid: 'eligible', profession: 'nurse'},
    {uid: 'engaged', profession: 'nurse'},
    {uid: 'capped', profession: 'nurse'},
    {uid: 'wrong', profession: 'physician'},
    {uid: 'manager', profession: 'nurse'},
  ];
  const preferences = new Map([
    ['eligible', {compatibleMissions: true}],
    ['engaged', {compatibleMissions: true}],
    ['capped', {compatibleMissions: true}],
    ['manager', {compatibleMissions: true}],
  ]);
  const recentNotifications = new Map([['capped', [0, 1, 2].map(() => ({category: 'compatible', occurredAt: now - 1000}))]]);
  const recipients = recipientsForEvent({
    event, mission: baseMission, roles: [], volunteers,
    engagements: [{missionId: 'mission-a', volunteerId: 'engaged', status: 'confirmed'}],
    preferences, recentNotifications, now,
  });
  assert.deepEqual(recipients.map((item) => item.uid), ['eligible']);
});

test('operational targeting reaches scoped managers and coordinators without notifying actor', () => {
  const event = missionUpdatedEvents({
    before: baseMission,
    after: {...baseMission, status: 'critical'},
    sourceEventId: 'critical',
    occurredAt: timestamp(now),
  }).find((item) => item.eventType === 'mission.became_critical');
  const recipients = recipientsForEvent({
    event,
    mission: baseMission,
    roles: [
      {uid: 'manager', role: 'site_manager', locationIds: ['site-a'], active: true},
      {uid: 'other-manager', role: 'site_manager', locationIds: ['site-b'], active: true},
      {uid: 'coord', role: 'coordinator', locationIds: ['*'], active: true},
    ],
    assignments: [
      {uid: 'coord', mobilizationId: 'mob-a', role: 'coordinator', active: true},
    ],
    volunteers: [], engagements: [], preferences: new Map(),
    recentNotifications: new Map(), now,
  });
  assert.deepEqual(new Set(recipients.map((item) => item.uid)), new Set(['manager', 'coord']));
});

test('multi-mobilization targeting keeps events, engagements and coordinators isolated', () => {
  const missionB = {...baseMission, id: 'mission-b', mobilizationId: 'mob-b'};
  const eventA = missionCreatedEvents({
    mission: baseMission,
    sourceEventId: 'create-a',
    occurredAt: timestamp(now),
  })[0];
  const eventB = missionCreatedEvents({
    mission: missionB,
    sourceEventId: 'create-b',
    occurredAt: timestamp(now),
  })[0];
  assert.notEqual(eventA.eventId, eventB.eventId);
  assert.equal(eventA.mobilizationId, 'mob-a');
  assert.equal(eventB.mobilizationId, 'mob-b');

  const common = {
    roles: [],
    assignments: [],
    volunteers: [{uid: 'professional', profession: 'nurse'}],
    engagements: [{
      missionId: 'mission-a',
      mobilizationId: 'mob-a',
      volunteerId: 'professional',
      status: 'confirmed',
    }],
    preferences: new Map([
      ['professional', {compatibleMissions: true}],
    ]),
    recentNotifications: new Map(),
    now,
  };
  assert.deepEqual(recipientsForEvent({
    ...common,
    event: eventA,
    mission: baseMission,
  }), []);
  assert.deepEqual(
    recipientsForEvent({...common, event: eventB, mission: missionB})
      .map((recipient) => recipient.uid),
    ['professional'],
  );

  const criticalB = missionUpdatedEvents({
    before: missionB,
    after: {...missionB, status: 'critical'},
    sourceEventId: 'critical-b',
    occurredAt: timestamp(now),
  }).find((event) => event.eventType === 'mission.became_critical');
  const coordinatorRecipients = recipientsForEvent({
    ...common,
    event: criticalB,
    mission: missionB,
    volunteers: [],
    roles: [
      {uid: 'coord-a', role: 'coordinator', active: true},
      {uid: 'coord-b', role: 'coordinator', active: true},
    ],
    assignments: [
      {uid: 'coord-a', mobilizationId: 'mob-a', role: 'coordinator', active: true},
      {uid: 'coord-b', mobilizationId: 'mob-b', role: 'coordinator', active: true},
    ],
  });
  assert.deepEqual(
    coordinatorRecipients.map((recipient) => recipient.uid),
    ['manager', 'coord-b'],
  );
  assert.equal(
    coordinatorRecipients.some((recipient) => recipient.uid === 'coord-a'),
    false,
  );
});

test('quiet hours defer normal notifications but never critical ones', () => {
  const atNight = new Date(2026, 7, 15, 23, 30);
  assert.equal(isQuietHour({quietHoursStart: 22, quietHoursEnd: 7}, atNight), true);
  assert.equal(isCriticalEvent('mission.updated'), false);
  assert.equal(isCriticalEvent('mission.became_critical'), true);
  assert.equal(isCriticalEvent('mission.cancelled'), true);
});

test('delivery claim is deduplicated, leased and retried no more than three times', () => {
  assert.deepEqual(deliveryClaimDecision(undefined, now), {claim: true, attempts: 1});
  assert.deepEqual(deliveryClaimDecision({status: 'delivered', attempts: 1}, now), {claim: false, attempts: 1});
  assert.deepEqual(deliveryClaimDecision({status: 'processing', attempts: 1, leaseExpiresAt: timestamp(now + 1)}, now), {claim: false, attempts: 1});
  assert.deepEqual(deliveryClaimDecision({status: 'failed', attempts: 2}, now), {claim: true, attempts: 3});
  assert.deepEqual(deliveryClaimDecision({status: 'failed', attempts: 3}, now), {claim: false, attempts: 4});
});

test('permanently invalid FCM tokens are identified for deactivation', () => {
  assert.equal(isInvalidToken('messaging/registration-token-not-registered'), true);
  assert.equal(isInvalidToken('messaging/invalid-registration-token'), true);
  assert.equal(isInvalidToken('messaging/internal-error'), false);
});
