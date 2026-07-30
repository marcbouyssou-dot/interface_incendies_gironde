import {NotificationProvider} from './notification_provider.js';
import {NotificationService} from './notification_service.js';
import {
  FakeNotificationProvider,
} from './providers/fake_notification_provider.js';

class UnconfiguredNotificationProvider extends NotificationProvider {
  constructor() {
    super({name: 'unconfigured'});
  }

  async send() {
    const error = new Error('Notification provider is not configured.');
    error.code = 'notification-provider-unconfigured';
    throw error;
  }
}

export function createNotificationService({provider}) {
  return new NotificationService({provider});
}

export function createServerNotificationService({
  isEmulator = false,
  emulatorFailure,
} = {}) {
  const provider = isEmulator
    ? new FakeNotificationProvider({
        providerMessageId: 'emulator-message-id',
        failure: emulatorFailure,
      })
    : new UnconfiguredNotificationProvider();
  return createNotificationService({provider});
}
