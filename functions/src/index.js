import {getApps, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore, Timestamp} from 'firebase-admin/firestore';
import {getMessaging} from 'firebase-admin/messaging';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {onDocumentCreated, onDocumentUpdated} from 'firebase-functions/v2/firestore';
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {defineSecret, defineString} from 'firebase-functions/params';

import {
  normalizeAdminInvitationEmail,
} from './admin_invitation_validation.js';
import {
  AdminInvitationManagementError,
  invitationManagementMutation,
  manageAdminInvitation as manageInvitation,
} from './manage_admin_invitation.js';
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
  listResponsibleAccess as listAccess,
  ResponsibleAccessAdministrationError,
  safeResponsibleAccount,
  updateResponsibleAccess as updateAccess,
} from './update_responsible_access.js';
import {
  createServerNotificationService,
} from './notifications/create_notification_service.js';
import {
  adminLocationRecord,
  listAdminLocations as listLocations,
  LocationAdministrationError,
  locationManagementMutation,
  manageLocation as manageAdminLocation,
} from './location_administration.js';
import {
  MissionUpdateError,
  missionUpdateMutation,
  updateMission as updateExistingMission,
} from './update_mission.js';
import {
  canCoordinateMobilization,
} from './coordinator_mobilization_access.js';
import {verifyRpps} from './ans_rpps_verification.js';
import {
  ProfessionalRppsVerificationError,
  verifyProfessionalRpps as verifyProfessionalRppsRequest,
} from './verify_professional_rpps.js';
import {
  confirmProfessionalRpps as confirmProfessionalRppsRequest,
} from './confirm_professional_rpps.js';
import {
  activateMobilization as activateMobilizationRequest,
  archiveMobilization as archiveMobilizationRequest,
  assignMobilizationCoordinator as assignMobilizationCoordinatorRequest,
  createOperation as createOperationRequest,
  createMobilization as createMobilizationRequest,
  deactivateMobilization as deactivateMobilizationRequest,
  PlatformAdministrationError,
  removeMobilizationCoordinator as removeMobilizationCoordinatorRequest,
  transitionOperation as transitionOperationRequest,
  updateOperation as updateOperationRequest,
  updateMobilization as updateMobilizationRequest,
} from './platform_administration.js';
import {
  platformAdministrationServices,
} from './platform_administration_firestore.js';
import {
  listMissionTeam as listMissionTeamRequest,
  listPlatformCoordinatorIdentities as listPlatformCoordinatorIdentitiesRequest,
  safeCoordinatorIdentity,
  safeProfessionalIdentity,
  UserDisplayIdentityError,
} from './user_display_identity.js';
import {
  engagementCreatedEvents,
  engagementUpdatedEvents,
  missionCreatedEvents,
  missionUpdatedEvents,
} from './operational_notifications/event_factory.js';
import {
  dispatchOperationalEvent,
  persistCanonicalEvents,
  processPendingDeliveries,
} from './operational_notifications/firestore_service.js';

if (getApps().length === 0) initializeApp();

const operationalTriggerOptions = Object.freeze({
  region: 'europe-west1',
  retry: true,
});

export const emitMissionPublished = onDocumentCreated(
  {...operationalTriggerOptions, document: 'missions/{missionId}'},
  async (event) => {
    const mission = {id: event.params.missionId, ...event.data.data()};
    await persistCanonicalEvents({
      firestore: getFirestore(),
      events: missionCreatedEvents({
        mission,
        sourceEventId: event.id,
        occurredAt: eventTimestamp(event),
      }),
    });
  },
);

export const emitMissionChanges = onDocumentUpdated(
  {...operationalTriggerOptions, document: 'missions/{missionId}'},
  async (event) => {
    const before = {id: event.params.missionId, ...event.data.before.data()};
    const after = {id: event.params.missionId, ...event.data.after.data()};
    await persistCanonicalEvents({
      firestore: getFirestore(),
      events: missionUpdatedEvents({
        before,
        after,
        sourceEventId: event.id,
        occurredAt: eventTimestamp(event),
      }),
    });
  },
);

export const emitEngagementCreated = onDocumentCreated(
  {...operationalTriggerOptions, document: 'engagements/{engagementId}'},
  async (event) => {
    const firestore = getFirestore();
    const engagement = {
      id: event.params.engagementId,
      ...event.data.data(),
    };
    const mission = await missionForEngagement(firestore, engagement);
    await persistCanonicalEvents({
      firestore,
      events: engagementCreatedEvents({
        engagement,
        mission,
        sourceEventId: event.id,
        occurredAt: eventTimestamp(event),
      }),
    });
  },
);

