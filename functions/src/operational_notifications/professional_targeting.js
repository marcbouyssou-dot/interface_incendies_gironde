import {isVerifiedRppsProfile} from '../professional_admission.js';

export const INTERVENTION_RADII_KM = Object.freeze([10, 20, 30, 50]);

const VERIFIED_SITE_STATUSES = new Set([
  'verified_official', 'verified_cross_source',
]);

export const TARGETING_UNAVAILABLE_SITE_LOCATION =
  'TARGETING_UNAVAILABLE_SITE_LOCATION';
export const TARGETING_READY = 'TARGETING_READY';

function canonicalProfession(value) {
  return {
    mk: 'physiotherapist', pp: 'podiatrist', doctor: 'physician',
  }[value] ?? value;
}

function isCoordinatePair(latitude, longitude) {
  return typeof latitude === 'number' && Number.isFinite(latitude)
    && latitude >= -90 && latitude <= 90
    && typeof longitude === 'number' && Number.isFinite(longitude)
    && longitude >= -180 && longitude <= 180;
}

export function targetingSiteStatus(location) {
  return location && VERIFIED_SITE_STATUSES.has(location.addressStatus)
    && isCoordinatePair(location.latitude, location.longitude)
    ? TARGETING_READY : TARGETING_UNAVAILABLE_SITE_LOCATION;
}

export function distanceKm(first, second) {
  if (!isCoordinatePair(first?.latitude, first?.longitude)
    || !isCoordinatePair(second?.latitude, second?.longitude)) return null;
  const radians = (degrees) => degrees * Math.PI / 180;
  const latDelta = radians(second.latitude - first.latitude);
  const lonDelta = radians(second.longitude - first.longitude);
  const a = Math.sin(latDelta / 2) ** 2
    + Math.cos(radians(first.latitude)) * Math.cos(radians(second.latitude))
      * Math.sin(lonDelta / 2) ** 2;
  return 6371.0088 * 2 * Math.asin(Math.min(1, Math.sqrt(a)));
}

function neededProfessions(mission) {
  const required = mission?.requiredByProfession ?? {
    physiotherapist: mission?.requiredMk ?? 0,
    podiatrist: mission?.requiredPp ?? 0,
  };
  const registered = mission?.registeredByProfession ?? {
    physiotherapist: mission?.registeredMk ?? 0,
    podiatrist: mission?.registeredPp ?? 0,
  };
  return new Set(Object.keys(required)
    .filter((profession) => (required[profession] ?? 0) >
      (registered[profession] ?? 0))
    .map(canonicalProfession));
}

// Returned UIDs are backend-only. Never persist a professional's coordinates,
// radius or computed distance in notification, diffusion or role read models.
export function eligibleProfessionalUids({
  mission, mobilization, operation, location, admissionMode,
  volunteers, targetings, admissions, preferences, now,
  allowLegacyWithoutPoint = false,
}) {
  if (!mission || mission.isActive !== true || mission.status === 'cancelled'
    || mission.mobilizationId !== mobilization?.id
    || mission.locationId !== location?.id
    || mobilization.status !== 'active'
    || mobilization.operationId !== operation?.id
    || operation.status !== 'active'
    || (operation.purpose ?? 'operational') !== 'operational'
    || typeof operation.ownerOrganizationId !== 'string'
    || targetingSiteStatus(location) !== TARGETING_READY
    || !['open', 'invitation_only'].includes(admissionMode)) return new Set();
  const endAt = mission.endAt?.toMillis?.() ??
    (mission.endAt instanceof Date ? mission.endAt.getTime() : Infinity);
  if (endAt <= now) return new Set();
  const needed = neededProfessions(mission);
  if (needed.size === 0) return new Set();
  const result = new Set();
  for (const volunteer of volunteers) {
    if (!volunteer?.uid
      || !isVerifiedRppsProfile(volunteer)
      || !needed.has(canonicalProfession(volunteer.profession))
      || preferences.get(volunteer.uid)?.compatibleMissions !== true) continue;
    const targeting = targetings.get(volunteer.uid);
    if (targeting && isCoordinatePair(targeting.latitude, targeting.longitude)) {
      if (targeting.uid !== volunteer.uid || targeting.enabled !== true
        || !INTERVENTION_RADII_KM.includes(targeting.radiusKm)) continue;
      const distance = distanceKm(targeting, location);
      if (distance === null || distance > targeting.radiusKm) continue;
    } else if (!allowLegacyWithoutPoint) continue;
    if (admissionMode === 'invitation_only') {
      const grant = admissions.get(volunteer.uid);
      if (!grant || grant.uid !== volunteer.uid
        || grant.operationId !== operation.id
        || grant.organizationId !== operation.ownerOrganizationId
        || grant.status !== 'active'
        || grant.profession !== volunteer.profession
        || !grant.expiresAt?.toMillis
        || grant.expiresAt.toMillis() <= now) continue;
    }
    result.add(volunteer.uid);
  }
  return result;
}
