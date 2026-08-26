import {createHash} from 'node:crypto';

import {FieldValue} from 'firebase-admin/firestore';

import {isPlatformAdministrator} from './platform_administration.js';

const REQUIRED_FIELDS = Object.freeze(['confirmation', 'subscriptionId']);
const CONFIRMATION = 'SEND_ONE_TEST_PUSH';
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
  const subscriptionId = validateRequest(data);
  requireServices(services);
  const claim = await services.claim({callerUid, subscriptionId});
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
  return {sent: true, subscriptionId: claim.subscriptionId};
}

export function targetedPushTestServices({
  firestore,
  messaging,
  serverTimestamp = () => FieldValue.serverTimestamp(),
}) {
  return {
    async claim({callerUid, subscriptionId}) {
      const administratorRef = firestore
          .collection('platformAdministrators').doc(callerUid);
      const subscriptionRef = firestore
          .collection('pushSubscriptions').doc(subscriptionId);
      const dispatchRef = firestore
          .collection('pushTestDispatches').doc(subscriptionId);
      const result = await firestore.runTransaction(async (transaction) => {
        const [administrator, subscription, existingDispatch] =
          await Promise.all([
            transaction.get(administratorRef),
            transaction.get(subscriptionRef),
            transaction.get(dispatchRef),
          ]);
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
        if (!subscription.exists) {
          throw new TargetedPushTestError(
            'not-found',
            'Abonnement Push introuvable.',
          );
        }
        const value = subscription.data();
        const token = value?.token;
        const installationId = value?.installationId;
        const uid = value?.uid;
        if (
          value?.platform !== 'web' ||
          typeof token !== 'string' ||
          token === '' ||
          typeof installationId !== 'string' ||
          installationId === '' ||
          typeof uid !== 'string' ||
          uid === '' ||
          subscriptionId !== `${uid}_${installationId}`
        ) {
          throw new TargetedPushTestError(
            'failed-precondition',
            'L’abonnement Push n’est pas actif ou valide.',
          );
        }
        const tokenFingerprint = fingerprint(token);
        const timestamp = serverTimestamp();
        if (existingDispatch.exists) {
          const current = existingDispatch.data();
          if (current?.status !== 'failed') {
            throw alreadyConsumed();
          }
          const previousFingerprint = current?.tokenFingerprint;
          if (
            typeof previousFingerprint !== 'string' ||
            previousFingerprint === ''
          ) {
            if (current?.errorCode === INVALID_TOKEN_CODE) {
              transaction.update(dispatchRef, {
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
          if (value?.active !== true) {
            throw new TargetedPushTestError(
              'failed-precondition',
              'L’abonnement Push doit être renouvelé avant un nouveau test.',
            );
          }
          transaction.update(dispatchRef, {
            requestedBy: callerUid,
            status: 'pending',
            tokenFingerprint,
            errorCode: null,
            updatedAt: timestamp,
          });
          return {
            dispatchId: subscriptionId,
            subscriptionId,
            token,
          };
        }
        if (value?.active !== true) {
          throw new TargetedPushTestError(
            'failed-precondition',
            'L’abonnement Push n’est pas actif ou valide.',
          );
        }
        transaction.create(dispatchRef, {
          dispatchId: subscriptionId,
          subscriptionId,
          requestedBy: callerUid,
          status: 'pending',
          tokenFingerprint,
          createdAt: timestamp,
          updatedAt: timestamp,
        });
        return {dispatchId: subscriptionId, subscriptionId, token};
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
  if (data.confirmation !== CONFIRMATION) throw invalidArgument();
  const subscriptionId = data.subscriptionId;
  if (
    typeof subscriptionId !== 'string' ||
    subscriptionId === '' ||
    subscriptionId.length > 400 ||
    subscriptionId.includes('/')
  ) {
    throw invalidArgument();
  }
  return subscriptionId;
}

function requireServices(services) {
  if (
    !services ||
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
