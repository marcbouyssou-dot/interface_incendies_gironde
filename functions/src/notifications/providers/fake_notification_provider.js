import {NotificationProvider} from '../notification_provider.js';

export class FakeNotificationProvider extends NotificationProvider {
  #messages = [];
  #deliveries = [];

  constructor({
    providerMessageId = 'fake-message-id',
    failure = null,
    name = 'fake',
  } = {}) {
    super({name});
    this.providerMessageId = providerMessageId;
    this.failure = failure;
  }

  get messages() {
    return Object.freeze([...this.#messages]);
  }

  get deliveries() {
    return Object.freeze([...this.#deliveries]);
  }

  async send(message, options = {}) {
    this.#messages.push(message);
    this.#deliveries.push(Object.freeze({
      message,
      idempotencyKey: options.idempotencyKey ?? null,
    }));
    if (this.failure) throw this.failure;
    return {providerMessageId: this.providerMessageId};
  }
}
