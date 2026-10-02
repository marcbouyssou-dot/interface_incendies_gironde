import {parseResponsibleAccess} from './responsible_access.js';
import {SITE_EQUIPMENT_IDS} from './mission_equipment.js';
import {hasExactlyKeys, isPlainObject} from './update_mission.js';

export class SiteEquipmentError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'SiteEquipmentError';
    this.code = code;
  }
}

export function normalizeSiteEquipment(raw) {
  if (!Array.isArray(raw) || raw.length > 100 ||
      raw.some((id) => typeof id !== 'string' ||
        !SITE_EQUIPMENT_IDS.includes(id))) {
    throw new SiteEquipmentError('invalid-argument', 'Matériel du site invalide.');
  }
  const selected = new Set(raw);
  return SITE_EQUIPMENT_IDS.filter((id) => selected.has(id));
}

export function validateSiteEquipmentRequest(data) {
  if (!isPlainObject(data) || !hasExactlyKeys(data, [
    'locationId', 'availableEquipment',
  ]) || typeof data.locationId !== 'string' ||
      !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(data.locationId) ||
      data.locationId.length > 120) {
    throw new SiteEquipmentError('invalid-argument', 'Lieu invalide.');
  }
  return Object.freeze({
    locationId: data.locationId,
    availableEquipment: normalizeSiteEquipment(data.availableEquipment),
  });
}

export function siteEquipmentMutation({request, role, location}) {
  let access;
  try {
    access = parseResponsibleAccess(role);
  } catch {
    throw new SiteEquipmentError('permission-denied', 'Accès au lieu refusé.');
  }
  if (!access.active || !(access.roles.includes('coordinator') ||
      access.roles.includes('site_manager') &&
      access.locationIds.includes(request.locationId))) {
    throw new SiteEquipmentError('permission-denied', 'Accès au lieu refusé.');
  }
  if (!isPlainObject(location)) {
    throw new SiteEquipmentError('not-found', 'Lieu introuvable.');
  }
  if (location.active === false || location.isOperational === false) {
    throw new SiteEquipmentError('failed-precondition', 'Lieu inactif.');
  }
  return Object.freeze({availableEquipment: request.availableEquipment});
}

export async function updateSiteEquipment({callerUid, data, services}) {
  if (typeof callerUid !== 'string' || callerUid === '') {
    throw new SiteEquipmentError('unauthenticated', 'Authentification requise.');
  }
  const request = validateSiteEquipmentRequest(data);
  return services.commitSiteEquipment({callerUid, request});
}
