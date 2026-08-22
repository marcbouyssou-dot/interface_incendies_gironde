import assert from 'node:assert/strict';
import test from 'node:test';

import {
  deliverPush,
  dispatchOperationalEvent,
} from '../src/operational_notifications/firestore_service.js';
import {
  canonicalSolicitationEntry,
  deriveSolicitationOrganizationContext,
  ensureCanonicalSolicitationEntry,
  listProfessionalSolicitationJournal,
  PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  recordProfessionalSolicitationConsulted,
  solicitationJournalEntryId,
  solicitationJournalFirestoreServices,
  SolicitationJournalError,
} from '../src/operational_notifications/solicitation_journal.js';

const recipientUid = 'professional-a';
const occurredAt = new Date('2026-08-20T10:00:00.000Z');
const context = Object.freeze({
  missionId: 'mission-a',
  mobilizationId: 'mobilization-a',
  operationId: 'operation-a',
  organizationId: 'organization-a',
});

function createdEntry(overrides = {}) {
  return canonicalSolicitationEntry({
    solicitationId: 'notification-a',
    recipientUid,
    factType: 'created',
    ...context,
    channel: 'in_app',
    occurredAt,
    source: 'notification_dispatch',
    sourceRecordIds: ['notification-a', 'event-a'],
    causeEventId: 'event-a',
    causeType: 'mission.published',
    category: 'compatible',
    recordedAt: occurredAt,
    ...overrides,
  });
}

function event() {
  return {
    eventId: 'event-a',
    eventType: 'mission.published',
    occurredAt,
    missionId: 'mission-a',
    mobilizationId: 'mobilization-a',
    actorUid: 'manager-a',
    payload: {
      locationName: 'Langon',
      requiredByProfession: {nurse: 1},
      registeredByProfession: {nurse: 0},
    },
  };
}

test('canonical entry is contextual and contains no score or presence', () => {
  const entry = createdEntry();

  assert.equal(entry.entryId.length, 64);
  assert.equal(entry.factType, 'created');
  assert.equal(entry.recipientUid, recipientUid);
  assert.equal(entry.organizationId, 'organization-a');
  assert.equal(entry.source, 'notification_dispatch');
  assert.equal(entry.schemaVersion, 1);
  for (const forbidden of [
    'score', 'ranking', 'rating', 'presence', 'delivered_to_device',
  ]) {
    assert.equal(Object.hasOwn(entry, forbidden), false);
  }
});

test('entry ids are stable and evidence-scoped', () => {
  const first = solicitationJournalEntryId({
    solicitationId: 'notification-a',
    factType: 'created',
  });
  const retry = solicitationJournalEntryId({
    solicitationId: 'notification-a',
    factType: 'created',
  });
  const provider = solicitationJournalEntryId({
    solicitationId: 'notification-a',
    factType: 'provider_accepted',
    evidenceId: 'delivery-a',
  });

  assert.equal(first, retry);
  assert.notEqual(first, provider);
});

test('created write is idempotent and a conflicting duplicate is refused', async () => {
  const firestore = new MemoryFirestore();
  const entry = createdEntry();

  assert.deepEqual(await ensureCanonicalSolicitationEntry({firestore, entry}), {
    created: true,
    entryId: entry.entryId,
  });
  assert.deepEqual(await ensureCanonicalSolicitationEntry({firestore, entry}), {
    created: false,
    entryId: entry.entryId,
  });
  assert.equal(firestore.collectionValues(
    PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  ).length, 1);

  await assert.rejects(
    () => ensureCanonicalSolicitationEntry({
      firestore,
      entry: {...entry, recipientUid: 'professional-forged'},
    }),
    (error) => error instanceof SolicitationJournalError
      && error.code === 'already-exists',
  );
  assert.equal(firestore.collectionValues(
    PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  ).length, 1);
});

