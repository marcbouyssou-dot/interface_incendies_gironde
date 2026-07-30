import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createNotificationMessage,
  NotificationMessageValidationError,
} from '../src/notifications/notification_message.js';
import {
  NotificationProvider,
  NotificationProviderConfigurationError,
} from '../src/notifications/notification_provider.js';
import {
  NotificationService,
  NotificationServiceError,
} from '../src/notifications/notification_service.js';
import {
  FakeNotificationProvider,
} from '../src/notifications/providers/fake_notification_provider.js';

const validEmail = (overrides = {}) => ({
  channel: 'email',
  recipient: 'responsable@example.fr',
  subject: 'Votre accès MobSanté',
  text: 'Votre accès est prêt.',
  html: '<p>Votre accès est prêt.</p>',
  metadata: {invitationId: 'invitation-a'},
  ...overrides,
});

test('creates an immutable valid email message', () => {
  const message = createNotificationMessage(validEmail());
  assert.equal(message.channel, 'email');
  assert.equal(message.recipient, 'responsable@example.fr');
  assert.equal(Object.isFrozen(message), true);
  assert.equal(Object.isFrozen(message.metadata), true);
});

for (const [name, overrides] of [
  ['empty recipient', {recipient: '  '}],
  ['empty subject', {subject: ''}],
  ['message without text or html', {text: ' ', html: null}],
  ['unknown channel', {channel: 'sms'}],
]) {
  test(`refuses ${name}`, () => {
    assert.throws(
      () => createNotificationMessage(validEmail(overrides)),
      NotificationMessageValidationError,
    );
  });
}

test('accepts a provider injected through the public contract', async () => {
  class TestProvider extends NotificationProvider {
    constructor() {
      super({name: 'test-provider'});
    }

    async send() {
      return {providerMessageId: 'test-id'};
    }
  }

  const result = await new NotificationService({
    provider: new TestProvider(),
  }).send(validEmail());
  assert.deepEqual(result, {
    success: true,
    providerMessageId: 'test-id',
    provider: 'test-provider',
  });
  assert.equal(Object.isFrozen(result), true);
});

test('refuses an invalid or unimplemented provider', async () => {
  assert.throws(
    () => new NotificationService({provider: {name: 'invalid'}}),
    NotificationProviderConfigurationError,
  );
  const service = new NotificationService({
    provider: new NotificationProvider({name: 'abstract'}),
  });
  await assert.rejects(
    service.send(validEmail()),
    (error) =>
      error instanceof NotificationServiceError
      && error.code === 'provider-failure'
      && error.cause instanceof NotificationProviderConfigurationError,
  );
});

test('transmits only a normalized message to the provider', async () => {
  const provider = new FakeNotificationProvider();
  await new NotificationService({provider}).send(
    validEmail({recipient: ' responsable@example.fr '}),
  );
  assert.equal(provider.messages.length, 1);
  assert.equal(provider.messages[0].recipient, 'responsable@example.fr');
  assert.equal(Object.isFrozen(provider.messages[0]), true);
});

test('normalizes the fake provider success result', async () => {
  const service = new NotificationService({
    provider: new FakeNotificationProvider({
      providerMessageId: 'stable-fake-id',
    }),
  });
  assert.deepEqual(await service.send(validEmail()), {
    success: true,
    providerMessageId: 'stable-fake-id',
    provider: 'fake',
  });
});

test('preserves a provider failure as a controlled cause', async () => {
  const technicalCause = new Error('provider unavailable');
  const service = new NotificationService({
    provider: new FakeNotificationProvider({failure: technicalCause}),
  });
  await assert.rejects(
    service.send(validEmail()),
    (error) =>
      error instanceof NotificationServiceError
      && error.code === 'provider-failure'
      && error.message === 'La notification n’a pas pu être envoyée.'
      && error.cause === technicalCause
      && !error.message.includes(technicalCause.message),
  );
});

test('defensively copies nested metadata', () => {
  const metadata = {
    context: {locationIds: ['location-a']},
  };
  const message = createNotificationMessage(validEmail({metadata}));
  metadata.context.locationIds.push('location-b');
  assert.deepEqual(message.metadata, {
    context: {locationIds: ['location-a']},
  });
  assert.equal(Object.isFrozen(message.metadata.context.locationIds), true);
});

test('fake provider records messages without any network dependency', async () => {
  const provider = new FakeNotificationProvider();
  await provider.send(createNotificationMessage(validEmail()));
  assert.equal(provider.messages.length, 1);
  assert.equal(provider.messages[0].subject, 'Votre accès MobSanté');
});

test('fake provider simulates failure after recording the message', async () => {
  const failure = new Error('simulated');
  const provider = new FakeNotificationProvider({failure});
  await assert.rejects(provider.send(createNotificationMessage(validEmail())), {
    message: 'simulated',
  });
  assert.equal(provider.messages.length, 1);
});
