import {createHash} from 'node:crypto';

import {isPlatformAdministrator} from './platform_administration.js';

const IDENTICAL = 'IDENTIQUE';
const DIFFERENT = 'DIFFÉRENT';
const INDETERMINATE = 'INDÉTERMINÉ';
const REQUIRED_FIELDS = Object.freeze(['installationId', 'postTokenSha256']);
const FINGERPRINT_PATTERN = /^[a-f0-9]{64}$/;

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

  const state = await services.read(request.installationId);
  return compareFcmChain({
    installationId: request.installationId,
    postTokenSha256: request.postTokenSha256,
    subscriptions: state.subscriptions,
    dispatch: state.dispatch,
  });
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
    async read(installationId) {
      const subscriptions = await firestore.collection('pushSubscriptions')
          .where('installationId', '==', installationId).get();
      const dispatch = await firestore.collection('pushTestDispatches')
          .doc(installationDispatchId(installationId)).get();
      return {
        subscriptions: subscriptions.docs.map((snapshot) => ({
          id: snapshot.id,
          value: snapshot.data(),
        })),
        dispatch: dispatch.exists ? dispatch.data() : null,
      };
    },
  };
}

export function compareFcmChain({
  installationId,
  postTokenSha256,
  subscriptions,
  dispatch,
}) {
  const result = indeterminateResult();
  if (!Array.isArray(subscriptions)) return result;
  const candidates = subscriptions.filter(({value}) =>
    value?.platform === 'web',
  );
  if (candidates.length !== 1) return result;

  const candidate = candidates[0];
  const token = candidate?.value?.token;
  const uid = candidate?.value?.uid;
  const storedInstallationId = candidate?.value?.installationId;
  const subscriptionId = candidate?.id;
  if (
    typeof token !== 'string' ||
    token === '' ||
    typeof uid !== 'string' ||
    uid === '' ||
    typeof storedInstallationId !== 'string' ||
    storedInstallationId === '' ||
    typeof subscriptionId !== 'string' ||
    subscriptionId === ''
  ) {
    return result;
  }

  const firestoreFingerprint = fingerprint(token);
  if (FINGERPRINT_PATTERN.test(postTokenSha256 ?? '')) {
    result.POST_TOKEN_VS_FIRESTORE = postTokenSha256 === firestoreFingerprint
      ? IDENTICAL
      : DIFFERENT;
  }

  const dispatchFingerprint = dispatch?.tokenFingerprint;
  if (FINGERPRINT_PATTERN.test(dispatchFingerprint ?? '')) {
    result.FIRESTORE_SHA256_VS_DISPATCH_SHA256 =
      dispatchFingerprint === firestoreFingerprint ? IDENTICAL : DIFFERENT;
  }

  const expectedSubscriptionId = `${uid}_${installationId}`;
  const dispatchSubscriptionId = dispatch?.subscriptionId;
  if (
    storedInstallationId !== installationId ||
    subscriptionId !== expectedSubscriptionId ||
    (typeof dispatchSubscriptionId === 'string' &&
      dispatchSubscriptionId !== subscriptionId)
  ) {
    result.INSTALLATION_VS_TARGET_RESOLVED = DIFFERENT;
  } else if (dispatch == null) {
    result.INSTALLATION_VS_TARGET_RESOLVED = INDETERMINATE;
  } else if (typeof dispatchSubscriptionId === 'string') {
    result.INSTALLATION_VS_TARGET_RESOLVED = IDENTICAL;
  }
  return result;
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
  const postTokenSha256 = data.postTokenSha256;
  if (
    postTokenSha256 !== null &&
    (typeof postTokenSha256 !== 'string' ||
      !FINGERPRINT_PATTERN.test(postTokenSha256))
  ) {
    throw invalidArgument();
  }
  return {installationId, postTokenSha256};
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
    typeof services.read !== 'function'
  ) {
    throw new FcmChainDiagnosticError(
      'internal',
      'Diagnostic FCM indisponible.',
    );
  }
}

function indeterminateResult() {
  return {
    POST_TOKEN_VS_FIRESTORE: INDETERMINATE,
    FIRESTORE_SHA256_VS_DISPATCH_SHA256: INDETERMINATE,
    INSTALLATION_VS_TARGET_RESOLVED: INDETERMINATE,
  };
}

function fingerprint(value) {
  return createHash('sha256').update(value).digest('hex');
}

function installationDispatchId(installationId) {
  return `installation-${fingerprint(installationId)}`;
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
