import {
  normalizeResponsibleAccessUpdate,
  parseResponsibleAccess,
  ResponsibleAccessError,
} from './responsible_access.js';

const UPDATE_FIELDS = Object.freeze([
  'targetUid',
  'roles',
  'locationIds',
  'active',
]);

export class ResponsibleAccessAdministrationError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResponsibleAccessAdministrationError';
    this.code = code;
  }
}

export async function updateResponsibleAccess({callerUid, data, services}) {
  requireCaller(callerUid);
  const request = validateUpdateRequest(data);
  if (request.targetUid === callerUid) {
    throw new ResponsibleAccessAdministrationError(
      'failed-precondition',
      'Votre propre accès doit être géré par un autre coordinateur.',
    );
  }
  return services.commitResponsibleAccessUpdate({callerUid, ...request});
}

export async function listResponsibleAccess({callerUid, services}) {
  requireCaller(callerUid);
  const accounts = await services.listResponsibleAccounts({callerUid});
  return {accounts};
}

export function validateUpdateRequest(data) {
  if (!isPlainObject(data) || !hasExactlyKeys(data, UPDATE_FIELDS)) {
    throw invalidArgument();
  }
  if (typeof data.targetUid !== 'string' || data.targetUid.trim() === '') {
    throw invalidArgument();
  }
  let access;
  try {
    access = normalizeResponsibleAccessUpdate(data);
  } catch (error) {
    if (error instanceof ResponsibleAccessError) throw invalidArgument();
    throw error;
  }
  return Object.freeze({
    targetUid: data.targetUid,
    role: access.role,
    roles: Object.freeze([...access.roles]),
    locationIds: Object.freeze([...access.locationIds]),
    active: access.active,
    schemaVersion: 2,
  });
}

export function safeResponsibleAccount(uid, document, identity = {}) {
  const access = parseResponsibleAccess(document);
  return {
    uid,
    displayName: optionalString(identity.displayName),
    email: optionalString(identity.email),
    role: access.role,
    roles: [...access.roles],
    locationIds: [...access.locationIds],
    active: access.active,
    schemaVersion: access.schemaVersion,
  };
}

function requireCaller(callerUid) {
  if (typeof callerUid !== 'string' || callerUid === '') {
    throw new ResponsibleAccessAdministrationError(
      'unauthenticated',
      'Authentification requise.',
    );
  }
}

function hasExactlyKeys(value, expected) {
  const keys = Object.keys(value).sort();
  return keys.length === expected.length
    && [...expected].sort().every((key, index) => key === keys[index]);
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function optionalString(value) {
  return typeof value === 'string' && value.trim() !== '' ? value : null;
}

function invalidArgument() {
  return new ResponsibleAccessAdministrationError(
    'invalid-argument',
    'La modification d’accès est invalide.',
  );
}
