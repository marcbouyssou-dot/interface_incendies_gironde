const CONTEXT_TYPES = new Set([
  'fire',
  'flood',
  'heatwave',
  'event',
  'white_plan',
  'other',
]);
const MOBILIZATION_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const CREATE_FIELDS = Object.freeze([
  'mobilizationId',
  'territoryId',
  'name',
  'subtitle',
  'contextType',
]);
const UPDATE_FIELDS = Object.freeze(CREATE_FIELDS);
const ID_FIELDS = Object.freeze(['mobilizationId']);
const ASSIGNMENT_FIELDS = Object.freeze(['mobilizationId', 'uid']);

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
    ...validateMobilizationPayload(data, CREATE_FIELDS),
  });
}

export async function updateMobilization({callerUid, data, services}) {
  requireCaller(callerUid);
  requireServices(services, 'updateMobilization');
  return services.updateMobilization({
    callerUid,
    ...validateMobilizationPayload(data, UPDATE_FIELDS),
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

function validateMobilizationPayload(data, expectedFields) {
  if (!isPlainObject(data) || !hasExactlyKeys(data, expectedFields)) {
    throw invalidArgument();
  }
  if (!CONTEXT_TYPES.has(data.contextType)) throw invalidArgument();
  return Object.freeze({
    mobilizationId: validateDocumentId(data.mobilizationId),
    territoryId: validateDocumentId(data.territoryId),
    name: requiredText(data.name, 160),
    subtitle: requiredText(data.subtitle, 240),
    contextType: data.contextType,
  });
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

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function invalidArgument() {
  return new PlatformAdministrationError(
    'invalid-argument',
    'La demande d’administration plateforme est invalide.',
  );
}
