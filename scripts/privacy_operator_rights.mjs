#!/usr/bin/env node
// Operator-assisted rights work. Run `review` first; apply requires the fresh
// manifest digest and a separately recorded human authorization. No implicit
// production mutation occurs. Backups and exports are AES-256-GCM encrypted.
import {createCipheriv, createHash, randomBytes} from 'node:crypto';
import {mkdir, writeFile} from 'node:fs/promises';
import {resolve} from 'node:path';
import {GeoPoint, Timestamp} from 'firebase-admin/firestore';
import {buildSubjectReview} from './privacy_subject_review.mjs';

const ownRoots = ['volunteers', 'professionalTargeting',
  'notificationPreferences', 'professionalRegistrationPermits',
  'termsAcceptances'];
const related = [
  ['professionalAdmissions', 'uid'], ['pushSubscriptions', 'uid'],
  ['engagements', 'volunteerId'], ['notificationDeliveries', 'recipientUid'],
  ['notifications', 'recipientUid'], ['professionalInvitations', 'consumedBy'],
  ['professionalInvitations', 'preparedBy'],
];
const rectifiableFields = new Set([
  'phone', 'professionalAddressLine1', 'professionalAddressLine2',
  'professionalPostalCode', 'professionalCity', 'professionalCountryCode',
  'cptsId', 'cptsLabel',
]);

export function encodeFirestoreValue(value) {
  if (value instanceof Timestamp) return {$timestamp: [value.seconds, value.nanoseconds]};
  if (value instanceof GeoPoint) return {$geopoint: [value.latitude, value.longitude]};
  if (value instanceof Date) return {$date: value.toISOString()};
  if (Buffer.isBuffer(value)) return {$bytes: value.toString('base64')};
  if (Array.isArray(value)) return value.map(encodeFirestoreValue);
  if (value && typeof value === 'object') return Object.fromEntries(
    Object.keys(value).sort().map((key) => [key, encodeFirestoreValue(value[key])]));
  return value;
}

export function decodeFirestoreValue(value) {
  if (Array.isArray(value)) return value.map(decodeFirestoreValue);
  if (value && typeof value === 'object') {
    if ('$timestamp' in value) return new Timestamp(...value.$timestamp);
    if ('$geopoint' in value) return new GeoPoint(...value.$geopoint);
    if ('$date' in value) return new Date(value.$date);
    if ('$bytes' in value) return Buffer.from(value.$bytes, 'base64');
    return Object.fromEntries(Object.entries(value).map(([key, item]) =>
      [key, decodeFirestoreValue(item)]));
  }
  return value;
}

export function subjectManifest({uid, caseId, action, documents, authRecord}) {
  const review = buildSubjectReview({uid, documents, authRecord});
  const paths = documents.map((item) => ({path: item.path,
    updateTime: item.updateTime ?? null,
    hash: createHash('sha256').update(JSON.stringify(encodeFirestoreValue(item.data)))
      .digest('hex')})).sort((a, b) => a.path.localeCompare(b.path));
  const fingerprint = createHash('sha256').update(JSON.stringify({
    uid, caseId, action, paths, authUid: authRecord?.uid ?? null,
  })).digest('hex');
  return {format: 'mobsante-rights-manifest-v1', caseId, action,
    uidHash: createHash('sha256').update(uid).digest('hex'), fingerprint,
    documentCount: paths.length, paths, review};
}

export function assertExecutableErasure(manifest) {
  const review = manifest.review;
  if (review.sharedReferences.length || review.erasure.anonymizeCandidates.length
    || review.erasure.quotaRecalculationMissions.length
    || review.erasure.retainedForReview.length || review.partial !== true) {
    throw Error('MANUAL_SHARED_REFERENCE_REVIEW_REQUIRED');
  }
  const covered = new Set(review.erasure.deleteCandidates.map((item) => item.path));
  if (covered.size !== manifest.documentCount) {
    throw Error('UNCLASSIFIED_DOCUMENTS_REQUIRE_REVIEW');
  }
  return [...covered].sort();
}

async function snapshotSubject(db, uid) {
  const found = new Map();
  const add = (doc) => {
    if (doc.exists) found.set(doc.ref.path, {path: doc.ref.path,
      data: doc.data(), updateTime: doc.updateTime?.toDate().toISOString()});
  };
  await Promise.all(ownRoots.map(async (root) => add(await db.collection(root).doc(uid).get())));
  await Promise.all(related.map(async ([root, field]) => {
    const query = await db.collection(root).where(field, '==', uid).get();
    query.docs.forEach(add);
  }));
  return [...found.values()].sort((a, b) => a.path.localeCompare(b.path));
}

async function encryptedWrite(filePath, value, key) {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const plain = Buffer.from(JSON.stringify(value));
  const ciphertext = Buffer.concat([cipher.update(plain), cipher.final()]);
  await writeFile(filePath, JSON.stringify({format: 'aes-256-gcm-v1',
    iv: iv.toString('base64'), tag: cipher.getAuthTag().toString('base64'),
    ciphertext: ciphertext.toString('base64')}), {flag: 'wx', mode: 0o600});
}

