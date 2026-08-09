import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ANS_RPPS_FHIR_ENDPOINT,
  verifyRpps,
} from '../src/ans_rpps_verification.js';

const SYNTHETIC_RPPS = '00000000000';
const API_KEY = 'test-api-key-never-sent';
const IDENTIFIER_TYPE_SYSTEM =
  'https://hl7.fr/ig/fhir/core/CodeSystem/fr-core-cs-v2-0203';
const PROFESSION_SYSTEM =
  'https://mos.esante.gouv.fr/NOS/TRE_G15-ProfessionSante/FHIR/'
  + 'TRE-G15-ProfessionSante';

function response(body, {ok = true} = {}) {
  return {
    ok,
    async json() {
      return body;
    },
  };
}

function practitioner(rpps = SYNTHETIC_RPPS) {
  return {
    resourceType: 'Practitioner',
    identifier: [{
      system: 'https://rpps.esante.gouv.fr',
      type: {
        coding: [{
          system: IDENTIFIER_TYPE_SYSTEM,
          code: 'RPPS',
        }],
      },
      value: rpps,
    }],
    name: [{
      use: 'official',
      family: 'EXEMPLE',
      given: ['Alice', 'Anne'],
    }],
    qualification: [{
      code: {
        coding: [{
          system: PROFESSION_SYSTEM,
          code: '10',
          display: 'Médecin',
        }],
      },
    }],
  };
}

function bundle(entries, total = entries.length) {
  return {
    resourceType: 'Bundle',
    type: 'searchset',
    total,
    entry: entries.map((resource) => ({resource})),
  };
}

test('vérifie un RPPS valide trouvé et normalise les données ANS', async () => {
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({url, options});
    return response(bundle([practitioner()]));
  };

  const result = await verifyRpps(`  ${SYNTHETIC_RPPS}  `, {
    apiKey: API_KEY,
    fetchImpl,
  });

  assert.deepEqual(result, {
    status: 'verified',
    rpps: SYNTHETIC_RPPS,
    firstName: 'Alice Anne',
    lastName: 'EXEMPLE',
    professionCode: '10',
    professionLabel: 'Médecin',
    source: 'ans_rpps',
  });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url.origin + calls[0].url.pathname, ANS_RPPS_FHIR_ENDPOINT);
  assert.equal(calls[0].url.searchParams.get('identifier'), SYNTHETIC_RPPS);
  assert.equal(calls[0].url.searchParams.get('_count'), '2');
  assert.equal(calls[0].options.headers['ESANTE-API-KEY'], API_KEY);
});

test('retourne not_found pour un Bundle FHIR vide', async () => {
  const result = await verifyRpps(SYNTHETIC_RPPS, {
    apiKey: API_KEY,
    fetchImpl: async () => response(bundle([])),
  });
  assert.equal(result.status, 'not_found');
  assert.equal(result.rpps, SYNTHETIC_RPPS);
});

test('rejette localement un format invalide sans appel réseau', async () => {
  let calls = 0;
  const result = await verifyRpps('  12345A  ', {
    fetchImpl: async () => {
      calls += 1;
      throw new Error('ne doit pas être appelé');
    },
  });
  assert.equal(result.status, 'invalid');
  assert.equal(result.rpps, '12345A');
  assert.equal(calls, 0);
});

test('retourne unavailable lors d’un timeout', async () => {
  const fetchImpl = (_url, {signal}) => new Promise((resolve, reject) => {
    signal.addEventListener('abort', () => {
      const error = new Error('timeout simulé');
      error.name = 'AbortError';
      reject(error);
    }, {once: true});
  });

  const result = await verifyRpps(SYNTHETIC_RPPS, {
    apiKey: API_KEY,
    fetchImpl,
    timeoutMs: 5,
  });
  assert.equal(result.status, 'unavailable');
});

test('retourne unavailable pour une réponse HTTP non 2xx', async () => {
  const result = await verifyRpps(SYNTHETIC_RPPS, {
    apiKey: API_KEY,
    fetchImpl: async () => response(null, {ok: false}),
  });
  assert.equal(result.status, 'unavailable');
});

test('retourne unavailable pour une réponse FHIR malformée', async () => {
  const malformedBundle = bundle([{resourceType: 'Patient'}]);
  const result = await verifyRpps(SYNTHETIC_RPPS, {
    apiKey: API_KEY,
    fetchImpl: async () => response(malformedBundle),
  });
  assert.equal(result.status, 'unavailable');
});

test('retourne unavailable sans choisir arbitrairement parmi plusieurs résultats', async () => {
  const multipleBundle = bundle([
    practitioner(),
    practitioner(),
  ]);
  const result = await verifyRpps(SYNTHETIC_RPPS, {
    apiKey: API_KEY,
    fetchImpl: async () => response(multipleBundle),
  });
  assert.equal(result.status, 'unavailable');
});

test('retourne unavailable pour un corps non JSON', async () => {
  const result = await verifyRpps(SYNTHETIC_RPPS, {
    apiKey: API_KEY,
    fetchImpl: async () => ({
      ok: true,
      async json() {
        throw new SyntaxError('JSON invalide simulé');
      },
    }),
  });
  assert.equal(result.status, 'unavailable');
});
