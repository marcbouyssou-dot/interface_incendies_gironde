import assert from 'node:assert/strict';
import test from 'node:test';

import {
  sendTargetedPushTest,
  targetedPushTestServices,
  TargetedPushTestError,
} from '../src/targeted_push_test.js';

const ADMIN_UID = 'platform-admin';
const OWNER_UID = 'professional-a';
const INSTALLATION_ID = 'device-a';
const SUBSCRIPTION_ID = `${OWNER_UID}_${INSTALLATION_ID}`;
const TOKEN = 'private-fcm-token';
const NOW = new Date('2026-08-26T08:00:00.000Z');

function request(overrides = {}) {
  return {
    confirmation: 'SEND_ONE_TEST_PUSH',
    subscriptionId: SUBSCRIPTION_ID,
    ...overrides,
  };
}

function harness({administrator = true, subscription = {}} = {}) {
  const firestore = new MemoryFirestore();
  if (administrator !== null) {
    firestore.seed(`platformAdministrators/${ADMIN_UID}`, {
      active: administrator,
    });
  }
  if (subscription !== null) {
    firestore.seed(`pushSubscriptions/${SUBSCRIPTION_ID}`, {
      uid: OWNER_UID,
      installationId: INSTALLATION_ID,
      token: TOKEN,
      platform: 'web',
      active: true,
      ...subscription,
    });
  }
  const messages = [];
  const services = targetedPushTestServices({
    firestore,
    messaging: {
      async send(message) {
        messages.push(message);
        return 'projects/demo/messages/test-message';
      },
    },
    serverTimestamp: () => NOW,
  });
  return {firestore, messages, services};
}

async function assertCode(action, code) {
  await assert.rejects(
    action,
    (error) => error instanceof TargetedPushTestError && error.code === code,
  );
}

test('unauthenticated caller is refused before every service call', async () => {
  let called = false;
  await assertCode(
    () => sendTargetedPushTest({
      callerUid: null,
      data: request(),
      services: {
        async claim() {
          called = true;
        },
      },
    }),
    'unauthenticated',
  );
  assert.equal(called, false);
});

test('non platform administrator is refused without sending', async () => {
  const {messages, services} = harness({administrator: false});
  await assertCode(
    () => sendTargetedPushTest({
      callerUid: ADMIN_UID,
      data: request(),
      services,
    }),
    'permission-denied',
  );
  assert.equal(messages.length, 0);
});

test('authorized administrator sends fixed payload to one installation', async () => {
  const {firestore, messages, services} = harness();
  const result = await sendTargetedPushTest({
    callerUid: ADMIN_UID,
    data: request(),
    services,
  });

  assert.deepEqual(result, {sent: true, subscriptionId: SUBSCRIPTION_ID});
  assert.equal(messages.length, 1);
  assert.deepEqual(messages[0], {
    token: TOKEN,
    data: {
      title: 'MobSanté — Test notification',
      body: 'Votre appareil peut recevoir les notifications MobSanté.',
      notificationId: 'push-test',
      url: '/',
    },
  });
  assert.equal(JSON.stringify(result).includes(TOKEN), false);
  assert.deepEqual(firestore.writtenCollections(), ['pushTestDispatches']);
  assert.equal(
    firestore.data(`pushTestDispatches/${SUBSCRIPTION_ID}`).status,
    'delivered',
  );
});

test('absent subscription returns a controlled error', async () => {
  const {messages, services} = harness({subscription: null});
  await assertCode(
    () => sendTargetedPushTest({
      callerUid: ADMIN_UID,
      data: request(),
      services,
    }),
    'not-found',
  );
  assert.equal(messages.length, 0);
});

test('inactive subscription returns a controlled error', async () => {
  const {messages, services} = harness({subscription: {active: false}});
  await assertCode(
    () => sendTargetedPushTest({
      callerUid: ADMIN_UID,
      data: request(),
      services,
    }),
    'failed-precondition',
  );
  assert.equal(messages.length, 0);
});

test('explicit confirmation and exact scalar document id are required', async () => {
  const {services} = harness();
  for (const data of [
    request({confirmation: 'yes'}),
    request({subscriptionId: ['one', 'two']}),
    request({subscriptionId: 'collection/document'}),
    {...request(), title: 'arbitrary'},
  ]) {
    await assertCode(
      () => sendTargetedPushTest({callerUid: ADMIN_UID, data, services}),
      'invalid-argument',
    );
  }
});

test('one-shot claim prevents repeated sends to the same installation', async () => {
  const {messages, services} = harness();
  await sendTargetedPushTest({
    callerUid: ADMIN_UID,
    data: request(),
    services,
  });
  await assertCode(
    () => sendTargetedPushTest({
      callerUid: ADMIN_UID,
      data: request(),
      services,
    }),
    'resource-exhausted',
  );
  assert.equal(messages.length, 1);
});

class MemoryFirestore {
  constructor() {
    this.documents = new Map();
    this.writes = [];
  }

  seed(path, value) {
    this.documents.set(path, structuredClone(value));
  }

  data(path) {
    const value = this.documents.get(path);
    return value === undefined ? undefined : structuredClone(value);
  }

  writtenCollections() {
    return [...new Set(this.writes.map((path) => path.split('/')[0]))];
  }

  collection(name) {
    return {
      doc: (id) => new MemoryReference(this, `${name}/${id}`),
    };
  }

  async runTransaction(action) {
    return action({
      get: async (reference) => reference.get(),
      create: (reference, value) => reference.create(value),
    });
  }
}

class MemoryReference {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
  }

  async get() {
    const value = this.firestore.documents.get(this.path);
    return {
      exists: value !== undefined,
      data: () => value === undefined ? undefined : structuredClone(value),
    };
  }

  create(value) {
    if (this.firestore.documents.has(this.path)) {
      throw new Error(`Document already exists: ${this.path}`);
    }
    this.firestore.documents.set(this.path, structuredClone(value));
    this.firestore.writes.push(this.path);
  }

  async update(value) {
    const current = this.firestore.documents.get(this.path);
    if (current === undefined) throw new Error(`Missing document: ${this.path}`);
    this.firestore.documents.set(this.path, {
      ...current,
      ...structuredClone(value),
    });
    this.firestore.writes.push(this.path);
  }
}
