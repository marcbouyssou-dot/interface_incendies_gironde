import {isCanonicalBlankText} from './responsible_access.js';

const ACTIONS = new Set(['create', 'update', 'setActive', 'delete']);
const GROUPS = new Set([
  'bordeauxMetropole',
  'northBasin',
  'southBasin',
  'medoc',
  'southGironde',
  'libournais',
  'hauteGironde',
  'partnerSites',
]);
const TYPES = new Set([
  'sdisStation',
  'interventionSector',
  'civilianReceptionSite',
  'redCross',
  'otherPartnerSite',
]);
const EDITABLE_FIELDS = Object.freeze([
  'name',
  'group',
  'type',
  'addressLine1',
  'addressLine2',
  'postalCode',
  'city',
  'country',
  'contactName',
  'contactPhone',
  'latitude',
  'longitude',
]);
const LOCATION_ID_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

export class LocationAdministrationError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'LocationAdministrationError';
    this.code = code;
  }
}

export async function manageLocation({callerUid, data, services}) {
  requireCaller(callerUid);
  const request = validateLocationManagementRequest(data);
  return services.commitLocationManagement({callerUid, ...request});
}

export async function listAdminLocations({callerUid, services}) {
  requireCaller(callerUid);
  const locations = await services.listAdminLocations({callerUid});
  return {locations};
}

export function validateLocationManagementRequest(data) {
  if (!isPlainObject(data) || !ACTIONS.has(data.action)) {
    throw invalidArgument();
  }
  const expected = data.action === 'delete'
    ? ['action', 'locationId']
    : ['action', 'locationId', 'data'];
  if (!hasExactlyKeys(data, expected)) throw invalidArgument();
  const locationId = validateLocationId(data.locationId);
  if (data.action === 'delete') {
    return Object.freeze({action: data.action, locationId});
  }
  if (data.action === 'setActive') {
    if (
      !isPlainObject(data.data)
      || !hasExactlyKeys(data.data, ['active'])
      || typeof data.data.active !== 'boolean'
    ) {
      throw invalidArgument();
    }
    return Object.freeze({
      action: data.action,
      locationId,
      data: Object.freeze({active: data.data.active}),
    });
  }
  return Object.freeze({
    action: data.action,
    locationId,
    data: validateLocationData(data.data),
  });
}

export function locationManagementMutation({
  action,
  locationId,
  data,
  current,
  used = false,
}) {
  if (action === 'create') {
    if (current !== null) {
      throw new LocationAdministrationError(
        'already-exists',
        'Cet identifiant de lieu existe déjà.',
      );
    }
    const fields = locationWriteFields(data);
    return Object.freeze({
      kind: 'create',
      fields: Object.freeze({
        id: locationId,
        ...fields,
        active: true,
        activeNeeds: 0,
        isOperational: true,
        addressStatus: fields.fullAddress === null
          ? 'not_found'
          : 'needs_confirmation',
      }),
    });
  }
  if (current === null) {
    throw new LocationAdministrationError(
      'not-found',
      'Lieu introuvable.',
    );
  }
  if (action === 'update') {
    return Object.freeze({
      kind: 'update',
      fields: locationWriteFields(data),
    });
  }
  if (action === 'setActive') {
    return Object.freeze({
      kind: 'update',
      fields: Object.freeze({active: data.active}),
    });
  }
  if (action === 'delete') {
    if (used) {
      throw new LocationAdministrationError(
        'failed-precondition',
        'Ce lieu est encore utilisé et ne peut pas être supprimé. '
          + 'Vous pouvez le désactiver.',
      );
    }
    return Object.freeze({kind: 'delete'});
  }
  throw invalidArgument();
}

export function adminLocationRecord(id, data, {used = false} = {}) {
  const addressLine1 = optionalStoredText(data.addressLine1)
    ?? optionalStoredText(data.address);
  return Object.freeze({
    id,
    name: optionalStoredText(data.name) ?? 'À renseigner',
    group: GROUPS.has(data.group)
      ? data.group
      : GROUPS.has(data.territorialGroup)
      ? data.territorialGroup
      : 'partnerSites',
    type: TYPES.has(data.type) ? data.type : 'otherPartnerSite',
    addressLine1,
    addressLine2: optionalStoredText(data.addressLine2),
    postalCode: optionalStoredText(data.postalCode),
    city: optionalStoredText(data.city),
    country: optionalStoredText(data.country) ?? 'France',
    contactName: optionalStoredText(data.contactName),
    contactPhone: optionalStoredText(data.contactPhone),
    latitude: finiteNumberOrNull(data.latitude),
    longitude: finiteNumberOrNull(data.longitude),
    active: typeof data.active === 'boolean' ? data.active : true,
    isOperational: typeof data.isOperational === 'boolean'
      ? data.isOperational
      : true,
    canDelete: !used,
  });
}