export const emitEngagementChanges = onDocumentUpdated(
  {...operationalTriggerOptions, document: 'engagements/{engagementId}'},
  async (event) => {
    const firestore = getFirestore();
    const before = {id: event.params.engagementId, ...event.data.before.data()};
    const after = {id: event.params.engagementId, ...event.data.after.data()};
    const mission = await missionForEngagement(firestore, after);
    await persistCanonicalEvents({
      firestore,
      events: engagementUpdatedEvents({
        before,
        after,
        mission,
        sourceEventId: event.id,
        occurredAt: eventTimestamp(event),
      }),
    });
  },
);

export const dispatchOperationalNotification = onDocumentCreated(
  {...operationalTriggerOptions, document: 'notificationEvents/{eventId}'},
  async (event) => dispatchOperationalEvent({
    firestore: getFirestore(),
    messaging: getMessaging(),
    event: event.data.data(),
  }),
);

export const retryDeferredNotifications = onSchedule(
  {region: 'europe-west1', schedule: 'every 15 minutes', retryCount: 3},
  async () => processPendingDeliveries({
    firestore: getFirestore(),
    messaging: getMessaging(),
  }),
);

function eventTimestamp(event) {
  const date = new Date(event.time);
  return Timestamp.fromDate(Number.isNaN(date.getTime()) ? new Date() : date);
}

async function missionForEngagement(firestore, engagement) {
  const mission = await firestore.collection('missions').doc(engagement.missionId).get();
  return mission.exists ? {id: mission.id, ...mission.data()} : null;
}

const appUrl = defineString('MOBSANTE_APP_URL');
const emailFrom = defineString('MOBSANTE_EMAIL_FROM');
const emailFromName = defineString('MOBSANTE_EMAIL_FROM_NAME', {default: ''});
const emailReplyTo = defineString('MOBSANTE_EMAIL_REPLY_TO', {default: ''});
const notificationMode = defineString('MOBSANTE_NOTIFICATION_MODE');
const isFunctionsEmulator = process.env.FUNCTIONS_EMULATOR === 'true';
const resendApiKey = isFunctionsEmulator
  ? null
  : defineSecret('RESEND_API_KEY');
const ansRppsApiKey = isFunctionsEmulator
  ? null
  : defineSecret('ESANTE_API_KEY');
const injectedEmulatorFailures = new Set();
const injectedEmulatorNotificationFailures = new Set();

export const listResponsibleAccess = onCall(
  {region: 'europe-west1'},
  async (request) => responsibleAccessCallable(() => listAccess({
    callerUid: request.auth?.uid,
    services: responsibleAccessAdministrationServices({
      firestore: getFirestore(),
      auth: getAuth(),
    }),
  })),
);

export const updateResponsibleAccess = onCall(
  {region: 'europe-west1'},
  async (request) => responsibleAccessCallable(() => updateAccess({
    callerUid: request.auth?.uid,
    data: request.data,
    services: responsibleAccessAdministrationServices({
      firestore: getFirestore(),
      auth: getAuth(),
    }),
  })),
);

export const listMissionTeam = onCall(
  {region: 'europe-west1', enforceAppCheck: true},
  async (request) => userDisplayIdentityCallable(() => listMissionTeamRequest({
    callerUid: request.auth?.uid,
    data: request.data,
    services: userDisplayIdentityServices({
      firestore: getFirestore(),
      auth: getAuth(),
    }),
  })),
);

export const listPlatformCoordinatorIdentities = onCall(
  {region: 'europe-west1', enforceAppCheck: true},
  async (request) => userDisplayIdentityCallable(() =>
    listPlatformCoordinatorIdentitiesRequest({
      callerUid: request.auth?.uid,
      services: userDisplayIdentityServices({
        firestore: getFirestore(),
        auth: getAuth(),
      }),
    })),
);

export const manageAdminInvitation = onCall(
  {region: 'europe-west1'},
  async (request) => adminInvitationManagementCallable(() => manageInvitation({
    callerUid: request.auth?.uid,
    data: request.data,
    services: adminInvitationManagementServices({
      firestore: getFirestore(),
    }),
  })),
);

