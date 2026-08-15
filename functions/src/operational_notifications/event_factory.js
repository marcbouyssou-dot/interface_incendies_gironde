import {createHash} from 'node:crypto';

export const EVENT_TYPES = Object.freeze([
  'mission.published',
  'mission.updated',
  'mission.cancelled',
  'engagement.created',
  'engagement.cancelled',
  'mission.became_critical',
  'mission.fully_covered',
]);

const MISSION_SIGNIFICANT_FIELDS = Object.freeze([
  'locationId', 'locationName', 'startAt', 'endAt',
  'requiredByProfession', 'requiredMk', 'requiredPp',
  'requestedEquipment', 'details',
]);

export function missionCreatedEvents({mission, sourceEventId, occurredAt}) {
  if (!mission?.id || !mission?.mobilizationId ||
      mission.isActive !== true || mission.status === 'cancelled') return [];
  return [canonicalEvent({
    sourceEventId,
    eventType: 'mission.published',
    occurredAt,
    mission,
    actorUid: mission.createdBy,
    payload: missionPayload(mission),
  })];
}

export function missionUpdatedEvents({before, after, sourceEventId, occurredAt}) {
  if (!after?.id || !after?.mobilizationId) return [];
  const events = [];
  const cancelled = before.status !== 'cancelled' && after.status === 'cancelled';
  if (cancelled) {
    events.push(canonicalEvent({
      sourceEventId, eventType: 'mission.cancelled', occurredAt,
      mission: after, actorUid: after.cancelledBy,
      payload: {...missionPayload(after), reason: safeText(after.cancellationReason, 160)},
    }));
  } else if (MISSION_SIGNIFICANT_FIELDS.some((key) => !same(before[key], after[key]))) {
    events.push(canonicalEvent({
      sourceEventId, eventType: 'mission.updated', occurredAt,
      mission: after, actorUid: after.lastModifiedBy,
      payload: missionPayload(after),
    }));
  }
  if (before.status !== 'critical' && after.status === 'critical') {
    events.push(canonicalEvent({
      sourceEventId, eventType: 'mission.became_critical', occurredAt,
      mission: after, actorUid: null,
      payload: coveragePayload(before, after),
    }));
  }
  if (before.status !== 'complete' && after.status === 'complete') {
    events.push(canonicalEvent({
      sourceEventId, eventType: 'mission.fully_covered', occurredAt,
      mission: after, actorUid: null,
      payload: coveragePayload(before, after),
    }));
  }
  return events;
}

export function engagementCreatedEvents({engagement, mission, sourceEventId, occurredAt}) {
  if (!engagement?.missionId || !engagement?.mobilizationId || !mission ||
      engagement.status === 'cancelled') return [];
  return [canonicalEvent({
    sourceEventId, eventType: 'engagement.created', occurredAt,
    mission, actorUid: engagement.volunteerId,
    payload: {
      engagementId: engagement.id,
      profession: safeText(engagement.profession, 64),
      status: safeText(engagement.status ?? 'confirmed', 32),
      locationName: safeText(mission.locationName, 120),
    },
  })];
}

export function engagementUpdatedEvents({before, after, mission, sourceEventId, occurredAt}) {
  const becameActive = before?.status === 'cancelled' && after?.status === 'confirmed';
  const cancelled = before?.status !== 'cancelled' && after?.status === 'cancelled';
  if (!becameActive && !cancelled) return [];
  return [canonicalEvent({
    sourceEventId,
    eventType: becameActive ? 'engagement.created' : 'engagement.cancelled',
    occurredAt,
    mission,
    actorUid: after.volunteerId,
    payload: {
      engagementId: after.id,
      profession: safeText(after.profession, 64),
      locationName: safeText(mission.locationName, 120),
    },
  })];
}

function canonicalEvent({sourceEventId, eventType, occurredAt, mission, actorUid, payload}) {
  if (!EVENT_TYPES.includes(eventType)) throw new Error('unsupported-event-type');
  const eventId = createHash('sha256')
    .update(`${sourceEventId}:${eventType}`)
    .digest('hex');
  return Object.freeze({
    eventId,
    eventType,
    occurredAt,
    missionId: mission.id,
    mobilizationId: mission.mobilizationId,
    actorUid: typeof actorUid === 'string' && actorUid !== '' ? actorUid : null,
    source: typeof actorUid === 'string' && actorUid !== '' ? 'user' : 'system',
    payload: Object.freeze(payload),
    version: 1,
    idempotencyKey: eventId,
  });
}

function missionPayload(mission) {
  return {
    locationId: safeText(mission.locationId, 160),
    locationName: safeText(mission.locationName, 120),
    startAt: mission.startAt ?? null,
    endAt: mission.endAt ?? null,
    requiredByProfession: minimalQuotas(mission.requiredByProfession, mission),
    registeredByProfession: minimalRegistered(mission.registeredByProfession, mission),
  };
}

function coveragePayload(before, after) {
  return {
    ...missionPayload(after),
    previousStatus: safeText(before.status, 32),
    currentStatus: safeText(after.status, 32),
  };
}

function minimalQuotas(value, legacy) {
  if (value && typeof value === 'object') return {...value};
  return {physiotherapist: legacy.requiredMk ?? 0, podiatrist: legacy.requiredPp ?? 0};
}

function minimalRegistered(value, legacy) {
  if (value && typeof value === 'object') return {...value};
  return {physiotherapist: legacy.registeredMk ?? 0, podiatrist: legacy.registeredPp ?? 0};
}

function safeText(value, maxLength) {
  return typeof value === 'string' ? value.trim().slice(0, maxLength) : '';
}

function same(left, right) {
  if (left?.toMillis && right?.toMillis) return left.toMillis() === right.toMillis();
  return JSON.stringify(left ?? null) === JSON.stringify(right ?? null);
}
