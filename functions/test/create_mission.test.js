import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createMission,
  missionCreateId,
  missionCreateMutation,
  missionCreateRequestHash,
  validateMissionCreateRequest,
} from '../src/create_mission.js';

const professions = [
  'physiotherapist', 'podiatrist', 'physician', 'nurse',
  'veterinarian', 'other_health_professional',
];
const quotas = (selected = {}) => Object.fromEntries(
  professions.map((profession) => [profession, selected[profession] ?? 0]),
);
const request = (overrides = {}) => ({
  mobilizationId: 'incendies-gironde-2026',
  locationId: 'bordeauxmetropole-bassens',
  startAtMillis: Date.parse('2026-10-04T06:00:00Z'),
  endAtMillis: Date.parse('2026-10-04T10:00:00Z'),
  requiredByProfession: quotas({
    physiotherapist: 3, podiatrist: 1, physician: 1, nurse: 2,
  }),
  priority: 'standard',
  requestedEquipmentByProfession: {
    physiotherapist: ['massage_table', 'massage_gun', 'massage_table'],
    podiatrist: ['podiatry_equipment'],
    physician: ['stethoscope', 'blood_pressure_monitor'],
    nurse: ['blood_pressure_monitor', 'care_equipment'],
  },
  details: 'Recette émulateur',
  idempotencyKey: '0123456789abcdef0123456789abcdef',
  ...overrides,
});
const manager = (sites = ['bordeauxmetropole-bassens']) => ({
  role: 'site_manager', roles: ['site_manager'], locationIds: sites,
  active: true, schemaVersion: 2,
});
const coordinator = () => ({
  role: 'coordinator', roles: ['coordinator'], locationIds: [],
  active: true, schemaVersion: 2,
});

function mutation(overrides = {}) {
  return missionCreateMutation({
    callerUid: 'manager-uid',
    missionId: missionCreateId('manager-uid', request().idempotencyKey),
    request: validateMissionCreateRequest(request()),
    callerRole: manager(),
    coordinatorAuthorized: false,
    organizationAuthorized: true,
    mobilization: {id: 'incendies-gironde-2026', status: 'active'},
    location: {name: 'Bassens', group: 'bordeauxMetropole', active: true,
      isOperational: true},
    serverTimestamp: 'SERVER_TIME',
    timestampFromMillis: (value) => new Date(value),
    ...overrides,
  });
}

function assertCode(action, code) {
  assert.throws(action, (error) => error.code === code);
}

test('Bassens multi-profession creation has seven places and deterministic equipment', () => {
  const parsed = validateMissionCreateRequest(request());
  const fields = mutation({request: parsed}).fields;
  assert.equal(Object.values(fields.requiredByProfession)
    .reduce((sum, value) => sum + value, 0), 7);
  assert.deepEqual(fields.requestedEquipmentByProfession.physiotherapist,
    ['massage_table', 'massage_gun']);
  assert.deepEqual(fields.requestedEquipment, [
    'Table de massage', 'Pistolet de massage', 'Matériel de podologie',
    'Stéthoscope', 'Tensiomètre', 'Matériel de soins',
  ]);
  assert.equal(fields.createdBy, 'manager-uid');
  assert.equal(fields.status, 'critical');
  assert.equal(fields.isActive, true);
  assert.equal(fields.createdAt, 'SERVER_TIME');
  assert.equal(fields.registeredMk, 0);
  assert.equal(fields.requiredMk, 3);
  assert.equal(fields.requiredPp, 1);
});

test('empty equipment, mono-profession and six professions remain valid', () => {
  const mono = validateMissionCreateRequest(request({
    requiredByProfession: quotas({physiotherapist: 1}),
    requestedEquipmentByProfession: {},
  }));
  assert.deepEqual(mutation({request: mono}).fields.requestedEquipment, []);
  const all = validateMissionCreateRequest(request({
    requiredByProfession: quotas(Object.fromEntries(professions.map((id) => [id, 1]))),
    requestedEquipmentByProfession: {},
  }));
  assert.equal(Object.values(all.requiredByProfession).reduce((a, b) => a + b), 6);
});

test('server rejects invalid equipment, profession, zero quota, schedule and sensitive fields', () => {
  for (const data of [
    request({requestedEquipmentByProfession: {physiotherapist: ['stethoscope']}}),
    request({requestedEquipmentByProfession: {veterinarian: ['electronic_chip_reader']}}),
    request({requestedEquipmentByProfession: {physiotherapist: []}}),
    request({requestedEquipmentByProfession: {doctor: ['stethoscope']}}),
    request({requiredByProfession: {...quotas({physiotherapist: 1}), doctor: 1}}),
    request({endAtMillis: request().startAtMillis}),
    request({authorId: 'attacker'}),
    request({role: 'coordinator'}),
    request({status: 'complete'}),
    request({requestedEquipment: ['Injected']}),
  ]) {
    assertCode(() => validateMissionCreateRequest(data), 'invalid-argument');
  }
});

