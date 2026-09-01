import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import test from 'node:test';

import {
  compareFcmChain,
  diagnoseFcmChain,
  fcmChainDiagnosticServices,
  FcmChainDiagnosticError,
} from '../src/fcm_chain_diagnostic.js';

const ADMIN_UID = 'platform-admin';
const OWNER_UID = 'professional-a';
const INSTALLATION_ID = 'device-a';
const SUBSCRIPTION_ID = `${OWNER_UID}_${INSTALLATION_ID}`;
const TOKEN = 'private-fcm-token';
const TOKEN_SHA256 = fingerprint(TOKEN);

function request(overrides = {}) {
  return {
    installationId: INSTALLATION_ID,
    postTokenSha256: TOKEN_SHA256,
    ...overrides,
  };
}

function state(overrides = {}) {
  return {
    subscriptions: [{
      id: SUBSCRIPTION_ID,
      value: {
        uid: OWNER_UID,
        installationId: INSTALLATION_ID,
        platform: 'web',
        token: TOKEN,
      },
    }],
    dispatch: {
      subscriptionId: SUBSCRIPTION_ID,
      tokenFingerprint: TOKEN_SHA256,
    },
    ...overrides,
  };
}

test('identical chain returns only the three allowlisted comparisons', () => {
  const result = compareFcmChain({
    installationId: INSTALLATION_ID,
    postTokenSha256: TOKEN_SHA256,
    ...state(),
  });

  assert.deepEqual(result, {
    POST_TOKEN_VS_FIRESTORE: 'IDENTIQUE',
    FIRESTORE_SHA256_VS_DISPATCH_SHA256: 'IDENTIQUE',
    INSTALLATION_VS_TARGET_RESOLVED: 'IDENTIQUE',
  });
  const serialized = JSON.stringify(result);
  assert.equal(serialized.includes(TOKEN), false);
  assert.equal(serialized.includes(TOKEN_SHA256), false);
  assert.equal(serialized.includes(ADMIN_UID), false);
  assert.equal(serialized.includes(INSTALLATION_ID), false);
});

test('different local fingerprint is reported without exposing it', () => {
  const result = compareFcmChain({
    installationId: INSTALLATION_ID,
    postTokenSha256: fingerprint('different-private-token'),
    ...state(),
  });

  assert.equal(result.POST_TOKEN_VS_FIRESTORE, 'DIFFÉRENT');
  assert.equal(result.FIRESTORE_SHA256_VS_DISPATCH_SHA256, 'IDENTIQUE');
});

test('absent multiple or malformed records remain indeterminate', () => {
  for (const subscriptions of [
    [],
    [state().subscriptions[0], state().subscriptions[0]],
    [{id: SUBSCRIPTION_ID, value: {platform: 'web'}}],
    [{id: SUBSCRIPTION_ID, value: {
      platform: 'web',
      uid: OWNER_UID,
      installationId: INSTALLATION_ID,
      token: '',
    }}],
  ]) {
    assert.deepEqual(compareFcmChain({
      installationId: INSTALLATION_ID,
      postTokenSha256: TOKEN_SHA256,
      subscriptions,
      dispatch: state().dispatch,
    }), {
      POST_TOKEN_VS_FIRESTORE: 'INDÉTERMINÉ',
      FIRESTORE_SHA256_VS_DISPATCH_SHA256: 'INDÉTERMINÉ',
      INSTALLATION_VS_TARGET_RESOLVED: 'INDÉTERMINÉ',
    });
  }
});

test('different dispatch fingerprint is reported', () => {
  const result = compareFcmChain({
    installationId: INSTALLATION_ID,
    postTokenSha256: TOKEN_SHA256,
    ...state({
      dispatch: {
        subscriptionId: SUBSCRIPTION_ID,
        tokenFingerprint: fingerprint('different-dispatch-token'),
      },
    }),
  });

  assert.equal(result.FIRESTORE_SHA256_VS_DISPATCH_SHA256, 'DIFFÉRENT');
});

test('absent dispatch keeps dispatch comparisons indeterminate', () => {
  const result = compareFcmChain({
    installationId: INSTALLATION_ID,
    postTokenSha256: TOKEN_SHA256,
    ...state({dispatch: null}),
  });

  assert.equal(result.POST_TOKEN_VS_FIRESTORE, 'IDENTIQUE');
  assert.equal(
    result.FIRESTORE_SHA256_VS_DISPATCH_SHA256,
    'INDÉTERMINÉ',
  );
  assert.equal(result.INSTALLATION_VS_TARGET_RESOLVED, 'INDÉTERMINÉ');
});

test('different dispatch target is reported', () => {
  const result = compareFcmChain({
    installationId: INSTALLATION_ID,
    postTokenSha256: TOKEN_SHA256,
    ...state({
      dispatch: {
        subscriptionId: `another-owner_${INSTALLATION_ID}`,
        tokenFingerprint: TOKEN_SHA256,
      },
    }),
  });

  assert.equal(result.INSTALLATION_VS_TARGET_RESOLVED, 'DIFFÉRENT');
});

test('diagnostic refuses non-admin and never reads the target', async () => {
  let reads = 0;
  await assert.rejects(
    () => diagnoseFcmChain({
      callerUid: ADMIN_UID,
      data: request(),
      services: {
        async isPlatformAdministrator() {
          return false;
        },
        async read() {
          reads += 1;
          return state();
        },
      },
    }),
    (error) => error instanceof FcmChainDiagnosticError &&
      error.code === 'permission-denied',
  );
  assert.equal(reads, 0);
});

test('Firestore service performs reads only and has no Messaging dependency', async () => {
  const firestore = new ReadOnlyFirestore({
    administrator: {active: true},
    subscriptions: state().subscriptions,
    dispatch: state().dispatch,
  });
  const services = fcmChainDiagnosticServices({firestore});
  const result = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request(),
    services,
  });

  assert.equal(result.POST_TOKEN_VS_FIRESTORE, 'IDENTIQUE');
  assert.deepEqual(firestore.operations, [
    'get:platformAdministrators',
    'query:pushSubscriptions',
    'get:pushTestDispatches',
  ]);
  assert.equal('send' in services, false);
});

test('invalid request shape fails without echoing sensitive input', async () => {
  await assert.rejects(
    () => diagnoseFcmChain({
      callerUid: ADMIN_UID,
      data: {...request(), token: TOKEN},
      services: {
        async isPlatformAdministrator() {
          return true;
        },
        async read() {
          return state();
        },
      },
    }),
    (error) => error instanceof FcmChainDiagnosticError &&
      error.code === 'invalid-argument' &&
      !error.message.includes(TOKEN),
  );
});

class ReadOnlyFirestore {
  constructor({administrator, subscriptions, dispatch}) {
    this.administrator = administrator;
    this.subscriptions = subscriptions;
    this.dispatch = dispatch;
    this.operations = [];
  }

  collection(name) {
    return {
      doc: () => ({
        get: async () => {
          this.operations.push(`get:${name}`);
          const value = name === 'platformAdministrators'
            ? this.administrator
            : this.dispatch;
          return snapshot(value);
        },
      }),
      where: () => ({
        get: async () => {
          this.operations.push(`query:${name}`);
          return {
            docs: this.subscriptions.map(({id, value}) => ({
              id,
              data: () => structuredClone(value),
            })),
          };
        },
      }),
    };
  }
}

function snapshot(value) {
  return {
    exists: value != null,
    data: () => value == null ? undefined : structuredClone(value),
  };
}

function fingerprint(value) {
  return createHash('sha256').update(value).digest('hex');
}
