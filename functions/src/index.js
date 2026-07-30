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
  createServerNotificationService,
} from './notifications/create_notification_service.js';

if (getApps().length === 0) initializeApp();

const appUrl = defineString('MOBSANTE_APP_URL');
const emailFrom = defineString('MOBSANTE_EMAIL_FROM');
const emailFromName = defineString('MOBSANTE_EMAIL_FROM_NAME', {default: ''});
const emailReplyTo = defineString('MOBSANTE_EMAIL_REPLY_TO', {default: ''});
const notificationMode = defineString('MOBSANTE_NOTIFICATION_MODE');
const resendApiKey = process.env.MOBSANTE_NOTIFICATION_MODE === 'fake'
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
      const isEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
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
    deleteUser: (uid) => auth.deleteUser(uid),
    generatePasswordResetLink: (email, settings) =>
      auth.generatePasswordResetLink(email, settings),
    async commitProvisioning({
      invitationId,
      targetUid,
      expectedInvitation,
      role,
      timestamps,
    }) {
      if (shouldFailCommit(invitationId)) {
        throw new Error('Injected emulator-only commit failure');
      }
      await firestore.runTransaction(async (transaction) => {
        const invitationRef = firestore
          .collection('adminInvitations')
          .doc(invitationId);
        const roleRef = firestore.collection('roles').doc(targetUid);
        const [invitationSnapshot, roleSnapshot] = await Promise.all([
          transaction.get(invitationRef),
          transaction.get(roleRef),
        ]);
        const current = invitationSnapshot.data();
        if (
          !invitationSnapshot.exists
          || current.status !== 'pending'
          || current.email !== expectedInvitation.email
        ) {
          throw new ProvisioningError(
            'aborted',
            'L’invitation a changé pendant le provisionnement.',
          );
        }
        const existingRole = roleSnapshot.exists ? roleSnapshot.data() : null;
        if (existingRole && !compatibleRole(existingRole, role)) {
          throw new ProvisioningError(
            'already-exists',
            'Un rôle incompatible existe déjà.',
          );
        }
        transaction.set(
          roleRef,
          {
            role: role.role,
            locationIds: role.locationIds,
            active: true,
            createdAt: existingRole?.createdAt ?? FieldValue.serverTimestamp(),
            createdBy: existingRole?.createdBy ?? role.createdBy,
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
          notificationErrorCode: FieldValue.delete(),
          notificationFailedAt: FieldValue.delete(),
        });
      });
    },
    async markNotificationSent({
      invitationId,
      targetUid,
      provider,
      providerMessageId,
      sentAt,
    }) {
      await updateNotificationState({
        firestore,
        invitationId,
        targetUid,
        values: {
          notificationStatus: 'sent',
          notificationSentAt: sentAt,
          notificationProvider: provider,
          notificationProviderMessageId: providerMessageId,
          notificationErrorCode: FieldValue.delete(),
          notificationFailedAt: FieldValue.delete(),
        },
      });
    },
    async markNotificationFailed({
      invitationId,
      targetUid,
      errorCode,
      failedAt,
    }) {
      await updateNotificationState({
        firestore,
        invitationId,
        targetUid,
        values: {
          notificationStatus: 'failed',
          notificationErrorCode: errorCode,
          notificationFailedAt: failedAt,
          notificationSentAt: FieldValue.delete(),
          notificationProvider: FieldValue.delete(),
          notificationProviderMessageId: FieldValue.delete(),
        },
      });
    },
  };
}

async function updateNotificationState({
  firestore,
  invitationId,
  targetUid,
  values,
}) {
  const invitationRef = firestore
    .collection('adminInvitations')
    .doc(invitationId);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(invitationRef);
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
    transaction.update(invitationRef, values);
  });
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

function compatibleRole(existing, expected) {
  const left = [...(existing.locationIds ?? [])].sort();
  const right = [...expected.locationIds].sort();
  return existing.role === expected.role
    && existing.active === true
    && left.length === right.length
    && left.every((value, index) => value === right[index]);
}
