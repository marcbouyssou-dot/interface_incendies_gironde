const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const ALLOWED_ROLES = new Set(['site_manager', 'coordinator']);

export class ProvisioningError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ProvisioningError';
    this.code = code;
  }
}

export class PendingAdminInvitationMailer {
  async prepare() {
    return {delivery: 'pending'};
  }
}

export async function provisionAdminInvitation({
  invitationId,
  callerUid,
  services,
  mailer = new PendingAdminInvitationMailer(),
  appUrl,
  now = new Date(),
}) {
  requireText(invitationId, 'invalid-argument', 'Invitation invalide.');
  requireText(callerUid, 'unauthenticated', 'Authentification requise.');
  requireText(appUrl, 'failed-precondition', 'MOBSANTE_APP_URL est requise.');

  const callerRole = await services.getRole(callerUid);
  if (callerRole?.active !== true || callerRole?.role !== 'coordinator') {
    throw new ProvisioningError(
      'permission-denied',
      'Accès coordinateur actif requis.',
    );
  }

  const invitation = await services.getInvitation(invitationId);
  if (!invitation) {
    throw new ProvisioningError('not-found', 'Invitation introuvable.');
  }
  if (invitation.status === 'accepted' && invitation.acceptedUid) {
    return safeResult({
      alreadyProvisioned: true,
    });
  }
  validateInvitation(invitation, now);

  let user;
  let createdUser = false;
  try {
    user = await services.getUserByEmail(invitation.email);
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
  }
  if (user?.disabled === true) {
    throw new ProvisioningError(
      'failed-precondition',
      'Le compte existant est désactivé.',
    );
  }
  if (!user) {
    user = await services.createUser({
      email: invitation.email,
      displayName: invitation.displayName,
      emailVerified: false,
      disabled: false,
    });
    createdUser = true;
  } else if (normalizedEmail(user.email) !== invitation.email) {
    throw new ProvisioningError(
      'failed-precondition',
      'L’adresse du compte existant est incompatible.',
    );
  }

  const expectedRole = {
    role: invitation.role,
    locationIds: invitation.role === 'coordinator'
      ? []
      : [...invitation.locationIds].sort(),
    active: true,
  };
  const existingRole = await services.getRole(user.uid);
  if (existingRole && !rolesAreCompatible(existingRole, expectedRole)) {
    if (createdUser) await compensateCreatedUser(services, user.uid);
    throw new ProvisioningError(
      'already-exists',
      'Un rôle incompatible existe déjà pour ce compte.',
    );
  }

  let activationLink;
  try {
    activationLink = await services.generatePasswordResetLink(
      invitation.email,
      {url: appUrl, handleCodeInApp: false},
    );
    await mailer.prepare({
      recipient: invitation.email,
      activationLink,
      displayName: invitation.displayName,
    });
    await services.commitProvisioning({
      invitationId,
      targetUid: user.uid,
      expectedInvitation: invitation,
      role: {
        ...expectedRole,
        createdBy: callerUid,
      },
      timestamps: {
        acceptedAt: now,
        provisionedAt: now,
        activationLinkGeneratedAt: now,
      },
    });
  } catch (error) {
    if (createdUser) await compensateCreatedUser(services, user.uid);
    throw error;
  } finally {
    activationLink = null;
  }

  return safeResult({
    alreadyProvisioned: false,
  });
}

function validateInvitation(invitation, now) {
  if (invitation.status !== 'pending') {
    throw new ProvisioningError(
      'failed-precondition',
      'Cette invitation n’est plus en attente.',
    );
  }
  const expiresAt = asDate(invitation.expiresAt);
  if (!expiresAt || expiresAt <= now) {
    throw new ProvisioningError('failed-precondition', 'Invitation expirée.');
  }
  invitation.email = normalizedEmail(invitation.email);
  if (!EMAIL_PATTERN.test(invitation.email)) {
    throw new ProvisioningError('invalid-argument', 'Adresse e-mail invalide.');
  }
  if (!ALLOWED_ROLES.has(invitation.role)) {
    throw new ProvisioningError('invalid-argument', 'Rôle invalide.');
  }
  if (!Array.isArray(invitation.locationIds)) {
    throw new ProvisioningError('invalid-argument', 'Centres invalides.');
  }
  if (
    (invitation.role === 'site_manager' && invitation.locationIds.length === 0)
    || (invitation.role === 'coordinator'
      && invitation.locationIds.length !== 0)
  ) {
    throw new ProvisioningError(
      'invalid-argument',
      'Périmètre de centres incohérent.',
    );
  }
}

function rolesAreCompatible(existing, expected) {
  return existing.role === expected.role
    && existing.active === expected.active
    && sameStrings(existing.locationIds, expected.locationIds);
}

function sameStrings(left, right) {
  if (!Array.isArray(left) || left.length !== right.length) return false;
  return [...left].sort().every((value, index) => value === [...right].sort()[index]);
}

async function compensateCreatedUser(services, uid) {
  try {
    await services.deleteUser(uid);
  } catch {
    // A retry reuses the account if compensation is unavailable.
  }
}

function safeResult({alreadyProvisioned}) {
  return {
    accountProvisioned: true,
    emailDelivery: 'pending',
    invitationStatus: 'accepted',
    alreadyProvisioned,
  };
}

function normalizedEmail(value) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

function requireText(value, code, message) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new ProvisioningError(code, message);
  }
}

function asDate(value) {
  if (value instanceof Date) return value;
  if (value && typeof value.toDate === 'function') return value.toDate();
  return null;
}
