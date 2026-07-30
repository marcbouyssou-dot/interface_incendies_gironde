import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createNotificationService,
  createServerNotificationService,
  NotificationServiceConfigurationError,
} from '../src/notifications/create_notification_service.js';
import {
  FakeNotificationProvider,
} from '../src/notifications/providers/fake_notification_provider.js';

const message = {
  channel: 'email',
  recipient: 'responsable@example.test',
  subject: 'Invitation MobSanté',
  text: 'Message de test.',
};

test('composition accepts an injected provider', async () => {
  const service = createNotificationService({
    provider: new FakeNotificationProvider({
      providerMessageId: 'injected-id',
    }),
  });
  assert.deepEqual(await service.send(message), {
    success: true,
    providerMessageId: 'injected-id',
    provider: 'fake',
  });
});

test('Emulator composition uses the fake provider without network', async () => {
  const service = createServerNotificationService({mode: 'emulator'});
  assert.deepEqual(await service.send(message), {
    success: true,
    providerMessageId: 'emulator-message-id',
    provider: 'fake',
  });
});

const validConfiguration = (overrides = {}) => ({
  apiKey: 're_test_configuration_only',
  fromEmail: 'notifications@example.test',
  fromName: 'MobSanté',
  replyTo: 'coordination@example.test',
  appUrl: 'https://mobsante.netlify.app',
  ...overrides,
});

test('real composition injects validated configuration without exposing it', () => {
  let received;
  const provider = new FakeNotificationProvider();
  const service = createServerNotificationService({
    mode: 'real',
    configuration: validConfiguration(),
    providerFactory: (options) => {
      received = options;
      return provider;
    },
  });
  assert.equal(service.provider, provider);
  assert.deepEqual(received, {
    apiKey: 're_test_configuration_only',
    fromEmail: 'notifications@example.test',
    fromName: 'MobSanté',
    replyTo: 'coordination@example.test',
  });
});

test('real composition supports sender email without optional values', () => {
  let received;
  createServerNotificationService({
    mode: 'real',
    configuration: validConfiguration({
      fromName: '',
      replyTo: '',
    }),
    providerFactory: (options) => {
      received = options;
      return new FakeNotificationProvider();
    },
  });
  assert.equal(received.fromName, undefined);
  assert.equal(received.replyTo, undefined);
});

for (const [label, overrides] of [
  ['missing secret', {apiKey: undefined}],
  ['empty secret', {apiKey: '  '}],
  ['missing sender', {fromEmail: undefined}],
  ['invalid sender', {fromEmail: 'invalid'}],
  ['invalid reply-to', {replyTo: 'invalid'}],
  ['invalid sender name', {fromName: 42}],
  ['missing app URL', {appUrl: undefined}],
  ['invalid app URL', {appUrl: 'http://mobsante.netlify.app'}],
  ['URL with credentials', {appUrl: 'https://user:pass@mobsante.netlify.app'}],
]) {
  test(`real composition refuses ${label} safely`, () => {
    assert.throws(
      () => createServerNotificationService({
        mode: 'real',
        configuration: validConfiguration(overrides),
        providerFactory: () => new FakeNotificationProvider(),
      }),
      (error) =>
        error instanceof NotificationServiceConfigurationError
        && error.code === 'invalid-notification-configuration'
        && !error.message.includes('re_test_configuration_only'),
    );
  });
}

test('injected Emulator mode never constructs a real provider', async () => {
  let factoryCalls = 0;
  const service = createServerNotificationService({
    mode: 'emulator',
    providerFactory: () => {
      factoryCalls += 1;
      return new FakeNotificationProvider();
    },
  });
  await service.send(message);
  assert.equal(factoryCalls, 0);
});

test('canonical production URL is accepted and the former URL is absent', () => {
  createServerNotificationService({
    mode: 'real',
    configuration: validConfiguration({
      appUrl: 'https://mobsante.netlify.app',
    }),
    providerFactory: () => new FakeNotificationProvider(),
  });
  assert.equal(
    JSON.stringify(validConfiguration())
      .includes('https://interfacerecup33.netlify.app'),
    false,
  );
});

test('unknown server mode is rejected without provider construction', () => {
  assert.throws(
    () => createServerNotificationService({mode: 'unknown'}),
    NotificationServiceConfigurationError,
  );
});
