import assert from 'node:assert/strict';
import test from 'node:test';

import {
  MissionUpdateError,
  missionUpdateMutation,
  updateMission,
  validateMissionUpdateRequest,
} from '../src/update_mission.js';

const professions = [
  'physiotherapist',
  'podiatrist',
  'physician',
  'nurse',
  'veterinarian',
  'other_health_professional',
];
const referenceNow = Date.UTC(2026, 7, 3, 10);
const activeMissionEnd = Date.UTC(2026, 7, 3, 12);

function timestamp(value) {
  return Object.freeze({toMillis: () => value});
}

function quotas(overrides = {}) {
  return Object.fromEntries(
    professions.map((profession) => [profession, overrides[profession] ?? 0]),
  );
}

function request(overrides = {}) {
  return {
    missionId: 'mission-1',
    locationId: 'location-b',
    startAtMillis: Date.UTC(2026, 7, 3, 8),
    endAtMillis: Date.UTC(2026, 7, 3, 12),
    requiredByProfession: quotas({physiotherapist: 2, podiatrist: 1}),
    equipment: ['Tables'],
    details: 'Accès nord',
    priority: 'standard',
    ...overrides,
  };
}

function role({roles = ['coordinator'], locationIds = [], active = true} = {}) {
  return {
    role: roles.includes('coordinator') ? 'coordinator' : 'site_manager',
    roles,
    locationIds,
    active,
    schemaVersion: 2,
  };
}

function mission(overrides = {}) {
  return {
    id: 'mission-1',
    mobilizationId: 'mobilization-active',
    locationId: 'location-a',
    registeredByProfession: quotas({physiotherapist: 1}),
    registeredMk: 1,
    registeredPp: 0,
    endAt: timestamp(activeMissionEnd),
    isActive: true,
    status: 'toComplete',
    createdAt: 'preserved',
    createdBy: 'creator',
    ...overrides,
  };
}

function destination(overrides = {}) {
  return {
    name: 'Centre B',
    group: 'medoc',
    active: true,
    isOperational: true,
    ...overrides,
  };
}

function mutation(overrides = {}) {
  return missionUpdateMutation({
    request: validateMissionUpdateRequest(
      overrides.request ?? request(),
    ),
    mission: Object.hasOwn(overrides, 'mission')
      ? overrides.mission
      : mission(),
    mobilization: Object.hasOwn(overrides, 'mobilization')
      ? overrides.mobilization
      : {id: 'mobilization-active', status: 'active'},
    coordinatorAuthorized: overrides.coordinatorAuthorized ?? true,
    destination: Object.hasOwn(overrides, 'destination')
      ? overrides.destination
      : destination(),
    callerRole: Object.hasOwn(overrides, 'callerRole')
      ? overrides.callerRole
      : role(),
    engagements: (
      Object.hasOwn(overrides, 'engagements') ? overrides.engagements : []
    ).map((engagement) => ({
      mobilizationId: 'mobilization-active',
      ...engagement,
    })),
    serverTimestamp: 'server-time',
    timestampFromMillis: (value) => `timestamp:${value}`,
    nowMillis: overrides.nowMillis ?? referenceNow,
  });
}

function assertCode(action, code) {
  assert.throws(action, (error) => {
    assert.ok(error instanceof MissionUpdateError);
    assert.equal(error.code, code);
    return true;
  });
}

test('strict request validation accepts the six canonical quotas', () => {
  const value = validateMissionUpdateRequest(request());
  assert.deepEqual(value.requiredByProfession, quotas({
    physiotherapist: 2,
    podiatrist: 1,
  }));
  assert.equal(value.details, 'Accès nord');
  assert.equal(value.priority, 'standard');
  assert.ok(Object.isFrozen(value));
});

test('strict request validation refuses malformed schedules and payloads', () => {
  for (const value of [
    {...request(), unknown: true},
    request({endAtMillis: request().startAtMillis}),
    request({requiredByProfession: {physiotherapist: 1}}),
    request({requiredByProfession: {
      ...quotas({physiotherapist: 1}),
      doctor: 0,
    }}),
    request({requiredByProfession: quotas({physiotherapist: -1})}),
    request({requiredByProfession: quotas()}),
    request({equipment: ['Tables', 'Tables']}),
    request({priority: 'information'}),
    request({priority: 1}),
  ]) {
    assertCode(() => validateMissionUpdateRequest(value), 'invalid-argument');
  }
});

