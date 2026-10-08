import {diffusionIdForNeed} from './diffusion.js';

export const DIFFUSION_SNAPSHOT_COLLECTION = 'diffusionSnapshots';

const SNAPSHOT_FIELDS = Object.freeze([
  'diffusionId',
  'needId',
  'createdAt',
  'populationCount',
  'criteriaSnapshot',
]);
const TARGETING_STATUSES = new Set([
  'TARGETING_READY',
  'TARGETING_UNAVAILABLE_SITE_LOCATION',
  'TARGETING_UNAVAILABLE_CONTEXT',
  'TARGETING_TRANSITION_LEGACY',
]);
const CRITERIA_FIELDS = Object.freeze([
  'profession',
  'consent',
  'alreadyEngaged',
  'antiRepetition',
]);
const CURRENT_CRITERIA_FIELDS = Object.freeze([
  ...CRITERIA_FIELDS,
  'action',
  'identity',
  'admission',
  'geography',
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

export function currentCriteriaSnapshot(targetingStatus = null) {
  return Object.freeze({
    profession: 'needed_professions',
    consent: 'compatibleMissions',
    alreadyEngaged: 'excluded',
    antiRepetition: Object.freeze({
      category: 'compatible',
      maximum: 3,
      windowHours: 24,
    }),
    action: 'active_operational',
    identity: 'verified_rpps',
    admission: 'operation_scoped_when_invitation_only',
    geography: targetingStatus === 'TARGETING_TRANSITION_LEGACY'
      ? 'verified_site_legacy_opt_in_or_selected_radius'
      : 'verified_site_within_selected_radius',
  });
}

export function diffusionSnapshot({
  diffusionId,
  needId,
  createdAt,
  populationCount,
  criteriaSnapshot = null,
  targetingStatus = null,
}) {
  return canonicalSnapshot({
    diffusionId,
    needId,
    createdAt,
    populationCount,
    criteriaSnapshot: criteriaSnapshot ?? currentCriteriaSnapshot(targetingStatus),
    ...(targetingStatus === null ? {} : {targetingStatus}),
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
    ...(value.targetingStatus === undefined
      ? {} : {targetingStatus: value.targetingStatus}),
  };
}

export function deserializeDiffusionSnapshot({id, data}) {
  requireIdentifier(id, 'diffusionId');
  requireSnapshotFields(data, 'Document Snapshot invalide.');
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
  targetingStatus = null,
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
      targetingStatus,
    }),
  });
}

function canonicalSnapshot(value) {
  requireSnapshotFields(value, 'Snapshot invalide.');
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
  if ('targetingStatus' in value
    && !TARGETING_STATUSES.has(value.targetingStatus)) {
    throw new DiffusionSnapshotError(
      'invalid-diffusion-snapshot', 'État de ciblage invalide.');
  }
  return Object.freeze({
    diffusionId: value.diffusionId,
    needId: value.needId,
    createdAt: value.createdAt,
    populationCount: value.populationCount,
    criteriaSnapshot,
    ...('targetingStatus' in value
      ? {targetingStatus: value.targetingStatus} : {}),
  });
}

function requireSnapshotFields(value, message) {
  if (!isPlainObject(value)
    || SNAPSHOT_FIELDS.some((field) => !Object.hasOwn(value, field))
    || Object.keys(value).some((field) =>
      !SNAPSHOT_FIELDS.includes(field) && field !== 'targetingStatus')) {
    throw new DiffusionSnapshotError('invalid-diffusion-snapshot', message);
  }
}

function canonicalCriteria(value) {
  const isCurrent = isPlainObject(value)
    && Object.keys(value).length === CURRENT_CRITERIA_FIELDS.length;
  requireExactFields(value,
    isCurrent ? CURRENT_CRITERIA_FIELDS : CRITERIA_FIELDS,
    'criteriaSnapshot invalide.');
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
  if (isCurrent && (value.action !== 'active_operational'
    || value.identity !== 'verified_rpps'
    || value.admission !== 'operation_scoped_when_invitation_only'
    || !['verified_site_within_selected_radius',
      'verified_site_legacy_opt_in_or_selected_radius'].includes(value.geography))) {
    throw new DiffusionSnapshotError(
      'invalid-diffusion-snapshot', 'Critères de ciblage invalides.');
  }
  const current = currentCriteriaSnapshot(value.geography ===
    'verified_site_legacy_opt_in_or_selected_radius'
    ? 'TARGETING_TRANSITION_LEGACY' : null);
  if (isCurrent) return current;
  return Object.freeze(Object.fromEntries(
    CRITERIA_FIELDS.map((field) => [field, current[field]])));
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
    ...('action' in value ? {
      action: value.action,
      identity: value.identity,
      admission: value.admission,
      geography: value.geography,
    } : {}),
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