test('organization is derived from operation and legacy fallback only', async () => {
  const firestore = new MemoryFirestore();
  firestore.seed('mobilizations/mobilization-a', {
    id: 'mobilization-a',
    operationId: 'operation-a',
  });
  firestore.seed('operations/operation-a', {
    id: 'operation-a',
    ownerOrganizationId: 'organization-a',
  });

  const derived = await deriveSolicitationOrganizationContext({
    firestore,
    missionId: 'mission-a',
    mission: {mobilizationId: 'mobilization-a'},
  });
  assert.deepEqual(derived, context);

  firestore.seed('mobilizations/mobilization-legacy', {
    id: 'mobilization-legacy',
  });
  assert.deepEqual(
    await deriveSolicitationOrganizationContext({
      firestore,
      missionId: 'mission-legacy',
      mission: {mobilizationId: 'mobilization-legacy'},
    }),
    {
      missionId: 'mission-legacy',
      mobilizationId: 'mobilization-legacy',
      operationId: null,
      organizationId: 'legacy-gironde',
    },
  );
});

test('dispatch creates one canonical created fact per real recipient', async () => {
  const firestore = operationalFirestore({compatibleMissions: true});
  const result = await dispatchOperationalEvent({
    firestore,
    messaging: {send: async () => 'unused'},
    event: event(),
    now: occurredAt,
  });
  await dispatchOperationalEvent({
    firestore,
    messaging: {send: async () => 'unused'},
    event: event(),
    now: occurredAt,
  });

  assert.deepEqual(result, {notifications: 1, pushes: 0});
  const entries = firestore.collectionValues(
    PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  );
  assert.equal(entries.length, 1);
  assert.equal(entries[0].factType, 'created');
  assert.equal(entries[0].recipientUid, recipientUid);
  assert.equal(entries[0].organizationId, 'organization-a');
});

test('an event without an effectively targeted recipient creates no entry', async () => {
  const firestore = operationalFirestore({compatibleMissions: false});
  const result = await dispatchOperationalEvent({
    firestore,
    messaging: {send: async () => 'unused'},
    event: event(),
    now: occurredAt,
  });

  assert.deepEqual(result, {notifications: 0, pushes: 0});
  assert.deepEqual(firestore.collectionValues(
    PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  ), []);
});

test('provider acceptance writes provider_accepted only after FCM success', async () => {
  const firestore = new MemoryFirestore();
  const delivered = await deliverPush({
    firestore,
    messaging: {send: async () => 'provider-message-a'},
    event: event(),
    content: {title: 'Mission', body: 'Une mission'},
    recipientUid,
    subscription: {
      id: 'subscription-a',
      installationId: 'installation-a',
      token: 'token-a',
    },
    notificationId: 'notification-a',
    context,
    now: occurredAt,
  });

  assert.equal(delivered, 'delivered');
  const entries = firestore.collectionValues(
    PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  );
  assert.equal(entries.length, 1);
  assert.equal(entries[0].factType, 'provider_accepted');
  assert.equal(entries[0].channel, 'push');
  assert.equal(entries[0].delivered_to_device, undefined);
  assert.equal(
    entries[0].sourceRecordIds.some((id) => id.startsWith('provider-')),
    true,
  );
  assert.equal(
    firestore.collectionValues('notificationDeliveries')[0].providerMessageId,
    'provider-message-a',
  );

  const failingFirestore = new MemoryFirestore();
  await assert.rejects(() => deliverPush({
    firestore: failingFirestore,
    messaging: {
      async send() {
        const error = new Error('provider failure');
        error.code = 'messaging/internal-error';
        throw error;
      },
    },
    event: event(),
    content: {title: 'Mission', body: 'Une mission'},
    recipientUid,
    subscription: {
      id: 'subscription-b',
      installationId: 'installation-b',
      token: 'token-b',
    },
    notificationId: 'notification-a',
    context,
    now: occurredAt,
  }));
  assert.deepEqual(failingFirestore.collectionValues(
    PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  ), []);

  const noProofFirestore = new MemoryFirestore();
  await assert.rejects(() => deliverPush({
    firestore: noProofFirestore,
    messaging: {send: async () => null},
    event: event(),
    content: {title: 'Mission', body: 'Une mission'},
    recipientUid,
    subscription: {
      id: 'subscription-c',
      installationId: 'installation-c',
      token: 'token-c',
    },
    notificationId: 'notification-a',
    context,
    now: occurredAt,
  }));
  assert.deepEqual(noProofFirestore.collectionValues(
    PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  ), []);
});

