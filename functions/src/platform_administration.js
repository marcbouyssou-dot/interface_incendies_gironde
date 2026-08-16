const CONTEXT_TYPES = new Set([
  'fire',
  'flood',
  'heatwave',
  'event',
  'white_plan',
  'other',
]);
const MOBILIZATION_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const OPERATION_TYPES = new Set([
  'emergency',
  'health_crisis',
  'natural_disaster',
  'event',
  'prevention',
  'exercise',
  'humanitarian',
  'other',
]);
const OPERATION_STATUSES = new Set([
  'draft', 'planned', 'active', 'suspended', 'completed', 'archived',
]);
const MOBILIZATION_REQUIRED_FIELDS = Object.freeze([
  'mobilizationId',
  'territoryId',
  'name',
  'subtitle',
  'contextType',
]);
const MOBILIZATION_OPTIONAL_FIELDS = Object.freeze([
  'operationId',
  'scopeRefs',
]);
const ID_FIELDS = Object.freeze(['mobilizationId']);
const ASSIGNMENT_FIELDS = Object.freeze(['mobilizationId', 'uid']);
const OPERATION_FIELDS = Object.freeze([
  'operationId', 'name', 'type', 'context', 'startAtMillis', 'endAtMillis',
  'scopeRefs',
]);
const OPERATION_TRANSITION_FIELDS = Object.freeze([
  'operationId', 'targetStatus',
]);

export class PlatformAdministrationError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'PlatformAdministrationError';
    this.code = code;
  }
}

export async function isPlatformAdministrator(uid, {getAdministrator}) {
  if (
    typeof uid !== 'string'
    || uid === ''
    || typeof getAdministrator !== 'function'
  ) {
    return false;
  }
  const administrator = await getAdministrator(uid);
  return isPlainObject(administrator) && administrator.active === true;
}

export async function createMobilization({callerUid, data, services}) {
  requireCaller(callerUid);
  requireServices(services, 'createMobilization');
  return services.createMobilization({
    callerUid,
    ...validateMobilizationPayload(data),
  });
}

export async function updateMobilization({callerUid, data, services}) {
  requireCaller(callerUid);
  requireServices(services, 'updateMobilization');
  return services.updateMobilization({
    callerUid,
    ...validateMobilizationPayload(data),
  });
}

export async function createOperation({callerUid, data, services}) {
  requireCaller(callerUid);
  requireServices(services, 'createOperation');
  return services.createOperation({
    callerUid,
    ...validateOperationPayload(data),
  });
}

export async function updateOperation({callerUid, data, services}) {
  requireCaller(callerUid);
  requireServices(services, 'updateOperation');
  return services.updateOperation({
    callerUid,
    ...validateOperationPayload(data),
  });
}

export async function transitionOperation({callerUid, data, services}) {
  requireCaller(callerUid);
  requireServices(services, 'transitionOperation');
  if (!isPlainObject(data) || !hasExactlyKeys(
    data,
    OPERATION_TRANSITION_FIELDS,
  )) {
    throw invalidArgument();
  }
  if (!OPERATION_STATUSES.has(data.targetStatus)) throw invalidArgument();
  return services.transitionOperation({
    callerUid,
    operationId: validateDocumentId(data.operationId),
    targetStatus: data.targetStatus,
  });
}

export async function activateMobilization({callerUid, data, services}) {
  return lifecycleRequest({
    callerUid,
    data,
    services,
    operation: 'activateMobilization',
  });
}

export async function deactivateMobilization({callerUid, data, services}) {
  return lifecycleRequest({
    callerUid,
    data,
    services,
    operation: 'deactivateMobilization',
  });
}

export async function archiveMobilization({callerUid, data, services}) {
  return lifecycleRequest({
    callerUid,
    data,
    services,
    operation: 'archiveMobilization',
  });
}

export async function assignMobilizationCoordinator({
  callerUid,
  data,
  services,
}) {
  return assignmentRequest({
    callerUid,
    data,
    services,
    operation: 'assignMobilizationCoordinator',
  });
}

export async function removeMobilizationCoordinator({
  callerUid,
  data,
  services,
}) {
  return assignmentRequest({
    callerUid,
    data,
    services,
    operation: 'removeMobilizationCoordinator',
  });
}

async function lifecycleRequest({callerUid, data, services, operation}) {
  requireCaller(callerUid);
  requireServices(services, operation);
  if (!isPlainObject(data) || !hasExactlyKeys(data, ID_FIELDS)) {
    throw invalidArgument();
  }
  return services[operation]({
    callerUid,
    mobilizationId: validateDocumentId(data.mobilizationId),
  });
}

