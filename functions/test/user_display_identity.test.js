import assert from 'node:assert/strict';
import test from 'node:test';

import {
  listMissionTeam,
  listPlatformCoordinatorIdentities,
  safeCoordinatorIdentity,
  safeProfessionalIdentity,
  UserDisplayIdentityError,
} from '../src/user_display_identity.js';

async function assertCode(action, code) {
  await assert.rejects(
    action,
    (error) => error instanceof UserDisplayIdentityError
      && error.code === code,
  );
}

test('mission identity resolution requires an authenticated caller', async () => {
  let called = false;
  await assertCode(
    () => listMissionTeam({
      callerUid: null,
      data: {missionId: 'mission-1'},
      services: {
        async listMissionTeam() {
          called = true;
          return [];
        },
      },
    }),
    'unauthenticated',
  );
  assert.equal(called, false);
});

test('mission identity resolution rejects broad or malformed requests', async () => {
  for (const data of [
    {},
    {missionId: ''},
    {missionId: 'mission-1', uids: ['volunteer-1']},
  ]) {
    await assertCode(
      () => listMissionTeam({
        callerUid: 'manager',
        data,
        services: {listMissionTeam: async () => []},
      }),
      'invalid-argument',
    );
  }
});

test('professional identity exposes only contextual display fields', () => {
  const value = safeProfessionalIdentity({
    engagement: {
      missionId: 'mission-1',
      volunteerId: 'technical-uid',
      profession: 'physiotherapist',
      status: 'confirmed',
    },
    profile: {
      firstName: 'Ancien',
      lastName: 'Nom',
      phone: '0600000000',
      email: 'secret@example.test',
      rpps: '12345678901',
      professionalAddressLine1: '10 rue confidentielle',
      professionalAddressLine2: 'Bâtiment B',
      professionalPostalCode: '33000',
      professionalCity: 'Bordeaux',
      professionalCountryCode: 'FR',
      verificationStatus: 'verified',
      verificationSource: 'ans_rpps',
      verifiedFirstName: 'Marc',
      verifiedLastName: 'BOUYSSOU',
      verifiedProfessionLabel: 'Masseur-Kinésithérapeute',
    },
  });

  assert.deepEqual(value, {
    uid: 'technical-uid',
    missionId: 'mission-1',
    displayName: 'Marc BOUYSSOU',
    profession: 'physiotherapist',
    professionLabel: 'Masseur-Kinésithérapeute',
    organizationLabel: null,
    status: 'confirmed',
  });
  assert.equal(Object.hasOwn(value, 'phone'), false);
  assert.equal(Object.hasOwn(value, 'email'), false);
  assert.equal(Object.hasOwn(value, 'rpps'), false);
  assert.equal(Object.hasOwn(value, 'professionalAddressLine1'), false);
  assert.equal(Object.hasOwn(value, 'professionalPostalCode'), false);
  assert.equal(Object.hasOwn(value, 'professionalCity'), false);
});

test('missing professional identity remains human and neutral', () => {
  const value = safeProfessionalIdentity({
    engagement: {
      missionId: 'mission-1',
      volunteerId: 'technical-uid',
      profession: 'nurse',
      status: 'confirmed',
    },
    profile: null,
  });

  assert.equal(value.displayName, null);
  assert.equal(value.professionLabel, 'Infirmier');
});

test('platform coordinator resolution is delegated only after auth', async () => {
  const expected = [safeCoordinatorIdentity({
    uid: 'coordinator-1',
    identity: {displayName: 'Camille Martin'},
    organizationLabel: 'Périmètre départemental',
  })];
  const result = await listPlatformCoordinatorIdentities({
    callerUid: 'platform-admin',
    services: {listPlatformCoordinators: async () => expected},
  });

  assert.deepEqual(result, {coordinators: expected});
  assert.equal(result.coordinators[0].displayName, 'Camille Martin');
});
