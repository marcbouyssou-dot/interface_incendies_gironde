const SUPPORTED_CHANNELS = new Set(['email']);

export class NotificationMessageValidationError extends Error {
  constructor(message) {
    super(message);
    this.name = 'NotificationMessageValidationError';
    this.code = 'invalid-notification-message';
  }
}

export function createNotificationMessage(value) {
  if (!isPlainObject(value)) {
    throw new NotificationMessageValidationError(
      'Le message de notification doit être un objet.',
    );
  }

  const channel = requiredText(value.channel, 'Canal de notification requis.');
  if (!SUPPORTED_CHANNELS.has(channel)) {
    throw new NotificationMessageValidationError(
      `Canal de notification non pris en charge : ${channel}.`,
    );
  }

  const recipient = requiredText(value.recipient, 'Destinataire requis.');
  const subject = requiredText(value.subject, 'Sujet requis pour un email.');
  const text = optionalText(value.text);
  const html = optionalText(value.html);
  if (!text && !html) {
    throw new NotificationMessageValidationError(
      'Une version texte ou HTML est requise.',
    );
  }

  const metadata = value.metadata ?? {};
  if (!isPlainObject(metadata)) {
    throw new NotificationMessageValidationError(
      'Les métadonnées doivent être un objet.',
    );
  }

  return Object.freeze({
    channel,
    recipient,
    subject,
    text,
    html,
    metadata: cloneAndFreeze(metadata),
  });
}

function requiredText(value, errorMessage) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new NotificationMessageValidationError(errorMessage);
  }
  return value.trim();
}

function optionalText(value) {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string') {
    throw new NotificationMessageValidationError(
      'Le contenu de notification doit être du texte.',
    );
  }
  const normalized = value.trim();
  return normalized === '' ? null : normalized;
}

function cloneAndFreeze(value) {
  if (Array.isArray(value)) {
    return Object.freeze(value.map(cloneAndFreeze));
  }
  if (isPlainObject(value)) {
    return Object.freeze(
      Object.fromEntries(
        Object.entries(value).map(([key, item]) => [
          key,
          cloneAndFreeze(item),
        ]),
      ),
    );
  }
  if (
    value === null
    || typeof value === 'string'
    || typeof value === 'number'
    || typeof value === 'boolean'
  ) {
    return value;
  }
  throw new NotificationMessageValidationError(
    'Les métadonnées contiennent une valeur non prise en charge.',
  );
}

function isPlainObject(value) {
  if (value === null || typeof value !== 'object') return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}
