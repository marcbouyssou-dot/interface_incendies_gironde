import {createHash} from 'node:crypto';

import {LEGACY_ORGANIZATION_ID} from '../organization_authorization.js';

export const PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION =
  'professionalSolicitationJournal';
export const SOLICITATION_JOURNAL_SCHEMA_VERSION = 1;

const FACT_TYPES = new Set(['created', 'provider_accepted', 'consulted']);
const CHANNELS = new Set(['in_app', 'push', 'email', 'sms']);
const SOURCES = new Set([
  'notification_dispatch',
  'push_provider',
  'consultation_callable',
]);

export class SolicitationJournalError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'SolicitationJournalError';
    this.code = code;
  }
}

export function solicitationJournalEntryId({
  solicitationId,
  factType,
  evidenceId = null,
}) {
  requireIdentifier(solicitationId, 'solicitationId');
  requireKnown(factType, FACT_TYPES, 'factType');
  if (evidenceId !== null) requireIdentifier(evidenceId, 'evidenceId');
  return createHash('sha256')
    .update([
      'professional-solicitation',
      solicitationId,
      factType,
      evidenceId ?? 'singleton',
    ].join(':'))
    .digest('hex');
}

export function canonicalSolicitationEntry({
  solicitationId,
  recipientUid,
  factType,
  missionId,
  mobilizationId = null,
  operationId = null,
  organizationId,
  channel,
  occurredAt,
  source,
  sourceRecordIds,
  causeEventId = null,
  causeType = null,
  category = null,
  engagementId = null,
  evidenceId = null,
  recordedAt,
}) {
  requireIdentifier(solicitationId, 'solicitationId');
  requireIdentifier(recipientUid, 'recipientUid');
  requireIdentifier(missionId, 'missionId');
  requireOptionalIdentifier(mobilizationId, 'mobilizationId');
  requireOptionalIdentifier(operationId, 'operationId');
  requireIdentifier(organizationId, 'organizationId');
  requireKnown(factType, FACT_TYPES, 'factType');
  requireKnown(channel, CHANNELS, 'channel');
  requireKnown(source, SOURCES, 'source');
  requireTimestamp(occurredAt, 'occurredAt');
  requireTimestamp(recordedAt, 'recordedAt');
  requireOptionalIdentifier(causeEventId, 'causeEventId');
  requireOptionalWireValue(causeType, 'causeType');
  requireOptionalWireValue(category, 'category');
  requireOptionalIdentifier(engagementId, 'engagementId');
  if (!Array.isArray(sourceRecordIds)
    || sourceRecordIds.length === 0
    || sourceRecordIds.length > 8
    || new Set(sourceRecordIds).size !== sourceRecordIds.length) {
    throw new SolicitationJournalError(
      'invalid-argument',
      'Preuves de sollicitation invalides.',
    );
  }
  sourceRecordIds.forEach((value) => requireIdentifier(value, 'sourceRecordId'));
  const entryId = solicitationJournalEntryId({
    solicitationId,
    factType,
    evidenceId,
  });
  return Object.freeze({
    entryId,
    solicitationId,
    recipientUid,
    factType,
    missionId,
    ...(mobilizationId === null ? {} : {mobilizationId}),
    ...(operationId === null ? {} : {operationId}),
    organizationId,
    channel,
    occurredAt,
    source,
    sources: Object.freeze(['canonical_journal']),
    sourceRecordIds: Object.freeze([...sourceRecordIds]),
    quality: 'complete',
    ...(causeEventId === null ? {} : {causeEventId}),
    ...(causeType === null ? {} : {causeType}),
    ...(category === null ? {} : {category}),
    ...(engagementId === null ? {} : {engagementId}),
    schemaVersion: SOLICITATION_JOURNAL_SCHEMA_VERSION,
    recordedAt,
  });
}

/// Crée uniquement. Une répétition strictement identique est dédupliquée ;
/// une collision d'identité est refusée sans mise à jour du document existant.
export async function ensureCanonicalSolicitationEntry({
  firestore,
  entry,
  transaction = null,
}) {
  const execute = async (activeTransaction) => {
    const reference = firestore
      .collection(PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION)
      .doc(entry.entryId);
    const existing = await activeTransaction.get(reference);
    if (existing.exists) {
      requireSameIdentity(existing.data(), entry);
      return {created: false, entryId: entry.entryId};
    }
    activeTransaction.create(reference, entry);
    return {created: true, entryId: entry.entryId};
  };
  return transaction === null
    ? firestore.runTransaction(execute)
    : execute(transaction);
}