test('the four priorities are accepted and legacy omission stays compatible', () => {
  for (const priority of ['standard', 'priority', 'urgent', 'crisis']) {
    const value = validateMissionUpdateRequest(request({priority}));
    assert.equal(value.priority, priority);
    assert.equal(mutation({request: request({priority})}).fields.priority,
      priority);
  }

  const legacyRequest = request();
  delete legacyRequest.priority;
  const validatedLegacy = validateMissionUpdateRequest(legacyRequest);
  assert.equal(Object.hasOwn(validatedLegacy, 'priority'), false);
  assert.equal(
    Object.hasOwn(mutation({request: legacyRequest}).fields, 'priority'),
    false,
  );
});

test('veterinarian quotas and counters are validated and preserved', () => {
  const value = mutation({
    request: request({
      requiredByProfession: quotas({veterinarian: 2}),
    }),
    mission: mission({
      registeredByProfession: quotas({veterinarian: 1}),
      registeredMk: 0,
    }),
    engagements: [{profession: 'veterinarian', status: 'confirmed'}],
  });
  assert.equal(value.fields.requiredByProfession.veterinarian, 2);
  assert.equal(value.fields.registeredByProfession.veterinarian, 1);

  assertCode(
    () => mutation({
      request: request({
        requiredByProfession: quotas({physiotherapist: 1}),
      }),
      mission: mission({
        registeredByProfession: quotas({veterinarian: 1}),
      }),
    }),
    'failed-precondition',
  );
});

test('coordinator update preserves counters and only returns editable fields', () => {
  const value = mutation();
  assert.equal(value.fields.locationId, 'location-b');
  assert.equal(value.fields.locationName, 'Centre B');
  assert.equal(value.fields.registeredMk, 1);
  assert.equal(value.fields.registeredByProfession.physiotherapist, 1);
  assert.equal(value.fields.status, 'critical');
  assert.equal(value.fields.priority, 'standard');
  assert.equal(value.fields.updatedAt, 'server-time');
  for (const protectedField of ['id', 'createdAt', 'createdBy', 'isActive']) {
    assert.equal(Object.hasOwn(value.fields, protectedField), false);
  }
});

test('site manager must manage both current and destination locations', () => {
  const manager = role({
    roles: ['site_manager'],
    locationIds: ['location-a', 'location-b'],
  });
  assert.equal(mutation({callerRole: manager}).fields.locationId, 'location-b');
  for (const locationIds of [['location-a'], ['location-b']]) {
    assertCode(
      () => mutation({
        callerRole: role({roles: ['site_manager'], locationIds}),
      }),
      'permission-denied',
    );
  }
});

test('inactive and malformed roles are denied without mutation', () => {
  assertCode(() => mutation({callerRole: role({active: false})}),
    'permission-denied');
  assertCode(() => mutation({
    callerRole: {
      role: 'coordinator',
      roles: ['coordinator'],
      active: true,
      schemaVersion: 2,
    },
  }), 'permission-denied');
  assertCode(() => mutation({callerRole: null}), 'permission-denied');
});

test('missing mission and inactive destination are refused', () => {
  assertCode(() => mutation({mission: null}), 'not-found');
  assertCode(
    () => mutation({destination: destination({active: false})}),
    'failed-precondition',
  );
  assertCode(
    () => mutation({destination: destination({isOperational: false})}),
    'failed-precondition',
  );
});

test('future and active-today missions retain their update behavior', () => {
  const activeToday = mutation({
    mission: mission({endAt: timestamp(referenceNow + 2 * 60 * 60 * 1000)}),
    nowMillis: referenceNow,
  });
  assert.equal(activeToday.fields.locationId, 'location-b');

  const future = mutation({
    mission: mission({endAt: timestamp(referenceNow + 24 * 60 * 60 * 1000)}),
    nowMillis: referenceNow,
  });
  assert.equal(future.fields.locationId, 'location-b');
});

