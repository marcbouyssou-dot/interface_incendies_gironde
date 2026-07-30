import {Resend} from 'resend';

import {NotificationProvider} from '../notification_provider.js';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export class ResendNotificationProviderError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'ResendNotificationProviderError';
    this.code = code;
  }
}

function configurationError(message) {
  return new ResendNotificationProviderError(
    'invalid-configuration',
    message,
  );
}

function validateEmail(value, fieldName, {required = true} = {}) {
  if (value === undefined || value === null || value === '') {
    if (!required) return null;
    throw configurationError(`${fieldName} est obligatoire.`);
  }
  if (typeof value !== 'string' || !EMAIL_PATTERN.test(value.trim())) {
    throw configurationError(`${fieldName} doit être une adresse valide.`);
  }
  return value.trim();
}

function validateFromName(value) {
  if (value === undefined || value === null || value === '') return null;
  if (
    typeof value !== 'string'
    || value.trim() === ''
    || /[\r\n<>]/.test(value)
  ) {
    throw configurationError('Le nom d’expéditeur est invalide.');
  }
  return value.trim();
}

function resolveClient({client, apiKey}) {
  if (client !== undefined) {
    if (
      client === null
      || typeof client !== 'object'
      || client.emails === null
      || typeof client.emails !== 'object'
      || typeof client.emails.send !== 'function'
    ) {
      throw configurationError('Le client Resend injecté est invalide.');
    }
    if (apiKey !== undefined) {
      throw configurationError(
        'Injectez un client Resend ou une clé API, pas les deux.',
      );
    }
    return client;
  }

  if (typeof apiKey !== 'string' || apiKey.trim() === '') {
    throw configurationError(
      'Un client Resend ou une clé API injectée est obligatoire.',
    );
  }
  return new Resend(apiKey.trim());
}

function safeProviderCause(providerError) {
  const cause = new Error('Le fournisseur Resend a refusé la requête.');
  cause.name = 'ResendApiError';
  if (
    providerError
    && typeof providerError === 'object'
    && typeof providerError.name === 'string'
    && providerError.name.trim() !== ''
  ) {
    cause.code = providerError.name.trim();
  }
  return cause;
}

export class ResendNotificationProvider extends NotificationProvider {
  #client;
  #from;
  #replyTo;

  constructor({
    client,
    apiKey,
    fromEmail,
    fromName,
    replyTo,
  } = {}) {
    super({name: 'resend'});
    this.#client = resolveClient({client, apiKey});
    const normalizedEmail = validateEmail(fromEmail, 'L’adresse expéditeur');
    const normalizedName = validateFromName(fromName);
    this.#replyTo = validateEmail(
      replyTo,
      'L’adresse de réponse',
      {required: false},
    );
    this.#from = normalizedName === null
      ? normalizedEmail
      : `${normalizedName} <${normalizedEmail}>`;
  }

  async send(message) {
    if (message?.channel !== 'email') {
      throw new ResendNotificationProviderError(
        'unsupported-channel',
        'Le fournisseur Resend prend uniquement en charge le canal email.',
      );
    }

    const payload = {
      from: this.#from,
      to: message.recipient,
      subject: message.subject,
    };
    if (message.text) payload.text = message.text;
    if (message.html) payload.html = message.html;
    if (this.#replyTo !== null) payload.replyTo = this.#replyTo;

    let response;
    try {
      response = await this.#client.emails.send(payload);
    } catch (error) {
      throw new ResendNotificationProviderError(
        'send-failed',
        'Resend n’a pas pu envoyer la notification.',
        {cause: error},
      );
    }

    if (response?.error) {
      throw new ResendNotificationProviderError(
        'send-failed',
        'Resend n’a pas pu envoyer la notification.',
        {cause: safeProviderCause(response.error)},
      );
    }

    const providerMessageId = response?.data?.id;
    if (
      typeof providerMessageId !== 'string'
      || providerMessageId.trim() === ''
    ) {
      throw new ResendNotificationProviderError(
        'invalid-response',
        'Resend a retourné une réponse invalide.',
      );
    }

    return Object.freeze({providerMessageId: providerMessageId.trim()});
  }
}
