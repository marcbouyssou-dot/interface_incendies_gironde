import {
  isCanonicalBlankText,
  normalizeRequestedAssignment,
  ResponsibleAccessError,
} from './responsible_access.js';

const BASE_FIELDS = Object.freeze([
  'email',
  'displayName',
  'role',
  'locationIds',
  'createdBy',
  'createdAt',
  'expiresAt',
  'status',
  'acceptedAt',
]);
const ACCEPTED_CORE_FIELDS = Object.freeze([
  'acceptedUid',
  'provisionedAt',
  'activationLinkGeneratedAt',
]);
const NOTIFICATION_FIELDS = Object.freeze({
  pending: Object.freeze(['notificationStatus']),
  sending: Object.freeze([
    'notificationStatus',
    'notificationAttemptId',
    'notificationReservedAt',
    'notificationLeaseExpiresAt',
  ]),
  failed: Object.freeze([
    'notificationStatus',
    'notificationErrorCode',
    'notificationFailedAt',
  ]),
  sent: Object.freeze([
    'notificationStatus',
    'notificationSentAt',
    'notificationProvider',
    'notificationProviderMessageId',
  ]),
});
const EMAIL_PATTERN = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
const MAX_EMAIL_LENGTH = 255;
const NOTIFICATION_ERROR_CODE_PATTERN = /^[a-z0-9_-]{1,64}$/i;
const CANONICAL_EDGE_WHITESPACE_PATTERN =
  /^[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+|[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF]+$/gu;

export const AdminInvitationValidationCode = Object.freeze({
  invalid: 'invalid-admin-invitation',
  expired: 'admin-invitation-expired',
  cancelled: 'admin-invitation-cancelled',
});

export class AdminInvitationValidationError extends Error {
  constructor(reason, message, options = {}) {
    super(message, options);
    this.name = 'AdminInvitationValidationError';
    this.reason = reason;
  }
}

export function validateProvisionableAdminInvitation(raw, {now} = {}) {
  const currentTime = requiredDate(now, 'Horloge de validation invalide.');
  if (!isPlainObject(raw)) throw invalidInvitation();

  for (const field of BASE_FIELDS) {
    if (!Object.hasOwn(raw, field)) throw invalidInvitation();
  }

  const status = raw.status;
  if (typeof status !== 'string') throw invalidInvitation();
  if (!new Set(['pending', 'accepted', 'cancelled']).has(status)) {
    if (status === 'expired') throw expiredInvitation();
    throw invalidInvitation();
  }

  const notificationStatus = status === 'accepted'
    ? validateNotificationStatus(raw)
    : null;
  const allowedFields = status === 'accepted'
    ? [
      ...BASE_FIELDS,
      ...ACCEPTED_CORE_FIELDS,
      ...(notificationStatus === null
        ? []
        : NOTIFICATION_FIELDS[notificationStatus]),
    ]
    : BASE_FIELDS;
  refuseUnknownFields(raw, allowedFields);

  const email = validateEmail(raw.email);
  const displayName = requiredNonBlankText(raw.displayName);
  const createdBy = requiredNonBlankText(raw.createdBy);
  const createdAt = requiredDate(raw.createdAt);
  const expiresAt = requiredDate(raw.expiresAt);
  if (createdAt > currentTime || expiresAt <= createdAt) {
    throw invalidInvitation();
  }

  let assignment;
  try {
    assignment = normalizeRequestedAssignment(raw);
  } catch (error) {
    if (!(error instanceof ResponsibleAccessError)) throw error;
    throw invalidInvitation(error);
  }

  if (status === 'cancelled') {
    if (raw.acceptedAt !== null) throw invalidInvitation();
    throw cancelledInvitation();
  }

  if (status === 'pending') {
    if (raw.acceptedAt !== null) throw invalidInvitation();
    if (expiresAt <= currentTime) throw expiredInvitation();
    return immutableInvitation({
      email,
      displayName,
      role: raw.role,
      locationIds: assignment.locationIds,
      createdBy,
      createdAt,
      expiresAt,
      status,
      acceptedAt: null,
    });
  }

  const acceptedAt = requiredDate(raw.acceptedAt);
  const acceptedUid = requiredNonBlankText(raw.acceptedUid);
  const provisionedAt = requiredDate(raw.provisionedAt);
  const activationLinkGeneratedAt = requiredDate(
    raw.activationLinkGeneratedAt,
  );
  if (
    acceptedAt < createdAt
    || acceptedAt >= expiresAt
    || provisionedAt < acceptedAt
    || provisionedAt >= expiresAt
    || activationLinkGeneratedAt < acceptedAt
    || activationLinkGeneratedAt >= expiresAt
    || acceptedAt > currentTime
    || provisionedAt > currentTime
    || activationLinkGeneratedAt > currentTime
  ) {
    throw invalidInvitation();
  }

  const notification = validateNotificationFields(raw, notificationStatus, {
    acceptedAt,
    now: currentTime,
  });
  return immutableInvitation({
    email,
    displayName,
    role: raw.role,
    locationIds: assignment.locationIds,
    createdBy,
    createdAt,
    expiresAt,
    status,
    acceptedAt,
    acceptedUid,
    provisionedAt,
    activationLinkGeneratedAt,
    ...notification,
  });
}

export function validateUnacceptedAdminInvitation(raw) {
  if (!isPlainObject(raw)) throw invalidInvitation();
  if (!new Set(['pending', 'cancelled', 'expired']).has(raw.status)) {
    throw invalidInvitation();
  }
  if (raw.acceptedAt !== null) throw invalidInvitation();
  const createdAt = requiredDate(raw.createdAt);
  const expiresAt = requiredDate(raw.expiresAt);
  if (expiresAt <= createdAt) throw invalidInvitation();
  const invitation = validateProvisionableAdminInvitation(
    {...raw, status: 'pending'},
    {now: createdAt},
  );
  return immutableInvitation({...invitation, status: raw.status});
}

export function validateAdminInvitationUpdate(raw) {
  if (!isPlainObject(raw)) throw invalidInvitation();
  refuseUnknownFields(raw, ['displayName', 'role', 'locationIds']);
  for (const field of ['displayName', 'role', 'locationIds']) {
    if (!Object.hasOwn(raw, field)) throw invalidInvitation();
  }
  const displayName = requiredNonBlankText(raw.displayName);
  let assignment;
  try {
    assignment = normalizeRequestedAssignment(raw);
  } catch (error) {
    if (!(error instanceof ResponsibleAccessError)) throw error;
    throw invalidInvitation(error);
  }
  return Object.freeze({
    displayName,
    role: raw.role,
    locationIds: Object.freeze([...assignment.locationIds]),
  });
}

export function normalizeAdminInvitationEmail(value) {
  if (typeof value !== 'string') return null;
  return value
    .replace(CANONICAL_EDGE_WHITESPACE_PATTERN, '')
    .toLowerCase();
}

function validateEmail(value) {
  if (typeof value !== 'string' || isCanonicalBlankText(value)) {
    throw invalidInvitation();
  }
  const normalized = normalizeAdminInvitationEmail(value);
  if (
    normalized.length > MAX_EMAIL_LENGTH
    || !EMAIL_PATTERN.test(normalized)
  ) throw invalidInvitation();
  return normalized;
}

function requiredNonBlankText(value) {
  if (typeof value !== 'string' || isCanonicalBlankText(value)) {
    throw invalidInvitation();
  }
  return value;
}

function requiredDate(value, message) {
  let date;
  if (value instanceof Date) {
    date = value;
  } else if (value && typeof value.toDate === 'function') {
    try {
      date = value.toDate();
    } catch {
      throw invalidInvitation();
    }
  }
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    if (message) throw new TypeError(message);
    throw invalidInvitation();
  }
  return new Date(date.getTime());
}

