import assert from 'node:assert/strict';
import test from 'node:test';

import {
  adminLocationRecord,
  listAdminLocations,
  LocationAdministrationError,
  locationManagementMutation,
  manageLocation,
  validateLocationManagementRequest,
} from '../src/location_administration.js';

const locationData = Object.freeze({
  name: 'Centre Test',
  group: 'bordeauxMetropole',
  type: 'sdisStation',
  addressLine1: '10 rue du Test',
  addressLine2: null,
  postalCode: '33000',
  city: 'Bordeaux',
  country: 'France',
  contactName: 'Camille Martin',
  contactPhone: '06 12 34 56 78',
  latitude: 44.84,
  longitude: -0.58,
});

function request(action, overrides = {}) {
  return action === 'delete'
    ? {action, locationId: 'centre-test', ...overrides}
    : {action, locationId: 'centre-test', data: locationData, ...overrides};
}

function assertCode(action, code) {
  assert.throws(action, (error) => {
    assert.ok(error instanceof LocationAdministrationError);
    assert.equal(error.code, code);
    return true;
  });
}

test('accepts strict create, update, setActive and delete requests', () => {
  assert.equal(validateLocationManagementRequest(request('create')).action,
    'create');
  assert.equal(validateLocationManagementRequest(request('update')).action,
    'update');
  assert.deepEqual(validateLocationManagementRequest(request('setActive', {
    data: {active: false},
  })).data, {active: false});
  assert.equal(validateLocationManagementRequest(request('delete')).action,
    'delete');
});

test('refuses unknown fields, actions, types and non-canonical ids', () => {
  for (const value of [
    {...request('create'), extra: true},
    request('unknown'),
    request('create', {locationId: 'Centre Test'}),
    request('create', {data: {...locationData, unknown: true}}),
    request('create', {data: {...locationData, group: 'unknown'}}),
    request('create', {data: {...locationData, latitude: '44.84'}}),
    request('create', {data: {...locationData, longitude: null}}),
  ]) {
    assertCode(() => validateLocationManagementRequest(value),
      'invalid-argument');
  }
});

test('creation stores canonical fields and administrative defaults', () => {
  const validated = validateLocationManagementRequest(request('create'));
  const mutation = locationManagementMutation({
    ...validated,
    current: null,
  });
  assert.equal(mutation.kind, 'create');
  assert.equal(mutation.fields.id, 'centre-test');
  assert.equal(mutation.fields.active, true);
  assert.equal(mutation.fields.activeNeeds, 0);
  assert.equal(mutation.fields.isOperational, true);
  assert.equal(mutation.fields.addressStatus, 'needs_confirmation');
  assert.equal(
    mutation.fields.fullAddress,
    '10 rue du Test, 33000 Bordeaux, France',
  );
});

test('duplicate creation is refused without mutation', () => {
  assertCode(() => locationManagementMutation({
    ...validateLocationManagementRequest(request('create')),
    current: {name: 'Existant'},
  }), 'already-exists');
});

test('update never writes the identifier or historical metadata', () => {
  const mutation = locationManagementMutation({
    ...validateLocationManagementRequest(request('update')),
    current: {id: 'centre-test', addressSourceUrl: 'https://example.test'},
  });
  assert.equal(mutation.kind, 'update');
  assert.equal(Object.hasOwn(mutation.fields, 'id'), false);
  assert.equal(Object.hasOwn(mutation.fields, 'addressSourceUrl'), false);
  assert.equal(Object.hasOwn(mutation.fields, 'activeNeeds'), false);
});

test('setActive supports deactivation and reactivation only', () => {
  for (const active of [false, true]) {
    const mutation = locationManagementMutation({
      ...validateLocationManagementRequest(request('setActive', {
        data: {active},
      })),
      current: {name: 'Centre Test'},
    });
    assert.deepEqual(mutation.fields, {active});
  }
});

test('delete succeeds unused and refuses every referenced location', () => {
  assert.deepEqual(locationManagementMutation({
    ...validateLocationManagementRequest(request('delete')),
    current: {name: 'Centre Test'},
    used: false,
  }), {kind: 'delete'});
  assertCode(() => locationManagementMutation({
    ...validateLocationManagementRequest(request('delete')),
    current: {name: 'Centre Test'},
    used: true,
  }), 'failed-precondition');
});

test('legacy locations remain readable and active by default', () => {
  const value = adminLocationRecord('legacy', {
    name: 'Centre historique',
    territorialGroup: 'medoc',
    type: 'sdisStation',
    address: '1 rue Historique',
    isOperational: false,
  });
  assert.equal(value.group, 'medoc');
  assert.equal(value.addressLine1, '1 rue Historique');
  assert.equal(value.active, true);
  assert.equal(value.isOperational, false);
});

test('management delegates only a validated request to its service', async () => {
  const calls = [];
  const result = await manageLocation({
    callerUid: 'coordinator',
    data: request('setActive', {data: {active: false}}),
    services: {
      async commitLocationManagement(value) {
        calls.push(value);
        return {location: {id: value.locationId, active: false}};
      },
    },
  });
  assert.equal(result.location.active, false);
  assert.equal(calls.length, 1);
  assert.equal(calls[0].callerUid, 'coordinator');
});

test('listing and management refuse anonymous callers before services', async () => {
  let calls = 0;
  const services = {
    async listAdminLocations() {
      calls++;
      return [];
    },
    async commitLocationManagement() {
      calls++;
    },
  };
  await assert.rejects(
    () => listAdminLocations({callerUid: null, services}),
    (error) => error.code === 'unauthenticated',
  );
  await assert.rejects(
    () => manageLocation({callerUid: '', data: request('delete'), services}),
    (error) => error.code === 'unauthenticated',
  );
  assert.equal(calls, 0);
});

test('listing returns the safe service projection without side effects', async () => {
  const locations = [adminLocationRecord('centre-test', locationData)];
  const result = await listAdminLocations({
    callerUid: 'coordinator',
    services: {async listAdminLocations() { return locations; }},
  });
  assert.deepEqual(result, {locations});
});
