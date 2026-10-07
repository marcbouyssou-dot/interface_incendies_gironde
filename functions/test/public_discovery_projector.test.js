import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
  PUBLIC_MISSION_FIELDS,
  isPubliclyDiscoverable,
  planPublicMissionDiscovery,
  projectPublicMission,
  publicMissionId,
} from '../src/public_discovery/projector.js';

const now = new Date('2026-10-07T12:00:00Z');
const mission = {
  mobilizationId: 'historical',
  territorialGroup: 'bordeauxMetropole',
  startAt: new Date('2026-10-08T08:00:00Z'),
  endAt: new Date('2026-10-08T12:00:00Z'),
  requiredByProfession: {physiotherapist: 2, nurse: 1, physician: 0},
  isActive: true,
  status: 'critical',
  locationId: 'sensitive-site', locationName: 'Precise site',
  address: '12 sensitive street', latitude: 44.0, longitude: -0.5,
  contactName: 'Private contact', contactPhone: 'private-phone',
  availableEquipmentOnSite: ['sensitive'],
  requestedEquipment: ['sensitive'],
  requestedEquipmentByProfession: {nurse: ['sensitive']},
  details: 'Sensitive operational note', createdBy: 'private-uid',
  registeredByProfession: {nurse: 1},
  engagementIds: ['private-uid'],
};
const mobilization = {id: 'historical', status: 'active'};

test('public projection is an exact allowlist and never copies operational fields', () => {
  const result = projectPublicMission({
    missionId: 'mission-safe', mission, mobilization,
    activeMobilizationId: 'historical', now,
  });
  assert.deepEqual(Object.keys(result), PUBLIC_MISSION_FIELDS);
  assert.deepEqual(result, {
    publicId: publicMissionId('mission-safe'), day: '2026-10-08',
    sectorLabel: 'Bordeaux Métropole',
    professions: ['physiotherapist', 'nurse'], status: 'open',
  });
  for (const value of ['sensitive', 'private', 'uid', 'address', 'equipment',
    'contact', 'latitude', 'longitude', 'details', 'quota', 'registered',
    'mission-safe']) {
    assert.equal(JSON.stringify(result).toLowerCase().includes(value), false);
  }
  assert.deepEqual(Object.keys(projectPublicMission({
    missionId: 'mission-safe', mission: {...mission, futureSecret: 'new secret'},
    mobilization, activeMobilizationId: 'historical', now,
  })), PUBLIC_MISSION_FIELDS);
});

test('publication and lifecycle remove cancelled, covered, past and hidden missions', () => {
  const input = {mission, mobilization, activeMobilizationId: 'historical', now};
  assert.equal(isPubliclyDiscoverable(input), true);
  for (const changed of [
    {...mission, isActive: false},
    {...mission, status: 'cancelled'},
    {...mission, status: 'complete'},
    {...mission, status: 'draft'},
    {...mission, endAt: new Date('2026-10-07T11:00:00Z')},
    {...mission, requiredByProfession: {nurse: 0}},
    {...mission, territorialGroup: 'unsupported'},
  ]) {
    const projected = projectPublicMission({...input, mission: changed,
      missionId: 'mission-safe'});
    assert.equal(projected, null);
  }
  assert.equal(projectPublicMission({...input, missionId: 'mission-safe',
    activeMobilizationId: 'other'}), null);
  assert.equal(projectPublicMission({...input, missionId: 'mission-safe',
    mobilization: {...mobilization, status: 'inactive'}}), null);
  assert.equal(projectPublicMission({...input, missionId: 'mission-safe',
    mobilization: {...mobilization, operationId: null}}), null);
});

test('new actions require explicit platform visibility', () => {
  const input = {missionId: 'mission-safe', mission,
    mobilization: {...mobilization, operationId: 'operation-a'},
    activeMobilizationId: 'historical', now};
  assert.equal(projectPublicMission({...input, operation: {status: 'active'}}), null);
  assert.equal(projectPublicMission({...input, operation: {
    visibility: 'organization_private', status: 'active',
  }}), null);
  assert.ok(projectPublicMission({...input, operation: {
    visibility: 'platform', status: 'active',
  }}));
});

test('rebuild plan is deterministic and idempotent', () => {
  const inputs = {
    missions: new Map([['a', mission], ['c', {...mission, status: 'cancelled'}]]),
    mobilizations: new Map([['historical', mobilization]]),
    operations: new Map(), activeMobilizationId: 'historical', now,
  };
  const currentProjections = new Map([['orphan-b', {publicId: 'orphan-b'}],
    [publicMissionId('c'), {publicId: publicMissionId('c')}]]);
  const first = planPublicMissionDiscovery({...inputs, currentProjections});
  assert.deepEqual(first.map(({action}) => action).sort(),
    ['CREATE', 'DELETE', 'DELETE']);
  assert.equal(first.find(({missionId}) => missionId === 'a').publicId,
    publicMissionId('a'));
  assert.equal(first.find(({publicId}) => publicId === 'orphan-b').missionId,
    null);
  const next = planPublicMissionDiscovery({...inputs,
    currentProjections: new Map([[publicMissionId('a'),
      first.find(({missionId}) => missionId === 'a').expected]])});
  assert.deepEqual(next.map(({action}) => action), ['UNCHANGED', 'UNCHANGED']);
});