test('consulted is owner-only, server-contextual and append-only', async () => {
  const firestore = new MemoryFirestore();
  seedConsultationContext(firestore);
  let timestampCalls = 0;
  const services = solicitationJournalFirestoreServices({
    firestore,
    serverTimestamp: () => {
      timestampCalls += 1;
      return new Date(occurredAt.getTime() + timestampCalls * 1000);
    },
    timestampFromMillis: (value) => timestamp(value),
  });

  await assert.rejects(
    () => recordProfessionalSolicitationConsulted({
      callerUid: 'professional-b',
      data: {recipientUid, solicitationId: 'notification-a'},
      services,
    }),
    (error) => error.code === 'permission-denied',
  );
  await assert.rejects(
    () => recordProfessionalSolicitationConsulted({
      callerUid: recipientUid,
      data: {
        recipientUid,
        solicitationId: 'notification-a',
        organizationId: 'organization-forged',
      },
      services,
    }),
    (error) => error.code === 'invalid-argument',
  );

  const first = await recordProfessionalSolicitationConsulted({
    callerUid: recipientUid,
    data: {recipientUid, solicitationId: 'notification-a'},
    services,
  });
  const initialReadAt = firestore.read('notifications/notification-a').readAt;
  const retry = await recordProfessionalSolicitationConsulted({
    callerUid: recipientUid,
    data: {recipientUid, solicitationId: 'notification-a'},
    services,
  });

  assert.equal(first.created, true);
  assert.equal(retry.created, false);
  assert.equal(firestore.collectionValues(
    PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  ).length, 1);
  assert.equal(firestore.collectionValues(
    PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION,
  )[0].organizationId, 'organization-a');
  assert.equal(
    firestore.read('notifications/notification-a').readAt,
    initialReadAt,
  );
  assert.equal(
    firestore.operations.some((operation) =>
      operation.type === 'update'
      && operation.path.startsWith(`${PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION}/`)),
    false,
  );
  assert.equal(
    firestore.operations.some((operation) => operation.type === 'delete'),
    false,
  );
});

test('paginated request is recipient-bound and limit is capped', async () => {
  const calls = [];
  const services = {
    async listEntries(request) {
      calls.push(request);
      return {entries: [], nextCursor: null};
    },
  };
  await assert.rejects(
    () => listProfessionalSolicitationJournal({
      callerUid: 'professional-b',
      data: {recipientUid},
      services,
    }),
    (error) => error.code === 'permission-denied',
  );
  await assert.rejects(
    () => listProfessionalSolicitationJournal({
      callerUid: recipientUid,
      data: {recipientUid, limit: 101},
      services,
    }),
    (error) => error.code === 'invalid-argument',
  );

  await listProfessionalSolicitationJournal({
    callerUid: recipientUid,
    data: {
      recipientUid,
      limit: 25,
      cursor: {occurredAtMillis: occurredAt.getTime(), entryId: 'entry-a'},
    },
    services,
  });
  assert.deepEqual(calls, [{
    recipientUid,
    limit: 25,
    cursor: {occurredAtMillis: occurredAt.getTime(), entryId: 'entry-a'},
  }]);
});

function operationalFirestore({compatibleMissions}) {
  const firestore = new MemoryFirestore();
  firestore.seed('missions/mission-a', {
    id: 'mission-a',
    mobilizationId: 'mobilization-a',
    locationId: 'location-a',
    locationName: 'Langon',
    createdBy: 'manager-a',
    isActive: true,
    status: 'toComplete',
  });
  firestore.seed('mobilizations/mobilization-a', {
    id: 'mobilization-a',
    operationId: 'operation-a',
  });
  firestore.seed('operations/operation-a', {
    id: 'operation-a',
    ownerOrganizationId: 'organization-a',
  });
  firestore.seed(`volunteers/${recipientUid}`, {
    uid: recipientUid,
    profession: 'nurse',
  });
  firestore.seed(`notificationPreferences/${recipientUid}`, {
    compatibleMissions,
    engagementUpdates: true,
    operationalAlerts: true,
  });
  return firestore;
}

