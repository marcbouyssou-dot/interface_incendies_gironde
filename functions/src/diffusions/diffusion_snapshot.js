import {diffusionIdForNeed} from './diffusion.js';

export const DIFFUSION_SNAPSHOT_COLLECTION = 'diffusionSnapshots';

const SNAPSHOT_FIELDS = Object.freeze([
  'diffusionId',
  'needId',
  'createdAt',
  'populationCount',
  'criteriaSnapshot',
]);
const CRITERIA_FIELDS = Object.freeze([
  'profession',
  'consent',
  'alreadyEngaged',
  'antiRepetition',
]);
const ANTI_REPETITION_FIELDS = Object.freeze([
  'category',
  'maximum',
  'windowHours',
]);

export class DiffusionSnapshotError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'DiffusionSnapshotError';
    this.code = code;
  }
}

export function currentCriteriaSnapshot() {
  return Object.freeze({
    profession: 'needed_professions',
    consent: 'compatibleMissions',
    alreadyEngaged: 'excluded',
    antiRepetition: Object.freeze({
      category: 'compatible',
      maximum: 3,
      windowHours: 24,
    }),
  });
}

export function diffusionSnapshot({
  diffusionId,
  needId,
  createdAt,
  populationCount,
  criteriaSnapshot = currentCriteriaSnapshot(),
}) {
  return canonicalSnapshot({
    diffusionId,
    needId,
    createdAt,
    populationCount,
    criteriaSnapshot,
  });
}

export function serializeDiffusionSnapshot(snapshot) {
  const value = canonicalSnapshot(snapshot);
  return {
    diffusionId: value.diffusionId,
    needId: value.needId,
    createdAt: value.createdAt,
    populationCount: value.populationCount,
    criteriaSnapshot: serializedCriteria(value.criteriaSnapshot),
  };
}

export function deserializeDiffusionSnapshot({id, data}) {
  requireIdentifier(id, 'diffusionId');
  requireExactFields(data, SNAPSHOT_FIELDS, 'Document Snapshot invalide.');
  if (data.diffusionId !== id) {
    throw new DiffusionSnapshotError(
      'invalid-diffusion-snapshot',
      'Identifiant Snapshot incohérent.',
    );
  }
  return canonicalSnapshot(data);
}

export async function ensureDiffusionSnapshot({firestore, snapshot}) {
  const serialized = serializeDiffusionSnapshot(snapshot);
  const reference = firestore
    .collection(DIFFUSION_SNAPSHOT_COLLECTION)
    .doc(serialized.diffusionId);
  return firestore.runTransaction(async (transaction) => {
    const existing = await transaction.get(reference);
    if (existing.exists) {
      return Object.freeze({
        created: false,
        snapshot: deserializeDiffusionSnapshot({
          id: reference.id,
          data: existing.data(),
        }),
      });
    }
    transaction.create(reference, serialized);
    return Object.freeze({
      created: true,
      snapshot: canonicalSnapshot(serialized),
    });
  });
}

export async function captureDiffusionSnapshot({
  firestore,
  event,
  recipients,
  createdAt,
}) {
  if (event?.eventType !== 'mission.published') return null;
  if (!Array.isArray(recipients)) {
    throw new DiffusionSnapshotError(
      'invalid-diffusion-snapshot',
      'Résultat de ciblage invalide.',
    );
  }
  return ensureDiffusionSnapshot({
    firestore,
    snapshot: diffusionSnapshot({
      diffusionId: diffusionIdForNeed(event.missionId),
      needId: event.missionId,
      createdAt,
      populationCount: recipients.length,
    }),
  });
}

function canonicalSnapshot(value) {
  requireExactFields(value, SNAPSHOT_FIELDS, 'Snapshot invalide.');
  requireIdentifier(value.diffusionId, 'diffusionId');
  requireIdentifier(value.needId, 'needId');
  if (value.diffusionId !== diffusionIdForNeed(value.needId)) {
    throw new DiffusionSnapshotError(
      'invalid-diffusion-snapshot',
      'Le Snapshot ne correspond pas au Besoin.',
    );
  }
  requireTimestamp(value.createdAt, 'createdAt');
  if (!Number.isSafeInteger(value.populationCount)
      || value.populationCount < 0) {
    throw new DiffusionSnapshotError(
      'invalid-diffusion-snapshot',
      'populationCount invalide.',
    );
  }
  const criteriaSnapshot = canonicalCriteria(value.criteriaSnapshot);
  return Object.freeze({
    diffusionId: value.diffusionId,
    needId: value.needId,
    createdAt: value.createdAt,
    populationCount: value.populationCount,
    criteriaSnapshot,
  });
}

function canonicalCriteria(value) {
  requireExactFields(value, CRITERIA_FIELDS, 'criteriaSnapshot invalide.');
  requireExactFields(
    value.antiRepetition,
    ANTI_REPETITION_FIELDS,
    'Critère anti-répétition invalide.',
  );
  if (value.profession !== 'needed_professions'
      || value.consent !== 'compatibleMissions'
      || value.alreadyEngaged !== 'excluded'
      || value.antiRepetition.category !== 'compatible'
      || value.antiRepetition.maximum !== 3
      || value.antiRepetition.windowHours !== 24) {
    throw new DiffusionSnapshotError(
      'invalid-diffusion-snapshot',
      'criteriaSnapshot ne reflète pas le ciblage actuel.',
    );
  }
  return currentCriteriaSnapshot();
}

function serializedCriteria(value) {
  return {
    profession: value.profession,
    consent: value.consent,
    alreadyEngaged: value.alreadyEngaged,
    antiRepetition: {
      category: value.antiRepetition.category,
      maximum: value.antiRepetition.maximum,
      windowHours: value.antiRepetition.windowHours,
    },
  };
}

function requireExactFields(value, fields, message) {
  if (!isPlainObject(value)
      || Object.keys(value).length !== fields.length
      || fields.some((field) => !Object.hasOwn(value, field))) {
    throw new DiffusionSnapshotError('invalid-diffusion-snapshot', message);
  }
}

function requireIdentifier(value, field) {
  if (typeof value !== 'string'
      || value.length === 0
      || value.length > 180
      || value.trim() !== value
      || value.includes('/')) {
    throw new DiffusionSnapshotError(
      'invalid-diffusion-snapshot',
      `${field} invalide.`,
    );
  }
}

function requireTimestamp(value, field) {
  if (!(value instanceof Date)
      && typeof value?.toMillis !== 'function'
      && typeof value?.toDate !== 'function') {
    throw new DiffusionSnapshotError(
      'invalid-diffusion-snapshot',
      `${field} invalide.`,
    );
  }
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
