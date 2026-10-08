import {resolveOrganizationAuthorization} from './organization_authorization.js';

const SCOPED_ROLES = new Set(['coordinator', 'site_manager']);
const validId = (value) => typeof value === 'string'
  && value.length > 0 && value.trim() === value && !value.includes('/');

/** Organization membership carries role capability; this grant carries the
 * Action and site scope. A malformed or inactive document grants nothing. */
export function resolveOperationAccess({
  operationId, organizationId, uid, membership, grant,
}) {
  if (![operationId, organizationId, uid].every(validId)) {
    return Object.freeze({coordinator: false, locationIds: Object.freeze([])});
  }
  const authorization = resolveOrganizationAuthorization({
    organizationId, uid, membership,
  });
  const validGrant = grant !== null && typeof grant === 'object'
    && !Array.isArray(grant)
    && grant.operationId === operationId
    && grant.organizationId === organizationId
    && grant.uid === uid
    && grant.active === true
    && Number.isInteger(grant.schemaVersion)
    && grant.schemaVersion >= 1
    && Array.isArray(grant.roles)
    && grant.roles.length > 0
    && grant.roles.length <= SCOPED_ROLES.size
    && new Set(grant.roles).size === grant.roles.length
    && grant.roles.every((role) => SCOPED_ROLES.has(role))
    && Array.isArray(grant.locationIds)
    && new Set(grant.locationIds).size === grant.locationIds.length
    && grant.locationIds.every(validId)
    && (grant.roles.includes('site_manager')
      ? grant.locationIds.length > 0 : grant.locationIds.length === 0);
  if (!authorization.hasActiveMembership || !validGrant) {
    return Object.freeze({coordinator: false, locationIds: Object.freeze([])});
  }
  return Object.freeze({
    coordinator: authorization.isCoordinator
      && grant.roles.includes('coordinator'),
    locationIds: Object.freeze(authorization.isSiteManager
      && grant.roles.includes('site_manager')
      ? grant.locationIds.filter((id) =>
        authorization.locationIds.includes(id)) : []),
  });
}

export function canManageOperationLocation(access, locationId) {
  return access?.coordinator === true
    || (typeof locationId === 'string'
      && access?.locationIds?.includes(locationId) === true);
}
