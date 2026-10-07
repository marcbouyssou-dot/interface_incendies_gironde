import {isDeepStrictEqual} from 'node:util';
import {createHash} from 'node:crypto';

// This collection is a presentation surface, never an operational source.
export const PUBLIC_MISSION_COLLECTION = 'publicMissionDiscovery';
export const PUBLIC_MISSION_FIELDS = Object.freeze([
  'publicId', 'day', 'sectorLabel', 'professions', 'status',
]);

export function publicMissionId(missionId) {
  if (typeof missionId !== 'string' || missionId.length === 0 ||
      missionId.includes('/')) return null;
  return `public_${createHash('sha256')
    .update(`mobsante-discovery-v1:${missionId}`)
    .digest('hex')}`;
}

const SECTORS = Object.freeze({
  bordeauxMetropole: 'Bordeaux Métropole',
  northBasin: 'Nord Bassin',
  southBasin: 'Sud Bassin',
  medoc: 'Médoc',
  southGironde: 'Sud Gironde',
  libournais: 'Libournais',
  hauteGironde: 'Haute Gironde',
  partnerSites: 'Secteur Gironde',
});

const PROFESSIONS = Object.freeze([
  'physiotherapist', 'podiatrist', 'physician', 'nurse',
  'veterinarian', 'other_health_professional',
]);

const LEGACY_QUOTAS = Object.freeze({
  physiotherapist: 'requiredMk',
  podiatrist: 'requiredPp',
});

function dateOf(value) {
  if (value instanceof Date) return value;
  if (typeof value?.toDate === 'function') return value.toDate();
  return null;
}

function localDay(date) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Paris', year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(date);
}

function requestedProfessions(mission) {
  const quotas = mission.requiredByProfession;
  return PROFESSIONS.filter((profession) => {
    const count = quotas && typeof quotas === 'object' && !Array.isArray(quotas)
      ? quotas[profession]
      : mission[LEGACY_QUOTAS[profession]];
    return Number.isInteger(count) && count > 0;
  });
}

/**
 * A public mission must be open, future-facing and in an active mobilization.
 * New mobilizations require an explicitly platform-visible, published operation.
 * The configured historical mobilization is the sole compatibility exception;
 * no organization identifier or site field is copied into the projection.
 */
export function isPubliclyDiscoverable({
  mission, mobilization, operation, activeMobilizationId, now = new Date(),
}) {
  if (!mission || !mobilization || mobilization.status !== 'active' ||
      mission.isActive !== true ||
      !['critical', 'toComplete'].includes(mission.status)) return false;
  const start = dateOf(mission.startAt);
  const end = dateOf(mission.endAt);
  if (!start || !end || !Number.isFinite(start.getTime()) ||
      !Number.isFinite(end.getTime()) || end <= start || end <= now) return false;
  if (requestedProfessions(mission).length === 0) return false;
  if (Object.hasOwn(mobilization, 'operationId')) {
    if (typeof mobilization.operationId !== 'string' ||
        mobilization.operationId.length === 0 ||
        mobilization.operationId.includes('/')) return false;
    return operation?.visibility === 'platform' &&
      ['planned', 'active'].includes(operation.status);
  }
  return mobilization.id === activeMobilizationId;
}

export function projectPublicMission({
  missionId, mission, mobilization, operation, activeMobilizationId,
  now = new Date(),
}) {
  if (!isPubliclyDiscoverable({
    mission, mobilization, operation, activeMobilizationId, now,
  })) return null;
  const publicId = publicMissionId(missionId);
  if (publicId === null) return null;
  const sector = SECTORS[mission.territorialGroup];
  if (!sector) return null;
  return {
    publicId,
    day: localDay(dateOf(mission.startAt)),
    sectorLabel: sector,
    professions: requestedProfessions(mission),
    status: 'open',
  };
}

export function projectionAction(expected, current) {
  if (expected === null) return current == null ? 'UNCHANGED' : 'DELETE';
  if (current == null) return 'CREATE';
  return isDeepStrictEqual(expected, current) ? 'UNCHANGED' : 'UPDATE';
}

export function planPublicMissionDiscovery({
  missions, mobilizations, operations, currentProjections,
  activeMobilizationId, now = new Date(),
}) {
  const sourceByPublicId = new Map(
    [...missions.keys()].map((missionId) => [publicMissionId(missionId), missionId]),
  );
  const publicIds = new Set([...sourceByPublicId.keys(), ...currentProjections.keys()]);
  return [...publicIds].filter((id) => id !== null).sort().map((publicId) => {
    const missionId = sourceByPublicId.get(publicId) ?? null;
    const mission = missions.get(missionId);
    const mobilization = mobilizations.get(mission?.mobilizationId);
    const operation = operations.get(mobilization?.operationId);
    const expected = projectPublicMission({
      missionId, mission, mobilization, operation, activeMobilizationId, now,
    });
    return {
      publicId, missionId,
      action: projectionAction(expected, currentProjections.get(publicId)),
      expected,
    };
  });
}
