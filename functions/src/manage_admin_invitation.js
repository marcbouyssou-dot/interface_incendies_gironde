import {
  AdminInvitationValidationError,
  validateAdminInvitationUpdate,
  validateUnacceptedAdminInvitation,
} from './admin_invitation_validation.js';

const ACTIONS = new Set(['cancel', 'reactivate', 'update', 'delete']);

export class AdminInvitationManagementError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'AdminInvitationManagementError';
    this.code = code;
  }
}

export async function manageAdminInvitation({
  callerUid,
  data,
  services,
  now = new Date(),
}) {
  requireText(callerUid, 'unauthenticated', 'Authentification requise.');
  const request = validateManagementRequest(data, {now});
  return services.commitAdminInvitationManagement({
    callerUid,
    ...request,
    now: new Date(now.getTime()),
  });
}

export function validateManagementRequest(data, {now = new Date()} = {}) {
  if (!isPlainObject(data)) throw invalidArgument();
  requireText(data.invitationId, 'invalid-argument', 'Invitation invalide.');
  if (!ACTIONS.has(data.action)) throw invalidArgument();
  const allowedFields = {
    cancel: ['invitationId', 'action'],
    reactivate: ['invitationId', 'action', 'expiresAtMillis'],
    update: ['invitationId', 'action', 'displayName', 'role', 'locationIds'],
    delete: ['invitationId', 'action'],
  }[data.action];
  if (
    Object.keys(data).some((field) => !allowedFields.includes(field))
    || allowedFields.some((field) => !Object.hasOwn(data, field))
  ) throw invalidArgument();

  if (data.action === 'reactivate') {
    if (!Number.isSafeInteger(data.expiresAtMillis)) throw invalidArgument();
    const expiresAt = new Date(data.expiresAtMillis);
    if (Number.isNaN(expiresAt.getTime()) || expiresAt <= now) {
      throw new AdminInvitationManagementError(
        'failed-precondition',
        'La nouvelle date d’expiration doit être future.',
      );
    }
    return Object.freeze({
      invitationId: data.invitationId,
      action: data.action,
      expiresAt,
    });
  }
  if (data.action === 'update') {
    let update;
    try {
      update = validateAdminInvitationUpdate({
        displayName: data.displayName,
        role: data.role,
        locationIds: data.locationIds,
      });
    } catch (error) {
      if (!(error instanceof AdminInvitationValidationError)) throw error;
      throw invalidArgument(error);
    }
    return Object.freeze({
      invitationId: data.invitationId,
      action: data.action,
      update,
    });
  }
  return Object.freeze({
    invitationId: data.invitationId,
    action: data.action,
  });
}

export function invitationManagementMutation({
  invitation,
  action,
  update,
  expiresAt,
  now = new Date(),
}) {
  let current;
  try {
    current = validateUnacceptedAdminInvitation(invitation);
  } catch (error) {
    if (!(error instanceof AdminInvitationValidationError)) throw error;
    throw new AdminInvitationManagementError(
      'failed-precondition',
      'Cette invitation a déjà été utilisée ou est invalide.',
      {cause: error},
    );
  }

  if (action === 'cancel') {
    if (current.status !== 'pending' || current.expiresAt <= now) {
      throw invalidTransition();
    }
    return Object.freeze({
      kind: 'update',
      fields: Object.freeze({status: 'cancelled'}),
      result: Object.freeze({status: 'cancelled'}),
    });
  }
  if (action === 'reactivate') {
    if (current.status !== 'cancelled' || !(expiresAt instanceof Date)) {
      throw invalidTransition();
    }
    if (Number.isNaN(expiresAt.getTime()) || expiresAt <= now) {
      throw new AdminInvitationManagementError(
        'failed-precondition',
        'La nouvelle date d’expiration doit être future.',
      );
    }
    const safeExpiration = new Date(expiresAt.getTime());
    return Object.freeze({
      kind: 'update',
      fields: Object.freeze({status: 'pending', expiresAt: safeExpiration}),
      result: Object.freeze({
        status: 'pending',
        expiresAtMillis: safeExpiration.getTime(),
      }),
    });
  }
  if (action === 'update') {
    if (!new Set(['pending', 'cancelled']).has(current.status) || !update) {
      throw invalidTransition();
    }
    return Object.freeze({
      kind: 'update',
      fields: Object.freeze({
        displayName: update.displayName,
        role: update.role,
        locationIds: Object.freeze([...update.locationIds]),
      }),
      result: Object.freeze({status: current.status}),
    });
  }
  if (action === 'delete') {
    return Object.freeze({
      kind: 'delete',
      result: Object.freeze({deleted: true}),
    });
  }
  throw invalidArgument();
}

function invalidArgument(cause) {
  return new AdminInvitationManagementError(
    'invalid-argument',
    'La demande de gestion de l’invitation est invalide.',
    {cause},
  );
}

function invalidTransition() {
  return new AdminInvitationManagementError(
    'failed-precondition',
    'Cette action n’est plus disponible pour cette invitation.',
  );
}

function requireText(value, code, message) {
  if (typeof value !== 'string' || value.length === 0) {
    throw new AdminInvitationManagementError(code, message);
  }
}

function isPlainObject(value) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}
