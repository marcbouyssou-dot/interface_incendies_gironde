import assert from 'node:assert/strict';
import {test} from 'node:test';

import {
  ReferenceGeocodingError,
  searchIgnAddress,
  searchProfessionalReferenceAddresses,
} from '../src/reference_geocoding.js';

function db({volunteer = true} = {}) {
  return {collection: (name) => {
    assert.equal(name, 'volunteers');
    return {doc: () => ({get: async () => ({
    exists: volunteer,
    data: () => ({uid: 'private-uid'}),
  })})};
  }};
}

const feature = {
  geometry: {type: 'Point', coordinates: [2.33115, 48.868989]},
  properties: {
    id: '75102_6998_00010', label: '10 Rue de la Paix 75002 Paris',
    score: 0.96, type: 'housenumber',
  },
};

test('provider request contains only a geographic query and returns canonical candidates', async () => {
  let requested;
  const results = await searchIgnAddress('10 rue de la Paix Paris', {
    fetchImpl: async (url, options) => {
      requested = {url: url.toString(), options};
      return {ok: true, json: async () => ({
        type: 'FeatureCollection', features: [feature],
      })};
    },
  });
  const url = new URL(requested.url);
  assert.equal(url.origin, 'https://data.geopf.fr');
  assert.deepEqual([...url.searchParams.keys()], ['q', 'limit', 'autocomplete']);
  assert.equal(url.searchParams.get('q'), '10 rue de la Paix Paris');
  for (const value of ['uid', 'firstName', 'lastName', 'email', 'phone',
    'rpps', 'profession', 'operationId', 'missionId', 'organizationId',
    'cpts', 'token']) {
    assert.equal(requested.url.includes(value), false);
  }
  assert.deepEqual(Object.keys(requested.options.headers), ['accept']);
  assert.equal(requested.options.method, 'GET');
  assert.deepEqual(results, [{
    displayLabel: '10 Rue de la Paix 75002 Paris',
    latitude: 48.868989, longitude: 2.33115,
    provider: 'ign_geoplateforme',
    providerReference: '75102_6998_00010',
    precision: 'housenumber', confidence: 0.96,
  }]);
});

test('empty, malformed and unavailable provider responses fail safely', async () => {
  assert.deepEqual(await searchIgnAddress('adresse exemple', {
    fetchImpl: async () => ({ok: true, json: async () => ({
      type: 'FeatureCollection', features: [],
    })}),
  }), []);
  assert.deepEqual(await searchIgnAddress('adresse exemple', {
    fetchImpl: async () => ({ok: true, json: async () => ({
      type: 'FeatureCollection', features: [{
        ...feature, geometry: {type: 'Point', coordinates: [999, 999]},
      }],
    })}),
  }), []);
  await assert.rejects(() => searchIgnAddress('adresse exemple', {
    fetchImpl: async () => { throw new Error('offline'); },
  }), (error) => error instanceof ReferenceGeocodingError
    && error.code === 'unavailable');
  await assert.rejects(() => searchIgnAddress('adresse exemple', {
    fetchImpl: async () => { throw {name: 'TimeoutError'}; },
  }), (error) => error.code === 'deadline-exceeded');
});

test('only an authenticated professional can search without passing identity to IGN', async () => {
  let providerCalls = 0;
  const searchProvider = async (query) => {
    providerCalls += 1;
    assert.equal(query, '10 rue de la Paix Paris');
    return [];
  };
  const input = {
    callerUid: 'private-uid', data: {query: '10 rue de la Paix Paris'},
    searchProvider,
  };
  assert.deepEqual(await searchProfessionalReferenceAddresses({
    ...input, db: db(),
  }), {results: []});
  for (const rejected of [
    {...input, db: db({volunteer: false})},
    {...input, db: db(), isAnonymous: true},
    {...input, db: db(), data: {query: 'alice@example.fr'}},
    {...input, db: db(), data: {query: '10123456789'}},
    {...input, db: db(), data: {query: 'Paris', uid: 'forged'}},
    {...input, db: db(), data: {query: 'Paris', profession: 'nurse'}},
    {...input, db: db(), data: {query: 'Paris', token: 'forged'}},
  ]) {
    await assert.rejects(() => searchProfessionalReferenceAddresses(rejected));
  }
  assert.equal(providerCalls, 1);
});