function validateLocationData(data) {
  if (!isPlainObject(data) || !hasExactlyKeys(data, EDITABLE_FIELDS)) {
    throw invalidArgument();
  }
  const name = requiredText(data.name, 160);
  if (!GROUPS.has(data.group) || !TYPES.has(data.type)) {
    throw invalidArgument();
  }
  const addressLine1 = optionalText(data.addressLine1, 240);
  const addressLine2 = optionalText(data.addressLine2, 240);
  const postalCode = optionalText(data.postalCode, 20);
  const city = optionalText(data.city, 120);
  const country = requiredText(data.country, 80);
  const contactName = optionalText(data.contactName, 160);
  const contactPhone = optionalText(data.contactPhone, 40);
  const latitude = optionalCoordinate(data.latitude, -90, 90);
  const longitude = optionalCoordinate(data.longitude, -180, 180);
  if ((latitude === null) !== (longitude === null)) throw invalidArgument();
  return Object.freeze({
    name,
    group: data.group,
    type: data.type,
    addressLine1,
    addressLine2,
    postalCode,
    city,
    country,
    contactName,
    contactPhone,
    latitude,
    longitude,
  });
}

function locationWriteFields(data) {
  const hasAddress = [
    data.addressLine1,
    data.addressLine2,
    data.postalCode,
    data.city,
  ].some(Boolean);
  const fullAddress = hasAddress
    ? [
      data.addressLine1,
      data.addressLine2,
      [data.postalCode, data.city].filter(Boolean).join(' '),
      data.country,
    ].filter(Boolean).join(', ')
    : null;
  return Object.freeze({
    name: data.name,
    group: data.group,
    type: data.type,
    addressLine1: data.addressLine1,
    addressLine2: data.addressLine2,
    postalCode: data.postalCode,
    city: data.city,
    country: data.country,
    contactName: data.contactName,
    contactPhone: data.contactPhone,
    latitude: data.latitude,
    longitude: data.longitude,
    address: fullAddress,
    fullAddress,
  });
}

function validateLocationId(value) {
  if (
    typeof value !== 'string'
    || value.length > 120
    || !LOCATION_ID_PATTERN.test(value)
  ) {
    throw invalidArgument();
  }
  return value;
}

function requiredText(value, maxLength) {
  if (
    typeof value !== 'string'
    || value.length > maxLength
    || isCanonicalBlankText(value)
  ) {
    throw invalidArgument();
  }
  return value.trim();
}

function optionalText(value, maxLength) {
  if (value === null) return null;
  if (typeof value !== 'string' || value.length > maxLength) {
    throw invalidArgument();
  }
  return isCanonicalBlankText(value) ? null : value.trim();
}

function optionalCoordinate(value, minimum, maximum) {
  if (value === null) return null;
  if (
    typeof value !== 'number'
    || !Number.isFinite(value)
    || value < minimum
    || value > maximum
  ) {
    throw invalidArgument();
  }
  return value;
}

function finiteNumberOrNull(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function optionalStoredText(value) {
  return typeof value === 'string' && value.trim() !== '' ? value : null;
}

function requireCaller(callerUid) {
  if (typeof callerUid !== 'string' || callerUid === '') {
    throw new LocationAdministrationError(
      'unauthenticated',
      'Authentification requise.',
    );
  }
}

function invalidArgument() {
  return new LocationAdministrationError(
    'invalid-argument',
    'La demande de gestion du lieu est invalide.',
  );
}

function hasExactlyKeys(value, expected) {
  const keys = Object.keys(value).sort();
  const sortedExpected = [...expected].sort();
  return keys.length === sortedExpected.length
    && sortedExpected.every((key, index) => key === keys[index]);
}

function isPlainObject(value) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}
