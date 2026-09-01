import {createHash} from 'node:crypto';

import {FieldValue} from 'firebase-admin/firestore';

import {isPlatformAdministrator} from './platform_administration.js';

const REQUIRED_FIELDS = Object.freeze(['confirmation', 'installationId']);
const SEND_CONFIRMATION = 'SEND_ONE_TEST_PUSH';
const CHECK_CONFIRMATION = 'CHECK_TEST_PUSH';
const TEST_TITLE = 'MobSanté — Test notification';
const TEST_BODY = 'Votre appareil peut recevoir les notifications MobSanté.';
const INVALID_TOKEN_CODE = 'messaging/registration-token-not-registered';

export class TargetedPushTestError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'TargetedPushTestError';
    this.code = code;
  }
}

export async function sendTargetedPushTest({callerUid, data, services}) {
  requireCaller(callerUid);
  const {confirmation, installationId} = validateRequest(data);
  requireServices(services);
  if (confirmation === CHECK_CONFIRMATION) {
    await services.check({callerUid, installationId});
    return {available: true};
  }
  const claim = await services.claim({callerUid, installationId});
  let providerMessageId;
  try {
    providerMessageId = await services.send({
      token: claim.token,
      data: {
        title: TEST_TITLE,
        body: TEST_BODY,
        notificationId: 'push-test',
        url: '/',
      },
    });
    if (typeof providerMessageId !== 'string' || providerMessageId === '') {
      throw new TargetedPushTestError(
        'internal',
        'Le fournisseur Push n’a retourné aucune preuve.',
      );
    }
  } catch (error) {
    try {
      await services.fail({
        dispatchId: claim.dispatchId,
        subscriptionId: claim.subscriptionId,
        errorCode: normalizeErrorCode(error),
      });
    } catch (_) {
      // The original provider failure remains authoritative.
    }
    throw error;
  }
  await services.complete({dispatchId: claim.dispatchId});
  return {sent: true};
}

