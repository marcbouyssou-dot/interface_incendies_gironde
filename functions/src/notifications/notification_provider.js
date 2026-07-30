export class NotificationProviderConfigurationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'NotificationProviderConfigurationError';
    this.code = 'invalid-notification-provider';
  }
}

export class NotificationProvider {
  constructor({name}) {
    if (typeof name !== 'string' || name.trim() === '') {
      throw new NotificationProviderConfigurationError(
        'Le fournisseur de notifications doit avoir un nom.',
      );
    }
    this.name = name.trim();
  }

  async send() {
    throw new NotificationProviderConfigurationError(
      'Le fournisseur de notifications ne définit pas send(message).',
    );
  }
}

export function assertNotificationProvider(provider) {
  if (
    provider === null
    || typeof provider !== 'object'
    || typeof provider.name !== 'string'
    || provider.name.trim() === ''
    || typeof provider.send !== 'function'
  ) {
    throw new NotificationProviderConfigurationError(
      'Fournisseur de notifications invalide.',
    );
  }
  return provider;
}
