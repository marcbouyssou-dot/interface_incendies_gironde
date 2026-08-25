import {isCanonicalBlankText, parseResponsibleAccess} from './responsible_access.js';

const PROFESSIONS = Object.freeze([
  'physiotherapist',
  'podiatrist',
  'physician',
  'nurse',
  'veterinarian',
  'other_health_professional',
]);
const PROFESSION_ALIASES = Object.freeze({
  physiotherapist: 'physiotherapist',
  mk: 'physiotherapist',
  podiatrist: 'podiatrist',
  pp: 'podiatrist',
  physician: 'physician',
  doctor: 'physician',
  nurse: 'nurse',
  veterinarian: 'veterinarian',
  other_health_professional: 'other_health_professional',
  otherHealthProfessional: 'other_health_professional',
});
const REQUEST_KEYS = Object.freeze([
  'missionId',
  'locationId',
  'startAtMillis',
  'endAtMillis',
  'requiredByProfession',
  'equipment',
  'details',
]);
const PRIORITIES = Object.freeze(['standard', 'priority', 'urgent', 'crisis']);

export class MissionUpdateError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'MissionUpdateError';
    this.code = code;
  }
}

export async function updateMission({callerUid, data, services}) {
  if (typeof callerUid !== 'string' || callerUid === '') {
    throw new MissionUpdateError(
      'unauthenticated',
      'Authentification responsable requise.',
    );
  }
  const request = validateMissionUpdateRequest(data);
  return services.commitMissionUpdate({callerUid, ...request});
}

export function validateMissionUpdateRequest(data) {
  if (!isPlainObject(data)
      || (!hasExactlyKeys(data, REQUEST_KEYS)
        && !hasExactlyKeys(data, [...REQUEST_KEYS, 'priority']))) {
    throw invalidArgument();
  }
  const missionId = requiredText(data.missionId, 200);
  const locationId = requiredText(data.locationId, 160);
  const startAtMillis = timestampMillis(data.startAtMillis);
  const endAtMillis = timestampMillis(data.endAtMillis);
  if (endAtMillis <= startAtMillis) throw invalidArgument();
  const requiredByProfession = validateRequiredQuotas(
    data.requiredByProfession,
  );
  const equipment = validateEquipment(data.equipment);
  const details = optionalText(data.details, 2000);
  const priority = data.priority === undefined
    ? null
    : requiredPriority(data.priority);
  return Object.freeze({
    missionId,
    locationId,
    startAtMillis,
    endAtMillis,
    requiredByProfession,
    equipment,
    details,
    ...(priority === null ? {} : {priority}),
  });
}

export function missionUpdateMutation({
  request,
  mission,
  mobilization,
  coordinatorAuthorized,
  destination,
  callerRole,
  engagements,
  serverTimestamp,
  timestampFromMillis,
  nowMillis = Date.now(),
}) {
  if (!isPlainObject(mission)) {
    throw new MissionUpdateError('not-found', 'Mission introuvable.');
  }
  if (
    typeof mission.mobilizationId !== 'string'
    || !isPlainObject(mobilization)
    || mobilization.id !== mission.mobilizationId
    || mobilization.status !== 'active'
    || engagements.some(
      (engagement) =>
        !isPlainObject(engagement)
        || engagement.mobilizationId !== mission.mobilizationId,
    )
  ) {
    throw new MissionUpdateError(
      'failed-precondition',
      'Cette mission n’appartient pas à une mobilisation active.',
    );
  }
  const access = parseAccess(callerRole);
  if (!canManage(access, mission.locationId, coordinatorAuthorized)
      || !canManage(access, request.locationId, coordinatorAuthorized)) {
    throw outsideScope();
  }
  if (
    mission.isActive === false
    || mission.status === 'cancelled'
    || missionHasEnded(mission, nowMillis)
  ) {
    throw new MissionUpdateError(
      'failed-precondition',
      'Cette mission ne peut plus être modifiée.',
    );
  }
  const changesLocation = request.locationId !== mission.locationId;
  if (
    !isPlainObject(destination)
    || (changesLocation
      && (destination.active === false || destination.isOperational === false))
  ) {
    throw new MissionUpdateError(
      'failed-precondition',
      'Le lieu sélectionné est inactif.',
    );
  }
  const registeredByProfession = registeredQuotas(mission);
  const confirmedByProfession = confirmedEngagementCounts(engagements);
  for (const profession of PROFESSIONS) {
    const minimum = Math.max(
      registeredByProfession[profession],
      confirmedByProfession[profession],
    );
    if (request.requiredByProfession[profession] < minimum) {
      throw new MissionUpdateError(
        'failed-precondition',
        'Le besoin ne peut pas être inférieur aux engagements confirmés.',
      );
    }
  }
  const fields = Object.freeze({
    locationId: request.locationId,
    locationName: requiredStoredText(destination.name, 'Lieu invalide.'),
    territorialGroup: requiredStoredText(
      destination.group ?? destination.territorialGroup,
      'Lieu invalide.',
    ),
    startAt: timestampFromMillis(request.startAtMillis),
    endAt: timestampFromMillis(request.endAtMillis),
    requiredByProfession: {...request.requiredByProfession},
    registeredByProfession: {...registeredByProfession},
    requiredMk: request.requiredByProfession.physiotherapist,
    requiredPp: request.requiredByProfession.podiatrist,
    registeredMk: registeredByProfession.physiotherapist,
    registeredPp: registeredByProfession.podiatrist,
    requestedEquipment: [...request.equipment],
    details: request.details,
    ...(request.priority === undefined ? {} : {priority: request.priority}),
    status: coverageStatus(
      request.requiredByProfession,
      registeredByProfession,
    ),
    updatedAt: serverTimestamp,
  });
  return Object.freeze({fields});
}

