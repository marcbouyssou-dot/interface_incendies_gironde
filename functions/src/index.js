import {getApps, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {defineSecret, defineString} from 'firebase-functions/params';

import {
  ProvisioningError,
  provisionAdminInvitation as provision,
} from './provision_admin_invitation.js';
import {
  hasActiveCoordinatorRole,
  mergeResponsibleAccess,
  normalizeRequestedAssignment,
  parseResponsibleAccess,
} from './responsible_access.js';
import {
  createServerNotificationService,
} from './notifications/create_notification_service.js';

if (getApps().length === 0) initializeApp();

const appUrl = defineString('MOBSANTE_APP_URL');
const emailFrom = defineString('MOBSANTE_EMAIL_FROM');
const emailFromName = defineString('MOBSANTE_EMAIL_FROM_NAME', {default: ''});
const emailReplyTo = defineString('MOBSANTE_EMAIL_REPLY_TO', {default: ''});
const notificationMode = defineString('MOBSANTE_NOTIFICATION_MODE');
const isFunctionsEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
const resendApiKey = isFunctionsEmulator
  ? null
  : defineSecret('RESEND_API_KEY');
const injectedEmulatorFailures = new Set();
const injectedEmulatorNotificationFailures = new Set();

export const provisionAdminInvitation = onCall(
  {
    region: 'europe-west1',
    secrets: resendApiKey === null ? [] : [resendApiKey],
  },
  async (request) => {
    try {
      const firestore = getFirestore();
      const auth = getAuth();
      const isEmulator = isFunctionsEmulator;
      const configuredAppUrl = appUrl.value();
      const configuredNotificationMode = notificationMode.value();
      if (
        (configuredNotificationMode === 'fake' && !isEmulator)
        || !new Set(['fake', 'resend']).has(configuredNotificationMode)
      ) {
        throw new ProvisioningError(
          'failed-precondition',
          'Mode de notification serveur invalide.',
        );
      }
      return await provision({
        invitationId: request.data?.invitationId,
        callerUid: request.auth?.uid,
        appUrl: configuredAppUrl,
        notificationService: createServerNotificationService({
          mode: configuredNotificationMode === 'fake' ? 'emulator' : 'real',
          emulatorFailure: emulatorNotificationFailure(
            request.data?.invitationId,
          ),
          configuration: isEmulator ? undefined : {
            apiKey: resendApiKey?.value(),
            fromEmail: emailFrom.value(),
            fromName: emailFromName.value(),
            replyTo: emailReplyTo.value(),
            appUrl: configuredAppUrl,
          },
        }),
        services: adminServices({
          firestore,
          auth,
          shouldFailCommit: emulatorCommitFailure,
        }),
      });
    } catch (error) {
      if (error instanceof ProvisioningError) {
        throw new HttpsError(error.code, error.message);
      }
      console.error('ADMIN_INVITATION_PROVISIONING_FAILED', {
        type: error?.constructor?.name ?? 'Unknown',
      });
      throw new HttpsError('internal', 'Le compte n’a pas pu être préparé.');
    }
  },
);

export function adminServices({
  firestore,
  auth,
  shouldFailCommit = () => false,
}) {
  return {
    async getRole(uid) {
      const snapshot = await firestore.collection('roles').doc(uid).get();
      return snapshot.exists ? snapshot.data() : null;
    },
    async getInvitation(id) {
      const snapshot = await firestore
        .collection('adminInvitations')
        .doc(id)
        .get();
      return snapshot.exists ? snapshot.data() : null;
    },
    getUserByEmail: (email) => auth.getUserByEmail(email),
    createUser: (properties) => auth.createUser(properties),
    generatePasswordResetLink: (email, settings) =>
      auth.generatePasswordResetLink(email, settings),
    async commitProvisioning({
      invitationId,
      targetUid,
      expectedInvitation,
      createdBy,
      timestamps,
    }) {
      if (shouldFailCommit(invitationId)) {
        throw new Error('Injected emulator-only commit failure');
      }
      return firestore.runTransaction(async (transaction) => {
        const invitationRef = firestore
          .collection('adminInvitations')
          .doc(invitationId);
        const roleRef = firestore.collection('roles').doc(targetUid);
        const callerRoleRef = firestore.collection('roles').doc(createdBy);
        const [invitationSnapshot, roleSnapshot, callerRoleSnapshot] =
          await Promise.all([
            transaction.get(invitationRef),
            transaction.get(roleRef),
            transaction.get(callerRoleRef),
          ]);
        if (
          !callerRoleSnapshot.exists
          || !hasActiveCoordinatorRole(callerRoleSnapshot.data())
        ) {
          throw new ProvisioningError(
            'permission-denied',
            'Accès coordinateur actif requis.',
          );
        }
        const current = invitationSnapshot.data();
        const existingRole = roleSnapshot.exists ? roleSnapshot.data() : null;
        if (
          invitationSnapshot.exists
          && current.status === 'accepted'
          && current.acceptedUid === targetUid
          && current.email === expectedInvitation.email
          && current.role === expectedInvitation.role
          && sameRequestedLocations(current, expectedInvitation)
          && existingRole !== null
          && hasProvisionedAssignment(existingRole, current)
        ) {
          return {state: 'already-provisioned'};
        }
        if (
          !invitationSnapshot.exists
          || current.status !== 'pending'
          || current.email !== expectedInvitation.email
          || current.role !== expectedInvitation.role
          || !sameRequestedLocations(current, expectedInvitation)
        ) {
          throw new ProvisioningError(
            'aborted',
            'L’invitation a changé pendant le provisionnement.',
          );
        }
        const mergedRole = mergeResponsibleAccess(existingRole, current);
        transaction.set(
          roleRef,
          {
            ...(existingRole ?? {}),
            role: mergedRole.role,
            roles: [...mergedRole.roles],
            locationIds: [...mergedRole.locationIds],
            active: mergedRole.active,
            schemaVersion: mergedRole.schemaVersion,
            createdAt: existingRole?.createdAt ?? FieldValue.serverTimestamp(),
            createdBy: existingRole?.createdBy ?? createdBy,
            updatedAt: FieldValue.serverTimestamp(),
          },
          {merge: false},
        );
        transaction.update(invitationRef, {
          status: 'accepted',
          acceptedUid: targetUid,
          acceptedAt: timestamps.acceptedAt,
          provisionedAt: timestamps.provisionedAt,
          activationLinkGeneratedAt: timestamps.activationLinkGeneratedAt,
          notificationStatus: 'pending',
          notificationAttemptId: FieldValue.delete(),
          notificationReservedAt: FieldValue.delete(),
          notificationLeaseExpiresAt: FieldValue.delete(),
          notificationSentAt: FieldValue.delete(),
          notificationProvider: FieldValue.delete(),
          notificationProviderMessageId: FieldValue.delete(),
          notificationErrorCode: FieldValue.delete(),
          notificationFailedAt: FieldValue.delete(),
        });
        return {state: 'provisioned'};
      });
    },
    async reserveNotificationDelivery({
      invitationId,
      targetUid,
      attemptId,
      reservedAt,
      leaseExpiresAt,
    }) {
      const invitationRef = firestore
        .collection('adminInvitations')
        .doc(invitationId);
      const roleRef = firestore.collection('roles').doc(targetUid);
      return firestore.runTransaction(async (transaction) => {
        const [snapshot, roleSnapshot] = await Promise.all([
          transaction.get(invitationRef),
          transaction.get(roleRef),
        ]);
        const current = acceptedInvitation(snapshot, targetUid);
        if (
          !roleSnapshot.exists
          || !hasProvisionedAssignment(roleSnapshot.data(), current)
        ) {
          throw new ProvisioningError(
            'aborted',
            'Le rôle attendu n’est pas attribué.',
          );
        }
        if (current.notificationStatus === 'sent') {
          return {state: 'sent'};
        }
        if (hasActiveNotificationLease(current, reservedAt)) {
          return {state: 'in-progress'};
        }
        transaction.update(invitationRef, {
          notificationStatus: 'sending',
          notificationAttemptId: attemptId,
          notificationReservedAt: reservedAt,
          notificationLeaseExpiresAt: leaseExpiresAt,
          notificationSentAt: FieldValue.delete(),
          notificationProvider: FieldValue.delete(),
          notificationProviderMessageId: FieldValue.delete(),
          notificationErrorCode: FieldValue.delete(),
          notificationFailedAt: FieldValue.delete(),
        });
        return {state: 'reserved'};
      });
    },
    async markNotificationSent({
      invitationId,
      targetUid,
      attemptId,
      provider,
      providerMessageId,
      sentAt,
    }) {
      return finalizeNotificationState({
        firestore,
        invitationId,
        targetUid,
        attemptId,
        values: {
          notificationStatus: 'sent',
          notificationSentAt: sentAt,
          notificationProvider: provider,
          notificationProviderMessageId: providerMessageId,
          notificationAttemptId: FieldValue.delete(),
          notificationReservedAt: FieldValue.delete(),
          notificationLeaseExpiresAt: FieldValue.delete(),
          notificationErrorCode: FieldValue.delete(),
          notificationFailedAt: FieldValue.delete(),
        },
      });
    },
    async markNotificationFailed({
      invitationId,
      targetUid,
      attemptId,
      errorCode,
      failedAt,
    }) {
      return finalizeNotificationState({
        firestore,
        invitationId,
        targetUid,
        attemptId,
        values: {
          notificationStatus: 'failed',
          notificationErrorCode: errorCode,
          notificationFailedAt: failedAt,
          notificationAttemptId: FieldValue.delete(),
          notificationReservedAt: FieldValue.delete(),
          notificationLeaseExpiresAt: FieldValue.delete(),
          notificationSentAt: FieldValue.delete(),
          notificationProvider: FieldValue.delete(),
          notificationProviderMessageId: FieldValue.delete(),
        },
      });
    },
  };
}

async function finalizeNotificationState({
  firestore,
  invitationId,
  targetUid,
  attemptId,
  values,
}) {
  const invitationRef = firestore
    .collection('adminInvitations')
    .doc(invitationId);
  return firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(invitationRef);
    const current = acceptedInvitation(snapshot, targetUid);
    if (current.notificationStatus === 'sent') {
      return {state: 'sent'};
    }
    if (
      current.notificationStatus !== 'sending'
      || current.notificationAttemptId !== attemptId
    ) {
      return {state: 'in-progress'};
    }
    transaction.update(invitationRef, values);
    return {state: values.notificationStatus};
  });
}

