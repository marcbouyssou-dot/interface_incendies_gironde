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

  async send(message, options = {}) {
    const normalizedMessage = createNotificationMessage(message);
    const normalizedOptions = normalizeSendOptions(options);
    try {
      const result = await this.provider.send(
        normalizedMessage,
        normalizedOptions,
      );
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

function normalizeSendOptions(options) {
  if (
    options === null
    || typeof options !== 'object'
    || Array.isArray(options)
  ) {
    throw new NotificationServiceError(
      'invalid-send-options',
      'Les options d’envoi sont invalides.',
    );
  }
  const idempotencyKey = options.idempotencyKey;
  if (idempotencyKey === undefined) return Object.freeze({});
  if (
    typeof idempotencyKey !== 'string'
    || !/^[A-Za-z0-9:_-]{1,256}$/.test(idempotencyKey)
  ) {
    throw new NotificationServiceError(
      'invalid-idempotency-key',
      'La clé d’idempotence est invalide.',
    );
  }
  return Object.freeze({idempotencyKey});
}