async function main() {
  const args = Object.fromEntries(process.argv.slice(2).reduce((pairs, item, index, all) => {
    if (index % 2 === 0) pairs.push([item, all[index + 1]]);
    return pairs;
  }, []));
  const action = args['--action'];
  const projectId = args['--project'];
  const uid = args['--uid'];
  const caseId = args['--case'];
  const outputDir = args['--out'];
  if (!['review', 'access', 'export', 'rectify', 'erase', 'close'].includes(action)
    || !/^[a-z0-9-]+$/.test(projectId ?? '')
    || !/^[A-Za-z0-9_-]{1,128}$/.test(uid ?? '')
    || !/^[A-Za-z0-9_-]{1,80}$/.test(caseId ?? '')
    || !outputDir || args['--identity-verified'] !== 'yes') {
    throw Error('Usage: --action review|access|export|rectify|erase|close --project ID --uid UID --case CASE --out PRIVATE_DIR --identity-verified yes [--confirm FINGERPRINT] [--field FIELD --value VALUE]');
  }
  const keyHex = process.env.MOBSANTE_RIGHTS_BACKUP_KEY_HEX;
  if (!/^[a-fA-F0-9]{64}$/.test(keyHex ?? '')) {
    throw Error('MOBSANTE_RIGHTS_BACKUP_KEY_HEX must be a 32-byte hex key');
  }
  const key = Buffer.from(keyHex, 'hex');
  const {initializeApp, applicationDefault} = await import('firebase-admin/app');
  const {getFirestore, FieldValue} = await import('firebase-admin/firestore');
  const {getAuth} = await import('firebase-admin/auth');
  initializeApp({projectId,
    ...(process.env.FIRESTORE_EMULATOR_HOST ? {} : {credential: applicationDefault()})});
  const db = getFirestore();
  const auth = getAuth();
  const user = await auth.getUser(uid);
  const authRecord = {uid: user.uid, email: user.email ?? null,
    createdAt: user.metadata.creationTime, lastSignInAt: user.metadata.lastSignInTime,
    disabled: user.disabled};
  const documents = await snapshotSubject(db, uid);
  const manifest = subjectManifest({uid, caseId, action, documents, authRecord});
  const destination = resolve(outputDir);
  await mkdir(destination, {recursive: true, mode: 0o700});
  const name = `${caseId}-${Date.now()}`;
  await encryptedWrite(resolve(destination, `${name}-preimage.enc.json`),
    {uid, projectId, authRecord, documents: documents.map((item) =>
      ({...item, data: encodeFirestoreValue(item.data)}))}, key);
  if (action === 'access' || action === 'export') {
    await encryptedWrite(resolve(destination, `${name}-subject-export.enc.json`),
      manifest.review, key);
  }
  const safeManifest = {...manifest,
    paths: manifest.paths.map((item) => ({
      pathHash: createHash('sha256').update(item.path).digest('hex'),
      updateTime: item.updateTime, hash: item.hash,
    })),
    review: {
    partial: manifest.review.partial,
    deleteCandidates: manifest.review.erasure.deleteCandidates.length,
    sharedReferences: manifest.review.sharedReferences.length,
    quotaRecalculationMissions: manifest.review.erasure.quotaRecalculationMissions.length,
  }};
  await writeFile(resolve(destination, `${name}-manifest.json`),
    JSON.stringify(safeManifest, null, 2), {flag: 'wx', mode: 0o600});
  if (['review', 'access', 'export'].includes(action)
    || !args['--confirm']) {
    process.stdout.write(JSON.stringify({action, caseId, fingerprint: manifest.fingerprint,
      documentCount: documents.length, partial: true, backupCreated: true,
      applied: false}) + '\n');
    return;
  }
  if (args['--confirm'] !== manifest.fingerprint
    || process.env.MOBSANTE_RIGHTS_APPLY_AUTHORIZED !== 'yes') {
    throw Error('APPLY_REQUIRES_FRESH_MANIFEST_AND_HUMAN_AUTHORIZATION');
  }
  if (action === 'rectify') {
    const field = args['--field'];
    const value = args['--value'];
    if (!rectifiableFields.has(field) || typeof value !== 'string'
      || value.length > 255 || !documents.some((item) => item.path === `volunteers/${uid}`)) {
      throw Error('RECTIFICATION_FIELD_INVALID');
    }
    await db.collection('volunteers').doc(uid).update({[field]: value,
      updatedAt: FieldValue.serverTimestamp()});
  } else if (action === 'close') {
    for (const item of documents.filter((doc) => doc.path.startsWith('professionalAdmissions/'))) {
      await db.doc(item.path).update({status: 'revoked', revokedAt: FieldValue.serverTimestamp()});
    }
    for (const item of documents.filter((doc) => doc.path.startsWith('pushSubscriptions/'))) {
      await db.doc(item.path).update({active: false, disabledReason: 'account_closed',
        updatedAt: FieldValue.serverTimestamp()});
    }
    await auth.updateUser(uid, {disabled: true}); // Auth last.
  } else {
    const paths = assertExecutableErasure(manifest);
    for (const path of paths) await db.doc(path).delete();
    await auth.deleteUser(uid); // Auth last.
  }
  process.stdout.write(JSON.stringify({action, caseId, fingerprint: manifest.fingerprint,
    backupCreated: true, completed: true, authLast: true}) + '\n');
}

if (process.argv[1]?.endsWith('/privacy_operator_rights.mjs')) {
  main().catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
}