function acceptedInvitation(snapshot, targetUid) {
  const current = snapshot.data();
  if (
    !snapshot.exists
    || current.status !== 'accepted'
    || current.acceptedUid !== targetUid
  ) {
    throw new ProvisioningError(
      'aborted',
      'L’invitation a changé pendant la notification.',
    );
  }
  return current;
}

function hasActiveNotificationLease(invitation, now) {
  if (
    invitation.notificationStatus !== 'sending'
    || typeof invitation.notificationAttemptId !== 'string'
    || invitation.notificationAttemptId === ''
  ) {
    return false;
  }
  const leaseExpiresAt = asDate(invitation.notificationLeaseExpiresAt);
  return leaseExpiresAt !== null && leaseExpiresAt > now;
}

function hasProvisionedAssignment(roleDocument, invitation) {
  try {
    const access = parseResponsibleAccess(roleDocument);
    const requested = normalizeRequestedAssignment(invitation);
    return access.active
      && requested.roles.every((role) => access.roles.includes(role))
      && requested.locationIds.every(
        (locationId) => access.locationIds.includes(locationId),
      );
  } catch {
    return false;
  }
}

function asDate(value) {
  if (value instanceof Date) return value;
  if (value && typeof value.toDate === 'function') return value.toDate();
  return null;
}

