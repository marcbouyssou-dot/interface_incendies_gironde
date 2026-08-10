export const platformAdministratorBootstrapProjectId = 'mobilisation-sante';
export const platformAdministratorBootstrapEmailEnvironmentKey =
  'PLATFORM_ADMIN_BOOTSTRAP_EMAIL';
export const platformAdministratorBootstrapUidEnvironmentKey =
  'PLATFORM_ADMIN_BOOTSTRAP_UID';
export const platformAdministratorBootstrapActor = 'system:v6-bootstrap';

export class PlatformAdministratorConflictError extends Error {
  constructor(path, detail) {
    super(`Document incompatible: ${path} (${detail}).`);
    this.name = 'PlatformAdministratorConflictError';
    this.path = path;
  }
}

export function resolvePlatformAdministratorExecution({
  environment,
  arguments: commandArguments,
}) {
  const dryRunCount = commandArguments.filter(
    (argument) => argument === '--dry-run',
  ).length;
  const applyCount = commandArguments.filter(
    (argument) => argument === '--apply',
  ).length;
  const projectIndexes = commandArguments.flatMap((argument, index) =>
    argument === '--project' ? [index] : []);
  const recognizedIndexes = new Set();
  for (const index of projectIndexes) {
    recognizedIndexes.add(index);
    recognizedIndexes.add(index + 1);
  }
  commandArguments.forEach((argument, index) => {
    if (argument === '--dry-run' || argument === '--apply') {
      recognizedIndexes.add(index);
    }
  });
  const hasUnknownArgument = commandArguments.some(
    (_, index) => !recognizedIndexes.has(index),
  );
  if (
    dryRunCount + applyCount !== 1
    || projectIndexes.length !== 1
    || hasUnknownArgument
  ) {
    throw new Error(
      'Utiliser exactement: --project mobilisation-sante '
      + '(--dry-run ou --apply).',
    );
  }
  const projectIndex = projectIndexes[0];
  const projectId = commandArguments[projectIndex + 1];
  if (projectId !== platformAdministratorBootstrapProjectId) {
    throw new Error(
      `Projet Firebase refusé: ${projectId || '<absent>'}. `
      + `Projet attendu: ${platformAdministratorBootstrapProjectId}.`,
    );
  }
  const targetEmail = environment[
    platformAdministratorBootstrapEmailEnvironmentKey
  ];
  const targetUid = environment[platformAdministratorBootstrapUidEnvironmentKey];
  const hasEmail = typeof targetEmail === 'string' && targetEmail.length > 0;
  const hasUid = typeof targetUid === 'string' && targetUid.length > 0;
  if (hasEmail === hasUid) {
    throw new Error(
      `Définir exactement une variable parmi `
      + `${platformAdministratorBootstrapEmailEnvironmentKey} et `
      + `${platformAdministratorBootstrapUidEnvironmentKey}.`,
    );
  }
  if (
    hasEmail
    && (
      targetEmail.trim() !== targetEmail
      || targetEmail.length > 254
      || !targetEmail.includes('@')
    )
  ) {
    throw new Error(
      `${platformAdministratorBootstrapEmailEnvironmentKey} est invalide.`,
    );
  }
  if (hasUid) {
    assertValidUid(targetUid);
  }
  return {
    mode: applyCount === 1 ? 'apply' : 'dry-run',
    projectId,
    targetEmail: hasEmail ? targetEmail : null,
    targetUid: hasUid ? targetUid : null,
  };
}

export async function resolvePlatformAdministratorUid({auth, email, uid}) {
  if (
    typeof auth?.getUserByEmail !== 'function'
    || typeof auth?.getUser !== 'function'
  ) {
    throw new TypeError('Firebase Auth Admin est requis.');
  }
  const user = uid === null
    ? await auth.getUserByEmail(email)
    : await auth.getUser(uid);
  if (
    user === null
    || typeof user !== 'object'
    || typeof user.uid !== 'string'
    || user.uid.length === 0
    || user.uid.length > 128
    || user.uid.includes('/')
    || user.disabled === true
    || (uid !== null && user.uid !== uid)
    || (
      email !== null
      && (
        typeof user.email !== 'string'
        || user.email.toLowerCase() !== email.toLowerCase()
      )
    )
  ) {
    throw new Error('Compte Firebase cible invalide ou désactivé.');
  }
  return user.uid;
}