export function targetedPushTestServices({
  firestore,
  messaging,
  serverTimestamp = () => FieldValue.serverTimestamp(),
}) {
  return {
    async check({callerUid, installationId}) {
      await firestore.runTransaction(async (transaction) => {
        await resolveActiveWebSubscription({
          transaction,
          firestore,
          callerUid,
          installationId,
        });
      });
    },
    async claim({callerUid, installationId}) {
      const result = await firestore.runTransaction(async (transaction) => {
        const resolved = await resolveActiveWebSubscription({
          transaction,
          firestore,
          callerUid,
          installationId,
        });
        const {
          subscriptionId,
          subscriptionRef,
          token,
          relatedSubscriptionIds,
        } = resolved;
        const dispatchId = installationDispatchId(installationId);
        const dispatchRef = firestore
            .collection('pushTestDispatches').doc(dispatchId);
        const legacyDispatchRefs = relatedSubscriptionIds.map((id) =>
          firestore.collection('pushTestDispatches').doc(id),
        );
        const [existingDispatch, ...legacyDispatches] = await Promise.all([
          transaction.get(dispatchRef),
          ...legacyDispatchRefs.map((ref) => transaction.get(ref)),
        ]);
        const tokenFingerprint = fingerprint(token);
        const timestamp = serverTimestamp();
        const previousDispatches = [
          {snapshot: existingDispatch, ref: dispatchRef},
          ...legacyDispatches.map((snapshot, index) => ({
            snapshot,
            ref: legacyDispatchRefs[index],
          })),
        ].filter(({snapshot}) => snapshot.exists);
        for (const {snapshot} of previousDispatches) {
          const current = snapshot.data();
          if (current?.status !== 'failed') {
            throw alreadyConsumed();
          }
        }
        for (const {snapshot, ref} of previousDispatches) {
          const current = snapshot.data();
          const previousFingerprint = current?.tokenFingerprint;
          if (
            typeof previousFingerprint !== 'string' ||
            previousFingerprint === ''
          ) {
            if (current?.errorCode === INVALID_TOKEN_CODE) {
              transaction.update(ref, {
                tokenFingerprint,
                updatedAt: timestamp,
              });
              transaction.update(subscriptionRef, {
                active: false,
                disabledReason: INVALID_TOKEN_CODE,
                updatedAt: timestamp,
              });
              return {requiresTokenRenewal: true};
            }
            throw alreadyConsumed();
          }
          if (previousFingerprint === tokenFingerprint) throw alreadyConsumed();
        }
        if (existingDispatch.exists) {
          transaction.update(dispatchRef, {
            subscriptionId,
            requestedBy: callerUid,
            status: 'pending',
            tokenFingerprint,
            errorCode: null,
            updatedAt: timestamp,
          });
          return {
            dispatchId,
            subscriptionId,
            token,
          };
        }
        transaction.create(dispatchRef, {
          dispatchId,
          subscriptionId,
          requestedBy: callerUid,
          status: 'pending',
          tokenFingerprint,
          createdAt: timestamp,
          updatedAt: timestamp,
        });
        return {dispatchId, subscriptionId, token};
      });
      if (result.requiresTokenRenewal === true) {
        throw new TargetedPushTestError(
          'failed-precondition',
          'Le token Push invalide doit être renouvelé avant un nouveau test.',
        );
      }
      return result;
    },
    send(message) {
      return messaging.send(message);
    },
    complete({dispatchId}) {
      return firestore.collection('pushTestDispatches').doc(dispatchId).update({
        status: 'success',
        deliveredAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    },
    fail({dispatchId, subscriptionId, errorCode}) {
      const dispatchRef = firestore
          .collection('pushTestDispatches').doc(dispatchId);
      const subscriptionRef = firestore
          .collection('pushSubscriptions').doc(subscriptionId);
      return firestore.runTransaction(async (transaction) => {
        const timestamp = serverTimestamp();
        transaction.update(dispatchRef, {
          status: 'failed',
          errorCode,
          updatedAt: timestamp,
        });
        if (errorCode === INVALID_TOKEN_CODE) {
          transaction.update(subscriptionRef, {
            active: false,
            disabledReason: errorCode,
            updatedAt: timestamp,
          });
        }
      });
    },
  };
}

function requireCaller(callerUid) {
  if (typeof callerUid !== 'string' || callerUid === '') {
    throw new TargetedPushTestError(
      'unauthenticated',
      'Authentification requise.',
    );
  }
}

function validateRequest(data) {
  if (!isPlainObject(data) || !hasExactlyKeys(data, REQUIRED_FIELDS)) {
    throw invalidArgument();
  }
  if (
    data.confirmation !== SEND_CONFIRMATION &&
    data.confirmation !== CHECK_CONFIRMATION
  ) {
    throw invalidArgument();
  }
  const installationId = data.installationId;
  if (
    typeof installationId !== 'string' ||
    installationId === '' ||
    installationId.length > 160 ||
    installationId.trim() !== installationId ||
    installationId.includes('/')
  ) {
    throw invalidArgument();
  }
  return {confirmation: data.confirmation, installationId};
}

function requireServices(services) {
  if (
    !services ||
    typeof services.check !== 'function' ||
    typeof services.claim !== 'function' ||
    typeof services.send !== 'function' ||
    typeof services.complete !== 'function' ||
    typeof services.fail !== 'function'
  ) {
    throw new TargetedPushTestError(
      'internal',
      'Service Push test indisponible.',
    );
  }
}

export async function resolveActiveWebSubscription({
  transaction,
  firestore,
  callerUid,
  installationId,
}) {
  const administratorRef = firestore
      .collection('platformAdministrators').doc(callerUid);
  const administrator = await transaction.get(administratorRef);
  const authorized = await isPlatformAdministrator(callerUid, {
    getAdministrator: async () => administrator.exists
      ? administrator.data()
      : null,
  });
  if (!authorized) {
    throw new TargetedPushTestError(
      'permission-denied',
      'Accès Administrateur plateforme requis.',
    );
  }

  const subscriptions = await transaction.get(
      firestore.collection('pushSubscriptions')
          .where('installationId', '==', installationId),
  );
  const activeWebSubscriptions = subscriptions.docs.filter((snapshot) => {
    const value = snapshot.data();
    return value?.platform === 'web' && value?.active === true;
  });
  if (activeWebSubscriptions.length === 0) {
    throw new TargetedPushTestError(
      'not-found',
      'Aucun abonnement Push Web actif pour cette installation.',
    );
  }
  if (activeWebSubscriptions.length > 1) {
    throw new TargetedPushTestError(
      'failed-precondition',
      'Plusieurs abonnements Push Web actifs existent pour cette installation.',
    );
  }

  const subscription = activeWebSubscriptions[0];
  const value = subscription.data();
  const token = value?.token;
  const uid = value?.uid;
  const subscriptionId = subscription.id;
  if (
    typeof token !== 'string' ||
    token === '' ||
    typeof uid !== 'string' ||
    uid === '' ||
    value?.installationId !== installationId ||
    subscriptionId !== `${uid}_${installationId}`
  ) {
    throw new TargetedPushTestError(
      'failed-precondition',
      'L’abonnement Push n’est pas actif ou valide.',
    );
  }
  return {
    subscriptionId,
    subscriptionRef: subscription.ref,
    token,
    value,
    relatedSubscriptionIds: subscriptions.docs.map((snapshot) => snapshot.id),
  };
}

function invalidArgument() {
  return new TargetedPushTestError(
    'invalid-argument',
    'Requête de Push test invalide.',
  );
}

function normalizeErrorCode(error) {
  const code = typeof error?.code === 'string' ? error.code : 'unknown';
  return code.slice(0, 120);
}

function fingerprint(token) {
  return createHash('sha256').update(token).digest('hex');
}

function installationDispatchId(installationId) {
  return `installation-${fingerprint(installationId)}`;
}

function alreadyConsumed() {
  return new TargetedPushTestError(
    'resource-exhausted',
    'Une notification de test a déjà été demandée avec ce token.',
  );
}

function isPlainObject(value) {
  return value !== null &&
    typeof value === 'object' &&
    !Array.isArray(value) &&
    Object.getPrototypeOf(value) === Object.prototype;
}

function hasExactlyKeys(value, expected) {
  const keys = Object.keys(value).sort();
  return keys.length === expected.length &&
    keys.every((key, index) => key === expected[index]);
}
