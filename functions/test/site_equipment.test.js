import assert from 'node:assert/strict';
import test from 'node:test';

import {SITE_EQUIPMENT_IDS} from '../src/mission_equipment.js';
import {
  normalizeSiteEquipment,
  siteEquipmentMutation,
  updateSiteEquipment,
  validateSiteEquipmentRequest,
} from '../src/site_equipment.js';

const bassens = 'bordeauxmetropole-bassens';
const other = 'bordeauxmetropole-autre';
const role = (roles, locations, active = true) => ({
  role: roles.includes('coordinator') ? 'coordinator' : 'site_manager',
  roles,
  locationIds: locations,
  active,
  schemaVersion: 2,
});
const request = (locationId = bassens) => validateSiteEquipmentRequest({
  locationId,
  availableEquipment: ['massage_table', 'stethoscope', 'massage_table'],
});
const mutation = (overrides = {}) => siteEquipmentMutation({
  request: request(),
  role: role(['site_manager'], [bassens]),
  location: {id: bassens, active: true, isOperational: true},
  ...overrides,
});
const code = (action, expected) => assert.throws(action, (error) => {
  assert.equal(error.code, expected);
  return true;
});

test('site catalog uses twenty concrete canonical entries and deduplicates', () => {
  assert.equal(SITE_EQUIPMENT_IDS.length, 20);
  assert.deepEqual(normalizeSiteEquipment([
    'stethoscope', 'massage_table', 'massage_table',
  ]), ['massage_table', 'stethoscope']);
  assert.deepEqual(normalizeSiteEquipment([]), []);
  for (const id of ['other_equipment', 'other_veterinary_equipment',
    'profession_specific_equipment', 'unknown']) {
    code(() => normalizeSiteEquipment([id]), 'invalid-argument');
  }
  code(() => normalizeSiteEquipment(null), 'invalid-argument');
});

test('request accepts only a site ID and concrete equipment IDs', () => {
  assert.deepEqual(Object.keys(request()), ['locationId', 'availableEquipment']);
  for (const data of [
    {locationId: bassens, availableEquipment: [], role: 'coordinator'},
    {locationId: '../other', availableEquipment: []},
    {locationId: bassens, availableEquipment: ['invalid']},
  ]) code(() => validateSiteEquipmentRequest(data), 'invalid-argument');
});

test('Bassens site manager and coordinator write only the site inventory', () => {
  assert.deepEqual(mutation(), {availableEquipment: ['massage_table', 'stethoscope']});
  assert.deepEqual(mutation({role: role(['coordinator'], [])}),
    {availableEquipment: ['massage_table', 'stethoscope']});
  code(() => mutation({request: request(other)}), 'permission-denied');
  code(() => mutation({role: role(['site_manager'], [bassens], false)}),
    'permission-denied');
  code(() => mutation({role: null}), 'permission-denied');
  code(() => mutation({role: {role: 'professional', active: true}}),
    'permission-denied');
  code(() => mutation({location: null}), 'not-found');
});

test('anonymous callers never reach the service', async () => {
  await assert.rejects(() => updateSiteEquipment({
    callerUid: null,
    data: {locationId: bassens, availableEquipment: []},
    services: {commitSiteEquipment: () => assert.fail('called')},
  }), (error) => error.code === 'unauthenticated');
});
