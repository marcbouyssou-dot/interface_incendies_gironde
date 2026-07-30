const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const ALLOWED_ROLES = new Set(['site_manager', 'coordinator']);

export class ProvisioningError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'ProvisioningError';
    this.code = code;
  }
}

export async function provisionAdminInvitation({
  invitationId,
  callerUid,
  services,
  notificationService,
  appUrl,
  now = new Date(),
}) {
  requireText(invitationId, 'invalid-argument', 'Invitation invalide.');
  requireText(callerUid, 'unauthenticated', 'Authentification requise.');
  const activationUrl = buildActivationUrl(appUrl);

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
  const alreadyProvisioned = invitation.status === 'accepted'
    && typeof invitation.acceptedUid === 'string'
    && invitation.acceptedUid !== '';
  if (alreadyProvisioned && invitation.notificationStatus === 'sent') {
    return safeResult({
      alreadyProvisioned: true,
      emailDelivery: 'sent',
    });
  }
  if (alreadyProvisioned) {
    validateInvitationData(invitation);
  } else {
    validateInvitation(invitation, now);
  }
  if (!notificationService || typeof notificationService.send !== 'function') {
    throw new ProvisioningError(
      'failed-precondition',
      'Service de notification indisponible.',
    );
  }

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
  let provisioningCommitted = alreadyProvisioned;
  try {
    activationLink = await services.generatePasswordResetLink(
      invitation.email,
      {url: activationUrl, handleCodeInApp: true},
    );
    if (!alreadyProvisioned) {
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
      provisioningCommitted = true;
    }

    try {
      const notificationResult = await notificationService.send(
        buildInvitationNotification({invitation, activationLink}),
      );
      await services.markNotificationSent({
        invitationId,
        targetUid: user.uid,
        provider: notificationResult.provider,
        providerMessageId: notificationResult.providerMessageId,
        sentAt: now,
      });
    } catch (error) {
      const errorCode = normalizedNotificationErrorCode(error);
      try {
        await services.markNotificationFailed({
          invitationId,
          targetUid: user.uid,
          errorCode,
          failedAt: now,
        });
      } catch {
        // The original notification failure remains the actionable cause.
      }
      throw new ProvisioningError(
        'unavailable',
        'Le compte est prêt, mais la notification n’a pas pu être envoyée.',
        {cause: error},
      );
    }
  } catch (error) {
    if (createdUser && !provisioningCommitted) {
      await compensateCreatedUser(services, user.uid);
    }
    throw error;
  } finally {
    activationLink = null;
  }

  return safeResult({
    alreadyProvisioned,
    emailDelivery: 'sent',
  });
}

export function buildInvitationNotification({invitation, activationLink}) {
  const roleLabel = invitation.role === 'coordinator'
    ? 'Coordinateur départemental'
    : 'Responsable de centre';
  const expiration = asDate(invitation.expiresAt);
  const expirationText = expiration
    ? expiration.toLocaleDateString('fr-FR', {timeZone: 'UTC'})
    : 'la date indiquée dans votre invitation';
  const text = [
    `Bonjour ${invitation.displayName ?? ''},`.trim(),
    '',
    'Votre compte responsable MobSanté a été préparé.',
    `Rôle attribué : ${roleLabel}.`,
    `Activez votre compte avant le ${expirationText} :`,
    activationLink,
    '',
    'Ne transférez pas ce lien personnel.',
    'Si vous avez reçu ce message par erreur, vous pouvez l’ignorer.',
  ].join('\n');
  const html = [
    `<p>Bonjour ${escapeHtml(invitation.displayName ?? '')},</p>`,
    '<p>Votre compte responsable MobSanté a été préparé.</p>',
    `<p><strong>Rôle attribué :</strong> ${roleLabel}.<br>`,
    `Activez votre compte avant le ${expirationText} :</p>`,
    `<p><a href="${escapeHtml(activationLink)}">Activer mon compte</a></p>`,
    '<p>Ne transférez pas ce lien personnel.</p>',
    '<p>Si vous avez reçu ce message par erreur, vous pouvez l’ignorer.</p>',
  ].join('');
  return {
    channel: 'email',
    recipient: invitation.email,
    subject: 'Activez votre compte responsable MobSanté',
    text,
    html,
    metadata: {kind: 'admin-invitation'},
  };
}

export function buildActivationUrl(value) {
  requireText(value, 'failed-precondition', 'MOBSANTE_APP_URL est requise.');
  let url;
  try {
    url = new URL(value);
  } catch {
    throw new ProvisioningError(
      'failed-precondition',
      'MOBSANTE_APP_URL est invalide.',
    );
  }
  const isLocalEmulator = url.protocol === 'http:'
    && new Set(['127.0.0.1', 'localhost', '::1']).has(url.hostname);
  if (url.protocol !== 'https:' && !isLocalEmulator) {
    throw new ProvisioningError(
      'failed-precondition',
      'MOBSANTE_APP_URL doit utiliser HTTPS.',
    );
  }
  if (url.username || url.password || url.search || url.hash) {
    throw new ProvisioningError(
      'failed-precondition',
      'MOBSANTE_APP_URL contient des éléments interdits.',
    );
  }
  const basePath = url.pathname.replace(/\/+$/, '');
  url.pathname = basePath.endsWith('/activation')
    ? basePath
    : `${basePath}/activation`;
  return url.toString().replace(/\/$/, '');
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
  validateInvitationData(invitation);
}

function validateInvitationData(invitation) {
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

function safeResult({alreadyProvisioned, emailDelivery}) {
  return {
    accountProvisioned: true,
    emailDelivery,
    invitationStatus: 'accepted',
    alreadyProvisioned,
  };
}

function normalizedNotificationErrorCode(error) {
  const value = error?.code;
  return typeof value === 'string' && /^[a-z0-9_-]{1,64}$/i.test(value)
    ? value
    : 'notification-failed';
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
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
