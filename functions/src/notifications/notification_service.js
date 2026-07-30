import {createNotificationMessage} from './notification_message.js';
import {assertNotificationProvider} from './notification_provider.js';

export class NotificationServiceError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'NotificationServiceError';
    this.code = code;
  }
}

export class NotificationService {
  constructor({provider}) {
    this.provider = assertNotificationProvider(provider);
  }

  async send(message) {
    const normalizedMessage = createNotificationMessage(message);
    try {
      const result = await this.provider.send(normalizedMessage);
      const providerMessageId = result?.providerMessageId;
      if (
        typeof providerMessageId !== 'string'
        || providerMessageId.trim() === ''
      ) {
        throw new NotificationServiceError(
          'invalid-provider-result',
          'Le fournisseur a retourné un résultat invalide.',
        );
      }
      return Object.freeze({
        success: true,
        providerMessageId: providerMessageId.trim(),
        provider: this.provider.name.trim(),
      });
    } catch (error) {
      if (error instanceof NotificationServiceError) throw error;
      throw new NotificationServiceError(
        'provider-failure',
        'La notification n’a pas pu être envoyée.',
        {cause: error},
      );
    }
  }
}
