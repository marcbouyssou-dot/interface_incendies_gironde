import {isPlatformAdministrator} from './platform_administration.js';
import {resolveActiveWebSubscription} from './targeted_push_test.js';

const IDENTICAL = 'IDENTIQUE';
const DIFFERENT = 'DIFFÉRENT';
const INDETERMINATE = 'INDÉTERMINÉ';
const COMPARISONS = new Set([IDENTICAL, DIFFERENT, INDETERMINATE]);
const REQUIRED_FIELDS = Object.freeze([
  'getTokenVsPersistInput',
  'installationId',
  'persistInputVsFirestoreAfterCommit',
]);

export class FcmChainDiagnosticError extends Error {
  constructor(code, message, options = {}) {
    super(message, options);
    this.name = 'FcmChainDiagnosticError';
    this.code = code;
  }
}

export async function diagnoseFcmChain({callerUid, data, services}) {
  requireCaller(callerUid);
  const request = validateRequest(data);
  requireServices(services);
  const authorized = await services.isPlatformAdministrator(callerUid);
  if (!authorized) {
    throw new FcmChainDiagnosticError(
      'permission-denied',
      'Accès Administrateur plateforme requis.',
    );
  }

  const result = indeterminateResult();
  result.GETTOKEN_VS_PERSIST_INPUT = request.getTokenVsPersistInput;
  let activeSubscriptions;
  try {
    activeSubscriptions = await services.readActive(request.installationId);
  } catch (_) {
    return result;
  }
  if (!Array.isArray(activeSubscriptions)) return result;
  if (activeSubscriptions.length === 0) {
    result.ACTIVE_SUBSCRIPTIONS_FOR_INSTALLATION = '0';
    return result;
  }
  if (activeSubscriptions.length > 1) {
    result.ACTIVE_SUBSCRIPTIONS_FOR_INSTALLATION = '>1';
    return result;
  }

  const firestoreTarget = targetFromCandidate(activeSubscriptions[0]);
  if (firestoreTarget == null) return result;
  result.ACTIVE_SUBSCRIPTIONS_FOR_INSTALLATION = '1';
  result.PERSIST_INPUT_VS_FIRESTORE =
    request.persistInputVsFirestoreAfterCommit;

  try {
    const preflightTarget = await services.resolve({
      callerUid,
      installationId: request.installationId,
    });
    result.FIRESTORE_VS_PREFLIGHT_TARGET = compareTargets(
        firestoreTarget,
        preflightTarget,
    );
    const sendTarget = await services.resolve({
      callerUid,
      installationId: request.installationId,
    });
    result.PREFLIGHT_TARGET_VS_SEND_TARGET = compareTargets(
        preflightTarget,
        sendTarget,
    );
  } catch (_) {
    // Any resolver ambiguity stays indeterminate and never triggers a write.
  }
  return result;
}

export function fcmChainDiagnosticServices({firestore}) {
  return {
    async isPlatformAdministrator(callerUid) {
      const administrator = await firestore
          .collection('platformAdministrators').doc(callerUid).get();
      return isPlatformAdministrator(callerUid, {
        getAdministrator: async () => administrator.exists
          ? administrator.data()
          : null,
      });
    },
    async readActive(installationId) {
      const subscriptions = await firestore.collection('pushSubscriptions')
          .where('installationId', '==', installationId).get();
      return subscriptions.docs
          .map((snapshot) => ({id: snapshot.id, value: snapshot.data()}))
          .filter(({value}) =>
            value?.platform === 'web' && value?.active === true,
          );
    },
    resolve({callerUid, installationId}) {
      return firestore.runTransaction((transaction) =>
        resolveActiveWebSubscription({
          transaction,
          firestore,
          callerUid,
          installationId,
        }),
      );
    },
  };
}

function targetFromCandidate(candidate) {
  const id = candidate?.id;
  const token = candidate?.value?.token;
  const uid = candidate?.value?.uid;
  const installationId = candidate?.value?.installationId;
  if (
    typeof id !== 'string' ||
    id === '' ||
    typeof token !== 'string' ||
    token === '' ||
    typeof uid !== 'string' ||
    uid === '' ||
    typeof installationId !== 'string' ||
    installationId === '' ||
    id !== `${uid}_${installationId}`
  ) {
    return null;
  }
  return {id, token};
}

function compareTargets(left, right) {
  const leftTarget = normalizeTarget(left);
  const rightTarget = normalizeTarget(right);
  if (leftTarget == null || rightTarget == null) return INDETERMINATE;
  return leftTarget.id === rightTarget.id &&
    leftTarget.token === rightTarget.token
    ? IDENTICAL
    : DIFFERENT;
}

function normalizeTarget(value) {
  const id = value?.subscriptionId ?? value?.id;
  const token = value?.token;
  if (
    typeof id !== 'string' ||
    id === '' ||
    typeof token !== 'string' ||
    token === ''
  ) {
    return null;
  }
  return {id, token};
}

function validateRequest(data) {
  if (!isPlainObject(data) || !hasExactlyKeys(data, REQUIRED_FIELDS)) {
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
  if (
    !COMPARISONS.has(data.getTokenVsPersistInput) ||
    !COMPARISONS.has(data.persistInputVsFirestoreAfterCommit)
  ) {
    throw invalidArgument();
  }
  return {
    installationId,
    getTokenVsPersistInput: data.getTokenVsPersistInput,
    persistInputVsFirestoreAfterCommit:
      data.persistInputVsFirestoreAfterCommit,
  };
}

function requireCaller(callerUid) {
  if (typeof callerUid !== 'string' || callerUid === '') {
    throw new FcmChainDiagnosticError(
      'unauthenticated',
      'Authentification requise.',
    );
  }
}

function requireServices(services) {
  if (
    !services ||
    typeof services.isPlatformAdministrator !== 'function' ||
    typeof services.readActive !== 'function' ||
    typeof services.resolve !== 'function'
  ) {
    throw new FcmChainDiagnosticError(
      'internal',
      'Diagnostic FCM indisponible.',
    );
  }
}

function indeterminateResult() {
  return {
    GETTOKEN_VS_PERSIST_INPUT: INDETERMINATE,
    PERSIST_INPUT_VS_FIRESTORE: INDETERMINATE,
    FIRESTORE_VS_PREFLIGHT_TARGET: INDETERMINATE,
    PREFLIGHT_TARGET_VS_SEND_TARGET: INDETERMINATE,
    ACTIVE_SUBSCRIPTIONS_FOR_INSTALLATION: INDETERMINATE,
  };
}

function invalidArgument() {
  return new FcmChainDiagnosticError(
    'invalid-argument',
    'Requête de diagnostic FCM invalide.',
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
