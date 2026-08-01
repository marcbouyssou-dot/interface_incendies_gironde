import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createNotificationMessage,
} from '../src/notifications/notification_message.js';
import {
  NotificationService,
  NotificationServiceError,
} from '../src/notifications/notification_service.js';
import {
  ResendNotificationProvider,
  ResendNotificationProviderError,
} from '../src/notifications/providers/resend_notification_provider.js';

const validMessage = (overrides = {}) => createNotificationMessage({
  channel: 'email',
  recipient: 'responsable@example.fr',
  subject: 'Votre accès MobSanté',
  text: 'Votre accès est prêt.',
  html: '<p>Votre accès est prêt.</p>',
  metadata: {invitationId: 'invitation-a'},
  ...overrides,
});

function fakeClient({
  response = {data: {id: 'resend-message-id'}, error: null},
  failure,
} = {}) {
  const calls = [];
  const options = [];
  return {
    calls,
    options,
    emails: {
      async send(payload, requestOptions) {
        calls.push(payload);
        options.push(requestOptions);
        if (failure) throw failure;
        return response;
      },
    },
  };
}

function provider(overrides = {}) {
  return new ResendNotificationProvider({
    client: fakeClient(),
    fromEmail: 'notifications@mobsante.fr',
    ...overrides,
  });
}

test('constructs a Resend provider with an injected client', () => {
  assert.equal(provider().name, 'resend');
});

for (const client of [null, {}, {emails: null}, {emails: {}}, {emails: {send: 1}}]) {
  test(`refuses invalid injected client ${JSON.stringify(client)}`, () => {
    assert.throws(
      () => provider({client}),
      (error) =>
        error instanceof ResendNotificationProviderError
        && error.code === 'invalid-configuration',
    );
  });
}

for (const fromEmail of ['', 'invalid', 'name@', 42]) {
  test(`refuses invalid sender ${JSON.stringify(fromEmail)}`, () => {
    assert.throws(
      () => provider({fromEmail}),
      ResendNotificationProviderError,
    );
  });
}

test('accepts an injected API key without reading the environment', () => {
  const resendProvider = new ResendNotificationProvider({
    apiKey: 're_injected_for_construction_only',
    fromEmail: 'notifications@mobsante.fr',
  });
  assert.equal(resendProvider.name, 'resend');
});

test('refuses ambiguous client and API key injection', () => {
  assert.throws(
    () => provider({apiKey: 're_not_used'}),
    ResendNotificationProviderError,
  );
});

test('maps sender, recipient, subject and text without internal metadata', async () => {
  const client = fakeClient();
  const resendProvider = provider({client});
  await resendProvider.send(validMessage({html: null}));
  assert.deepEqual(client.calls, [{
    from: 'notifications@mobsante.fr',
    to: 'responsable@example.fr',
    subject: 'Votre accès MobSanté',
    text: 'Votre accès est prêt.',
  }]);
});

test('formats an optional sender name', async () => {
  const client = fakeClient();
  await provider({client, fromName: 'MobSanté'}).send(validMessage());
  assert.equal(
    client.calls[0].from,
    'MobSanté <notifications@mobsante.fr>',
  );
});

test('maps html and optional reply-to', async () => {
  const client = fakeClient();
  await provider({
    client,
    replyTo: 'coordination@mobsante.fr',
  }).send(validMessage({text: null}));
  assert.deepEqual(client.calls[0], {
    from: 'notifications@mobsante.fr',
    to: 'responsable@example.fr',
    subject: 'Votre accès MobSanté',
    html: '<p>Votre accès est prêt.</p>',
    replyTo: 'coordination@mobsante.fr',
  });
});

test('omits optional sender name and reply-to when absent', async () => {
  const client = fakeClient();
  await provider({client}).send(validMessage());
  assert.equal('replyTo' in client.calls[0], false);
  assert.equal(client.calls[0].from, 'notifications@mobsante.fr');
});

for (const fromName of [42, 'bad\nname', 'bad <name>']) {
  test(`refuses malformed sender name ${JSON.stringify(fromName)}`, () => {
    assert.throws(
      () => provider({fromName}),
      ResendNotificationProviderError,
    );
  });
}

for (const replyTo of [42, 'invalid']) {
  test(`refuses malformed reply-to ${JSON.stringify(replyTo)}`, () => {
    assert.throws(
      () => provider({replyTo}),
      ResendNotificationProviderError,
    );
  });
}

test('refuses a non-email channel without invoking the client', async () => {
  const client = fakeClient();
  await assert.rejects(
    provider({client}).send({channel: 'sms'}),
    (error) =>
      error instanceof ResendNotificationProviderError
      && error.code === 'unsupported-channel',
  );
  assert.equal(client.calls.length, 0);
});

test('returns only the normalized Resend message identifier', async () => {
  const result = await provider().send(validMessage());
  assert.deepEqual(result, {providerMessageId: 'resend-message-id'});
  assert.equal(Object.isFrozen(result), true);
});

test('integrates with NotificationService normalized result', async () => {
  const service = new NotificationService({provider: provider()});
  assert.deepEqual(await service.send(validMessage()), {
    success: true,
    providerMessageId: 'resend-message-id',
    provider: 'resend',
  });
});

test('forwards the exact provider idempotency key through the Resend SDK', async () => {
  const client = fakeClient();
  const service = new NotificationService({provider: provider({client})});
  const key = 'admin-invitation:stable-digest:activation';
  await service.send(validMessage(), {idempotencyKey: key});
  assert.deepEqual(client.options, [{idempotencyKey: key}]);
  assert.equal('idempotencyKey' in client.calls[0], false);
});

test('refuses a successful provider response without an identifier', async () => {
  await assert.rejects(
    provider({client: fakeClient({response: {data: {}, error: null}})})
      .send(validMessage()),
    (error) =>
      error instanceof ResendNotificationProviderError
      && error.code === 'invalid-response',
  );
});

test('encapsulates a Resend API error without exposing its raw response', async () => {
  const rawError = {
    name: 'rate_limit_exceeded',
    message: 'sensitive provider details',
    apiKey: 'secret',
  };
  await assert.rejects(
    provider({
      client: fakeClient({response: {data: null, error: rawError}}),
    }).send(validMessage()),
    (error) =>
      error instanceof ResendNotificationProviderError
      && error.code === 'send-failed'
      && error.cause !== rawError
      && error.cause.code === 'rate_limit_exceeded'
      && !error.message.includes(rawError.message)
      && !JSON.stringify(error.cause).includes(rawError.apiKey),
  );
});

test('preserves a thrown technical cause behind a safe provider error', async () => {
  const technicalCause = new Error('network unavailable');
  const resendProvider = provider({
    client: fakeClient({failure: technicalCause}),
  });
  await assert.rejects(
    resendProvider.send(validMessage()),
    (error) =>
      error instanceof ResendNotificationProviderError
      && error.code === 'send-failed'
      && error.cause === technicalCause
      && !error.message.includes(technicalCause.message),
  );
});

test('NotificationService preserves the controlled Resend failure', async () => {
  const technicalCause = new Error('network unavailable');
  const service = new NotificationService({
    provider: provider({client: fakeClient({failure: technicalCause})}),
  });
  await assert.rejects(
    service.send(validMessage()),
    (error) =>
      error instanceof NotificationServiceError
      && error.code === 'provider-failure'
      && error.cause instanceof ResendNotificationProviderError
      && error.cause.cause === technicalCause,
  );
});

test('tests use only an injected fake client and perform no network call', async () => {
  const client = fakeClient();
  await provider({client}).send(validMessage());
  assert.equal(client.calls.length, 1);
});
