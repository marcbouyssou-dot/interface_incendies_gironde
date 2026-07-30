import {getApps, initializeApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';
import {FieldValue, getFirestore} from 'firebase-admin/firestore';
import {HttpsError, onCall} from 'firebase-functions/v2/https';
import {defineString} from 'firebase-functions/params';

import {
  PendingAdminInvitationMailer,
  ProvisioningError,
  provisionAdminInvitation as provision,
} from './provision_admin_invitation.js';

if (getApps().length === 0) initializeApp();

const appUrl = defineString('MOBSANTE_APP_URL');

export const provisionAdminInvitation = onCall(
  {region: 'europe-west1'},
  async (request) => {
    try {
      const firestore = getFirestore();
      const auth = getAuth();
      return await provision({
        invitationId: request.data?.invitationId,
        callerUid: request.auth?.uid,
        appUrl: appUrl.value(),
        mailer: new PendingAdminInvitationMailer(),
        services: adminServices({firestore, auth}),
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

export function adminServices({firestore, auth}) {
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
        });
      });
    },
  };
}

function compatibleRole(existing, expected) {
  const left = [...(existing.locationIds ?? [])].sort();
  const right = [...expected.locationIds].sort();
  return existing.role === expected.role
    && existing.active === true
    && left.length === right.length
    && left.every((value, index) => value === right[index]);
}
