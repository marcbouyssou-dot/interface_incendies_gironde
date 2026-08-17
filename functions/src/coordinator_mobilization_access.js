import {hasActiveCoordinatorRole} from './responsible_access.js';

export const ACTIVE_MOBILIZATION_ASSIGNMENTS_FIELD =
  'hasActiveMobilizationAssignments';

export function canCoordinateMobilization({
  uid,
  role,
  assignment,
  mobilization,
  platformConfig,
}) {
  if (
    typeof uid !== 'string'
    || uid === ''
    || !hasActiveCoordinatorRole(role)
    || !isActiveMobilization(mobilization)
  ) {
    return false;
  }
  if (isActiveAssignment({assignment, uid, mobilizationId: mobilization.id})) {
    return true;
  }
  if (!legacyFallbackIsAvailable(role)) return false;
  return isPlainObject(platformConfig)
    && platformConfig.activeMobilizationId === mobilization.id;
}

function isActiveAssignment({assignment, uid, mobilizationId}) {
  return isPlainObject(assignment)
    && assignment.uid === uid
    && assignment.mobilizationId === mobilizationId
    && assignment.role === 'coordinator'
    && assignment.active === true;
}

function legacyFallbackIsAvailable(role) {
  return !Object.hasOwn(role, ACTIVE_MOBILIZATION_ASSIGNMENTS_FIELD)
    || role[ACTIVE_MOBILIZATION_ASSIGNMENTS_FIELD] === false;
}

function isActiveMobilization(value) {
  return isPlainObject(value)
    && typeof value.id === 'string'
    && value.id !== ''
    && value.status === 'active';
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