test('ended mission is refused and admin does not gain shared access', () => {
  const endedMission = mission({endAt: timestamp(referenceNow)});
  const authorizedRoles = [
    role(),
    role({
      roles: ['site_manager'],
      locationIds: ['location-a', 'location-b'],
    }),
  ];

  for (const callerRole of authorizedRoles) {
    assertCode(
      () => mutation({
        mission: endedMission,
        callerRole,
        nowMillis: referenceNow,
      }),
      'failed-precondition',
    );
  }

  assertCode(
    () => mutation({
      mission: endedMission,
      callerRole: {
        role: 'admin',
        roles: ['admin'],
        locationIds: [],
        active: true,
        schemaVersion: 2,
      },
      nowMillis: referenceNow,
    }),
    'permission-denied',
  );
});

test('past rejection preserves legacy mission and historical engagements', () => {
  const legacyMission = mission({
    endAt: new Date(referenceNow - 1),
    registeredByProfession: undefined,
    registeredMk: 1,
    registeredPp: 1,
  });
  const historicalEngagements = [{
    mobilizationId: 'mobilization-active',
    profession: 'mk',
    status: 'cancelled',
  }];
  const missionBefore = {...legacyMission};
  const engagementsBefore = historicalEngagements.map((value) => ({...value}));

  assertCode(
    () => missionUpdateMutation({
      request: validateMissionUpdateRequest(request()),
      mission: legacyMission,
      mobilization: {id: 'mobilization-active', status: 'active'},
      coordinatorAuthorized: true,
      destination: destination(),
      callerRole: role(),
      engagements: historicalEngagements,
      serverTimestamp: 'server-time',
      timestampFromMillis: (value) => `timestamp:${value}`,
      nowMillis: referenceNow,
    }),
    'failed-precondition',
  );
  assert.deepEqual(legacyMission, missionBefore);
  assert.deepEqual(historicalEngagements, engagementsBefore);
});

test('mission update is restricted to the active mobilization', () => {
  assertCode(
    () => mutation({mission: mission({mobilizationId: 'other'})}),
    'failed-precondition',
  );
  assertCode(
    () => mutation({mobilization: {id: 'mobilization-active', status: 'inactive'}}),
    'failed-precondition',
  );
  assertCode(
    () => mutation({
      engagements: [{
        profession: 'mk',
        status: 'confirmed',
        mobilizationId: 'other',
      }],
    }),
    'failed-precondition',
  );
});

test('an inactive historical location can remain but cannot be a destination', () => {
  const historical = destination({active: false, isOperational: false});
  const unchanged = mutation({
    request: request({locationId: 'location-a'}),
    destination: historical,
  });
  assert.equal(unchanged.fields.locationId, 'location-a');
  assertCode(
    () => mutation({destination: historical}),
    'failed-precondition',
  );
});

test('quota cannot fall below counters or confirmed engagements', () => {
  const tooLow = request({
    requiredByProfession: quotas({physiotherapist: 1}),
  });
  assertCode(
    () => mutation({
      request: tooLow,
      mission: mission({
        registeredByProfession: quotas({physiotherapist: 2}),
        registeredMk: 2,
      }),
    }),
    'failed-precondition',
  );
  assertCode(
    () => mutation({
      request: tooLow,
      engagements: [
        {profession: 'mk', status: 'confirmed'},
        {profession: 'physiotherapist'},
      ],
    }),
    'failed-precondition',
  );
});

test('assigned cumulative coordinator preserves legacy counters', () => {
  const value = mutation({
    callerRole: role({
      roles: ['coordinator', 'site_manager'],
      locationIds: ['location-a'],
    }),
    mission: mission({
      registeredByProfession: undefined,
      registeredMk: 1,
      registeredPp: 1,
    }),
  });
  assert.equal(value.fields.registeredMk, 1);
  assert.equal(value.fields.registeredPp, 1);
});

test('coordinator outside the mission mobilization assignment is refused', () => {
  assertCode(
    () => mutation({coordinatorAuthorized: false}),
    'permission-denied',
  );
});

test('public operation validates before delegating and preserves service result', async () => {
  let received;
  const result = await updateMission({
    callerUid: 'coordinator',
    data: request(),
    services: {
      async commitMissionUpdate(value) {
        received = value;
        return {missionId: value.missionId};
      },
    },
  });
  assert.equal(received.callerUid, 'coordinator');
  assert.deepEqual(result, {missionId: 'mission-1'});
  await assert.rejects(
    () => updateMission({callerUid: null, data: request(), services: {}}),
    (error) => error.code === 'unauthenticated',
  );
});