export const listAdminLocations = onCall(
  {region: 'europe-west1'},
  async (request) => locationAdministrationCallable(() => listLocations({
    callerUid: request.auth?.uid,
    services: locationAdministrationServices({firestore: getFirestore()}),
  })),
);

export const manageLocation = onCall(
  {region: 'europe-west1'},
  async (request) => locationAdministrationCallable(() =>
    manageAdminLocation({
      callerUid: request.auth?.uid,
      data: request.data,
      services: locationAdministrationServices({firestore: getFirestore()}),
    })),
);

export const updateMission = onCall(
  {region: 'europe-west1'},
  async (request) => missionUpdateCallable(() => updateExistingMission({
    callerUid: request.auth?.uid,
    data: request.data,
    services: missionUpdateServices({firestore: getFirestore()}),
  })),
);

const platformCallableOptions = Object.freeze({
  region: 'europe-west1',
  enforceAppCheck: true,
});

export const createOperation = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    createOperationRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const updateOperation = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    updateOperationRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const transitionOperation = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    transitionOperationRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const createMobilization = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    createMobilizationRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const updateMobilization = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    updateMobilizationRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const activateMobilization = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    activateMobilizationRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const deactivateMobilization = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    deactivateMobilizationRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const archiveMobilization = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    archiveMobilizationRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const assignMobilizationCoordinator = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    assignMobilizationCoordinatorRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const removeMobilizationCoordinator = onCall(
  platformCallableOptions,
  async (request) => platformAdministrationCallable(() =>
    removeMobilizationCoordinatorRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: platformServices(),
    })),
);

export const verifyProfessionalRpps = onCall(
  {
    region: 'europe-west1',
    enforceAppCheck: true,
    secrets: ansRppsApiKey === null ? [] : [ansRppsApiKey],
  },
  async (request) => professionalRppsVerificationCallable(() =>
    verifyProfessionalRppsRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: {
        verifyRpps: (rpps) => verifyRpps(rpps, {
          apiKey: ansRppsApiKey?.value() ?? process.env.ESANTE_API_KEY,
        }),
      },
    })),
);