function validateNotificationStatus(raw) {
  if (!Object.hasOwn(raw, 'notificationStatus')) return null;
  const value = raw.notificationStatus;
  if (typeof value !== 'string' || !Object.hasOwn(NOTIFICATION_FIELDS, value)) {
    throw invalidInvitation();
  }
  return value;
}

function validateNotificationFields(raw, status, {acceptedAt, now}) {
  if (status === null || status === 'pending') {
    return status === null ? {} : {notificationStatus: status};
  }
  if (status === 'sending') {
    const result = {notificationStatus: status};
    copyOptionalText(raw, result, 'notificationAttemptId');
    copyOptionalDate(raw, result, 'notificationReservedAt');
    copyOptionalDate(raw, result, 'notificationLeaseExpiresAt');
    if (
      result.notificationReservedAt
      && (
        result.notificationReservedAt < acceptedAt
        || result.notificationReservedAt > now
      )
    ) {
      throw invalidInvitation();
    }
    if (
      result.notificationReservedAt
      && result.notificationLeaseExpiresAt
      && result.notificationLeaseExpiresAt <= result.notificationReservedAt
    ) throw invalidInvitation();
    return result;
  }
  if (status === 'failed') {
    const result = {notificationStatus: status};
    if (Object.hasOwn(raw, 'notificationErrorCode')) {
      const value = raw.notificationErrorCode;
      if (
        typeof value !== 'string'
        || !NOTIFICATION_ERROR_CODE_PATTERN.test(value)
      ) {
        throw invalidInvitation();
      }
      result.notificationErrorCode = value;
    }
    copyOptionalDate(raw, result, 'notificationFailedAt');
    if (
      result.notificationFailedAt
      && (
        result.notificationFailedAt < acceptedAt
        || result.notificationFailedAt > now
      )
    ) throw invalidInvitation();
    return result;
  }
  const result = {notificationStatus: status};
  copyOptionalDate(raw, result, 'notificationSentAt');
  copyOptionalText(raw, result, 'notificationProvider');
  copyOptionalText(raw, result, 'notificationProviderMessageId');
  if (
    result.notificationSentAt
    && (result.notificationSentAt < acceptedAt || result.notificationSentAt > now)
  ) throw invalidInvitation();
  return result;
}

