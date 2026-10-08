import {resolveOrganizationAuthorization} from './organization_authorization.js';
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

/** A snapshot is derived only from an Action's own missions/scopes and the
 * current canonical organization memberships or coordinator assignments. */
export function planHistoricalAccessGrants({
  operationId,
  operation,
  mobilizations,
  missions,
  assignments,
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
  const coordinatorUids = new Set();
  if (operation.coordinatorUid !== null
    && operation.coordinatorUid !== undefined) {
    if (!isHistoricalAccessId(operation.coordinatorUid)) throw invalidSource();
    coordinatorUids.add(operation.coordinatorUid);
  }
  for (const assignment of assignments) {
    const {uid, mobilizationId, role, active} = assignment.data;
    if (active !== true || role !== 'coordinator') continue;
    if (!isHistoricalAccessId(uid)
      || !mobilizationIds.has(mobilizationId)
      || assignment.id !== `${mobilizationId}_${uid}`) throw invalidSource();
    coordinatorUids.add(uid);
  }
  const grants = [];
  const seenUids = new Set();
  for (const membership of memberships) {
    const {uid} = membership.data;
    if (!isHistoricalAccessId(uid)
      || membership.id !== `${organizationId}_${uid}`
      || seenUids.has(uid)) throw invalidSource();
    seenUids.add(uid);
    const authorization = resolveOrganizationAuthorization({
      organizationId,
      uid,
      membership: membership.data,
    });
    if (!authorization.hasActiveMembership) continue;
    const coordinator = authorization.isCoordinator
      && coordinatorUids.has(uid);
    const locationIds = authorization.isSiteManager
      ? authorization.locationIds.filter((id) => actionSiteIds.has(id)).sort()
      : [];
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
