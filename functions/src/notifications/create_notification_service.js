import {NotificationService} from './notification_service.js';
import {
  FakeNotificationProvider,
} from './providers/fake_notification_provider.js';
import {
  ResendNotificationProvider,
} from './providers/resend_notification_provider.js';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export class NotificationServiceConfigurationError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'NotificationServiceConfigurationError';
    this.code = code;
  }
}

export function createNotificationService({provider}) {
  return new NotificationService({provider});
}

export function createServerNotificationService({
  mode,
  emulatorFailure,
  configuration,
  providerFactory = (options) => new ResendNotificationProvider(options),
} = {}) {
  if (mode === 'emulator') {
    return createNotificationService({
      provider: new FakeNotificationProvider({
        providerMessageId: 'emulator-message-id',
        failure: emulatorFailure,
      }),
    });
  }
  if (mode !== 'real') {
    throw configurationError('Mode de notification serveur invalide.');
  }
  const normalized = validateRealConfiguration(configuration);
  let provider;
  try {
    provider = providerFactory({
      apiKey: normalized.apiKey,
      fromEmail: normalized.fromEmail,
      fromName: normalized.fromName,
      replyTo: normalized.replyTo,
    });
  } catch (error) {
    throw configurationError(
      'La configuration du fournisseur de notifications est invalide.',
      {cause: error},
    );
  }
  return createNotificationService({provider});
}

function validateRealConfiguration(value) {
  if (!value || typeof value !== 'object') {
    throw configurationError('Configuration de notification absente.');
  }
  const apiKey = requiredText(
    value.apiKey,
    'Le secret Resend est absent ou vide.',
  );
  const fromEmail = requiredText(
    value.fromEmail,
    'L’adresse expéditeur est absente.',
  );
  if (!EMAIL_PATTERN.test(fromEmail)) {
    throw configurationError('L’adresse expéditeur est invalide.');
  }
  const appUrl = requiredText(
    value.appUrl,
    'L’URL MobSanté est absente.',
  );
  validateAppUrl(appUrl);
  const replyTo = optionalText(value.replyTo);
  if (replyTo !== undefined && !EMAIL_PATTERN.test(replyTo)) {
    throw configurationError('L’adresse de réponse est invalide.');
  }
  return {
    apiKey,
    fromEmail,
    fromName: optionalText(value.fromName),
    replyTo,
  };
}

function validateAppUrl(value) {
  let url;
  try {
    url = new URL(value);
  } catch {
    throw configurationError('L’URL MobSanté est invalide.');
  }
  if (
    url.protocol !== 'https:'
    || url.username
    || url.password
    || url.search
    || url.hash
  ) {
    throw configurationError('L’URL MobSanté est invalide.');
  }
}

function requiredText(value, message) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw configurationError(message);
  }
  return value.trim();
}

function optionalText(value) {
  if (value === undefined || value === null || value === '') return undefined;
  if (typeof value !== 'string' || value.trim() === '') {
    throw configurationError('Un paramètre facultatif est invalide.');
  }
  return value.trim();
}

function configurationError(message, options = {}) {
  return new NotificationServiceConfigurationError(
    'invalid-notification-configuration',
    message,
    options,
  );
}