function copyOptionalText(source, target, field) {
  if (!Object.hasOwn(source, field)) return;
  target[field] = requiredNonBlankText(source[field]);
}

function copyOptionalDate(source, target, field) {
  if (!Object.hasOwn(source, field)) return;
  target[field] = requiredDate(source[field]);
}

function refuseUnknownFields(raw, allowedFields) {
  const allowed = new Set(allowedFields);
  if (Object.keys(raw).some((field) => !allowed.has(field))) {
    throw invalidInvitation();
  }
}

function immutableInvitation(value) {
  return Object.freeze({
    ...value,
    locationIds: Object.freeze([...value.locationIds]),
    createdAt: new Date(value.createdAt.getTime()),
    expiresAt: new Date(value.expiresAt.getTime()),
    ...(value.acceptedAt instanceof Date
      ? {acceptedAt: new Date(value.acceptedAt.getTime())}
      : {}),
    ...(value.provisionedAt instanceof Date
      ? {provisionedAt: new Date(value.provisionedAt.getTime())}
      : {}),
    ...(value.activationLinkGeneratedAt instanceof Date
      ? {
        activationLinkGeneratedAt: new Date(
          value.activationLinkGeneratedAt.getTime(),
        ),
      }
      : {}),
    ...(value.notificationReservedAt instanceof Date
      ? {notificationReservedAt: new Date(value.notificationReservedAt)}
      : {}),
    ...(value.notificationLeaseExpiresAt instanceof Date
      ? {notificationLeaseExpiresAt: new Date(value.notificationLeaseExpiresAt)}
      : {}),
    ...(value.notificationFailedAt instanceof Date
      ? {notificationFailedAt: new Date(value.notificationFailedAt)}
      : {}),
    ...(value.notificationSentAt instanceof Date
      ? {notificationSentAt: new Date(value.notificationSentAt)}
      : {}),
  });
}

function isPlainObject(value) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return false;
  }
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function invalidInvitation(cause) {
  return new AdminInvitationValidationError(
    AdminInvitationValidationCode.invalid,
    'Le document d’invitation est invalide.',
    {cause},
  );
}

function expiredInvitation() {
  return new AdminInvitationValidationError(
    AdminInvitationValidationCode.expired,
    'L’invitation a expiré.',
  );
}

function cancelledInvitation() {
  return new AdminInvitationValidationError(
    AdminInvitationValidationCode.cancelled,
    'L’invitation a été annulée.',
  );
}