export async function deriveSolicitationOrganizationContext({
  firestore,
  missionId,
  mission = null,
}) {
  requireIdentifier(missionId, 'missionId');
  let missionData = mission;
  if (missionData === null) {
    const missionSnapshot = await firestore.collection('missions').doc(missionId).get();
    if (!missionSnapshot.exists) {
      throw new SolicitationJournalError(
        'failed-precondition',
        'Mission de sollicitation introuvable.',
      );
    }
    missionData = missionSnapshot.data();
  }
  const mobilizationId = canonicalOptionalIdentifier(
    missionData?.mobilizationId,
  );
  if (mobilizationId === null) {
    throw new SolicitationJournalError(
      'failed-precondition',
      'Mobilisation de sollicitation introuvable.',
    );
  }
  const mobilizationSnapshot = await firestore
    .collection('mobilizations')
    .doc(mobilizationId)
    .get();
  if (!mobilizationSnapshot.exists) {
    throw new SolicitationJournalError(
      'failed-precondition',
      'Mobilisation de sollicitation introuvable.',
    );
  }
  const operationId = canonicalOptionalIdentifier(
    mobilizationSnapshot.data()?.operationId,
  );
  if (operationId === null) {
    return Object.freeze({
      missionId,
      mobilizationId,
      operationId: null,
      organizationId: LEGACY_ORGANIZATION_ID,
    });
  }
  const operationSnapshot = await firestore
    .collection('operations')
    .doc(operationId)
    .get();
  if (!operationSnapshot.exists) {
    throw new SolicitationJournalError(
      'failed-precondition',
      'Opération de sollicitation introuvable.',
    );
  }
  const rawOwner = operationSnapshot.data()?.ownerOrganizationId;
  const organizationId = rawOwner === undefined || rawOwner === null
    ? LEGACY_ORGANIZATION_ID
    : canonicalOptionalIdentifier(rawOwner);
  if (organizationId === null) {
    throw new SolicitationJournalError(
      'failed-precondition',
      'Organisation de sollicitation invalide.',
    );
  }
  return Object.freeze({
    missionId,
    mobilizationId,
    operationId,
    organizationId,
  });
}

export async function recordProfessionalSolicitationConsulted({
  callerUid,
  data,
  services,
}) {
  requireAuthenticated(callerUid);
  requireExactKeys(data, ['recipientUid', 'solicitationId']);
  requireIdentifier(data.recipientUid, 'recipientUid');
  requireIdentifier(data.solicitationId, 'solicitationId');
  if (data.recipientUid !== callerUid) {
    throw new SolicitationJournalError(
      'permission-denied',
      'Cette sollicitation ne vous appartient pas.',
    );
  }
  return services.recordConsulted({
    recipientUid: data.recipientUid,
    solicitationId: data.solicitationId,
  });
}

export async function listProfessionalSolicitationJournal({
  callerUid,
  data,
  services,
}) {
  requireAuthenticated(callerUid);
  requireExactKeys(data, ['recipientUid', 'limit', 'cursor'], {
    optional: ['limit', 'cursor'],
  });
  requireIdentifier(data.recipientUid, 'recipientUid');
  if (data.recipientUid !== callerUid) {
    throw new SolicitationJournalError(
      'permission-denied',
      'Lecture du journal refusée.',
    );
  }
  const limit = data.limit ?? 50;
  if (!Number.isInteger(limit) || limit < 1 || limit > 100) {
    throw new SolicitationJournalError(
      'invalid-argument',
      'Limite de journal invalide.',
    );
  }
  const cursor = parseCursor(data.cursor);
  return services.listEntries({
    recipientUid: data.recipientUid,
    limit,
    cursor,
  });
}

