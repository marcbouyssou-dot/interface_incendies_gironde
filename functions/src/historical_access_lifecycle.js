import {resolveOperationAccess} from './operation_access.js';
import {PlatformAdministrationError} from './platform_administration.js';

const MAX_GRANTS = 200;

function invalidSource() {
  return new PlatformAdministrationError(
    'failed-precondition',
    'Le périmètre historique de cette Action ne peut pas être établi.',
  );
}

export function isHistoricalAccessId(value) {
  return typeof value === 'string'
    && value.length > 0
    && value.length <= 160
    && value.trim() === value
    && !value.includes('/');
}

function addScopedLocations(target, scopeRefs) {
  if (scopeRefs === undefined || scopeRefs === null) return;
  if (!Array.isArray(scopeRefs)) throw invalidSource();
  for (const reference of scopeRefs) {
    if (typeof reference !== 'string') throw invalidSource();
    if (!reference.startsWith('locations/')) continue;
    const locationId = reference.slice('locations/'.length);
    if (!isHistoricalAccessId(locationId)) throw invalidSource();
    target.add(locationId);
  }
}

/** A snapshot is derived from explicit Action grants and the same Action's
 * sites. An organization role or legacy locationIds alone never mint history. */
export function planHistoricalAccessGrants({
  operationId,
  operation,
  mobilizations,
  missions,
  operationAccess = [],
  memberships,
}) {
  const organizationId = operation.ownerOrganizationId;
  if (!isHistoricalAccessId(operationId)
    || !isHistoricalAccessId(organizationId)) throw invalidSource();
  const mobilizationIds = new Set();
  const actionSiteIds = new Set();
  addScopedLocations(actionSiteIds, operation.scopeRefs);
  for (const mobilization of mobilizations) {
    if (!isHistoricalAccessId(mobilization.id)
      || mobilization.data.operationId !== operationId) throw invalidSource();
    mobilizationIds.add(mobilization.id);
    addScopedLocations(actionSiteIds, mobilization.data.scopeRefs);
  }
  for (const mission of missions) {
    if (!isHistoricalAccessId(mission.id)
      || !mobilizationIds.has(mission.data.mobilizationId)
      || !isHistoricalAccessId(mission.data.locationId)) throw invalidSource();
    actionSiteIds.add(mission.data.locationId);
  }
  const membershipByUid = new Map(memberships.map((entry) =>
    [entry.data.uid, entry]));
  const grants = [];
  const seenUids = new Set();
  for (const scope of operationAccess) {
    const {uid} = scope.data;
    if (!isHistoricalAccessId(uid)
      || scope.id !== `${operationId}_${uid}`
      || seenUids.has(uid)) throw invalidSource();
    seenUids.add(uid);
    const membership = membershipByUid.get(uid);
    if (membership !== undefined
      && membership.id !== `${organizationId}_${uid}`) throw invalidSource();
    const resolved = resolveOperationAccess({operationId, organizationId,
      uid, membership: membership?.data ?? null, grant: scope.data});
    const coordinator = resolved.coordinator;
    const locationIds = resolved.locationIds
      .filter((id) => actionSiteIds.has(id)).sort();
    if (!coordinator && locationIds.length === 0) continue;
    grants.push({
      uid,
      operationId,
      roles: [
        ...(coordinator ? ['coordinator'] : []),
        ...(locationIds.length > 0 ? ['site_manager'] : []),
      ],
      locationIds,
      active: true,
      schemaVersion: 1,
    });
  }
  if (grants.length > MAX_GRANTS) throw invalidSource();
  return grants.sort((a, b) => a.uid.localeCompare(b.uid));
}

export function sameHistoricalAccessGrant(existing, proposed) {
  return existing?.uid === proposed.uid
    && existing?.operationId === proposed.operationId
    && existing?.active === true
    && existing?.schemaVersion === 1
    && Array.isArray(existing.roles)
    && existing.roles.length === proposed.roles.length
    && existing.roles.every((role, index) => role === proposed.roles[index])
    && Array.isArray(existing.locationIds)
    && existing.locationIds.length === proposed.locationIds.length
    && existing.locationIds.every(
      (id, index) => id === proposed.locationIds[index]
    )
    && existing.createdAt !== undefined
    && existing.createdBy !== undefined
    && existing.sourceTransition !== undefined;
}
