import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createNotificationService,
  createServerNotificationService,
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
  const service = createServerNotificationService({isEmulator: true});
  assert.deepEqual(await service.send(message), {
    success: true,
    providerMessageId: 'emulator-message-id',
    provider: 'fake',
  });
});

test('server composition without configuration fails only when sending', async () => {
  const service = createServerNotificationService();
  await assert.rejects(
    service.send(message),
    (error) =>
      error.code === 'provider-failure'
      && error.cause?.code === 'notification-provider-unconfigured',
  );
});