export const confirmProfessionalRpps = onCall(
  {
    region: 'europe-west1',
    enforceAppCheck: true,
    secrets: ansRppsApiKey === null ? [] : [ansRppsApiKey],
  },
  async (request) => professionalRppsVerificationCallable(() => {
    const firestore = getFirestore();
    return confirmProfessionalRppsRequest({
      callerUid: request.auth?.uid,
      data: request.data,
      services: {
        verifyRpps: (rpps) => verifyRpps(rpps, {
          apiKey: ansRppsApiKey?.value() ?? process.env.ESANTE_API_KEY,
        }),
        getVolunteerProfile: async (uid) => {
          const snapshot = await firestore.collection('volunteers').doc(uid).get();
          return snapshot.exists ? snapshot.data() : null;
        },
        persistVerifiedProfile: (uid, result, expectedProfession) => {
          const reference = firestore.collection('volunteers').doc(uid);
          return firestore.runTransaction(async (transaction) => {
            const snapshot = await transaction.get(reference);
            if (
              !snapshot.exists
              || snapshot.data()?.profession !== expectedProfession
            ) {
              return false;
            }
            transaction.update(reference, {
              professionalIdType: 'rpps',
              professionalIdValue: result.rpps,
              rpps: result.rpps,
              verificationStatus: 'verified',
              verificationSource: 'ans_rpps',
              verifiedFirstName: result.firstName,
              verifiedLastName: result.lastName,
              verifiedProfessionCode: result.professionCode,
              verifiedProfessionLabel: result.professionLabel,
              verifiedAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });
            return true;
          });
        },
      },
    });
  }),
);

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
        resend: request.data?.resend ?? false,
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
          && normalizeAdminInvitationEmail(current.email)
            === expectedInvitation.email
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
          || normalizeAdminInvitationEmail(current.email)
            !== expectedInvitation.email
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
      forceResend,
      activationLinkGeneratedAt,
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
        if (current.notificationStatus === 'sent' && !forceResend) {
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
          ...(forceResend ? {activationLinkGeneratedAt} : {}),
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

export function responsibleAccessAdministrationServices({firestore, auth}) {
  return {
    async commitResponsibleAccessUpdate({
      callerUid,
      targetUid,
      role,
      roles,
      locationIds,
      active,
      schemaVersion,
    }) {
      return firestore.runTransaction(async (transaction) => {
        const callerRef = firestore.collection('roles').doc(callerUid);
        const targetRef = firestore.collection('roles').doc(targetUid);
        const [callerSnapshot, targetSnapshot] = await Promise.all([
          transaction.get(callerRef),
          transaction.get(targetRef),
        ]);
        if (
          !callerSnapshot.exists
          || !hasActiveCoordinatorRole(callerSnapshot.data())
        ) {
          throw new ResponsibleAccessAdministrationError(
            'permission-denied',
            'Accès coordinateur actif requis.',
          );
        }
        if (!targetSnapshot.exists) {
          throw new ResponsibleAccessAdministrationError(
            'not-found',
            'Compte responsable introuvable.',
          );
        }
        const existing = targetSnapshot.data();
        try {
          parseResponsibleAccess(existing);
        } catch {
          throw new ResponsibleAccessAdministrationError(
            'failed-precondition',
            'Le compte responsable existant est invalide.',
          );
        }
        transaction.set(targetRef, {
          ...existing,
          role,
          roles: [...roles],
          locationIds: [...locationIds],
          active,
          schemaVersion,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: false});
        return {
          account: safeResponsibleAccount(targetUid, {
            role,
            roles: [...roles],
            locationIds: [...locationIds],
            active,
            schemaVersion,
          }),
        };
      });
    },
    async listResponsibleAccounts({callerUid}) {
      const snapshots = await firestore.runTransaction(async (transaction) => {
        const callerRef = firestore.collection('roles').doc(callerUid);
        const callerSnapshot = await transaction.get(callerRef);
        if (
          !callerSnapshot.exists
          || !hasActiveCoordinatorRole(callerSnapshot.data())
        ) {
          throw new ResponsibleAccessAdministrationError(
            'permission-denied',
            'Accès coordinateur actif requis.',
          );
        }
        return transaction.get(firestore.collection('roles'));
      });
      const documents = snapshots.docs.flatMap((snapshot) => {
        try {
          parseResponsibleAccess(snapshot.data());
          return [{uid: snapshot.id, data: snapshot.data()}];
        } catch {
          return [];
        }
      }).sort((left, right) => left.uid.localeCompare(right.uid));
      const identities = new Map();
      for (let start = 0; start < documents.length; start += 100) {
        const batch = documents.slice(start, start + 100);
        const result = await auth.getUsers(batch.map(({uid}) => ({uid})));
        for (const user of result.users) identities.set(user.uid, user);
      }
      return documents.map(({uid, data}) =>
        safeResponsibleAccount(uid, data, identities.get(uid)));
    },
  };
}

export function adminInvitationManagementServices({firestore}) {
  return {
    async commitAdminInvitationManagement({
      callerUid,
      invitationId,
      action,
      update,
      expiresAt,
      now,
    }) {
      return firestore.runTransaction(async (transaction) => {
        const callerRef = firestore.collection('roles').doc(callerUid);
        const invitationRef = firestore
          .collection('adminInvitations')
          .doc(invitationId);
        const [callerSnapshot, invitationSnapshot] = await Promise.all([
          transaction.get(callerRef),
          transaction.get(invitationRef),
        ]);
        if (
          !callerSnapshot.exists
          || !hasActiveCoordinatorRole(callerSnapshot.data())
        ) {
          throw new AdminInvitationManagementError(
            'permission-denied',
            'Accès coordinateur actif requis.',
          );
        }
        if (!invitationSnapshot.exists) {
          throw new AdminInvitationManagementError(
            'not-found',
            'Invitation introuvable.',
          );
        }
        const mutation = invitationManagementMutation({
          invitation: invitationSnapshot.data(),
          action,
          update,
          expiresAt,
          now,
        });
        if (mutation.kind === 'delete') {
          transaction.delete(invitationRef);
        } else {
          transaction.update(invitationRef, mutation.fields);
        }
        return mutation.result;
      });
    },
  };
}

export function locationAdministrationServices({firestore}) {
  return {
    async listAdminLocations({callerUid}) {
      const [caller, locations, missions, roles, invitations] =
        await Promise.all([
          firestore.collection('roles').doc(callerUid).get(),
          firestore.collection('locations').get(),
          firestore.collection('missions').get(),
          firestore.collection('roles').get(),
          firestore.collection('adminInvitations').get(),
        ]);
      requireActiveCoordinator(caller);
      const referencedIds = new Set();
      const referencedNames = new Set();
      for (const mission of missions.docs) {
        const data = mission.data();
        if (typeof data.locationId === 'string') {
          referencedIds.add(data.locationId);
        }
        if (typeof data.place === 'string') referencedNames.add(data.place);
      }
      for (const snapshot of [roles, invitations]) {
        for (const document of snapshot.docs) {
          const locationIds = document.data().locationIds;
          if (!Array.isArray(locationIds)) continue;
          for (const id of locationIds) {
            if (typeof id === 'string') referencedIds.add(id);
          }
        }
      }
      return locations.docs
        .map((document) => adminLocationRecord(
          document.id,
          document.data(),
          {
            used: referencedIds.has(document.id)
              || referencedNames.has(document.data().name),
          },
        ))
        .sort((left, right) => left.name.localeCompare(right.name, 'fr'));
    },

    async commitLocationManagement({
      callerUid,
      action,
      locationId,
      data,
    }) {
      return firestore.runTransaction(async (transaction) => {
        const callerRef = firestore.collection('roles').doc(callerUid);
        const locationRef = firestore.collection('locations').doc(locationId);
        const [caller, location] = await Promise.all([
          transaction.get(callerRef),
          transaction.get(locationRef),
        ]);
        requireActiveCoordinator(caller);
        let used = false;
        if (action === 'delete' && location.exists) {
          const name = location.data().name;
          const queries = [
            firestore.collection('missions')
              .where('locationId', '==', locationId).limit(1),
            firestore.collection('roles')
              .where('locationIds', 'array-contains', locationId).limit(1),
            firestore.collection('adminInvitations')
              .where('locationIds', 'array-contains', locationId).limit(1),
          ];
          if (typeof name === 'string' && name !== '') {
            queries.push(
              firestore.collection('missions').where('place', '==', name)
                .limit(1),
            );
          }
          const references = await Promise.all(
            queries.map((query) => transaction.get(query)),
          );
          used = references.some((snapshot) => !snapshot.empty);
        }
        const mutation = locationManagementMutation({
          action,
          locationId,
          data,
          current: location.exists ? location.data() : null,
          used,
        });
        if (mutation.kind === 'create') {
          transaction.create(locationRef, mutation.fields);
        } else if (mutation.kind === 'update') {
          transaction.update(locationRef, mutation.fields);
        } else {
          transaction.delete(locationRef);
        }
        return {
          action,
          location: mutation.kind === 'delete'
            ? null
            : adminLocationRecord(
              locationId,
              {...(location.data() ?? {}), ...mutation.fields},
            ),
        };
      });
    },
  };
}

export function missionUpdateServices({firestore}) {
  return {
    async commitMissionUpdate({callerUid, missionId, ...request}) {
      return firestore.runTransaction(async (transaction) => {
        const callerRef = firestore.collection('roles').doc(callerUid);
        const missionRef = firestore.collection('missions').doc(missionId);
        const destinationRef = firestore
          .collection('locations')
          .doc(request.locationId);
        const engagementsQuery = firestore
          .collection('engagements')
          .where('missionId', '==', missionId);
        const [caller, mission, destination, engagements] = await Promise.all([
          transaction.get(callerRef),
          transaction.get(missionRef),
          transaction.get(destinationRef),
          transaction.get(engagementsQuery),
        ]);
        const missionData = mission.exists ? mission.data() : null;
        const mobilizationId = missionData?.mobilizationId;
        const validMobilizationId = typeof mobilizationId === 'string'
          && mobilizationId !== ''
          && !mobilizationId.includes('/');
        const [mobilization, coordinatorAssignment, platformConfig] =
          validMobilizationId
            ? await Promise.all([
              transaction.get(
                firestore.collection('mobilizations').doc(mobilizationId),
              ),
              transaction.get(
                firestore.collection('mobilizationAssignments')
                  .doc(`${mobilizationId}_${callerUid}`),
              ),
              transaction.get(firestore.collection('platform').doc('config')),
            ])
            : [null, null, null];
        const assignmentData = coordinatorAssignment?.exists
          ? coordinatorAssignment.data()
          : null;
        const mobilizationData = mobilization?.exists
          ? mobilization.data()
          : null;
        const callerRole = caller.exists ? caller.data() : null;
        const mutation = missionUpdateMutation({
          request: {missionId, ...request},
          mission: missionData,
          mobilization: mobilizationData,
          coordinatorAuthorized: canCoordinateMobilization({
            uid: callerUid,
            role: callerRole,
            assignment: assignmentData,
            mobilization: mobilizationData,
            platformConfig: platformConfig?.exists
              ? platformConfig.data()
              : null,
          }),
          destination: destination.exists ? destination.data() : null,
          callerRole,
          engagements: engagements.docs.map((document) => document.data()),
          serverTimestamp: FieldValue.serverTimestamp(),
          timestampFromMillis: (value) => new Date(value),
        });
        transaction.update(missionRef, mutation.fields);
        return {missionId};
      });
    },
  };
}

async function responsibleAccessCallable(action) {
  try {
    return await action();
  } catch (error) {
    if (error instanceof ResponsibleAccessAdministrationError) {
      throw new HttpsError(error.code, error.message);
    }
    console.error('RESPONSIBLE_ACCESS_ADMINISTRATION_FAILED', {
      type: error?.constructor?.name ?? 'Unknown',
    });
    throw new HttpsError(
      'internal',
      'La gestion de l’accès responsable a échoué.',
    );
  }
}

async function adminInvitationManagementCallable(action) {
  try {
    return await action();
  } catch (error) {
    if (error instanceof AdminInvitationManagementError) {
      throw new HttpsError(error.code, error.message);
    }
    console.error('ADMIN_INVITATION_MANAGEMENT_FAILED', {
      type: error?.constructor?.name ?? 'Unknown',
    });
    throw new HttpsError(
      'internal',
      'La gestion de l’invitation a échoué.',
    );
  }
}

async function locationAdministrationCallable(action) {
  try {
    return await action();
  } catch (error) {
    if (error instanceof LocationAdministrationError) {
      throw new HttpsError(error.code, error.message);
    }
    console.error('LOCATION_ADMINISTRATION_FAILED', {
      type: error?.constructor?.name ?? 'Unknown',
    });
    throw new HttpsError('internal', 'La gestion du lieu a échoué.');
  }
}

async function missionUpdateCallable(action) {
  try {
    return await action();
  } catch (error) {
    if (error instanceof MissionUpdateError) {
      throw new HttpsError(error.code, error.message);
    }
    console.error('MISSION_UPDATE_FAILED', {
      type: error?.constructor?.name ?? 'Unknown',
    });
    throw new HttpsError('internal', 'La mission n’a pas pu être mise à jour.');
  }
}

function platformServices() {
  return platformAdministrationServices({
    firestore: getFirestore(),
    serverTimestamp: FieldValue.serverTimestamp,
  });
}

export function userDisplayIdentityServices({firestore, auth}) {
  return {
    async listMissionTeam({callerUid, missionId}) {
      const [callerSnapshot, missionSnapshot] = await Promise.all([
        firestore.collection('roles').doc(callerUid).get(),
        firestore.collection('missions').doc(missionId).get(),
      ]);
      if (!callerSnapshot.exists || !missionSnapshot.exists) {
        throw new UserDisplayIdentityError(
          'permission-denied',
          'Accès à cette équipe refusé.',
        );
      }
      let access;
      try {
        access = parseResponsibleAccess(callerSnapshot.data());
      } catch {
        throw new UserDisplayIdentityError(
          'permission-denied',
          'Accès à cette équipe refusé.',
        );
      }
      const mission = missionSnapshot.data();
      const mobilizationId = mission.mobilizationId;
      if (typeof mobilizationId !== 'string' || mobilizationId === '') {
        throw new UserDisplayIdentityError(
          'permission-denied',
          'Accès à cette équipe refusé.',
        );
      }
      const [mobilizationSnapshot, assignmentSnapshot, platformConfig] =
        await Promise.all([
          firestore.collection('mobilizations').doc(mobilizationId).get(),
          firestore.collection('mobilizationAssignments')
            .doc(`${mobilizationId}_${callerUid}`).get(),
          firestore.collection('platform').doc('config').get(),
        ]);
      const assignment = assignmentSnapshot.data();
      const mobilization = mobilizationSnapshot.data();
      const canReadTerritory = canCoordinateMobilization({
        uid: callerUid,
        role: callerSnapshot.data(),
        assignment: assignmentSnapshot.exists ? assignment : null,
        mobilization: mobilizationSnapshot.exists ? mobilization : null,
        platformConfig: platformConfig.exists ? platformConfig.data() : null,
      });
      const canReadLocation = access.active
        && access.roles.includes('site_manager')
        && access.locationIds.includes(mission.locationId);
      if (
        (!canReadTerritory && !canReadLocation)
        || !mobilizationSnapshot.exists
        || mobilization?.status !== 'active'
        || mission.isActive !== true
      ) {
        throw new UserDisplayIdentityError(
          'permission-denied',
          'Accès à cette équipe refusé.',
        );
      }
      const engagementsSnapshot = await firestore
        .collection('engagements')
        .where('missionId', '==', missionId)
        .where('mobilizationId', '==', mobilizationId)
        .get();
      const engagements = engagementsSnapshot.docs.map((snapshot) =>
        snapshot.data());
      const volunteerIds = [...new Set(engagements
        .map((engagement) => engagement.volunteerId)
        .filter((uid) => typeof uid === 'string' && uid !== ''))];
      const profiles = new Map();
      if (volunteerIds.length > 0) {
        const snapshots = await firestore.getAll(...volunteerIds.map((uid) =>
          firestore.collection('volunteers').doc(uid)));
        for (const snapshot of snapshots) {
          if (snapshot.exists) profiles.set(snapshot.id, snapshot.data());
        }
      }
      return engagements.map((engagement) => safeProfessionalIdentity({
        engagement,
        profile: profiles.get(engagement.volunteerId),
      }));
    },

    async listPlatformCoordinators({callerUid}) {
      const administrator = await firestore
        .collection('platformAdministrators')
        .doc(callerUid)
        .get();
      if (!administrator.exists || administrator.data()?.active !== true) {
        throw new UserDisplayIdentityError(
          'permission-denied',
          'Accès Administrateur plateforme requis.',
        );
      }
      const rolesSnapshot = await firestore.collection('roles').get();
      const coordinators = rolesSnapshot.docs.flatMap((snapshot) => {
        try {
          const access = parseResponsibleAccess(snapshot.data());
          return access.roles.includes('coordinator')
            ? [{uid: snapshot.id, access}]
            : [];
        } catch {
          return [];
        }
      });
      const identities = new Map();
      for (let start = 0; start < coordinators.length; start += 100) {
        const batch = coordinators.slice(start, start + 100);
        const result = await auth.getUsers(
          batch.map(({uid}) => ({uid})),
        );
        for (const user of result.users) identities.set(user.uid, user);
      }
      return coordinators.map(({uid}) => safeCoordinatorIdentity({
        uid,
        identity: identities.get(uid),
        organizationLabel: 'Périmètre départemental',
      }));
    },
  };
}

async function platformAdministrationCallable(action) {
  try {
    return await action();
  } catch (error) {
    if (error instanceof PlatformAdministrationError) {
      throw new HttpsError(error.code, error.message);
    }
    console.error('PLATFORM_ADMINISTRATION_FAILED', {
      type: error?.constructor?.name ?? 'Unknown',
    });
    throw new HttpsError(
      'internal',
      'L’administration de la plateforme a échoué.',
    );
  }
}

async function userDisplayIdentityCallable(action) {
  try {
    return await action();
  } catch (error) {
    if (error instanceof UserDisplayIdentityError) {
      throw new HttpsError(error.code, error.message);
    }
    console.error('USER_DISPLAY_IDENTITY_FAILED', {
      type: error?.constructor?.name ?? 'Unknown',
    });
    throw new HttpsError(
      'internal',
      'Les identités ne sont pas disponibles pour le moment.',
    );
  }
}

async function professionalRppsVerificationCallable(action) {
  try {
    return await action();
  } catch (error) {
    if (error instanceof ProfessionalRppsVerificationError) {
      throw new HttpsError(error.code, error.message);
    }
    console.error('PROFESSIONAL_RPPS_VERIFICATION_FAILED', {
      type: error?.constructor?.name ?? 'Unknown',
    });
    throw new HttpsError(
      'internal',
      'La vérification RPPS n’a pas pu être exécutée.',
    );
  }
}

function requireActiveCoordinator(snapshot) {
  if (!snapshot.exists || !hasActiveCoordinatorRole(snapshot.data())) {
    throw new LocationAdministrationError(
      'permission-denied',
      'Accès coordinateur actif requis.',
    );
  }
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
