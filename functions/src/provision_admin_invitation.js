import {createHash, randomUUID} from 'node:crypto';

import {
  AdminInvitationValidationCode,
  AdminInvitationValidationError,
  validateProvisionableAdminInvitation,
} from './admin_invitation_validation.js';

import {
  hasActiveCoordinatorRole,
  ResponsibleAccessError,
} from './responsible_access.js';

export const NOTIFICATION_LEASE_DURATION_MS = 5 * 60 * 1000;

export class ProvisioningError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'ProvisioningError';
    this.code = code;
    this.reason = options.reason;
  }
}

export async function provisionAdminInvitation({
  invitationId,
  callerUid,
  services,
  notificationService,
  appUrl,
  now = new Date(),
  createNotificationAttemptId = randomUUID,
}) {
  requireText(invitationId, 'invalid-argument', 'Invitation invalide.');
  requireText(callerUid, 'unauthenticated', 'Authentification requise.');
  const activationUrl = buildActivationUrl(appUrl);

  const callerRole = await services.getRole(callerUid);
  if (!hasActiveCoordinatorRole(callerRole)) {
    throw new ProvisioningError(
      'permission-denied',
      'Accès coordinateur actif requis.',
    );
  }

  const rawInvitation = await services.getInvitation(invitationId);
  if (!rawInvitation) {
    throw new ProvisioningError('not-found', 'Invitation introuvable.');
  }
  let invitation;
  try {
    invitation = validateProvisionableAdminInvitation(rawInvitation, {now});
  } catch (error) {
    throw normalizedInvitationValidationError(error);
  }
  let alreadyProvisioned = invitation.status === 'accepted'
    && typeof invitation.acceptedUid === 'string';
  if (alreadyProvisioned && invitation.notificationStatus === 'sent') {
    return safeResult({
      alreadyProvisioned: true,
      emailDelivery: 'sent',
    });
  }
  if (!notificationService || typeof notificationService.send !== 'function') {
    throw new ProvisioningError(
      'failed-precondition',
      'Service de notification indisponible.',
    );
  }

  const user = await getOrCreateUser({services, invitation});
  if (user?.disabled === true) {
    throw new ProvisioningError(
      'failed-precondition',
      'Le compte existant est désactivé.',
    );
  }
  if (normalizedEmail(user.email) !== invitation.email) {
    throw new ProvisioningError(
      'failed-precondition',
      'L’adresse du compte existant est incompatible.',
    );
  }

  let firebaseActionLink;
  let activationLink;
  try {
    firebaseActionLink = await services.generatePasswordResetLink(
      invitation.email,
      {url: activationUrl, handleCodeInApp: true},
    );
    activationLink = buildCustomActivationLink({
      firebaseActionLink,
      activationUrl,
    });
    if (!alreadyProvisioned) {
      const commitResult = await services.commitProvisioning({
        invitationId,
        targetUid: user.uid,
        expectedInvitation: invitation,
        createdBy: callerUid,
        timestamps: {
          acceptedAt: now,
          provisionedAt: now,
          activationLinkGeneratedAt: now,
        },
      });
      if (commitResult?.state === 'already-provisioned') {
        alreadyProvisioned = true;
      }
    }

    const attemptId = createNotificationAttemptId();
    requireText(
      attemptId,
      'internal',
      'La tentative de notification est invalide.',
    );
    const reservation = await services.reserveNotificationDelivery({
      invitationId,
      targetUid: user.uid,
      attemptId,
      reservedAt: now,
      leaseExpiresAt: new Date(
        now.getTime() + NOTIFICATION_LEASE_DURATION_MS,
      ),
    });
    if (reservation.state === 'sent') {
      return safeResult({
        alreadyProvisioned: true,
        emailDelivery: 'sent',
      });
    }
    if (reservation.state === 'in-progress') {
      return safeResult({
        alreadyProvisioned: true,
        emailDelivery: 'pending',
      });
    }
    if (reservation.state !== 'reserved') {
      throw new ProvisioningError(
        'aborted',
        'La notification ne peut pas être réservée.',
      );
    }

    let notificationResult;
    try {
      notificationResult = await notificationService.send(
        buildInvitationNotification({invitation, activationLink}),
        {idempotencyKey: invitationNotificationIdempotencyKey(invitationId)},
      );
    } catch (error) {
      const errorCode = normalizedNotificationErrorCode(error);
      try {
        await services.markNotificationFailed({
          invitationId,
          targetUid: user.uid,
          attemptId,
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
    const finalization = await services.markNotificationSent({
      invitationId,
      targetUid: user.uid,
      attemptId,
      provider: notificationResult.provider,
      providerMessageId: notificationResult.providerMessageId,
      sentAt: now,
    });
    if (finalization?.state === 'in-progress') {
      return safeResult({
        alreadyProvisioned: true,
        emailDelivery: 'pending',
      });
    }
  } catch (error) {
    throw normalizedAccessError(error);
  } finally {
    firebaseActionLink = null;
    activationLink = null;
  }

  return safeResult({
    alreadyProvisioned,
    emailDelivery: 'sent',
  });
}

export function invitationNotificationIdempotencyKey(invitationId) {
  requireText(invitationId, 'invalid-argument', 'Invitation invalide.');
  const digest = createHash('sha256').update(invitationId).digest('hex');
  return `admin-invitation:${digest}:activation`;
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

export function buildCustomActivationLink({firebaseActionLink, activationUrl}) {
  let firebaseUrl;
  let mobSanteUrl;
  try {
    firebaseUrl = new URL(firebaseActionLink);
    mobSanteUrl = new URL(activationUrl);
  } catch {
    throw invalidGeneratedActivationLink();
  }

  const mode = firebaseUrl.searchParams.get('mode');
  const oobCode = firebaseUrl.searchParams.get('oobCode')?.trim() ?? '';
  if (mode !== 'resetPassword' || oobCode === '') {
    throw invalidGeneratedActivationLink();
  }

  mobSanteUrl.searchParams.set('mode', mode);
  mobSanteUrl.searchParams.set('oobCode', oobCode);
  copyOptionalQueryParameter(firebaseUrl, mobSanteUrl, 'apiKey');
  copyOptionalQueryParameter(firebaseUrl, mobSanteUrl, 'lang');
  return mobSanteUrl.toString();
}

function copyOptionalQueryParameter(source, target, name) {
  const value = source.searchParams.get(name);
  if (value !== null && value !== '') {
    target.searchParams.set(name, value);
  }
}

function invalidGeneratedActivationLink() {
  return new ProvisioningError(
    'internal',
    'Le lien d’activation n’a pas pu être préparé.',
  );
}

async function getOrCreateUser({services, invitation}) {
  try {
    return await services.getUserByEmail(invitation.email);
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
  }
  try {
    return await services.createUser({
      email: invitation.email,
      displayName: invitation.displayName,
      emailVerified: false,
      disabled: false,
    });
  } catch (error) {
    if (error?.code !== 'auth/email-already-exists') throw error;
    return await services.getUserByEmail(invitation.email);
  }
}

function normalizedAccessError(error) {
  if (!(error instanceof ResponsibleAccessError)) return error;
  if (error.code === 'inactive-role') {
    return new ProvisioningError(
      'failed-precondition',
      'Le compte responsable existant est inactif.',
      {cause: error},
    );
  }
  if (error.code === 'invalid-assignment') {
    return new ProvisioningError(
      'invalid-argument',
      'L’attribution demandée est invalide.',
      {cause: error},
    );
  }
  if (error.code === 'responsible-access-location-limit-exceeded') {
    return new ProvisioningError(
      'failed-precondition',
      'Le nombre maximal de centres autorisés est dépassé.',
      {cause: error},
    );
  }
  return new ProvisioningError(
    'failed-precondition',
    'Le rôle existant ne peut pas être modifié automatiquement.',
    {cause: error},
  );
}

function normalizedInvitationValidationError(error) {
  if (!(error instanceof AdminInvitationValidationError)) return error;
  if (error.reason === AdminInvitationValidationCode.expired) {
    return new ProvisioningError(
      'failed-precondition',
      'Invitation expirée.',
      {cause: error, reason: error.reason},
    );
  }
  if (error.reason === AdminInvitationValidationCode.cancelled) {
    return new ProvisioningError(
      'failed-precondition',
      'Cette invitation a été annulée.',
      {cause: error, reason: error.reason},
    );
  }
  return new ProvisioningError(
    'failed-precondition',
    'Cette invitation ne peut pas être préparée.',
    {cause: error, reason: error.reason},
  );
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