export function solicitationJournalFirestoreServices({
  firestore,
  serverTimestamp,
  timestampFromMillis,
}) {
  return Object.freeze({
    async recordConsulted({recipientUid, solicitationId}) {
      const notificationReference = firestore
        .collection('notifications')
        .doc(solicitationId);
      const notificationSnapshot = await notificationReference.get();
      if (!notificationSnapshot.exists
        || notificationSnapshot.data()?.recipientUid !== recipientUid) {
        throw new SolicitationJournalError(
          'not-found',
          'Sollicitation introuvable.',
        );
      }
      const notification = notificationSnapshot.data();
      const missionId = canonicalOptionalIdentifier(notification.missionId);
      if (missionId === null) {
        throw new SolicitationJournalError(
          'failed-precondition',
          'Contexte de sollicitation incomplet.',
        );
      }
      const context = await deriveSolicitationOrganizationContext({
        firestore,
        missionId,
      });
      return firestore.runTransaction(async (transaction) => {
        const currentNotification = await transaction.get(notificationReference);
        if (!currentNotification.exists
          || currentNotification.data()?.recipientUid !== recipientUid) {
          throw new SolicitationJournalError(
            'not-found',
            'Sollicitation introuvable.',
          );
        }
        const timestamp = serverTimestamp();
        const entry = canonicalSolicitationEntry({
          solicitationId,
          recipientUid,
          factType: 'consulted',
          ...context,
          channel: 'in_app',
          occurredAt: timestamp,
          source: 'consultation_callable',
          sourceRecordIds: [solicitationId],
          causeEventId: canonicalOptionalIdentifier(notification.eventId),
          causeType: canonicalOptionalWireValue(notification.eventType),
          category: canonicalOptionalWireValue(notification.category),
          engagementId: canonicalOptionalIdentifier(notification.engagementId),
          recordedAt: timestamp,
        });
        const result = await ensureCanonicalSolicitationEntry({
          firestore,
          transaction,
          entry,
        });
        if (result.created) {
          transaction.update(notificationReference, {readAt: timestamp});
        }
        return result;
      });
    },

    async listEntries({recipientUid, limit, cursor}) {
      let query = firestore
        .collection(PROFESSIONAL_SOLICITATION_JOURNAL_COLLECTION)
        .where('recipientUid', '==', recipientUid)
        .orderBy('occurredAt', 'desc')
        .orderBy('entryId', 'desc');
      if (cursor !== null) {
        query = query.startAfter(
          timestampFromMillis(cursor.occurredAtMillis),
          cursor.entryId,
        );
      }
      const snapshot = await query.limit(limit).get();
      const entries = snapshot.docs.map((document) => {
        const value = document.data();
        const {occurredAt, recordedAt, ...serialized} = value;
        return {
          ...serialized,
          occurredAtMillis: occurredAt.toMillis(),
          recordedAtMillis: recordedAt.toMillis(),
        };
      });
      const last = snapshot.docs.at(-1);
      const nextCursor = last === undefined
        ? null
        : {
          occurredAtMillis: last.data().occurredAt.toMillis(),
          entryId: last.data().entryId,
        };
      return {entries, nextCursor};
    },
  });
}

function requireSameIdentity(existing, candidate) {
  for (const field of [
    'entryId',
    'solicitationId',
    'recipientUid',
    'factType',
    'missionId',
    'organizationId',
    'channel',
    'source',
    'schemaVersion',
  ]) {
    if (existing?.[field] !== candidate[field]) {
      throw new SolicitationJournalError(
        'already-exists',
        'Collision dans le journal canonique des sollicitations.',
      );
    }
  }
}

function parseCursor(value) {
  if (value === undefined || value === null) return null;
  requireExactKeys(value, ['occurredAtMillis', 'entryId']);
  if (!Number.isSafeInteger(value.occurredAtMillis)
    || value.occurredAtMillis < 0) {
    throw new SolicitationJournalError(
      'invalid-argument',
      'Curseur de journal invalide.',
    );
  }
  requireIdentifier(value.entryId, 'entryId');
  return Object.freeze({
    occurredAtMillis: value.occurredAtMillis,
    entryId: value.entryId,
  });
}

function requireAuthenticated(uid) {
  if (typeof uid !== 'string' || uid === '') {
    throw new SolicitationJournalError(
      'unauthenticated',
      'Authentification requise.',
    );
  }
}

function requireExactKeys(value, keys, {optional = []} = {}) {
  if (!isPlainObject(value)) {
    throw new SolicitationJournalError(
      'invalid-argument',
      'Requête de journal invalide.',
    );
  }
  const allowed = new Set(keys);
  const required = keys.filter((key) => !optional.includes(key));
  if (Object.keys(value).some((key) => !allowed.has(key))
    || required.some((key) => !Object.hasOwn(value, key))) {
    throw new SolicitationJournalError(
      'invalid-argument',
      'Requête de journal invalide.',
    );
  }
}

function requireIdentifier(value, field) {
  if (typeof value !== 'string'
    || value.length === 0
    || value.length > 180
    || value.trim() !== value
    || value.includes('/')) {
    throw new SolicitationJournalError(
      'invalid-argument',
      `${field} invalide.`,
    );
  }
}

function requireOptionalIdentifier(value, field) {
  if (value !== null) requireIdentifier(value, field);
}

function requireKnown(value, allowed, field) {
  if (!allowed.has(value)) {
    throw new SolicitationJournalError(
      'invalid-argument',
      `${field} invalide.`,
    );
  }
}

function requireTimestamp(value, field) {
  if (value === null || value === undefined
    || (typeof value !== 'object' && !(value instanceof Date))) {
    throw new SolicitationJournalError(
      'invalid-argument',
      `${field} invalide.`,
    );
  }
}

function requireOptionalWireValue(value, field) {
  if (value === null) return;
  if (typeof value !== 'string'
    || !/^[a-z0-9][a-z0-9._-]*$/.test(value)) {
    throw new SolicitationJournalError(
      'invalid-argument',
      `${field} invalide.`,
    );
  }
}

function canonicalOptionalIdentifier(value) {
  if (value === undefined || value === null || value === '') return null;
  requireIdentifier(value, 'identifier');
  return value;
}

function canonicalOptionalWireValue(value) {
  if (value === undefined || value === null || value === '') return null;
  requireOptionalWireValue(value, 'wireValue');
  return value;
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
