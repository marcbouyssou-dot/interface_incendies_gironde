import assert from 'node:assert/strict';
import test from 'node:test';

import {
  diagnoseFcmChain,
  fcmChainDiagnosticServices,
  FcmChainDiagnosticError,
} from '../src/fcm_chain_diagnostic.js';

const ADMIN_UID = 'platform-admin';
const OWNER_UID = 'professional-a';
const INSTALLATION_ID = 'device-a';
const SUBSCRIPTION_ID = `${OWNER_UID}_${INSTALLATION_ID}`;
const TOKEN = 'private-fcm-token';

function request(overrides = {}) {
  return {
    installationId: INSTALLATION_ID,
    getTokenVsPersistInput: 'IDENTIQUE',
    persistInputVsFirestoreAfterCommit: 'IDENTIQUE',
    ...overrides,
  };
}

function subscription(overrides = {}) {
  return {
    id: SUBSCRIPTION_ID,
    value: {
      uid: OWNER_UID,
      installationId: INSTALLATION_ID,
      platform: 'web',
      active: true,
      token: TOKEN,
      ...overrides,
    },
  };
}

function target(overrides = {}) {
  return {
    subscriptionId: SUBSCRIPTION_ID,
    token: TOKEN,
    ...overrides,
  };
}

function services({active = [subscription()], resolutions = [target(), target()]} = {}) {
  let resolutionIndex = 0;
  return {
    async isPlatformAdministrator() {
      return true;
    },
    async readActive() {
      return structuredClone(active);
    },
    async resolve() {
      const value = resolutions[resolutionIndex];
      resolutionIndex += 1;
      if (value instanceof Error) throw value;
      return structuredClone(value);
    },
  };
}

test('identical chain returns only the five allowlisted states', async () => {
  const result = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request(),
    services: services(),
  });

  assert.deepEqual(result, {
    GETTOKEN_VS_PERSIST_INPUT: 'IDENTIQUE',
    PERSIST_INPUT_VS_FIRESTORE: 'IDENTIQUE',
    FIRESTORE_VS_PREFLIGHT_TARGET: 'IDENTIQUE',
    PREFLIGHT_TARGET_VS_SEND_TARGET: 'IDENTIQUE',
    ACTIVE_SUBSCRIPTIONS_FOR_INSTALLATION: '1',
  });
  assert.deepEqual(Object.keys(result).sort(), [
    'ACTIVE_SUBSCRIPTIONS_FOR_INSTALLATION',
    'FIRESTORE_VS_PREFLIGHT_TARGET',
    'GETTOKEN_VS_PERSIST_INPUT',
    'PERSIST_INPUT_VS_FIRESTORE',
    'PREFLIGHT_TARGET_VS_SEND_TARGET',
  ]);
  const serialized = JSON.stringify(result);
  for (const sensitive of [
    TOKEN,
    ADMIN_UID,
    OWNER_UID,
    INSTALLATION_ID,
    SUBSCRIPTION_ID,
  ]) {
    assert.equal(serialized.includes(sensitive), false);
  }
});

test('different getToken and persist input remains boolean-only', async () => {
  const result = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request({getTokenVsPersistInput: 'DIFFÉRENT'}),
    services: services(),
  });

  assert.equal(result.GETTOKEN_VS_PERSIST_INPUT, 'DIFFÉRENT');
});

test('different value immediately after commit is retained', async () => {
  const result = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request({persistInputVsFirestoreAfterCommit: 'DIFFÉRENT'}),
    services: services(),
  });

  assert.equal(result.PERSIST_INPUT_VS_FIRESTORE, 'DIFFÉRENT');
});

test('client-detected overwrite stays different through resolution', async () => {
  const overwrittenToken = 'private-overwritten-token';
  const result = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request({persistInputVsFirestoreAfterCommit: 'DIFFÉRENT'}),
    services: services({
      active: [subscription({token: overwrittenToken})],
      resolutions: [
        target({token: overwrittenToken}),
        target({token: overwrittenToken}),
      ],
    }),
  });

  assert.equal(result.PERSIST_INPUT_VS_FIRESTORE, 'DIFFÉRENT');
  assert.equal(result.FIRESTORE_VS_PREFLIGHT_TARGET, 'IDENTIQUE');
});

test('active subscription count reports zero one and multiple', async () => {
  for (const [active, expected] of [
    [[], '0'],
    [[subscription()], '1'],
    [[subscription(), subscription({token: 'second'})], '>1'],
  ]) {
    const result = await diagnoseFcmChain({
      callerUid: ADMIN_UID,
      data: request(),
      services: services({active}),
    });
    assert.equal(result.ACTIVE_SUBSCRIPTIONS_FOR_INSTALLATION, expected);
  }
});

test('two successive resolver reads can demonstrate a changed target', async () => {
  const result = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request(),
    services: services({
      resolutions: [target(), target({token: 'changed-before-send'})],
    }),
  });

  assert.equal(result.FIRESTORE_VS_PREFLIGHT_TARGET, 'IDENTIQUE');
  assert.equal(result.PREFLIGHT_TARGET_VS_SEND_TARGET, 'DIFFÉRENT');
});

