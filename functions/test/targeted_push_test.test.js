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

function harness({administrator = true, subscription = {}, send} = {}) {
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
        if (send) {
          return send({message, messages, firestore});
        }
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

test('authorized administrator sends fixed payload then records success', async () => {
  const {firestore, messages, services} = harness({
    send: async ({firestore}) => {
      assert.equal(
        firestore.data(`pushTestDispatches/${SUBSCRIPTION_ID}`).status,
        'pending',
      );
      return 'projects/demo/messages/test-message';
    },
  });
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
    'success',
  );
});

test('invalid FCM token marks both dispatch failed and subscription stale', async () => {
  const {firestore, services} = harness({
    send: async () => {
      throw messagingError('messaging/registration-token-not-registered');
    },
  });

  await assert.rejects(() => sendTargetedPushTest({
    callerUid: ADMIN_UID,
    data: request(),
    services,
  }));

  const dispatch = firestore.data(`pushTestDispatches/${SUBSCRIPTION_ID}`);
  const subscription = firestore.data(`pushSubscriptions/${SUBSCRIPTION_ID}`);
  assert.equal(dispatch.status, 'failed');
  assert.equal(
    dispatch.errorCode,
    'messaging/registration-token-not-registered',
  );
  assert.equal(subscription.active, false);
  assert.equal(
    subscription.disabledReason,
    'messaging/registration-token-not-registered',
  );
});

test('same token cannot retry after a failed send', async () => {
  let sendCalls = 0;
  const {firestore, services} = harness({
    send: async () => {
      sendCalls += 1;
      throw messagingError('messaging/registration-token-not-registered');
    },
  });
  await assert.rejects(() => sendTargetedPushTest({
    callerUid: ADMIN_UID,
    data: request(),
    services,
  }));
  firestore.seed(`pushSubscriptions/${SUBSCRIPTION_ID}`, {
    uid: OWNER_UID,
    installationId: INSTALLATION_ID,
    token: TOKEN,
    platform: 'web',
    active: true,
  });

  await assertCode(
    () => sendTargetedPushTest({
      callerUid: ADMIN_UID,
      data: request(),
      services,
    }),
    'resource-exhausted',
  );
  assert.equal(sendCalls, 1);
});

test('a genuinely renewed token can retry a failed send once', async () => {
  let sendCalls = 0;
  const {firestore, messages, services} = harness({
    send: async () => {
      sendCalls += 1;
      if (sendCalls === 1) {
        throw messagingError('messaging/registration-token-not-registered');
      }
      return 'projects/demo/messages/renewed-token';
    },
  });
  await assert.rejects(() => sendTargetedPushTest({
    callerUid: ADMIN_UID,
    data: request(),
    services,
  }));
  firestore.seed(`pushSubscriptions/${SUBSCRIPTION_ID}`, {
    uid: OWNER_UID,
    installationId: INSTALLATION_ID,
    token: 'renewed-private-fcm-token',
    platform: 'web',
    active: true,
  });

  const result = await sendTargetedPushTest({
    callerUid: ADMIN_UID,
    data: request(),
    services,
  });

  assert.deepEqual(result, {sent: true, subscriptionId: SUBSCRIPTION_ID});
  assert.equal(messages.length, 2);
  assert.equal(messages[1].token, 'renewed-private-fcm-token');
  assert.equal(
    firestore.data(`pushTestDispatches/${SUBSCRIPTION_ID}`).status,
    'success',
  );
});

test('other FCM errors do not mark the subscription stale', async () => {
  const {firestore, services} = harness({
    send: async () => {
      throw messagingError('messaging/internal-error');
    },
  });

  await assert.rejects(() => sendTargetedPushTest({
    callerUid: ADMIN_UID,
    data: request(),
    services,
  }));

  const subscription = firestore.data(`pushSubscriptions/${SUBSCRIPTION_ID}`);
  assert.equal(subscription.active, true);
  assert.equal(subscription.disabledReason, undefined);
  assert.equal(
    firestore.data(`pushTestDispatches/${SUBSCRIPTION_ID}`).status,
    'failed',
  );
});

test('legacy invalid-token failure is reconciled without sending again', async () => {
  const {firestore, messages, services} = harness();
  firestore.seed(`pushTestDispatches/${SUBSCRIPTION_ID}`, {
    dispatchId: SUBSCRIPTION_ID,
    subscriptionId: SUBSCRIPTION_ID,
    requestedBy: ADMIN_UID,
    status: 'failed',
    errorCode: 'messaging/registration-token-not-registered',
  });

  await assertCode(
    () => sendTargetedPushTest({
      callerUid: ADMIN_UID,
      data: request(),
      services,
    }),
    'failed-precondition',
  );

  assert.equal(messages.length, 0);
  assert.equal(
    firestore.data(`pushSubscriptions/${SUBSCRIPTION_ID}`).active,
    false,
  );
  assert.match(
    firestore.data(`pushTestDispatches/${SUBSCRIPTION_ID}`).tokenFingerprint,
    /^[a-f0-9]{64}$/,
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
      update: (reference, value) => reference.update(value),
    });
  }
}

function messagingError(code) {
  const error = new Error(code);
  error.code = code;
  return error;
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
