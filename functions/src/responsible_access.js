const COORDINATOR = 'coordinator';
const SITE_MANAGER = 'site_manager';
const CANONICAL_ROLES = Object.freeze([COORDINATOR, SITE_MANAGER]);
const MAX_LOCATION_IDS = 65;
const RULES_LIST_SEPARATOR = '\u001f';
const BLANK_LOCATION_ID_PATTERN =
  /^[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]*$/u;

export function isCanonicalBlankText(value) {
  return typeof value === 'string' && BLANK_LOCATION_ID_PATTERN.test(value);
}

export class ResponsibleAccessError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ResponsibleAccessError';
    this.code = code;
  }
}

export function parseResponsibleAccess(document) {
  if (!isPlainObject(document)) throw malformedRole();
  const active = document.active;
  if (typeof active !== 'boolean') throw malformedRole();
  return Object.hasOwn(document, 'roles')
    ? parseV2(document, active)
    : parseLegacy(document, active);
}

export function normalizeRequestedAssignment({role, locationIds} = {}) {
  if (!CANONICAL_ROLES.includes(role)) {
    throw new ResponsibleAccessError(
      'invalid-assignment',
      'Le rôle demandé est invalide.',
    );
  }
  const normalizedLocations = normalizeLocationIds(
    locationIds,
    invalidAssignment,
  );
  if (
    (role === COORDINATOR && normalizedLocations.length !== 0)
    || (role === SITE_MANAGER && normalizedLocations.length === 0)
  ) {
    throw new ResponsibleAccessError(
      'invalid-assignment',
      'Le périmètre demandé est incohérent.',
    );
  }
  return immutableAccess({roles: [role], locationIds: normalizedLocations});
}

export function mergeResponsibleAccess(existingDocument, assignment) {
  const requested = normalizeRequestedAssignment(assignment);
  const existing = existingDocument === null || existingDocument === undefined
    ? null
    : parseResponsibleAccess(existingDocument);
  if (existing?.active === false) {
    throw new ResponsibleAccessError(
      'inactive-role',
      'Le compte responsable existant est inactif.',
    );
  }
  const roleSet = new Set([
    ...(existing?.roles ?? []),
    ...requested.roles,
  ]);
  const roles = CANONICAL_ROLES.filter((role) => roleSet.has(role));
  const locations = new Set([
    ...(existing?.locationIds ?? []),
    ...requested.locationIds,
  ]);
  const locationIds = [...locations].sort();
  if (locationIds.length > MAX_LOCATION_IDS) {
    throw locationLimitExceeded();
  }
  const role = roles.includes(COORDINATOR) ? COORDINATOR : SITE_MANAGER;
  return Object.freeze({
    role,
    roles: Object.freeze(roles),
    locationIds: Object.freeze(locationIds),
    active: true,
    schemaVersion: 2,
  });
}

export function hasActiveCoordinatorRole(document) {
  try {
    const access = parseResponsibleAccess(document);
    return access.active && access.roles.includes(COORDINATOR);
  } catch {
    return false;
  }
}

function parseLegacy(document, active) {
  if (Object.hasOwn(document, 'schemaVersion')) throw malformedRole();
  if (!CANONICAL_ROLES.includes(document.role)) throw malformedRole();
  const hasLocations = Object.hasOwn(document, 'locationIds');
  const rawLocations = hasLocations ? document.locationIds : [];
  if (document.role === COORDINATOR) {
    const legacyWildcard = Array.isArray(rawLocations)
      && rawLocations.length === 1
      && rawLocations[0] === '*';
    const emptyScope = Array.isArray(rawLocations)
      && rawLocations.length === 0;
    if (!legacyWildcard && !emptyScope) throw malformedRole();
    return immutableAccess({
      roles: [COORDINATOR],
      locationIds: [],
      active,
      schemaVersion: 1,
    });
  }
  const locationIds = normalizeLocationIds(rawLocations);
  if (locationIds.length === 0) throw malformedRole();
  return immutableAccess({
    roles: [SITE_MANAGER],
    locationIds,
    active,
    schemaVersion: 1,
  });
}

function parseV2(document, active) {
  if (!Number.isInteger(document.schemaVersion)
    || document.schemaVersion !== 2) {
    throw malformedRole();
  }
  const roles = document.roles;
  if (!Array.isArray(roles) || !isCanonicalRoleList(roles)) {
    throw malformedRole();
  }
  if (!Object.hasOwn(document, 'locationIds')) throw malformedRole();
  const locationIds = normalizeLocationIds(document.locationIds);
  const expectedProjection = roles.includes(COORDINATOR)
    ? COORDINATOR
    : SITE_MANAGER;
  if (document.role !== expectedProjection) throw malformedRole();
  const containsSiteManager = roles.includes(SITE_MANAGER);
  if (
    (containsSiteManager && locationIds.length === 0)
    || (!containsSiteManager && locationIds.length !== 0)
  ) {
    throw malformedRole();
  }
  return immutableAccess({roles, locationIds, active, schemaVersion: 2});
}

function normalizeLocationIds(value, errorFactory = malformedRole) {
  if (!Array.isArray(value) || value.length > MAX_LOCATION_IDS) {
    throw errorFactory();
  }
  if (value.some((item) =>
    typeof item !== 'string'
    || isCanonicalBlankText(item)
    || item === '*'
    || item.includes(RULES_LIST_SEPARATOR))) {
    throw errorFactory();
  }
  const unique = new Set(value);
  if (unique.size !== value.length) throw errorFactory();
  return [...unique].sort();
}

function isCanonicalRoleList(value) {
  return (
    value.length === 1
    && (value[0] === COORDINATOR || value[0] === SITE_MANAGER)
  ) || (
    value.length === 2
    && value[0] === COORDINATOR
    && value[1] === SITE_MANAGER
  );
}

function immutableAccess({roles, locationIds, active = true, schemaVersion}) {
  const role = roles.includes(COORDINATOR) ? COORDINATOR : SITE_MANAGER;
  return Object.freeze({
    role,
    roles: Object.freeze([...roles]),
    locationIds: Object.freeze([...locationIds]),
    active,
    schemaVersion,
  });
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function malformedRole() {
  return new ResponsibleAccessError(
    'malformed-role',
    'Le document de rôle existant est invalide.',
  );
}

function invalidAssignment() {
  return new ResponsibleAccessError(
    'invalid-assignment',
    'Le périmètre demandé est invalide.',
  );
}

function locationLimitExceeded() {
  return new ResponsibleAccessError(
    'responsible-access-location-limit-exceeded',
    'Le nombre maximal de centres autorisés est dépassé.',
  );
}
