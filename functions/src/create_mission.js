import {createHash} from 'node:crypto';

import {parseResponsibleAccess} from './responsible_access.js';
import {operationAllowsOperationalMutation} from './operation_activity.js';
import {globalMissionEquipmentLabels, normalizeMissionEquipment} from './mission_equipment.js';
import {normalizeSiteEquipment, SiteEquipmentError} from './site_equipment.js';
import {
  MissionUpdateError as MissionWriteError,
  hasExactlyKeys,
  isPlainObject,
  optionalText,
  requiredPriority,
  requiredStoredText,
  requiredText,
  timestampMillis,
  validateRequiredQuotas,
} from './update_mission.js';

const REQUEST_KEYS = Object.freeze([
  'mobilizationId', 'locationId', 'startAtMillis', 'endAtMillis',
  'requiredByProfession', 'priority', 'requestedEquipmentByProfession',
  'details', 'idempotencyKey',
]);

export function validateMissionCreateRequest(data) {
  if (!isPlainObject(data) || !hasExactlyKeys(data, REQUEST_KEYS)) {
    throw invalidArgument();
  }
  const mobilizationId = requiredText(data.mobilizationId, 160);
  const locationId = requiredText(data.locationId, 160);
  if (mobilizationId.includes('/') || locationId.includes('/')) {
    throw invalidArgument();
  }
  const startAtMillis = timestampMillis(data.startAtMillis);
  const endAtMillis = timestampMillis(data.endAtMillis);
  if (endAtMillis <= startAtMillis) throw invalidArgument();
  const requiredByProfession = validateRequiredQuotas(data.requiredByProfession);
  let equipmentByProfession;
  try {
    equipmentByProfession = normalizeMissionEquipment(
      data.requestedEquipmentByProfession,
      requiredByProfession,
    );
  } catch {
    throw invalidArgument();
  }
  const idempotencyKey = data.idempotencyKey;
  if (typeof idempotencyKey !== 'string'
      || !/^[A-Za-z0-9_-]{16,128}$/.test(idempotencyKey)) {
    throw invalidArgument();
  }
  return Object.freeze({
    mobilizationId,
    locationId,
    startAtMillis,
    endAtMillis,
    requiredByProfession,
    priority: requiredPriority(data.priority),
    equipmentByProfession,
    details: optionalText(data.details, 2000),
    idempotencyKey,
  });
}

export function missionCreateId(callerUid, idempotencyKey) {
  return `created_${createHash('sha256')
    .update(JSON.stringify([callerUid, idempotencyKey]))
    .digest('hex')}`;
}

export function missionCreateRequestHash(request) {
  const {idempotencyKey: ignored, ...businessFields} = request;
  return createHash('sha256').update(JSON.stringify(businessFields)).digest('hex');
}

export async function createMission({callerUid, data, services}) {
  if (typeof callerUid !== 'string' || callerUid === '') {
    throw new MissionWriteError('unauthenticated', 'Authentification responsable requise.');
  }
  const request = validateMissionCreateRequest(data);
  return services.commitMissionCreate({callerUid, request});
}

export function missionCreateMutation({
  callerUid,
  missionId,
  request,
  callerRole,
  coordinatorAuthorized,
  organizationAuthorized,
  mobilization,
  operation = null,
  location,
  serverTimestamp,
  timestampFromMillis,
}) {
  if (!isPlainObject(mobilization)
      || mobilization.id !== request.mobilizationId
      || mobilization.status !== 'active'
      || !operationAllowsOperationalMutation(mobilization, operation)) {
    throw new MissionWriteError('failed-precondition', 'Mobilisation inactive.');
  }
  let access;
  try {
    access = parseResponsibleAccess(callerRole);
  } catch {
    throw outsideScope();
  }
  if (!access.active || organizationAuthorized !== true
      || !(access.roles.includes('coordinator') && coordinatorAuthorized === true)
        && !(access.roles.includes('site_manager')
          && access.locationIds.includes(request.locationId))) {
    throw outsideScope();
  }
  if (!isPlainObject(location)
      || location.active === false
      || location.isOperational === false) {
    throw new MissionWriteError('failed-precondition', 'Le lieu sélectionné est inactif.');
  }
  let siteEquipment;
  if (Object.hasOwn(location, 'availableEquipment')) {
    try {
      siteEquipment = normalizeSiteEquipment(location.availableEquipment);
    } catch (error) {
      if (error instanceof SiteEquipmentError) {
        throw new MissionWriteError('failed-precondition', 'Matériel du site invalide.');
      }
      throw error;
    }
  }
  const registeredByProfession = Object.fromEntries(
    Object.keys(request.requiredByProfession).map((profession) => [profession, 0]),
  );
  const fields = Object.freeze({
    id: missionId,
    mobilizationId: request.mobilizationId,
    locationId: request.locationId,
    locationName: requiredStoredText(location.name, 'Lieu invalide.'),
    territorialGroup: requiredStoredText(
      location.group ?? location.territorialGroup, 'Lieu invalide.'),
    startAt: timestampFromMillis(request.startAtMillis),
    endAt: timestampFromMillis(request.endAtMillis),
    requiredByProfession: {...request.requiredByProfession},
    registeredByProfession,
    requiredMk: request.requiredByProfession.physiotherapist,
    requiredPp: request.requiredByProfession.podiatrist,
    registeredMk: 0,
    registeredPp: 0,
    requestedEquipmentByProfession: request.equipmentByProfession,
    ...(siteEquipment === undefined ? {} : {availableEquipmentOnSite: siteEquipment}),
    requestedEquipment: globalMissionEquipmentLabels(request.equipmentByProfession),
    priority: request.priority,
    details: request.details,
    status: 'critical',
    isActive: true,
    createdBy: callerUid,
    createdAt: serverTimestamp,
    updatedAt: serverTimestamp,
    creationRequestHash: missionCreateRequestHash(request),
  });
  return Object.freeze({fields});
}

function invalidArgument() {
  return new MissionWriteError('invalid-argument', 'Les informations de la mission sont invalides.');
}

function outsideScope() {
  return new MissionWriteError('permission-denied', 'Vous ne pouvez publier que pour vos centres.');
}