async function assignmentRequest({callerUid, data, services, operation}) {
  requireCaller(callerUid);
  requireServices(services, operation);
  if (!isPlainObject(data) || !hasExactlyKeys(data, ASSIGNMENT_FIELDS)) {
    throw invalidArgument();
  }
  return services[operation]({
    callerUid,
    mobilizationId: validateDocumentId(data.mobilizationId),
    uid: validateUid(data.uid),
  });
}

function validateMobilizationPayload(data) {
  if (
    !isPlainObject(data)
    || !hasRequiredAndOnlyKeys(
      data,
      MOBILIZATION_REQUIRED_FIELDS,
      MOBILIZATION_OPTIONAL_FIELDS,
    )
  ) {
    throw invalidArgument();
  }
  if (!CONTEXT_TYPES.has(data.contextType)) throw invalidArgument();
  const result = {
    mobilizationId: validateDocumentId(data.mobilizationId),
    territoryId: validateDocumentId(data.territoryId),
    name: requiredText(data.name, 160),
    subtitle: requiredText(data.subtitle, 240),
    contextType: data.contextType,
  };
  if (Object.hasOwn(data, 'operationId')) {
    result.operationId = validateDocumentId(data.operationId);
  }
  if (Object.hasOwn(data, 'scopeRefs')) {
    result.scopeRefs = validateScopeRefs(data.scopeRefs);
  }
  return Object.freeze(result);
}

function validateOperationPayload(data) {
  if (!isPlainObject(data) || !hasExactlyKeys(data, OPERATION_FIELDS)) {
    throw invalidArgument();
  }
  if (!OPERATION_TYPES.has(data.type)) throw invalidArgument();
  const startAtMillis = timestampMillis(data.startAtMillis);
  const endAtMillis = data.endAtMillis === null
    ? null
    : timestampMillis(data.endAtMillis);
  if (endAtMillis !== null && endAtMillis <= startAtMillis) {
    throw invalidArgument();
  }
  return Object.freeze({
    operationId: validateDocumentId(data.operationId),
    name: requiredText(data.name, 160),
    type: data.type,
    context: optionalText(data.context, 2000),
    startAtMillis,
    endAtMillis,
    scopeRefs: validateScopeRefs(data.scopeRefs),
  });
}

function validateScopeRefs(value) {
  if (!Array.isArray(value) || value.length > 65) throw invalidArgument();
  const refs = value.map((ref) => {
    if (
      typeof ref !== 'string'
      || ref.length > 180
      || ref.trim() !== ref
      || !/^(territories|locations)\/[^/]{1,160}$/.test(ref)
    ) {
      throw invalidArgument();
    }
    return ref;
  });
  if (new Set(refs).size !== refs.length) throw invalidArgument();
  return Object.freeze(refs);
}

function timestampMillis(value) {
  if (!Number.isSafeInteger(value) || value <= 0) throw invalidArgument();
  return value;
}

function optionalText(value, maximumLength) {
  if (value === null) return null;
  if (typeof value !== 'string' || value.length > maximumLength) {
    throw invalidArgument();
  }
  const result = value.trim();
  return result === '' ? null : result;
}

function validateDocumentId(value) {
  if (
    typeof value !== 'string'
    || value.length > 120
    || !MOBILIZATION_ID_PATTERN.test(value)
  ) {
    throw invalidArgument();
  }
  return value;
}

function validateUid(value) {
  if (
    typeof value !== 'string'
    || value.length === 0
    || value.length > 128
    || value.trim() !== value
    || value.includes('/')
  ) {
    throw invalidArgument();
  }
  return value;
}

function requiredText(value, maximumLength) {
  if (
    typeof value !== 'string'
    || value.length > maximumLength
    || value.trim() === ''
  ) {
    throw invalidArgument();
  }
  return value.trim();
}

function requireCaller(callerUid) {
  if (typeof callerUid !== 'string' || callerUid === '') {
    throw new PlatformAdministrationError(
      'unauthenticated',
      'Authentification requise.',
    );
  }
}

function requireServices(services, operation) {
  if (!services || typeof services[operation] !== 'function') {
    throw new PlatformAdministrationError(
      'internal',
      'Service d’administration plateforme indisponible.',
    );
  }
}

function hasExactlyKeys(value, expected) {
  const keys = Object.keys(value).sort();
  const sortedExpected = [...expected].sort();
  return keys.length === sortedExpected.length
    && sortedExpected.every((key, index) => key === keys[index]);
}

function hasRequiredAndOnlyKeys(value, required, optional) {
  const keys = Object.keys(value);
  const allowed = new Set([...required, ...optional]);
  return required.every((key) => Object.hasOwn(value, key))
    && keys.every((key) => allowed.has(key));
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function invalidArgument() {
  return new PlatformAdministrationError(
    'invalid-argument',
    'La demande d’administration plateforme est invalide.',
  );
}