function seedConsultationContext(firestore) {
  firestore.seed('notifications/notification-a', {
    notificationId: 'notification-a',
    recipientUid,
    eventId: 'event-a',
    eventType: 'mission.published',
    category: 'compatible',
    missionId: 'mission-a',
    mobilizationId: 'mobilization-a',
    readAt: null,
  });
  firestore.seed('missions/mission-a', {
    id: 'mission-a',
    mobilizationId: 'mobilization-a',
  });
  firestore.seed('mobilizations/mobilization-a', {
    id: 'mobilization-a',
    operationId: 'operation-a',
  });
  firestore.seed('operations/operation-a', {
    id: 'operation-a',
    ownerOrganizationId: 'organization-a',
  });
}

function timestamp(milliseconds) {
  return {toMillis: () => milliseconds};
}

class MemoryFirestore {
  constructor() {
    this.values = new Map();
    this.operations = [];
  }

  seed(path, value) {
    this.values.set(path, value);
  }

  read(path) {
    return this.values.get(path);
  }

  collection(name) {
    return new MemoryQuery(this, name);
  }

  collectionValues(name) {
    return [...this.values.entries()]
      .filter(([path]) => path.startsWith(`${name}/`)
        && path.split('/').length === 2)
      .map(([, value]) => value);
  }

  async runTransaction(action) {
    const transaction = new MemoryTransaction(this);
    const result = await action(transaction);
    transaction.commit();
    return result;
  }
}

class MemoryQuery {
  constructor(firestore, collectionName, filters = []) {
    this.firestore = firestore;
    this.collectionName = collectionName;
    this.filters = filters;
  }

  doc(id) {
    return new MemoryReference(this.firestore, `${this.collectionName}/${id}`);
  }

  where(field, operator, value) {
    assert.equal(operator, '==');
    return new MemoryQuery(this.firestore, this.collectionName, [
      ...this.filters,
      {field, value},
    ]);
  }

  orderBy() {
    return this;
  }

  startAfter() {
    return this;
  }

  limit() {
    return this;
  }

  async get() {
    const docs = [...this.firestore.values.entries()]
      .filter(([path]) => path.startsWith(`${this.collectionName}/`)
        && path.split('/').length === 2)
      .map(([path, value]) => new MemorySnapshot(
        new MemoryReference(this.firestore, path),
        value,
      ))
      .filter((snapshot) => this.filters.every(
        ({field, value}) => snapshot.data()?.[field] === value,
      ));
    return {docs};
  }
}

class MemoryReference {
  constructor(firestore, path) {
    this.firestore = firestore;
    this.path = path;
    this.id = path.split('/').at(-1);
  }

  async get() {
    return new MemorySnapshot(this, this.firestore.values.get(this.path));
  }

  async update(fields) {
    if (!this.firestore.values.has(this.path)) throw new Error('not-found');
    this.firestore.values.set(this.path, {
      ...this.firestore.values.get(this.path),
      ...fields,
    });
    this.firestore.operations.push({type: 'update', path: this.path});
  }
}

class MemorySnapshot {
  constructor(reference, value) {
    this.ref = reference;
    this.id = reference.id;
    this.value = value;
    this.exists = value !== undefined;
  }

  data() {
    return this.value;
  }
}

class MemoryTransaction {
  constructor(firestore) {
    this.firestore = firestore;
    this.pending = [];
  }

  async get(reference) {
    return reference.get();
  }

  create(reference, value) {
    this.pending.push({type: 'create', reference, value});
  }

  set(reference, value, options = {}) {
    this.pending.push({type: 'set', reference, value, options});
  }

  update(reference, fields) {
    this.pending.push({type: 'update', reference, value: fields});
  }

  commit() {
    for (const operation of this.pending) {
      const {path} = operation.reference;
      const current = this.firestore.values.get(path);
      if (operation.type === 'create' && current !== undefined) {
        throw new Error('already-exists');
      }
      if (operation.type === 'update' && current === undefined) {
        throw new Error('not-found');
      }
      const merged = operation.type === 'update'
        || (operation.type === 'set' && operation.options.merge === true);
      this.firestore.values.set(path, merged
        ? {...current, ...operation.value}
        : operation.value);
      this.firestore.operations.push({type: operation.type, path});
    }
  }
}