export function platformAdministratorDocumentPath(uid) {
  assertValidUid(uid);
  return `platformAdministrators/${uid}`;
}

export function buildPlatformAdministratorPlan({
  uid,
  existingDocument,
  isTimestamp = isFirestoreTimestamp,
}) {
  const path = platformAdministratorDocumentPath(uid);
  if (existingDocument === null) {
    return {path, action: 'create'};
  }
  assertCompatibleDocument({path, uid, existingDocument, isTimestamp});
  return {path, action: 'unchanged'};
}

export function materializePlatformAdministratorDocument({
  uid,
  serverTimestamp,
}) {
  if (typeof serverTimestamp !== 'function') {
    throw new TypeError('Un timestamp serveur est requis.');
  }
  const timestamp = serverTimestamp();
  return {
    path: platformAdministratorDocumentPath(uid),
    data: {
      uid,
      active: true,
      createdAt: timestamp,
      createdBy: platformAdministratorBootstrapActor,
      updatedAt: timestamp,
    },
  };
}

export async function runPlatformAdministratorBootstrap({
  mode,
  uid,
  readDocument,
  createDocument,
  serverTimestamp,
  isTimestamp = isFirestoreTimestamp,
}) {
  if (!['dry-run', 'apply'].includes(mode)) {
    throw new Error('Mode de bootstrap invalide.');
  }
  if (typeof readDocument !== 'function') {
    throw new TypeError('Le reader Admin est requis.');
  }
  const path = platformAdministratorDocumentPath(uid);
  const existingDocument = await readDocument(path);
  const plan = buildPlatformAdministratorPlan({
    uid,
    existingDocument,
    isTimestamp,
  });
  if (mode === 'dry-run' || plan.action === 'unchanged') {
    return {...plan, mode, writes: 0};
  }
  if (typeof createDocument !== 'function') {
    throw new TypeError('Le writer Admin est requis en mode apply.');
  }
  const creation = materializePlatformAdministratorDocument({
    uid,
    serverTimestamp,
  });
  await createDocument(creation);
  return {...plan, mode, writes: 1};
}

function assertCompatibleDocument({
  path,
  uid,
  existingDocument,
  isTimestamp,
}) {
  if (!isPlainObject(existingDocument)) {
    throw new PlatformAdministratorConflictError(path, 'structure invalide');
  }
  const expectedKeys = [
    'active',
    'createdAt',
    'createdBy',
    'uid',
    'updatedAt',
  ];
  const actualKeys = Object.keys(existingDocument).sort();
  if (
    actualKeys.length !== expectedKeys.length
    || expectedKeys.some((key, index) => key !== actualKeys[index])
  ) {
    throw new PlatformAdministratorConflictError(path, 'champs différents');
  }
  const expectedValues = {
    uid,
    active: true,
    createdBy: platformAdministratorBootstrapActor,
  };
  for (const [field, expected] of Object.entries(expectedValues)) {
    if (existingDocument[field] !== expected) {
      throw new PlatformAdministratorConflictError(
        path,
        `valeur différente pour ${field}`,
      );
    }
  }
  for (const field of ['createdAt', 'updatedAt']) {
    if (!isTimestamp(existingDocument[field])) {
      throw new PlatformAdministratorConflictError(
        path,
        `timestamp invalide pour ${field}`,
      );
    }
  }
}

function assertValidUid(uid) {
  if (
    typeof uid !== 'string'
    || uid.length === 0
    || uid.length > 128
    || uid.includes('/')
  ) {
    throw new Error('UID Firebase cible invalide.');
  }
}

function isFirestoreTimestamp(value) {
  return value !== null
    && typeof value === 'object'
    && typeof value.toDate === 'function';
}

function isPlainObject(value) {
  return value !== null
    && typeof value === 'object'
    && !Array.isArray(value);
}