test('different Firestore and preflight target is demonstrated', async () => {
  const result = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request(),
    services: services({
      resolutions: [target({subscriptionId: 'other'}), target()],
    }),
  });

  assert.equal(result.FIRESTORE_VS_PREFLIGHT_TARGET, 'DIFFÉRENT');
});

test('malformed target or resolver failure stays indeterminate', async () => {
  const malformed = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request(),
    services: services({active: [subscription({token: ''})]}),
  });
  assert.equal(malformed.PERSIST_INPUT_VS_FIRESTORE, 'INDÉTERMINÉ');
  assert.equal(malformed.FIRESTORE_VS_PREFLIGHT_TARGET, 'INDÉTERMINÉ');
  assert.equal(
      malformed.ACTIVE_SUBSCRIPTIONS_FOR_INSTALLATION,
      'INDÉTERMINÉ',
  );

  const failed = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request(),
    services: services({resolutions: [new Error('private-error')]}),
  });
  assert.equal(failed.FIRESTORE_VS_PREFLIGHT_TARGET, 'INDÉTERMINÉ');
  assert.equal(failed.PREFLIGHT_TARGET_VS_SEND_TARGET, 'INDÉTERMINÉ');
  assert.equal(JSON.stringify(failed).includes('private-error'), false);

  const readFailed = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request(),
    services: {
      ...services(),
      async readActive() {
        throw new Error('private-read-error');
      },
    },
  });
  assert.deepEqual(readFailed, {
    GETTOKEN_VS_PERSIST_INPUT: 'IDENTIQUE',
    PERSIST_INPUT_VS_FIRESTORE: 'INDÉTERMINÉ',
    FIRESTORE_VS_PREFLIGHT_TARGET: 'INDÉTERMINÉ',
    PREFLIGHT_TARGET_VS_SEND_TARGET: 'INDÉTERMINÉ',
    ACTIVE_SUBSCRIPTIONS_FOR_INSTALLATION: 'INDÉTERMINÉ',
  });
});

test('diagnostic refuses non-admin before subscription reads', async () => {
  let reads = 0;
  await assert.rejects(
    () => diagnoseFcmChain({
      callerUid: ADMIN_UID,
      data: request(),
      services: {
        async isPlatformAdministrator() {
          return false;
        },
        async readActive() {
          reads += 1;
          return [];
        },
        async resolve() {
          reads += 1;
          return target();
        },
      },
    }),
    (error) => error instanceof FcmChainDiagnosticError &&
      error.code === 'permission-denied',
  );
  assert.equal(reads, 0);
});

test('Firestore implementation performs reads only with no send capability', async () => {
  const firestore = new ReadOnlyFirestore({
    administrator: {active: true},
    subscriptions: [subscription()],
  });
  const diagnosticServices = fcmChainDiagnosticServices({firestore});
  const result = await diagnoseFcmChain({
    callerUid: ADMIN_UID,
    data: request(),
    services: diagnosticServices,
  });

  assert.equal(result.PREFLIGHT_TARGET_VS_SEND_TARGET, 'IDENTIQUE');
  assert.equal('send' in diagnosticServices, false);
  assert.deepEqual(firestore.writes, []);
  assert.equal(
      firestore.operations.filter((value) => value === 'transaction').length,
      2,
  );
  assert.equal(
      firestore.operations.every((value) =>
        value === 'get:platformAdministrators' ||
        value === 'query:pushSubscriptions' ||
        value === 'transaction',
      ),
      true,
  );
});

test('invalid request fails without echoing sensitive input', async () => {
  await assert.rejects(
    () => diagnoseFcmChain({
      callerUid: ADMIN_UID,
      data: {...request(), token: TOKEN},
      services: services(),
    }),
    (error) => error instanceof FcmChainDiagnosticError &&
      error.code === 'invalid-argument' &&
      !error.message.includes(TOKEN),
  );
});

class ReadOnlyFirestore {
  constructor({administrator, subscriptions}) {
    this.administrator = administrator;
    this.subscriptions = subscriptions;
    this.operations = [];
    this.writes = [];
  }

  collection(name) {
    return {
      doc: () => ({
        get: async () => {
          this.operations.push(`get:${name}`);
          return snapshot(
              name === 'platformAdministrators' ? this.administrator : null,
          );
        },
      }),
      where: () => query(name, this),
    };
  }

  runTransaction(callback) {
    this.operations.push('transaction');
    return callback({
      get: async (reference) => reference.get(),
      set: (...args) => this.writes.push(['set', ...args]),
      update: (...args) => this.writes.push(['update', ...args]),
      create: (...args) => this.writes.push(['create', ...args]),
      delete: (...args) => this.writes.push(['delete', ...args]),
    });
  }
}

function query(name, firestore) {
  return {
    async get() {
      firestore.operations.push(`query:${name}`);
      return {
        docs: firestore.subscriptions.map(({id, value}) => ({
          id,
          ref: {id},
          data: () => structuredClone(value),
        })),
      };
    },
  };
}

function snapshot(value) {
  return {
    exists: value != null,
    data: () => value == null ? undefined : structuredClone(value),
  };
}
