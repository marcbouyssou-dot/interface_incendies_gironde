import {NotificationProvider} from '../notification_provider.js';

export class FakeNotificationProvider extends NotificationProvider {
  #messages = [];

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

  async send(message) {
    this.#messages.push(message);
    if (this.failure) throw this.failure;
    return {providerMessageId: this.providerMessageId};
  }
}
