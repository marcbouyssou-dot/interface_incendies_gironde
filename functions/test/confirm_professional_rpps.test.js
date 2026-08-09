import assert from 'node:assert/strict';
import test from 'node:test';

import {confirmProfessionalRpps} from '../src/confirm_professional_rpps.js';
import {ProfessionalRppsVerificationError} from '../src/verify_professional_rpps.js';

const RPPS = '00000000000';
const VERIFIED = Object.freeze({
  status: 'verified',
  rpps: RPPS,
  firstName: 'Alice',
  lastName: 'EXEMPLE',
  professionCode: '70',
  professionLabel: 'Masseur-Kinésithérapeute',
  source: 'ans_rpps',
});

function services({result = VERIFIED, profile = {profession: 'physiotherapist'}} = {}) {
  const writes = [];
  return {
    writes,
    async verifyRpps() {
      return result;
    },
    async getVolunteerProfile() {
      return profile;
    },
    async persistVerifiedProfile(uid, value, expectedProfession) {
      writes.push({uid, value, expectedProfession});
      return true;
    },
  };
}

test('revérifie puis persiste uniquement les données ANS normalisées', async () => {
  const dependencies = services();
  const value = await confirmProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: RPPS},
    services: dependencies,
  });

  assert.deepEqual(value, VERIFIED);
  assert.deepEqual(dependencies.writes, [{
    uid: 'user-1',
    value: VERIFIED,
    expectedProfession: 'physiotherapist',
  }]);
});

test('accepte les identifiants de profession historiques', async () => {
  const dependencies = services({profile: {profession: 'mk'}});
  const value = await confirmProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: RPPS},
    services: dependencies,
  });

  assert.equal(value.status, 'verified');
  assert.equal(dependencies.writes.length, 1);
});

test('ne persiste pas une réponse non vérifiée', async () => {
  const dependencies = services({
    result: {...VERIFIED, status: 'not_found', firstName: '', lastName: '', professionCode: '', professionLabel: ''},
  });
  const value = await confirmProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: RPPS},
    services: dependencies,
  });

  assert.equal(value.status, 'not_found');
  assert.deepEqual(dependencies.writes, []);
});

test('refuse une profession incompatible sans écriture', async () => {
  const dependencies = services({profile: {profession: 'physician'}});
  await assert.rejects(
    () => confirmProfessionalRpps({
      callerUid: 'user-1',
      data: {rpps: RPPS},
      services: dependencies,
    }),
    (error) => error instanceof ProfessionalRppsVerificationError
      && error.code === 'failed-precondition',
  );
  assert.deepEqual(dependencies.writes, []);
});

test('refuse une confirmation sans profil', async () => {
  const dependencies = services({profile: null});
  await assert.rejects(
    () => confirmProfessionalRpps({
      callerUid: 'user-1',
      data: {rpps: RPPS},
      services: dependencies,
    }),
    (error) => error instanceof ProfessionalRppsVerificationError
      && error.code === 'failed-precondition',
  );
  assert.deepEqual(dependencies.writes, []);
});

test('refuse une écriture si la profession change pendant la transaction', async () => {
  const dependencies = services();
  dependencies.persistVerifiedProfile = async () => false;
  await assert.rejects(
    () => confirmProfessionalRpps({
      callerUid: 'user-1',
      data: {rpps: RPPS},
      services: dependencies,
    }),
    (error) => error instanceof ProfessionalRppsVerificationError
      && error.code === 'failed-precondition',
  );
});
