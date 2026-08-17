import assert from 'node:assert/strict';
import test from 'node:test';

import {
  canCoordinateMobilization,
} from '../src/coordinator_mobilization_access.js';

const uid = 'coordinator';
const mobilization = {id: 'legacy', status: 'active'};
const platformConfig = {activeMobilizationId: 'legacy'};

function role(overrides = {}) {
  return {
    role: 'coordinator',
    roles: ['coordinator'],
    locationIds: [],
    active: true,
    schemaVersion: 2,
    ...overrides,
  };
}

function assignment(overrides = {}) {
  return {
    uid,
    mobilizationId: 'legacy',
    role: 'coordinator',
    active: true,
    ...overrides,
  };
}

function allowed(overrides = {}) {
  return canCoordinateMobilization({
    uid,
    role: role(),
    assignment: null,
    mobilization,
    platformConfig,
    ...overrides,
  });
}

test('legacy fallback accepts only the configured active mobilization', () => {
  assert.equal(allowed(), true);
  assert.equal(allowed({
    mobilization: {id: 'other', status: 'active'},
  }), false);
  assert.equal(allowed({
    mobilization: {id: 'legacy', status: 'inactive'},
  }), false);
  assert.equal(allowed({platformConfig: null}), false);
});

test('inactive and non-coordinator roles never receive the fallback', () => {
  assert.equal(allowed({role: role({active: false})}), false);
  assert.equal(allowed({
    role: {
      role: 'site_manager',
      roles: ['site_manager'],
      locationIds: ['langon'],
      active: true,
      schemaVersion: 2,
    },
  }), false);
  assert.equal(allowed({role: null}), false);
});

test('explicit assignment is authoritative for its mobilization', () => {
  assert.equal(allowed({
    role: role({hasActiveMobilizationAssignments: true}),
    assignment: assignment(),
  }), true);
  assert.equal(allowed({
    role: role({hasActiveMobilizationAssignments: true}),
    assignment: assignment({mobilizationId: 'other'}),
  }), false);
});

test('explicit assignment authority disables the legacy fallback', () => {
  assert.equal(allowed({
    role: role({hasActiveMobilizationAssignments: true}),
  }), false);
  assert.equal(allowed({
    role: role({hasActiveMobilizationAssignments: 'true'}),
  }), false);
  assert.equal(allowed({
    role: role({hasActiveMobilizationAssignments: false}),
  }), true);
});
