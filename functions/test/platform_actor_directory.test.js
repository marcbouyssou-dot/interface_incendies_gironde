import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildPlatformActorDirectory,
  listPlatformActorDirectory,
  PlatformActorDirectoryError,
} from '../src/platform_actor_directory.js';

async function assertCode(action, code) {
  await assert.rejects(
    action,
    (error) => error instanceof PlatformActorDirectoryError
      && error.code === code,
  );
}

test('actor directory requires an active platform administrator', async () => {
  const services = {
    isPlatformAdministrator: async () => false,
    loadDirectoryData: async () => assert.fail('must not load data'),
  };
  await assertCode(
    () => listPlatformActorDirectory({callerUid: null, services}),
    'unauthenticated',
  );
  await assertCode(
    () => listPlatformActorDirectory({callerUid: 'admin', services}),
    'permission-denied',
  );
});

test('professional participations are aggregated without leaking contacts', () => {
  const directory = buildPlatformActorDirectory(fixture());

  assert.equal(directory.professionals.length, 1);
  const professional = directory.professionals[0];
  assert.equal(professional.displayName, 'Alice MARTIN');
  assert.equal(professional.participations.length, 2);
  assert.deepEqual(
    professional.participations.map((item) => item.operationId).sort(),
    ['operation-a', 'operation-b'],
  );
  assert.equal(professional.departmentLabel, 'Gironde');
  assert.equal(professional.regionLabel, 'Nouvelle-Aquitaine');
  assert.equal(Object.hasOwn(professional, 'phone'), false);
  assert.equal(Object.hasOwn(professional, 'email'), false);
  assert.equal(Object.hasOwn(professional, 'rpps'), false);
});

test('coordinators and managers keep exact operation and location scopes', () => {
  const directory = buildPlatformActorDirectory(fixture());

  assert.deepEqual(directory.coordinators, [{
    uid: 'coordinator-1',
    displayName: 'Camille Martin',
    active: true,
    mobilizations: [{
      id: 'mobilization-a',
      label: 'Mobilisation A',
      active: true,
    }],
    operations: [{id: 'operation-a', label: 'Opération A'}],
  }]);
  assert.deepEqual(directory.managers, [{
    uid: 'manager-1',
    displayName: 'Morgan Dupont',
    active: false,
    locations: [{id: 'location-a', label: 'Centre A'}],
    operations: [{id: 'operation-a', label: 'Opération A'}],
    territories: [{id: 'territory-a', label: 'Gironde'}],
  }]);
});

function fixture() {
  return {
    operations: [
      {id: 'operation-a', name: 'Opération A', coordinatorUid: 'coordinator-1'},
      {id: 'operation-b', name: 'Opération B'},
    ],
    mobilizations: [
      {
        id: 'mobilization-a',
        name: 'Mobilisation A',
        operationId: 'operation-a',
        territoryId: 'territory-a',
      },
      {
        id: 'mobilization-b',
        name: 'Mobilisation B',
        operationId: 'operation-b',
        territoryId: 'territory-b',
      },
    ],
    missions: [
      {
        id: 'mission-a',
        mobilizationId: 'mobilization-a',
        locationId: 'location-a',
        locationName: 'Centre A',
      },
      {
        id: 'mission-b',
        mobilizationId: 'mobilization-b',
        locationId: 'location-b',
        locationName: 'Centre B',
      },
    ],
    engagements: [
      {
        volunteerId: 'professional-1',
        missionId: 'mission-a',
        mobilizationId: 'mobilization-a',
        profession: 'nurse',
        status: 'confirmed',
        createdAt: new Date('2026-08-20T10:00:00Z'),
      },
      {
        volunteerId: 'professional-1',
        missionId: 'mission-b',
        mobilizationId: 'mobilization-b',
        profession: 'nurse',
        status: 'cancelled',
        createdAt: new Date('2026-08-19T10:00:00Z'),
      },
    ],
    volunteers: [{
      id: 'professional-1',
      firstName: 'Alice',
      lastName: 'MARTIN',
      phone: '0600000000',
      email: 'secret@example.test',
      rpps: '12345678901',
      professionalPostalCode: '33000',
      cptsId: 'cpts-a',
      cptsLabel: 'CPTS A',
    }],
    roles: [
      {
        id: 'coordinator-1',
        roles: ['coordinator'],
        locationIds: [],
        active: true,
      },
      {
        id: 'manager-1',
        roles: ['site_manager'],
        locationIds: ['location-a'],
        active: false,
      },
    ],
    assignments: [{
      uid: 'coordinator-1',
      mobilizationId: 'mobilization-a',
      active: true,
    }],
    locations: [
      {id: 'location-a', name: 'Centre A'},
      {id: 'location-b', name: 'Centre B'},
    ],
    territories: [
      {id: 'territory-a', name: 'Gironde'},
      {id: 'territory-b', name: 'Landes'},
    ],
    roleIdentities: [
      {uid: 'coordinator-1', displayName: 'Camille Martin'},
      {uid: 'manager-1', displayName: 'Morgan Dupont'},
    ],
  };
}
