import assert from 'node:assert/strict';
import {test} from 'node:test';
import {Timestamp} from 'firebase-admin/firestore';

import {
  distanceKm, eligibleProfessionalUids, INTERVENTION_RADII_KM,
  TARGETING_READY, TARGETING_UNAVAILABLE_SITE_LOCATION, targetingSiteStatus,
} from '../src/operational_notifications/professional_targeting.js';

const now = Date.UTC(2026, 9, 8);
const site = {
  id: 'site-a', latitude: 0, longitude: 0,
  addressStatus: 'verified_official',
};
const mission = {
  id: 'mission-a', mobilizationId: 'mobilization-a', locationId: 'site-a',
  isActive: true, status: 'critical',
  requiredByProfession: {physiotherapist: 1},
  registeredByProfession: {physiotherapist: 0},
};
const mobilization = {
  id: 'mobilization-a', operationId: 'operation-a', status: 'active',
};
const operation = {
  id: 'operation-a', ownerOrganizationId: 'organization-a',
  status: 'active', purpose: 'operational',
};

function professional(uid, profession = 'physiotherapist', verified = true) {
  return {
    uid, profession, professionalIdType: 'rpps',
    professionalIdValue: '10123456789', rpps: '10123456789',
    verificationStatus: verified ? 'verified' : 'unverified',
    verificationSource: verified ? 'ans_rpps' : null,
    verifiedFirstName: verified ? 'Alice' : null,
    verifiedLastName: verified ? 'Exemple' : null,
    verifiedProfessionCode: profession === 'nurse' ? '60' : '70',
    verifiedProfessionLabel: verified ? 'Professionnel' : null,
    verifiedAt: verified ? Timestamp.fromMillis(now) : null,
  };
}

function grant(uid, operationId = 'operation-a') {
  return {
    uid, operationId, organizationId: 'organization-a',
    profession: 'physiotherapist', status: 'active',
    expiresAt: Timestamp.fromMillis(now + 86400000),
  };
}

function targeting(uid, latitude, enabled = true) {
  return {uid, latitude, longitude: 0, radiusKm: 20, enabled};
}

function candidateSet(overrides = {}) {
  const volunteers = [
    professional('within'), professional('outside'),
    professional('wrong-profession', 'nurse'),
    professional('wrong-action'), professional('unverified', 'physiotherapist', false),
    professional('disabled'), professional('no-preference'),
  ];
  const targetings = new Map([
    ['within', targeting('within', 0.09)],
    ['outside', targeting('outside', 0.27)],
    ['wrong-profession', targeting('wrong-profession', 0.09)],
    ['wrong-action', targeting('wrong-action', 0.09)],
    ['unverified', targeting('unverified', 0.09)],
    ['disabled', targeting('disabled', 0.09, false)],
  ]);
  const admissions = new Map(volunteers
    .filter((item) => item.uid !== 'wrong-action')
    .map((item) => [item.uid, grant(item.uid)]));
  return eligibleProfessionalUids({
    mission, mobilization, operation, location: site,
    admissionMode: 'invitation_only', volunteers, targetings, admissions,
    preferences: new Map(volunteers.map((item) =>
      [item.uid, {compatibleMissions: true}])),
    now, ...overrides,
  });
}

test('20 km radius admits a 10 km professional and excludes 30 km', () => {
  assert.deepEqual(INTERVENTION_RADII_KM, [10, 20, 30, 50]);
  assert.ok(distanceKm({latitude: 0.09, longitude: 0}, site) > 9);
  assert.ok(distanceKm({latitude: 0.27, longitude: 0}, site) > 29);
  assert.deepEqual(candidateSet(), new Set(['within']));
});

test('unverified site coordinates return an explicit unavailable state', () => {
  assert.equal(targetingSiteStatus(site), TARGETING_READY);
  assert.equal(targetingSiteStatus({...site, latitude: null}),
    TARGETING_UNAVAILABLE_SITE_LOCATION);
  assert.equal(targetingSiteStatus({...site, addressStatus: 'needs_confirmation'}),
    TARGETING_UNAVAILABLE_SITE_LOCATION);
});

test('Action, identity, profession, opt-in and site gates fail closed', () => {
  assert.deepEqual(candidateSet({operation: {...operation, id: 'operation-b'}}), new Set());
  assert.deepEqual(candidateSet({location: {...site, addressStatus: 'needs_confirmation'}}), new Set());
  assert.deepEqual(candidateSet({admissionMode: 'unknown'}), new Set());
  assert.deepEqual(candidateSet({roleUids: new Set(['within'])}),
    new Set(['within']));
  assert.deepEqual(candidateSet({preferences: new Map()}), new Set());
  assert.deepEqual(candidateSet({now: now + 86400001}), new Set());
});

test('open mode skips Action admission while retaining all other checks', () => {
  const admissions = new Map();
  assert.deepEqual(candidateSet({admissionMode: 'open', admissions}),
    new Set(['within', 'wrong-action']));
});