function emulatorCommitFailure(invitationId) {
  if (process.env.FUNCTIONS_EMULATOR !== 'true') return false;
  const configuredIds = new Set(
    (process.env.MOBSANTE_EMULATOR_FAIL_INVITATION_IDS ?? '')
      .split(',')
      .filter(Boolean),
  );
  if (
    !configuredIds.has(invitationId)
    || injectedEmulatorFailures.has(invitationId)
  ) {
    return false;
  }
  injectedEmulatorFailures.add(invitationId);
  return true;
}

function emulatorNotificationFailure(invitationId) {
  if (process.env.FUNCTIONS_EMULATOR !== 'true') return undefined;
  const configuredIds = new Set(
    (process.env.MOBSANTE_EMULATOR_FAIL_NOTIFICATION_IDS ?? '')
      .split(',')
      .filter(Boolean),
  );
  if (
    !configuredIds.has(invitationId)
    || injectedEmulatorNotificationFailures.has(invitationId)
  ) {
    return undefined;
  }
  injectedEmulatorNotificationFailures.add(invitationId);
  const error = new Error('Injected emulator-only notification failure');
  error.code = 'provider-failure';
  return error;
}

function sameRequestedLocations(current, expected) {
  try {
    const currentAssignment = normalizeRequestedAssignment(current);
    const expectedAssignment = normalizeRequestedAssignment(expected);
    return currentAssignment.role === expectedAssignment.role
      && currentAssignment.locationIds.length
        === expectedAssignment.locationIds.length
      && currentAssignment.locationIds.every(
        (value, index) => value === expectedAssignment.locationIds[index],
      );
  } catch {
    return false;
  }
}
