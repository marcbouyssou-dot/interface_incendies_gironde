import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ProfessionalRppsVerificationError,
  verifyProfessionalRpps,
} from '../src/verify_professional_rpps.js';

const RPPS = '00000000000';

function result(status, overrides = {}) {
  return {
    status,
    rpps: status === 'invalid' ? 'invalid' : RPPS,
    firstName: status === 'verified' ? 'Alice' : '',
    lastName: status === 'verified' ? 'EXEMPLE' : '',
    professionCode: status === 'verified' ? '70' : '',
    professionLabel: status === 'verified'
      ? 'Masseur-Kinésithérapeute'
      : '',
    source: 'ans_rpps',
    ...overrides,
  };
}

function service(response) {
  const calls = [];
  return {
    calls,
    async verifyRpps(rpps) {
      calls.push(rpps);
      return typeof response === 'function' ? response(rpps) : response;
    },
  };
}

test('refuse un utilisateur non authentifié avant le service', async () => {
  const services = service(result('verified'));
  await assert.rejects(
    () => verifyProfessionalRpps({
      callerUid: null,
      data: {rpps: RPPS},
      services,
    }),
    (error) => error instanceof ProfessionalRppsVerificationError
      && error.code === 'unauthenticated',
  );
  assert.equal(services.calls.length, 0);
});

test('conserve le statut invalid du service RPPS', async () => {
  const services = service(result('invalid'));
  const value = await verifyProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: ' invalid '},
    services,
  });
  assert.equal(value.status, 'invalid');
  assert.equal(value.rpps, 'invalid');
  assert.deepEqual(services.calls, [' invalid ']);
});

test('retourne un professionnel trouvé', async () => {
  const value = await verifyProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: RPPS},
    services: service(result('verified')),
  });
  assert.equal(value.status, 'verified');
  assert.equal(value.professionLabel, 'Masseur-Kinésithérapeute');
});

test('conserve le statut not_found sans identité', async () => {
  const value = await verifyProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: RPPS},
    services: service(result('not_found')),
  });
  assert.deepEqual(value, result('not_found'));
});

test('conserve le statut unavailable sans le transformer en not_found', async () => {
  const value = await verifyProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: RPPS},
    services: service(result('unavailable')),
  });
  assert.equal(value.status, 'unavailable');
});

test('normalise exactement la réponse publique attendue', async () => {
  const value = await verifyProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: RPPS},
    services: service(result('verified', {
      firstName: ' Alice ',
      lastName: ' EXEMPLE ',
    })),
  });
  assert.deepEqual(value, {
    status: 'verified',
    rpps: RPPS,
    firstName: 'Alice',
    lastName: 'EXEMPLE',
    professionCode: '70',
    professionLabel: 'Masseur-Kinésithérapeute',
    source: 'ans_rpps',
  });
});

test('n’expose jamais un secret ou un champ fournisseur supplémentaire', async () => {
  const fakeSecret = 'ans-secret-must-not-leak';
  const value = await verifyProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: RPPS},
    services: service(result('verified', {
      apiKey: fakeSecret,
      rawProviderResponse: {secret: fakeSecret},
    })),
  });
  assert.deepEqual(Object.keys(value), [
    'status',
    'rpps',
    'firstName',
    'lastName',
    'professionCode',
    'professionLabel',
    'source',
  ]);
  assert.equal(JSON.stringify(value).includes(fakeSecret), false);
});

test('convertit une exception technique du service en unavailable', async () => {
  const value = await verifyProfessionalRpps({
    callerUid: 'user-1',
    data: {rpps: RPPS},
    services: service(() => {
      throw new Error('panne ANS simulée');
    }),
  });
  assert.deepEqual(value, result('unavailable'));
});