function parseAccess(document) {
  try {
    const access = parseResponsibleAccess(document);
    if (!access.active) throw outsideScope();
    return access;
  } catch (error) {
    if (error instanceof MissionUpdateError) throw error;
    throw outsideScope();
  }
}

function canManage(access, locationId, coordinatorAuthorized) {
  if (access.roles.includes('coordinator') && coordinatorAuthorized === true) {
    return true;
  }
  if (typeof locationId !== 'string' || locationId === '') return false;
  return access.roles.includes('site_manager')
    && access.locationIds.includes(locationId);
}

function missionHasEnded(mission, nowMillis) {
  const endAtMillis = storedTimestampMillis(mission.endAt);
  return !Number.isSafeInteger(nowMillis) || nowMillis >= endAtMillis;
}

function storedTimestampMillis(value) {
  const millis = value instanceof Date
    ? value.getTime()
    : value?.toMillis?.();
  if (!Number.isSafeInteger(millis) || millis <= 0) {
    throw new MissionUpdateError(
      'failed-precondition',
      'Cette mission ne peut plus être modifiée.',
    );
  }
  return millis;
}

function registeredQuotas(mission) {
  const result = emptyQuotas();
  if (isPlainObject(mission.registeredByProfession)) {
    for (const profession of PROFESSIONS) {
      const value = mission.registeredByProfession[profession] ?? 0;
      if (!Number.isInteger(value) || value < 0) throw invalidStoredMission();
      result[profession] = value;
    }
    if (Object.keys(mission.registeredByProfession)
      .some((key) => !PROFESSIONS.includes(key))) {
      throw invalidStoredMission();
    }
    return result;
  }
  result.physiotherapist = storedCounter(mission.registeredMk);
  result.podiatrist = storedCounter(mission.registeredPp);
  return result;
}

function confirmedEngagementCounts(engagements) {
  if (!Array.isArray(engagements)) throw invalidStoredMission();
  const result = emptyQuotas();
  for (const engagement of engagements) {
    if (!isPlainObject(engagement)) continue;
    const status = Object.hasOwn(engagement, 'status')
      ? engagement.status
      : 'confirmed';
    if (status !== 'confirmed') continue;
    const profession = PROFESSION_ALIASES[engagement.profession];
    if (profession !== undefined) result[profession] += 1;
  }
  return result;
}

function validateRequiredQuotas(value) {
  if (!isPlainObject(value)
      || !hasExactlyKeys(value, PROFESSIONS)) {
    throw invalidArgument();
  }
  const result = {};
  let total = 0;
  for (const profession of PROFESSIONS) {
    const quota = value[profession];
    if (!Number.isInteger(quota) || quota < 0) {
      throw invalidArgument();
    }
    result[profession] = quota;
    total += quota;
  }
  if (total === 0) throw invalidArgument();
  return Object.freeze(result);
}

function validateEquipment(value) {
  if (!Array.isArray(value) || value.length > 20) throw invalidArgument();
  const result = value.map((item) => requiredText(item, 100));
  if (new Set(result).size !== result.length) throw invalidArgument();
  return Object.freeze(result);
}

function coverageStatus(required, registered) {
  const requiredTotal = PROFESSIONS.reduce(
    (total, profession) => total + required[profession],
    0,
  );
  const registeredTotal = PROFESSIONS.reduce(
    (total, profession) => total + registered[profession],
    0,
  );
  if (registeredTotal === requiredTotal) return 'complete';
  return registeredTotal * 2 < requiredTotal ? 'critical' : 'toComplete';
}

function emptyQuotas() {
  return Object.fromEntries(PROFESSIONS.map((profession) => [profession, 0]));
}

function storedCounter(value) {
  if (value === undefined) return 0;
  if (!Number.isInteger(value) || value < 0) throw invalidStoredMission();
  return value;
}

function requiredStoredText(value, message) {
  if (typeof value !== 'string' || isCanonicalBlankText(value)) {
    throw new MissionUpdateError('failed-precondition', message);
  }
  return value.trim();
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
  if (typeof value !== 'string' || value.length > maxLength) {
    throw invalidArgument();
  }
  return isCanonicalBlankText(value) ? '' : value.trim();
}

function requiredPriority(value) {
  if (typeof value !== 'string' || !PRIORITIES.includes(value)) {
    throw invalidArgument();
  }
  return value;
}

function timestampMillis(value) {
  if (!Number.isSafeInteger(value) || value <= 0) throw invalidArgument();
  return value;
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

function invalidArgument() {
  return new MissionUpdateError(
    'invalid-argument',
    'Les informations de la mission sont invalides.',
  );
}

function invalidStoredMission() {
  return new MissionUpdateError(
    'failed-precondition',
    'Les compteurs de cette mission sont invalides.',
  );
}

function outsideScope() {
  return new MissionUpdateError(
    'permission-denied',
    'Vous ne pouvez modifier que les missions de vos centres.',
  );
}
