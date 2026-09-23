import {createHash} from 'node:crypto';

export const DIFFUSION_COLLECTION = 'diffusions';
export const DIFFUSION_STATUSES = Object.freeze(['READY', 'CANCELLED']);

const DIFFUSION_FIELDS = Object.freeze([
  'id',
  'needId',
  'organizationId',
  'mobilizationId',
  'createdBy',
  'createdAt',
  'status',
]);

export class DiffusionError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'DiffusionError';
    this.code = code;
  }
}

export function diffusionIdForNeed(needId) {
  requireIdentifier(needId, 'needId');
  return createHash('sha256')
    .update(`diffusion:${needId}`)
    .digest('hex');
}

export function readyDiffusion({
  needId,
  organizationId,
  mobilizationId,
  createdBy,
  createdAt,
}) {
  return canonicalDiffusion({
    id: diffusionIdForNeed(needId),
    needId,
    organizationId,
    mobilizationId,
    createdBy,
    createdAt,
    status: 'READY',
  });
}

export function serializeDiffusion(diffusion) {
  const value = canonicalDiffusion(diffusion);
  return {
    id: value.id,
    needId: value.needId,
    organizationId: value.organizationId,
    mobilizationId: value.mobilizationId,
    createdBy: value.createdBy,
    createdAt: value.createdAt,
    status: value.status,
  };
}

export function deserializeDiffusion({id, data}) {
  requireIdentifier(id, 'id');
  if (!isPlainObject(data)
      || Object.keys(data).length !== DIFFUSION_FIELDS.length
      || DIFFUSION_FIELDS.some((field) => !Object.hasOwn(data, field))) {
    throw new DiffusionError(
      'invalid-diffusion',
      'Document Diffusion invalide.',
    );
  }
  if (data.id !== id) {
    throw new DiffusionError(
      'invalid-diffusion',
      'Identifiant Diffusion incohérent.',
    );
  }
  return canonicalDiffusion(data);
}

export async function ensureDiffusion({firestore, diffusion}) {
  const serialized = serializeDiffusion(diffusion);
  const reference = firestore
    .collection(DIFFUSION_COLLECTION)
    .doc(serialized.id);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    if (snapshot.exists) {
      const current = deserializeDiffusion({
        id: reference.id,
        data: snapshot.data(),
      });
      if (!sameDiffusion(current, serialized)) {
        throw new DiffusionError(
          'diffusion-conflict',
          'Une autre Diffusion existe déjà pour ce Besoin.',
        );
      }
      return Object.freeze({created: false, diffusion: current});
    }
    transaction.create(reference, serialized);
    return Object.freeze({
      created: true,
      diffusion: canonicalDiffusion(serialized),
    });
  });
}

function canonicalDiffusion(value) {
  if (!isPlainObject(value)) {
    throw new DiffusionError('invalid-diffusion', 'Diffusion invalide.');
  }
  requireIdentifier(value.id, 'id');
  requireIdentifier(value.needId, 'needId');
  requireIdentifier(value.organizationId, 'organizationId');
  requireIdentifier(value.mobilizationId, 'mobilizationId');
  requireIdentifier(value.createdBy, 'createdBy');
  requireTimestamp(value.createdAt, 'createdAt');
  if (!DIFFUSION_STATUSES.includes(value.status)) {
    throw new DiffusionError(
      'invalid-diffusion-status',
      'Statut Diffusion invalide.',
    );
  }
  if (value.id !== diffusionIdForNeed(value.needId)) {
    throw new DiffusionError(
      'invalid-diffusion',
      'La Diffusion ne correspond pas au Besoin.',
    );
  }
  return Object.freeze({
    id: value.id,
    needId: value.needId,
    organizationId: value.organizationId,
    mobilizationId: value.mobilizationId,
    createdBy: value.createdBy,
    createdAt: value.createdAt,
    status: value.status,
  });
}

function sameDiffusion(left, right) {
  return left.id === right.id
    && left.needId === right.needId
    && left.organizationId === right.organizationId
    && left.mobilizationId === right.mobilizationId
    && left.createdBy === right.createdBy
    && timestampMillis(left.createdAt) === timestampMillis(right.createdAt)
    && left.status === right.status;
}

function timestampMillis(value) {
  if (value instanceof Date) return value.getTime();
  if (typeof value?.toMillis === 'function') return value.toMillis();
  if (typeof value?.toDate === 'function') return value.toDate().getTime();
  return Number.NaN;
}

function requireIdentifier(value, field) {
  if (typeof value !== 'string'
      || value.length === 0
      || value.length > 180
      || value.trim() !== value
      || value.includes('/')) {
    throw new DiffusionError(
      'invalid-diffusion',
      `${field} invalide.`,
    );
  }
}

function requireTimestamp(value, field) {
  if (!(value instanceof Date)
      && typeof value?.toMillis !== 'function'
      && typeof value?.toDate !== 'function') {
    throw new DiffusionError(
      'invalid-diffusion',
      `${field} invalide.`,
    );
  }
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