test('authorization restricts site manager and coordinator and denies professional/admin alone', () => {
  assertCode(() => mutation({callerRole: manager(['another-site'])}), 'permission-denied');
  assertCode(() => mutation({callerRole: coordinator()}), 'permission-denied');
  assert.doesNotThrow(() => mutation({callerRole: coordinator(), coordinatorAuthorized: true}));
  assertCode(() => mutation({organizationAuthorized: false}), 'permission-denied');
  assertCode(() => mutation({callerRole: null}), 'permission-denied');
  assertCode(() => mutation({callerRole: {role: 'platform_admin'}}), 'permission-denied');
  assertCode(() => mutation({mobilization: {id: 'incendies-gironde-2026', status: 'closed'}}),
    'failed-precondition');
  assertCode(() => mutation({location: {name: 'Bassens', group: 'medoc', active: false}}),
    'failed-precondition');
});

test('authentication is required before any service call', async () => {
  await assert.rejects(() => createMission({
    callerUid: null,
    data: request(),
    services: {commitMissionCreate: () => assert.fail('not called')},
  }), (error) => error.code === 'unauthenticated');
});

test('same request key produces same document; different key or payload is distinct', () => {
  assert.equal(missionCreateId('uid', 'aaaaaaaaaaaaaaaa'),
    missionCreateId('uid', 'aaaaaaaaaaaaaaaa'));
  assert.notEqual(missionCreateId('uid', 'aaaaaaaaaaaaaaaa'),
    missionCreateId('uid', 'bbbbbbbbbbbbbbbb'));
  assert.notEqual(missionCreateId('uid', 'aaaaaaaaaaaaaaaa'),
    missionCreateId('other', 'aaaaaaaaaaaaaaaa'));
  const parsed = validateMissionCreateRequest(request());
  assert.equal(missionCreateRequestHash(parsed), missionCreateRequestHash(parsed));
  assert.notEqual(missionCreateRequestHash(parsed), missionCreateRequestHash(
    validateMissionCreateRequest(request({details: 'Changed'}))));
});


test('publication captures site inventory and preserves absent versus empty', () => {
  const withEquipment = mutation({location: {
    name: 'Bassens', group: 'bordeauxMetropole', active: true,
    availableEquipment: ['stethoscope', 'massage_table', 'massage_table'],
  }}).fields;
  assert.deepEqual(withEquipment.availableEquipmentOnSite,
    ['massage_table', 'stethoscope']);
  const withoutInventory = mutation().fields;
  assert.equal(Object.hasOwn(withoutInventory, 'availableEquipmentOnSite'), false);
  const explicitNone = mutation({location: {
    name: 'Bassens', group: 'bordeauxMetropole', active: true,
    availableEquipment: [],
  }}).fields;
  assert.deepEqual(explicitNone.availableEquipmentOnSite, []);
  const clientInjection = request({availableEquipmentOnSite: ['massage_table']});
  assertCode(() => validateMissionCreateRequest(clientInjection), 'invalid-argument');
  assertCode(() => mutation({location: {
    name: 'Bassens', group: 'bordeauxMetropole', active: true,
    availableEquipment: ['invalid'],
  }}), 'failed-precondition');
  // Changing the source after publication cannot mutate the snapshot object.
  const site = {name: 'Bassens', group: 'bordeauxMetropole', active: true,
    availableEquipment: ['massage_table']};
  const published = mutation({location: site}).fields;
  site.availableEquipment = ['stethoscope'];
  assert.deepEqual(published.availableEquipmentOnSite, ['massage_table']);
});

test('closed or missing parent Action blocks mission creation', () => {
  const mobilization = {
    id: 'incendies-gironde-2026', status: 'active', operationId: 'action-a',
  };
  for (const status of ['completed', 'archived', 'suspended', 'planned']) {
    assertCode(() => mutation({
      mobilization, operation: {id: 'action-a', status},
    }), 'failed-precondition');
  }
  assertCode(() => mutation({mobilization}), 'failed-precondition');
  assertCode(() => mutation({mobilization,
    operation: {id: 'action-a', status: 'active'}}), 'permission-denied');
  assert.equal(mutation({mobilization,
    operation: {id: 'action-a', status: 'active'},
    operationAccess: {coordinator: false,
      locationIds: ['bordeauxmetropole-bassens']}}).fields.id.length > 0, true);
});
