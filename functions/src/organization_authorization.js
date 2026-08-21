import {
  isCanonicalBlankText,
  parseResponsibleAccess,
} from './responsible_access.js';

export const LEGACY_ORGANIZATION_ID = 'legacy-gironde';

export const ORGANIZATION_ROLES = Object.freeze([
  'organization_admin',
  'coordinator',
  'site_manager',
  'professional',
]);

export const ORGANIZATION_PERMISSIONS = Object.freeze([
  'read_organization',
  'read_operations',
  'manage_operations',
  'manage_coordinators',
  'manage_site_managers',
  'manage_sites',
  'view_actors',
  'view_statistics',
  'view_history',
  'export_data',
  'manage_invitations',
]);

const ADMIN_PERMISSIONS = new Set(ORGANIZATION_PERMISSIONS);
const MEMBER_PERMISSIONS = new Set(['read_organization', 'read_operations']);

export function organizationMembershipId(organizationId, uid) {
  requireIdentifier(organizationId, 160);
  requireIdentifier(uid, 128);
  return `${organizationId}_${uid}`;
}

/**
 * Résout une autorisation sans effectuer de lecture ni de mutation.
 *
 * Une membership présente est toujours prioritaire. Si elle est inactive ou
 * malformée, le fallback RC3 n'est pas utilisé. `platform_admin` reste un
 * privilège global distinct et n'est jamais ajouté à la liste des rôles.
 */
export function resolveOrganizationAuthorization({
  organizationId,
  uid,
  membership = null,
  legacyRole = null,
  platformAdministrator = false,
}) {
  requireIdentifier(organizationId, 160);
  requireIdentifier(uid, 128);
  const membershipPresent = membership !== null && membership !== undefined;
  const membershipValid = membershipPresent
    && isValidMembership(membership, organizationId, uid);
  const hasActiveMembership = membershipValid && membership.active === true;
  const usesLegacyFallback = !membershipPresent
    && organizationId === LEGACY_ORGANIZATION_ID
    && hasActiveLegacyRole(legacyRole);
  const roles = hasActiveMembership
    ? Object.freeze([...membership.roles])
    : usesLegacyFallback
    ? Object.freeze([...parseResponsibleAccess(legacyRole).roles])
    : Object.freeze([]);
  const locationIds = hasActiveMembership
    ? Object.freeze([...(membership.locationIds ?? [])])
    : usesLegacyFallback
    ? Object.freeze([...parseResponsibleAccess(legacyRole).locationIds])
    : Object.freeze([]);
  const roleSet = new Set(roles);
  const isOrganizationAdmin = hasActiveMembership
    && roleSet.has('organization_admin');
  const globalPlatformAccess = platformAdministrator === true;
  const hasOrganizationAccess = globalPlatformAccess
    || hasActiveMembership
    || usesLegacyFallback;

  return Object.freeze({
    organizationId,
    uid,
    membershipPresent,
    membershipValid,
    hasActiveMembership,
    usesLegacyFallback,
    isPlatformAdministrator: globalPlatformAccess,
    isOrganizationAdmin,
    isCoordinator: roleSet.has('coordinator'),
    isSiteManager: roleSet.has('site_manager'),
    isProfessional: roleSet.has('professional'),
    roles,
    locationIds,
    hasRole: (role) => ORGANIZATION_ROLES.includes(role) && roleSet.has(role),
    allows: (permission) => {
      if (!ORGANIZATION_PERMISSIONS.includes(permission)) return false;
      if (globalPlatformAccess) return true;
      if (!hasOrganizationAccess) return false;
      return isOrganizationAdmin
        ? ADMIN_PERMISSIONS.has(permission)
        : MEMBER_PERMISSIONS.has(permission);
    },
  });
}

export function canReadOrganizationMissionTeam({
  authorization,
  locationId,
}) {
  if (!authorization || typeof authorization !== 'object') return false;
  if (authorization.isPlatformAdministrator === true
    || authorization.isCoordinator === true) {
    return true;
  }
  return authorization.isSiteManager === true
    && typeof locationId === 'string'
    && authorization.locationIds.includes(locationId);
}

/**
 * Contrat de lecture commun destiné aux futures callables RC4.
 *
 * Il centralise les trois documents d'identité nécessaires sans modifier les
 * callables existantes dans RC4.3C.
 */
export async function readOrganizationAuthorization({
  firestore,
  organizationId,
  uid,
}) {
  const membershipId = organizationMembershipId(organizationId, uid);
  const reads = [
    firestore.collection('organizationMemberships').doc(membershipId).get(),
    firestore.collection('platformAdministrators').doc(uid).get(),
  ];
  if (organizationId === LEGACY_ORGANIZATION_ID) {
    reads.push(firestore.collection('roles').doc(uid).get());
  }
  const [membershipSnapshot, platformSnapshot, legacyRoleSnapshot] =
    await Promise.all(reads);
  return resolveOrganizationAuthorization({
    organizationId,
    uid,
    membership: membershipSnapshot.exists ? membershipSnapshot.data() : null,
    legacyRole: legacyRoleSnapshot?.exists ? legacyRoleSnapshot.data() : null,
    platformAdministrator: platformSnapshot.exists
      && platformSnapshot.data()?.active === true,
  });
}

function isValidMembership(membership, organizationId, uid) {
  const locationIds = membership?.locationIds ?? [];
  if (!isPlainObject(membership)
    || membership.organizationId !== organizationId
    || membership.uid !== uid
    || typeof membership.active !== 'boolean'
    || !Array.isArray(membership.roles)
    || membership.roles.length === 0
    || membership.roles.length > ORGANIZATION_ROLES.length
    || new Set(membership.roles).size !== membership.roles.length
    || membership.roles.some((role) => !ORGANIZATION_ROLES.includes(role))
    || !Array.isArray(locationIds)
    || locationIds.length > 65
    || new Set(locationIds).size !== locationIds.length
    || locationIds.some((locationId) => typeof locationId !== 'string'
      || isCanonicalBlankText(locationId)
      || locationId === '*'
      || locationId.includes('/'))
    || (membership.roles.includes('site_manager')
      ? locationIds.length === 0
      : locationIds.length !== 0)
    || !Number.isInteger(membership.schemaVersion)
    || membership.schemaVersion < 1) {
    return false;
  }
  return true;
}

function hasActiveLegacyRole(role) {
  try {
    return parseResponsibleAccess(role).active === true;
  } catch {
    return false;
  }
}

function requireIdentifier(value, maxLength) {
  if (typeof value !== 'string'
    || value.length === 0
    || value.length > maxLength
    || value.trim() !== value
    || value.includes('/')) {
    throw new TypeError('Identifiant organisationnel invalide.');
  }
}

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}
